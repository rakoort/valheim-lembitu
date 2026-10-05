using System;
using System.Collections.Generic;
using System.Linq;
using BepInEx.Logging;
using HarmonyLib;
using UnityEngine;
using North = global::Guilds;
using Spawns = global::SeparateSpawns;

namespace Lembitu.Guilds;

/// <summary>
/// The server-side bridge between Northarun/Guilds' membership and SeparateSpawns' groups (ADR-0028).
/// Guild state is read from Guilds' server store only, never from what a client reports: a player
/// whose guild holds a region is assigned to that region's group — their bedless respawn and their
/// portal — and a player in no guild is assigned to none, so their spawn stays vanilla, at the
/// sacrificial stones. SeparateSpawns' own roster JSON stays the sync vehicle, so assignments and
/// portals survive a restart; the hooks below make the roster's stored rows follow the guild state.
/// Beds always override, as in vanilla, because a bed is a custom spawn point SeparateSpawns and the
/// game already honour.
/// </summary>
internal static class Bridge
{
    private static ManualLogSource s_log = null!;

    /// <summary>Whether the hold feature's patches are on (feature verified at startup).</summary>
    public static bool HoldOn;

    /// <summary>Whether the follow feature is on: the authority lookup and the server reconcile.</summary>
    public static bool FollowOn;

    private static float s_timer;
    private static ZNet? s_identityNetwork;
    private static readonly Dictionary<long, (ZNetPeer Peer, long Pid)> s_peerPids = new();
    private static readonly List<long> s_departedPeers = new();

    public static void Configure(ManualLogSource log) => s_log = log;

    // ----- startup verification

    /// <summary>What the hold feature needs from SeparateSpawns 0.1.1, plus its two patches.</summary>
    public static IEnumerable<PatchPlan> HoldPlan()
    {
        VerifyRosterSurface();
        Hooks.Method(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.GetGroupNames), Type.EmptyTypes, typeof(IReadOnlyList<string>));
        Hooks.Method(typeof(Spawns.PlatformIdHelper), nameof(Spawns.PlatformIdHelper.GetLocalPlatformUserId), Type.EmptyTypes, typeof(string));
        Hooks.Property(typeof(Spawns.RosterSync), nameof(Spawns.RosterSync.ClientHasRoster), typeof(bool));
        var assign = Hooks.Method(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.AssignRandomGroup), new[] { typeof(string) }, typeof(string));
        var pending = Hooks.Method(typeof(Spawns.GroupSpawnResolver), nameof(Spawns.GroupSpawnResolver.IsSeparateSpawnPending), Type.EmptyTypes, typeof(bool));
        yield return new PatchPlan(assign) { Prefix = Hooks.Patch(typeof(Bridge), nameof(HoldRandomAssignment)) };
        yield return new PatchPlan(pending) { Prefix = Hooks.Patch(typeof(Bridge), nameof(GuildlessIsNotPending)) };
    }

    /// <summary>What the follow feature reads on both mods, plus the authority lookup patch.</summary>
    public static IEnumerable<PatchPlan> FollowPlan()
    {
        VerifyRosterSurface();
        // The initial-spawn guard and Guilds' server store.
        Hooks.Field(typeof(Game), nameof(Game.m_firstSpawn), typeof(bool));
        Hooks.Method(typeof(North.GuildServer), nameof(North.GuildServer.GuildOf), new[] { typeof(long) }, typeof(North.Guild));
        Hooks.Method(typeof(North.GuildServer), "EnsureLoaded", Type.EmptyTypes, typeof(void));
        Hooks.Method(typeof(North.GuildServer), "FindGuild", new[] { typeof(long) }, typeof(North.Guild));
        Hooks.Field(typeof(North.GuildServer), "Guilds", typeof(List<North.Guild>));
        Hooks.Method(typeof(North.Guild), nameof(North.Guild.Find), new[] { typeof(long) }, typeof(North.Member));
        Hooks.Field(typeof(North.Guild), nameof(North.Guild.Id), typeof(long));
        Hooks.Field(typeof(North.Guild), nameof(North.Guild.Tag), typeof(string));
        Hooks.Field(typeof(North.Guild), nameof(North.Guild.Name), typeof(string));
        Hooks.Field(typeof(North.Member), nameof(North.Member.Pid), typeof(long));
        Hooks.Field(typeof(North.Member), nameof(North.Member.Rank), typeof(int));
        Hooks.Field(typeof(North.Member), nameof(North.Member.Name), typeof(string));
        var lookup = Hooks.Method(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.GetGroupForPlayer), new[] { typeof(string) }, typeof(string));
        yield return new PatchPlan(lookup) { Postfix = Hooks.Patch(typeof(Bridge), nameof(FollowGuildState)) };
        // A returning player asks for their assignment before the periodic reconcile can have repaired
        // the stored row (a member left or a guild disbanded while they were offline); reconcile first,
        // so the roster the server answers with is already the guild state.
        var request = Hooks.Method(typeof(Spawns.RosterSync), "OnRequestAssignment", new[] { typeof(long), typeof(string) }, typeof(void));
        yield return new PatchPlan(request) { Prefix = Hooks.Patch(typeof(Bridge), nameof(ReconcileBeforeAssignment)) };
    }

    private static void VerifyRosterSurface()
    {
        Hooks.Property(typeof(Spawns.Plugin), nameof(Spawns.Plugin.Roster), typeof(Spawns.GroupRoster));
        Hooks.Property(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.Groups), typeof(Dictionary<string, Spawns.GroupEntry>));
        Hooks.Method(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.Save), Type.EmptyTypes, typeof(void));
        Hooks.Property(typeof(Spawns.GroupEntry), nameof(Spawns.GroupEntry.Players), typeof(List<string>));
        Hooks.Method(typeof(Spawns.RosterSync), nameof(Spawns.RosterSync.Broadcast), Type.EmptyTypes, typeof(void));
        Hooks.Method(typeof(Spawns.PlatformIdHelper), nameof(Spawns.PlatformIdHelper.Normalize), new[] { typeof(string) }, typeof(string));
        Hooks.Method(typeof(Spawns.PlatformIdHelper), nameof(Spawns.PlatformIdHelper.IdsMatch), new[] { typeof(string), typeof(string) }, typeof(bool));
    }

    // ----- patches

    /// <summary>
    /// AssignRandomGroup, server side: a guild with a region pulls its player into that region's
    /// group, and everyone else is assigned to nothing — which is what holds SeparateSpawns' random
    /// placement back and leaves new players at the sacrificial stones.
    /// </summary>
    private static bool HoldRandomAssignment(string platformUserId, ref string? __result)
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer() || !Settings.Enabled)
        {
            return true;
        }
        try
        {
            long pid = PidForPlatform(platformUserId);
            if (pid == 0)
            {
                __result = null; // unresolved is not guildless; leave the stored row untouched
                return false;
            }
            string? region = RegionOf(pid);
            if (region != null)
            {
                if (RawGroupOf(platformUserId) != region)
                {
                    AddToGroup(region, platformUserId);
                    Spawns.Plugin.Roster.Save();
                    Spawns.RosterSync.Broadcast();
                }
                s_log.LogInfo($"lembitu.guilds: {platformUserId} joins {region} with their guild.");
                __result = region;
                return false;
            }
            s_log.LogInfo($"lembitu.guilds: {platformUserId} is in no guild with a region and holds the stones.");
            __result = null;
            return false;
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: holding {platformUserId} at the stones after an error: {error}");
            __result = null;
            return false;
        }
    }

    /// <summary>
    /// IsSeparateSpawnPending: a settled guildless player is not pending, so SeparateSpawns' own
    /// FindSpawnPoint postfix leaves the vanilla result — the sacrificial stones — alone instead of
    /// holding the spawn for an assignment that will never come.
    /// </summary>
    private static bool GuildlessIsNotPending(ref bool __result)
    {
        if (ZNet.instance == null || !Settings.Enabled)
        {
            return true;
        }
        try
        {
            if (!ZNet.instance.IsServer() && !Spawns.RosterSync.ClientHasRoster)
            {
                return true; // the old session's roster can still be in memory after reconnect
            }
            Spawns.GroupRoster? roster = Spawns.Plugin.Roster;
            if (roster == null || roster.GetGroupNames().Count == 0)
            {
                return true; // nothing synced yet: SeparateSpawns waits, as it always does
            }
            string id = Spawns.PlatformIdHelper.GetLocalPlatformUserId();
            if (string.IsNullOrEmpty(id) || roster.GetGroupForPlayer(id) != null)
            {
                return true; // rostered players are SeparateSpawns' own business
            }
            __result = false;
            return false;
        }
        catch
        {
            return true;
        }
    }

    /// <summary>
    /// GetGroupForPlayer, server side: the stored roster row answers only while the guild state
    /// agrees with it, so a stale row can never keep a region alive after a leave, a kick or a
    /// disband. Before a client's first body exists, an old Steam row cannot identify its selected
    /// character: leave that initial spawn vanilla; beds and logout points already override it.
    /// </summary>
    private static void FollowGuildState(string platformUserId, ref string? __result)
    {
        if (ZNet.instance == null || !Settings.Enabled)
        {
            return;
        }
        if (Game.instance != null && Game.instance.m_firstSpawn
            && Spawns.PlatformIdHelper.IdsMatch(platformUserId, Spawns.PlatformIdHelper.GetLocalPlatformUserId()))
        {
            __result = null; // initial spawn cannot inherit another character's Steam row
            return;
        }
        if (!ZNet.instance.IsServer())
        {
            return;
        }
        try
        {
            long pid = PidForPlatform(platformUserId);
            if (pid == 0)
            {
                return; // character not known yet: the stored row stands until the reconcile can look
            }
            string? expected = RegionOf(pid);
            if (__result == expected)
            {
                return;
            }
            s_log.LogInfo($"lembitu.guilds: {platformUserId} resolves to {(expected ?? "no group")} by guild state, not '{__result ?? "none"}' by roster.");
            __result = expected;
        }
        catch
        {
            // The stored row stands; the reconcile repairs it when it can read the state again.
        }
    }

    // ----- server reconcile

    /// <summary>The join-time reconcile: the roster the server answers with is the guild state.</summary>
    private static void ReconcileBeforeAssignment(long sender, string platformUserId)
    {
        try
        {
            if (ZNet.instance != null && ZNet.instance.IsServer() && Settings.Enabled && FollowOn)
            {
                RunReconcile();
            }
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: join reconcile failed: {error.Message}");
        }
    }

    /// <summary>Called from the plugin's Update; no-op everywhere but a server in a loaded world.</summary>
    public static void Tick()
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer() || !Settings.Enabled || !FollowOn)
        {
            return;
        }
        if (ZRoutedRpc.instance == null || Game.instance == null || ZNet.instance.GetWorldName().Length == 0)
        {
            return;
        }
        North.GuildServer.EnsureLoaded();
        Claims.EnsureLoaded();
        s_timer += Time.deltaTime;
        if (s_timer < Settings.ReconcileSeconds)
        {
            return;
        }
        s_timer = 0f;
        RunReconcile();
    }

    /// <summary>Re-derives every online player's assignment from the guild state and repairs the roster.</summary>
    public static void RunReconcile()
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer())
        {
            return;
        }
        RefreshPeerIdentityCache();
        bool changed = Claims.FreeDisbanded();
        changed |= ReconcilePlayer(Player.m_localPlayer);
        foreach (ZNetPeer peer in ZNet.instance.GetPeers())
        {
            changed |= ReconcilePeer(peer);
        }
        if (changed)
        {
            Spawns.Plugin.Roster.Save();
            Spawns.RosterSync.Broadcast();
        }
    }

    private static bool ReconcilePeer(ZNetPeer peer)
    {
        try
        {
            string id = Spawns.PlatformIdHelper.Normalize(peer.m_socket?.GetHostName() ?? "");
            long pid = PidOfPeer(peer);
            return id.Length != 0 && pid != 0 && SetAssignment(id, RegionOf(pid));
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: could not reconcile a peer: {error.Message}");
            return false;
        }
    }

    private static bool ReconcilePlayer(Player? player)
    {
        if (player == null)
        {
            return false;
        }
        try
        {
            string id = Spawns.PlatformIdHelper.GetLocalPlatformUserId();
            long pid = player.GetPlayerID();
            return id.Length != 0 && pid != 0 && SetAssignment(id, RegionOf(pid));
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: could not reconcile the local player: {error.Message}");
            return false;
        }
    }

    /// <summary>Makes the stored roster row agree with the guild state; reports whether it wrote.</summary>
    private static bool SetAssignment(string platformUserId, string? expected)
    {
        string? stored = RawGroupOf(platformUserId);
        if (stored == expected)
        {
            return false;
        }
        if (stored != null)
        {
            RemoveFromAllGroups(platformUserId);
        }
        if (expected != null)
        {
            AddToGroup(expected, platformUserId);
        }
        s_log.LogInfo($"lembitu.guilds: {platformUserId} moves from {(stored ?? "no group")} to {(expected ?? "the stones")}.");
        return true;
    }

    // ----- guild and player identity, server side

    /// <summary>The region the player's guild holds, or null for guildless players.</summary>
    public static string? RegionOf(long pid)
    {
        return pid != 0 ? Claims.RegionOfGuild(North.GuildServer.GuildOf(pid)?.Id ?? 0) : null;
    }

    /// <summary>Valheim character id for a routed-RPC sender, resolved the way Guilds resolves it.</summary>
    public static long PidOfSender(long sender)
    {
        if (ZNet.instance == null)
        {
            return 0;
        }
        if (sender == ZDOMan.GetSessionID())
        {
            return Player.m_localPlayer != null ? Player.m_localPlayer.GetPlayerID() : 0;
        }
        ZNetPeer? peer = ZNet.instance.GetPeer(sender);
        return peer != null ? PidOfPeer(peer) : 0;
    }

    public static long PidOfPeer(ZNetPeer peer)
    {
        UseCurrentIdentityNetwork();
        long pid = 0;
        if (ZDOMan.instance != null && !peer.m_characterID.IsNone())
        {
            ZDO? zdo = ZDOMan.instance.GetZDO(peer.m_characterID);
            if (zdo != null)
            {
                pid = zdo.GetLong(ZDOVars.s_playerID, 0L);
            }
        }
        if (pid != 0)
        {
            s_peerPids[peer.m_uid] = (peer, pid);
            return pid;
        }
        // Death temporarily sets characterID to None. Only the same connection may reuse its pid;
        // reconnecting with another character on the same account must start unresolved again.
        return s_peerPids.TryGetValue(peer.m_uid, out var known) && ReferenceEquals(known.Peer, peer)
            ? known.Pid : 0;
    }

    private static void UseCurrentIdentityNetwork()
    {
        if (!ReferenceEquals(s_identityNetwork, ZNet.instance))
        {
            s_peerPids.Clear();
            s_identityNetwork = ZNet.instance;
        }
    }

    private static void RefreshPeerIdentityCache()
    {
        UseCurrentIdentityNetwork();
        s_departedPeers.Clear();
        foreach (var known in s_peerPids)
        {
            if (!ReferenceEquals(ZNet.instance.GetPeer(known.Key), known.Value.Peer))
            {
                s_departedPeers.Add(known.Key);
            }
        }
        foreach (long uid in s_departedPeers)
        {
            s_peerPids.Remove(uid);
        }
    }

    /// <summary>Valheim character id for a SeparateSpawns platform id, via the peer that carries it.</summary>
    public static long PidForPlatform(string platformUserId)
    {
        if (ZNet.instance == null)
        {
            return 0;
        }
        string wanted = Spawns.PlatformIdHelper.Normalize(platformUserId);
        if (wanted.Length == 0)
        {
            return 0;
        }
        if (Player.m_localPlayer != null)
        {
            string local = Spawns.PlatformIdHelper.GetLocalPlatformUserId();
            if (local.Length != 0 && Spawns.PlatformIdHelper.IdsMatch(local, wanted))
            {
                return Player.m_localPlayer.GetPlayerID();
            }
        }
        foreach (ZNetPeer peer in ZNet.instance.GetPeers())
        {
            string host = Spawns.PlatformIdHelper.Normalize(peer.m_socket?.GetHostName() ?? "");
            if (host.Length == 0 || !Spawns.PlatformIdHelper.IdsMatch(host, wanted))
            {
                continue;
            }
            return PidOfPeer(peer);
        }
        return 0;
    }

    // ----- raw roster rows (mirrors SeparateSpawns' own matching, bypassing the authority lookup)

    /// <summary>The group the stored roster names for this player, before guild state is applied.</summary>
    public static string? RawGroupOf(string platformUserId)
    {
        foreach (KeyValuePair<string, Spawns.GroupEntry> group in Spawns.Plugin.Roster.Groups)
        {
            if (group.Value?.Players != null && group.Value.Players.Any(player => Spawns.PlatformIdHelper.IdsMatch(player, platformUserId)))
            {
                return group.Key;
            }
        }
        return null;
    }

    /// <summary>Adds the player to the group's row the way AssignRandomGroup would have.</summary>
    public static void AddToGroup(string region, string platformUserId)
    {
        Spawns.GroupRoster roster = Spawns.Plugin.Roster;
        if (!roster.Groups.TryGetValue(region, out Spawns.GroupEntry? entry) || entry == null)
        {
            entry = new Spawns.GroupEntry();
            roster.Groups[region] = entry;
        }
        if (!entry.Players.Any(player => Spawns.PlatformIdHelper.IdsMatch(player, platformUserId)))
        {
            entry.Players.Add(Spawns.PlatformIdHelper.Normalize(platformUserId));
        }
    }

    public static void RemoveFromAllGroups(string platformUserId)
    {
        foreach (Spawns.GroupEntry entry in Spawns.Plugin.Roster.Groups.Values)
        {
            entry?.Players.RemoveAll(player => Spawns.PlatformIdHelper.IdsMatch(player, platformUserId));
        }
    }
}
