using System;
using System.Collections.Generic;
using BepInEx.Logging;
using UnityEngine;
using North = global::Guilds;

namespace Lembitu.Guilds;

/// <summary>Server-owned guild membership and character vitals for the always-on HUD (ADR-0035).</summary>
internal static class GuildRoster
{
    public const string RpcName = "lembitu.guilds GuildRoster";
    public static bool On;
    public static readonly List<MemberState> Members = new(5);
    public static float ReceivedAt = float.NegativeInfinity;
    private static readonly Dictionary<long, Connection> Online = new(10);
    private static readonly List<North.Guild> ActiveGuilds = new(10);
    private static ManualLogSource s_log = null!;
    private static float s_nextSend;
    private static ZNet? s_network;

    internal readonly struct MemberState(long pid, string name, bool online, float health, float maxHealth, bool dead, float x, float z)
    {
        public readonly long Pid = pid;
        public readonly string Name = name;
        public readonly bool Online = online;
        public readonly float MaxHealth = Clamp(maxHealth, 0f, 100000f);
        public readonly float Health = Clamp(health, 0f, Clamp(maxHealth, 0f, 100000f));
        public readonly bool Dead = dead;
        public readonly float X = Finite(x);
        public readonly float Z = Finite(z);
    }

    private readonly struct Connection(long uid, ZDO? character)
    {
        public readonly long Uid = uid;
        public readonly ZDO? Character = character;
    }

    public static void Configure(ManualLogSource log) => s_log = log;

    public static IEnumerable<PatchPlan> Plan()
    {
        Hooks.Method(typeof(North.GuildServer), "GuildOf", [typeof(long)], typeof(North.Guild));
        Hooks.Field(typeof(North.Guild), "Members", typeof(List<North.Member>));
        Hooks.Field(typeof(North.Member), "Pid", typeof(long));
        Hooks.Field(typeof(North.Member), "Name", typeof(string));
        return Array.Empty<PatchPlan>();
    }

    public static void Reset()
    {
        Members.Clear();
        Online.Clear();
        ActiveGuilds.Clear();
        ReceivedAt = float.NegativeInfinity;
        s_nextSend = 0f;
        GuildMemberHud.Reset();
    }

    public static void Tick()
    {
        if (!On) return;
        ZNet? network = ZNet.instance;
        if (!ReferenceEquals(network, s_network))
        {
            Reset();
            s_network = network;
        }
        if (network == null || !network.enabled || (!network.IsServer() &&
            ZNet.GetConnectionStatus() != ZNet.ConnectionStatus.Connected &&
            ZNet.GetConnectionStatus() != ZNet.ConnectionStatus.Connecting))
        {
            Reset();
            return;
        }
        try
        {
            if (network.IsServer() && ZRoutedRpc.instance != null && Time.unscaledTime >= s_nextSend)
            {
                s_nextSend = Time.unscaledTime + 0.5f;
                Send(network);
            }
            GuildMemberHud.Tick();
        }
        catch (Exception error)
        {
            On = false;
            Reset();
            s_log.LogError($"Guild members stay on the HUD: off, runtime error: {error}");
        }
    }

    private static void AddOnline(long pid, long uid, ZDO? character)
    {
        if (pid == 0) return;
        Online[pid] = new Connection(uid, character);
        North.Guild? guild = North.GuildServer.GuildOf(pid);
        if (guild != null && !ActiveGuilds.Contains(guild)) ActiveGuilds.Add(guild);
    }

    private static void Send(ZNet network)
    {
        Online.Clear();
        ActiveGuilds.Clear();
        foreach (ZNetPeer peer in network.GetPeers())
        {
            AddOnline(Bridge.PidOfPeer(peer), peer.m_uid,
                ZDOMan.instance?.GetZDO(peer.m_characterID));
        }
        Player? local = Player.m_localPlayer;
        if (local != null)
            AddOnline(local.GetPlayerID(), ZDOMan.GetSessionID(), local.m_nview?.GetZDO());

        foreach (North.Guild guild in ActiveGuilds)
        {
            var data = new ZPackage();
            data.Write(guild.Members.Count);
            foreach (North.Member member in guild.Members)
            {
                bool online = Online.TryGetValue(member.Pid, out Connection connection);
                data.Write(member.Pid);
                data.Write(member.Name ?? "");
                data.Write(online);
                if (!online) continue;
                ZDO? zdo = connection.Character;
                float max = zdo?.GetFloat(ZDOVars.s_maxHealth) ?? 0f;
                Vector3 position = zdo?.GetPosition() ?? Vector3.zero;
                var state = new MemberState(member.Pid, member.Name ?? "", true,
                    zdo?.GetFloat(ZDOVars.s_health, max) ?? 0f, max,
                    zdo == null || zdo.GetBool(ZDOVars.s_dead), position.x, position.z);
                data.Write(state.Health);
                data.Write(state.MaxHealth);
                data.Write(state.Dead);
                data.Write(state.X);
                data.Write(state.Z);
            }
            foreach (North.Member member in guild.Members)
                if (Online.TryGetValue(member.Pid, out Connection connection)) Deliver(connection.Uid, data);
        }
        // Leaving a guild clears the old roster immediately, rather than waiting for its expiry.
        ZPackage? empty = null;
        foreach (var pair in Online)
        {
            if (North.GuildServer.GuildOf(pair.Key) != null) continue;
            if (empty == null)
            {
                empty = new ZPackage();
                empty.Write(0);
            }
            Deliver(pair.Value.Uid, empty);
        }
    }

    private static void Deliver(long uid, ZPackage data)
    {
        if (uid == ZDOMan.GetSessionID())
        {
            data.SetPos(0);
            RPC_Roster(uid, data);
        }
        else ZRoutedRpc.instance.InvokeRoutedRPC(uid, RpcName, data);
    }

    public static void RPC_Roster(long sender, ZPackage data)
    {
        if (!On || ZNet.instance == null ||
            sender != (ZNet.instance.IsServer() ? ZDOMan.GetSessionID() : ZNet.instance.GetServerPeer()?.m_uid ?? 0)) return;
        Members.Clear();
        int count = data.ReadInt();
        for (int i = 0; i < count; ++i)
        {
            long pid = data.ReadLong();
            string name = data.ReadString();
            bool online = data.ReadBool();
            Members.Add(online
                ? new MemberState(pid, name, true, data.ReadSingle(), data.ReadSingle(), data.ReadBool(), data.ReadSingle(), data.ReadSingle())
                : new MemberState(pid, name, false, 0f, 0f, false, 0f, 0f));
        }
        Members.Sort(CompareMembers);
        ReceivedAt = Time.unscaledTime;
    }

    private static int CompareMembers(MemberState a, MemberState b)
    {
        int online = b.Online.CompareTo(a.Online);
        if (online != 0) return online;
        int name = StringComparer.OrdinalIgnoreCase.Compare(a.Name, b.Name);
        return name != 0 ? name : a.Pid.CompareTo(b.Pid);
    }

    private static float Clamp(float value, float min, float max) =>
        float.IsNaN(value) ? min : Math.Max(min, Math.Min(max, value));
    private static float Finite(float value) => float.IsNaN(value) || float.IsInfinity(value) ? 0f : value;
}
