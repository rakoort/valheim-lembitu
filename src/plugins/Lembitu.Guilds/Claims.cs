using System;
using System.Collections.Generic;
using System.IO;
using BepInEx;
using BepInEx.Logging;
using Newtonsoft.Json;
using North = global::Guilds;

namespace Lembitu.Guilds;

/// <summary>One guild's hold on one start region, kept on the server per world and never sent to clients.</summary>
internal sealed class RegionClaim
{
    public string Region = "";
    public long GuildId;
    public string GuildTag = "";
    public string GuildName = "";
    public long ClaimedTicks;
    public string ClaimedBy = "";

    public string Label => $"[{GuildTag}] {GuildName}";
}

/// <summary>
/// The server's claim store (ADR-0028): first come, first served, one region per guild, and a claim
/// dies with its guild. Stored beside the guilds themselves, under the world's name, so it survives
/// a restart; a claim whose guild no longer exists is freed the next time the store is read.
/// </summary>
internal static class Claims
{
    private static ManualLogSource s_log = null!;
    private static readonly List<RegionClaim> s_claims = new();
    private static bool s_loaded;
    private static string s_world = "";
    private static string s_path = "";

    public static void Configure(ManualLogSource log) => s_log = log;

    public static IReadOnlyList<RegionClaim> All => s_claims;

    /// <summary>The region this guild holds, or null. No guild (zero) holds nothing.</summary>
    public static string? RegionOfGuild(long guildId)
    {
        if (guildId == 0)
        {
            return null;
        }
        foreach (RegionClaim claim in s_claims)
        {
            if (claim.GuildId == guildId)
            {
                return claim.Region;
            }
        }
        return null;
    }

    public static RegionClaim? ClaimOfRegion(string region)
    {
        foreach (RegionClaim claim in s_claims)
        {
            if (claim.Region == region)
            {
                return claim;
            }
        }
        return null;
    }

    /// <summary>Records the claim, replacing any row for the same region, and writes the store.</summary>
    public static void Record(RegionClaim claim)
    {
        s_claims.RemoveAll(existing => existing.Region == claim.Region);
        s_claims.Add(claim);
        Save();
    }

    /// <summary>Loads the world's store once; frees claims whose guild disbanded while the server was down.</summary>
    public static void EnsureLoaded()
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer())
        {
            return;
        }
        string world = Sanitize(ZNet.instance.GetWorldName());
        if (world.Length == 0)
        {
            return;
        }
        if (s_loaded && s_world == world)
        {
            return;
        }
        // First load, or another world was loaded into this process: this world's claims only.
        s_claims.Clear();
        s_world = world;
        s_path = Path.Combine(Paths.ConfigPath, "Lembitu.Guilds", s_world + ".claims.json");
        try
        {
            if (File.Exists(s_path))
            {
                Payload? payload = JsonConvert.DeserializeObject<Payload>(File.ReadAllText(s_path));
                if (payload?.Claims != null)
                {
                    foreach (RegionClaim claim in payload.Claims)
                    {
                        if (claim != null && !string.IsNullOrEmpty(claim.Region))
                        {
                            s_claims.Add(claim);
                        }
                    }
                }
                s_log.LogInfo($"lembitu.guilds: loaded {s_claims.Count} region claim(s) for {s_world} from {s_path}.");
            }
            else
            {
                s_log.LogInfo($"lembitu.guilds: no region claims yet for {s_world} ({s_path}).");
            }
        }
        catch (Exception error)
        {
            string backup = s_path + ".broken-" + DateTime.Now.ToString("yyyyMMdd-HHmmss");
            s_log.LogError($"lembitu.guilds: could not read {s_path} — copy saved as {backup}. {error}");
            try
            {
                File.Copy(s_path, backup, overwrite: true);
            }
            catch
            {
                // The unreadable file stays where it is; the next Save overwrites it.
            }
            s_claims.Clear();
        }
        s_loaded = true;
        FreeDisbanded(whileDown: true);
    }

    /// <summary>
    /// Frees every claim whose guild no longer exists. Runs only while the bridge can read Guilds'
    /// server store; if that feature is off, the claims stay frozen and nothing is destroyed.
    /// </summary>
    public static bool FreeDisbanded(bool whileDown = false)
    {
        if (!Bridge.FollowOn)
        {
            return false;
        }
        bool changed = false;
        for (int i = s_claims.Count - 1; i >= 0; i--)
        {
            RegionClaim claim = s_claims[i];
            if (North.GuildServer.FindGuild(claim.GuildId) != null)
            {
                continue;
            }
            s_claims.RemoveAt(i);
            s_log.LogInfo(
                $"lembitu.guilds: the {claim.Region} start region is free again ({claim.Label} disbanded" +
                (whileDown ? " while the server was down" : "") + ").");
            changed = true;
        }
        if (changed)
        {
            Save();
        }
        return changed;
    }

    private static void Save()
    {
        if (s_path.Length == 0)
        {
            return;
        }
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(s_path)!);
            File.WriteAllText(s_path, JsonConvert.SerializeObject(new Payload { Claims = s_claims }, Formatting.Indented));
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: could not write {s_path}: {error}");
        }
    }

    private static string Sanitize(string world)
    {
        foreach (char invalid in Path.GetInvalidFileNameChars())
        {
            world = world.Replace(invalid, '_');
        }
        return world;
    }

    private sealed class Payload
    {
        public int Version = 1;

        public List<RegionClaim> Claims = new();
    }
}
