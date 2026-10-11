using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using BepInEx.Logging;
using UnityEngine;
using UnityEngine.Networking;

namespace Lembitu.Updater;

/// <summary>Finds the newest published Pack, works out which files differ from the installed one,
/// fetches only those out of the release zip and stages them with a plan. Nothing in the game
/// folder changes here: the patcher applies the plan at the next start, before any mod loads.</summary>
internal sealed class PackUpdater
{
    private const string TagPrefix = "client-pack-";
    // Requests to the zip are grouped while the gap between wanted entries stays small.
    private const long MaxGap = 1 << 20, MaxGroup = 32L << 20;

    private readonly string feed;
    private readonly ManualLogSource log;
    private readonly Notice notice;
    private string target = "", releasePage = "";

    internal PackUpdater(string feed, ManualLogSource log, Notice notice)
    {
        this.feed = feed;
        this.log = log;
        this.notice = notice;
    }

    internal IEnumerator Run()
    {
        IEnumerator steps = Steps();
        while (true)
        {
            object? current;
            try
            {
                if (!steps.MoveNext()) yield break;
                current = steps.Current;
            }
            catch (Exception error)
            {
                string reason = (error is AggregateException { InnerException: { } inner } ? inner : error).Message;
                if (target.Length == 0)
                {
                    // Offline, rate-limited or GitHub down: the game still works, so this stays in the log.
                    log.LogWarning("Pack update check failed: " + reason);
                }
                else
                {
                    log.LogError($"Pack update to {target} failed: {reason}");
                    notice.Fail($"Lembitu Pack {target} could not be downloaded ({reason}). Install it by hand from {releasePage}");
                }
                yield break;
            }
            yield return current;
        }
    }

    private IEnumerator Steps()
    {
        string root = PackFiles.PackRoot();
        string stage = PackFiles.Under(root, PackFiles.StageDir);
        ReportPreviousStart(stage);
        string installedFile = PackFiles.Under(root, PackFiles.VersionFile);
        string installed = File.Exists(installedFile) ? File.ReadAllText(installedFile).Trim() : "";
        log.LogInfo("Installed Pack: " + (installed.Length == 0 ? "unknown (no version file)" : installed));

        UnityWebRequest listing = Get(feed);
        yield return listing.SendWebRequest();
        Release[] releases = Release.ListFrom(Encoding.UTF8.GetString(Body(listing)));
        log.LogInfo($"Pack update check: {releases.Length} release(s) listed");
        Release? latest = releases.FirstOrDefault(r => !r.draft && !r.prerelease && r.tag_name.StartsWith(TagPrefix, StringComparison.Ordinal));
        if (latest == null)
        {
            log.LogWarning("Pack update check: no published Pack release");
            yield break;
        }
        string label = latest.tag_name.Substring(TagPrefix.Length);
        if (!Regex.IsMatch(label, "^[A-Za-z0-9._-]+$")) throw new InvalidDataException("unexpected release tag " + latest.tag_name);
        if (label == installed)
        {
            log.LogInfo($"Pack {label} is the newest release");
            yield break;
        }
        target = label;
        releasePage = latest.html_url;
        string planFile = Path.Combine(stage, PackFiles.PlanFile);
        if (File.Exists(planFile) && UpdatePlan.Parse(File.ReadAllText(planFile)).Version == label)
        {
            log.LogInfo($"Pack {label} is already staged");
            notice.Ready(label);
            yield break;
        }
        log.LogInfo($"Pack {label} is published; preparing the update");
        notice.Progress($"Lembitu Pack {label} is out. Checking which files changed…");

        Asset zip = AssetOf(latest, $"lembitu-client-pack-{label}.zip");
        Asset inventory = AssetOf(latest, $"lembitu-client-pack-{label}.versions.txt");
        UnityWebRequest nextRequest = Get(inventory.browser_download_url);
        yield return nextRequest.SendWebRequest();
        Dictionary<string, string> next = PackFiles.ParseInventory(Verified(nextRequest, inventory));

        Dictionary<string, string>? before = null;
        Release? current = installed.Length == 0 ? null : releases.FirstOrDefault(r => r.tag_name == TagPrefix + installed);
        if (current != null)
        {
            Asset old = AssetOf(current, $"lembitu-client-pack-{installed}.versions.txt");
            UnityWebRequest beforeRequest = Get(old.browser_download_url);
            yield return beforeRequest.SendWebRequest();
            before = PackFiles.ParseInventory(Verified(beforeRequest, old));
        }
        else log.LogWarning("The installed Pack's release is not listed; every differing file is replaced and nothing is removed");

        string[] leftOut = PackFiles.LeftOut(root);
        if (leftOut.Length > 0) log.LogInfo("Left out on purpose, never restored: " + string.Join(", ", leftOut));
        Task<UpdatePlan> planning = Task.Run(() => UpdatePlan.Compute(label, next, before, path =>
        {
            string file = PackFiles.Under(root, path);
            return File.Exists(file) ? PackFiles.Sha256File(file) : null;
        }, leftOut));
        while (!planning.IsCompleted) yield return null;
        UpdatePlan plan = planning.Result;
        log.LogInfo($"Pack {label}: {plan.Writes.Count} file(s) to write, {plan.Deletes.Count} to remove");

        string staged = Path.Combine(stage, PackFiles.StagedDir);
        if (Directory.Exists(staged)) Directory.Delete(staged, true);
        if (File.Exists(planFile)) File.Delete(planFile);
        Directory.CreateDirectory(staged);

        long downloaded = 0;
        if (plan.Writes.Count > 0)
        {
            if (zip.size <= 0) throw new InvalidDataException("the release lists no size for its zip");
            long tailFrom = Math.Max(0, zip.size - RemoteZip.EndRecordSearch);
            byte[] tail = null!;
            foreach (object step in Fetch(zip.browser_download_url, tailFrom, zip.size - 1, bytes => tail = bytes)) yield return step;
            var (directoryOffset, directorySize) = RemoteZip.FindCentralDirectory(tail);
            byte[] directory = null!;
            foreach (object step in Fetch(zip.browser_download_url, directoryOffset, directoryOffset + directorySize - 1, bytes => directory = bytes)) yield return step;
            Dictionary<string, RemoteZip.Entry> entries = RemoteZip.ReadCentralDirectory(directory);

            var wanted = plan.Writes.Select(w => entries.TryGetValue(w.Path, out RemoteZip.Entry? entry)
                    ? (w.Sha, w.Path, Entry: entry)
                    : throw new InvalidDataException("the zip lacks " + w.Path))
                .OrderBy(w => w.Entry.LocalOffset).ToList();
            var groups = new List<List<(string Sha, string Path, RemoteZip.Entry Entry)>>();
            long groupEnd = -1, groupStart = 0;
            foreach (var item in wanted)
            {
                long end = Math.Min(directoryOffset, item.Entry.LocalOffset + RemoteZip.SpanEstimate(item.Entry));
                if (groups.Count == 0 || item.Entry.LocalOffset - groupEnd > MaxGap || end - groupStart > MaxGroup)
                {
                    groups.Add(new());
                    groupStart = item.Entry.LocalOffset;
                }
                groups[groups.Count - 1].Add(item);
                groupEnd = Math.Max(groupEnd, end);
            }

            int done = 0;
            foreach (var group in groups)
            {
                long from = group[0].Entry.LocalOffset;
                long to = group.Max(g => Math.Min(directoryOffset, g.Entry.LocalOffset + RemoteZip.SpanEstimate(g.Entry))) - 1;
                byte[] buffer = null!;
                foreach (object step in Fetch(zip.browser_download_url, from, to, bytes => buffer = bytes)) yield return step;
                downloaded += buffer.Length;
                foreach (var (sha, path, entry) in group)
                {
                    byte[]? data = RemoteZip.Extract(buffer, (int)(entry.LocalOffset - from), entry);
                    if (data == null)
                    {
                        // The local extra field outgrew the allowance: fetch this entry on its own.
                        byte[] single = null!;
                        long last = Math.Min(directoryOffset, entry.LocalOffset + 30 + entry.NameLength + 65535 + entry.CompressedSize) - 1;
                        foreach (object step in Fetch(zip.browser_download_url, entry.LocalOffset, last, bytes => single = bytes)) yield return step;
                        downloaded += single.Length;
                        data = RemoteZip.Extract(single, 0, entry) ?? throw new InvalidDataException(path + " runs past its range");
                    }
                    if (PackFiles.Sha256(data, 0, data.Length) != sha)
                        throw new InvalidDataException(path + " does not match the release inventory");
                    string file = PackFiles.Under(staged, path);
                    Directory.CreateDirectory(Path.GetDirectoryName(file)!);
                    File.WriteAllBytes(file, data);
                    done++;
                }
                notice.Progress($"Downloading Lembitu Pack {label}: {done} of {plan.Writes.Count} files…");
            }
        }

        // The plan goes last: a half-staged update has no plan, so the patcher never sees it.
        File.WriteAllText(planFile + ".tmp", plan.Serialize());
        File.Move(planFile + ".tmp", planFile);
        log.LogInfo($"Pack update staged: {label} ({plan.Writes.Count} file(s), {plan.Deletes.Count} removal(s), {downloaded} bytes downloaded); it installs at the next start");
        notice.Ready(label);
    }

    /// <summary>One byte range of a release asset. GitHub answers the asset URL with a redirect to
    /// signed storage; the redirect is resolved first so the range goes to the server holding the
    /// bytes, and the download is capped so a server that ignores ranges cannot send the whole zip.</summary>
    private IEnumerable<object> Fetch(string url, long from, long to, Action<byte[]> received)
    {
        UnityWebRequest head = UnityWebRequest.Head(url);
        head.redirectLimit = 0;
        head.timeout = 60;
        head.SetRequestHeader("User-Agent", UserAgent);
        yield return head.SendWebRequest();
        string location = head.GetResponseHeader("Location") ?? "";
        long headCode = head.responseCode;
        head.Dispose();
        string source = headCode is >= 300 and < 400 && location.Length > 0 ? location : url;
        if (headCode is not (>= 200 and < 400)) throw new IOException($"{url}: HTTP {headCode}");

        long expected = to - from + 1;
        var handler = new CappedBuffer(expected);
        var request = new UnityWebRequest(source, "GET", handler, null) { timeout = 600 };
        request.SetRequestHeader("Range", $"bytes={from}-{to}");
        request.SetRequestHeader("User-Agent", UserAgent);
        yield return request.SendWebRequest();
        long code = request.responseCode;
        string error = request.error ?? "";
        byte[] bytes = handler.Bytes;
        request.Dispose();
        if (handler.Overflowed || code == 200) throw new IOException("the download server ignored a range request");
        if (code != 206) throw new IOException($"range {from}-{to}: HTTP {code} {error}");
        if (bytes.Length != expected) throw new IOException($"range {from}-{to}: got {bytes.Length} of {expected} bytes");
        received(bytes);
    }

    private void ReportPreviousStart(string stage)
    {
        string result = Path.Combine(stage, PackFiles.ResultFile);
        if (!File.Exists(result)) return;
        string text = File.ReadAllText(result).Trim();
        File.Delete(result);
        if (text.StartsWith("updated ", StringComparison.Ordinal))
        {
            string label = text.Substring(8).Split(' ')[0];
            log.LogInfo("Pack update installed at this start: " + text.Substring(8));
            notice.Done($"Lembitu Pack updated to {label}.");
        }
        else
        {
            log.LogError("Pack update was not installed at this start: " + text);
            notice.Fail("The Lembitu Pack update could not be installed (" + text.Replace("failed ", "") + "). Install the Pack by hand from GitHub.");
        }
    }

    private static string UserAgent => "Lembitu-Updater/" + PluginInfo.Version;

    private static UnityWebRequest Get(string url)
    {
        UnityWebRequest request = UnityWebRequest.Get(url);
        request.timeout = 60;
        request.SetRequestHeader("User-Agent", UserAgent);
        request.SetRequestHeader("Accept", "application/vnd.github+json");
        return request;
    }

    private static byte[] Body(UnityWebRequest request)
    {
        try
        {
            if (request.result != UnityWebRequest.Result.Success)
                throw new IOException($"{request.url}: {request.error} (HTTP {request.responseCode})");
            return request.downloadHandler.data;
        }
        finally { request.Dispose(); }
    }

    private static string Verified(UnityWebRequest request, Asset asset)
    {
        byte[] body = Body(request);
        if (!asset.digest.StartsWith("sha256:", StringComparison.Ordinal))
            throw new InvalidDataException(asset.name + " has no published SHA-256 digest");
        if (PackFiles.Sha256(body, 0, body.Length) != asset.digest.Substring(7))
            throw new InvalidDataException(asset.name + " does not match its published digest");
        return Encoding.UTF8.GetString(body);
    }

    private static Asset AssetOf(Release release, string name) =>
        release.assets.FirstOrDefault(a => a.name == name) ?? throw new InvalidDataException($"{release.tag_name} has no {name}");

    private sealed class CappedBuffer : DownloadHandlerScript
    {
        private readonly MemoryStream buffer = new();
        private readonly long cap;
        internal bool Overflowed;
        internal CappedBuffer(long cap) : base(new byte[64 * 1024]) => this.cap = cap;
        internal byte[] Bytes => buffer.ToArray();

        protected override bool ReceiveData(byte[] chunk, int length)
        {
            if (buffer.Length + length > cap)
            {
                Overflowed = true;
                return false;
            }
            buffer.Write(chunk, 0, length);
            return true;
        }
    }

    // The fields of GitHub's release list the updater reads.
    private sealed class Release
    {
        internal string tag_name = "", html_url = "";
        internal bool draft, prerelease;
        internal Asset[] assets = Array.Empty<Asset>();

        internal static Release[] ListFrom(string json)
        {
            if (Json.Parse(json) is not List<object?> items) throw new InvalidDataException("the release list is not a JSON array");
            return items.OfType<Dictionary<string, object?>>().Select(r => new Release
            {
                tag_name = Text(r, "tag_name"),
                html_url = Text(r, "html_url"),
                draft = r.TryGetValue("draft", out object? draft) && draft is true,
                prerelease = r.TryGetValue("prerelease", out object? pre) && pre is true,
                assets = (r.TryGetValue("assets", out object? list) && list is List<object?> assets ? assets : new List<object?>())
                    .OfType<Dictionary<string, object?>>().Select(a => new Asset
                    {
                        name = Text(a, "name"),
                        browser_download_url = Text(a, "browser_download_url"),
                        digest = Text(a, "digest"),
                        size = a.TryGetValue("size", out object? size) && size is double bytes ? (long)bytes : 0
                    }).ToArray()
            }).ToArray();
        }

        private static string Text(Dictionary<string, object?> map, string key) =>
            map.TryGetValue(key, out object? value) && value is string text ? text : "";
    }
    private sealed class Asset
    {
        internal string name = "", browser_download_url = "", digest = "";
        internal long size;
    }
}
