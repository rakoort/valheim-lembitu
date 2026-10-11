using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace Lembitu.Updater;

/// <summary>The Pack's file inventory and the staged-update plan. Compiled into both the plugin,
/// which stages an update, and the patcher, which applies it before any mod loads.</summary>
internal static class PackFiles
{
    /// <summary>Where staging lives, relative to the Pack root (the folder holding BepInEx/).</summary>
    internal const string StageDir = "BepInEx/lembitu-update";
    /// <summary>The installed Pack's label, written by scripts/build-client-pack.sh.</summary>
    internal const string VersionFile = "BepInEx/lembitu-pack-version.txt";
    internal const string PlanFile = "plan.txt", StagedDir = "staged", ResultFile = "result.txt", LeftoverFile = "leftovers.txt";
    internal const string BackupSuffix = ".lembitu-old";

    /// <summary>The Pack root: the folder the Pack zip is extracted into, which holds BepInEx/.</summary>
    internal static string PackRoot() =>
        Path.GetDirectoryName(BepInEx.Paths.BepInExRootPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar))
        ?? throw new InvalidOperationException("BepInEx root has no parent folder");

    /// <summary>A Pack-relative path ("BepInEx/plugins/x.dll") as a full path under root.</summary>
    internal static string Under(string root, string path)
    {
        CheckPath(path);
        return Path.Combine(root, path.Replace('/', Path.DirectorySeparatorChar));
    }

    /// <summary>Refuses anything but a plain relative path with forward slashes, so a damaged or
    /// hostile inventory can never name a file outside the Pack root.</summary>
    internal static void CheckPath(string path)
    {
        if (path.Length == 0 || path[0] == '/' || path.IndexOf('\\') >= 0 || path.IndexOf(':') >= 0 || path.IndexOf('\0') >= 0)
            throw new InvalidDataException("unsafe Pack path: " + path);
        foreach (string part in path.Split('/'))
            if (part.Length == 0 || part == "." || part == "..")
                throw new InvalidDataException("unsafe Pack path: " + path);
    }

    /// <summary>"&lt;sha256&gt;  &lt;path&gt;" per line, as scripts/build-client-pack.sh writes the
    /// release's versions.txt.</summary>
    internal static Dictionary<string, string> ParseInventory(string text)
    {
        var files = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (string raw in text.Split('\n'))
        {
            string line = raw.TrimEnd('\r');
            if (line.Length == 0) continue;
            if (line.Length < 67 || line[64] != ' ' || line[65] != ' ' || !IsSha256(line.Substring(0, 64)))
                throw new InvalidDataException("inventory line is not '<sha256>  <path>': " + line);
            string path = line.Substring(66);
            CheckPath(path);
            files[path] = line.Substring(0, 64);
        }
        if (files.Count == 0) throw new InvalidDataException("inventory lists no files");
        return files;
    }

    internal static bool IsSha256(string text) =>
        text.Length == 64 && text.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');

    internal static string Sha256(byte[] data, int offset, int count)
    {
        using var sha = SHA256.Create();
        return Hex(sha.ComputeHash(data, offset, count));
    }

    internal static string Sha256File(string file)
    {
        using var sha = SHA256.Create();
        using var stream = File.OpenRead(file);
        return Hex(sha.ComputeHash(stream));
    }

    private static string Hex(byte[] hash)
    {
        var text = new StringBuilder(hash.Length * 2);
        foreach (byte b in hash) text.Append(b.ToString("x2"));
        return text.ToString();
    }
}

/// <summary>What an update changes: the files to write, each with the hash it must have, and the
/// files to remove. Serialised to plan.txt, which the plugin writes last, once every staged file is
/// in place, and the patcher consumes.</summary>
internal sealed class UpdatePlan
{
    internal string Version = "";
    internal readonly List<(string Sha, string Path)> Writes = new();
    internal readonly List<string> Deletes = new();

    /// <summary>Only what the Pack itself changed. A file missing from the install is written; a file
    /// the Pack did not change between the installed and the new version keeps its local content,
    /// so a player's edit or a mod's own rewrite of a seeded config survives. Without the installed
    /// inventory every differing file is written and nothing is removed. A removed file is deleted
    /// only while it still holds the installed Pack's bytes.</summary>
    internal static UpdatePlan Compute(string version, IReadOnlyDictionary<string, string> next,
        IReadOnlyDictionary<string, string>? installed, Func<string, string?> localHash)
    {
        var plan = new UpdatePlan { Version = version };
        foreach (var file in next.OrderBy(f => f.Key, StringComparer.Ordinal))
        {
            string? local = localHash(file.Key);
            if (local == file.Value) continue;
            if (local != null && installed != null && installed.TryGetValue(file.Key, out string? before) && before == file.Value)
                continue;
            plan.Writes.Add((file.Value, file.Key));
        }
        if (installed != null)
            foreach (var file in installed.OrderBy(f => f.Key, StringComparer.Ordinal))
                if (!next.ContainsKey(file.Key) && localHash(file.Key) == file.Value)
                    plan.Deletes.Add(file.Key);
        return plan;
    }

    internal string Serialize()
    {
        var text = new StringBuilder("version " + Version + "\n");
        foreach (var (sha, path) in Writes) text.Append("write ").Append(sha).Append(' ').Append(path).Append('\n');
        foreach (string path in Deletes) text.Append("delete ").Append(path).Append('\n');
        return text.ToString();
    }

    internal static UpdatePlan Parse(string text)
    {
        var plan = new UpdatePlan();
        foreach (string raw in text.Split('\n'))
        {
            string line = raw.TrimEnd('\r');
            if (line.Length == 0) continue;
            if (line.StartsWith("version ", StringComparison.Ordinal)) plan.Version = line.Substring(8);
            else if (line.StartsWith("write ", StringComparison.Ordinal) && line.Length > 71 && line[70] == ' ' && PackFiles.IsSha256(line.Substring(6, 64)))
            {
                string path = line.Substring(71);
                PackFiles.CheckPath(path);
                plan.Writes.Add((line.Substring(6, 64), path));
            }
            else if (line.StartsWith("delete ", StringComparison.Ordinal))
            {
                string path = line.Substring(7);
                PackFiles.CheckPath(path);
                plan.Deletes.Add(path);
            }
            else throw new InvalidDataException("unreadable plan line: " + line);
        }
        if (plan.Version.Length == 0) throw new InvalidDataException("plan names no version");
        return plan;
    }
}
