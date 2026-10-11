using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;
using Guild = Guilds.Guild;
using GuildServer = Guilds.GuildServer;
using UnityEngine;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// A kill pays the killer's guild members nearby (ADR-0035). Oathbound's server-side RouteDeath keeps its validation,
/// its once-per-death guard and its per-creature XP; only the send of the killer's reward is
/// replaced. With SharedExperience off the killer is the only recipient Oathbound computes, so that
/// one send is where the guild split happens. Membership comes from Guilds' server, never from
/// guild data a client publishes on its character. Positions come from connected character ZDOs.
/// </summary>
internal static class GuildExperience
{
    private const string RewardRpc = "Warrior_Reward_1";

    /// <summary>The largest reward Oathbound's client accepts (Plugin.ReceiveReward).</summary>
    private const int MaxReward = 3250;

    private static readonly System.Random Rounding = new();

    private static ConfigEntry<float> s_radius = null!;
    private static ConfigEntry<float> s_fullBonus = null!;
    private static ConfigEntry<int> s_fullBonusMembers = null!;
    private static ManualLogSource s_log = null!;

    public static void Configure(ConfigFile config, ManualLogSource log)
    {
        s_log = log;
        s_radius = config.Bind("Guild XP", "Radius", 100f, new ConfigDescription(
            "Metres from the dead creature within which a connected, alive guild member shares its XP. The killer always counts. The same radius World Advancement Progression uses for boss keys and ProgressivePowers for mastery credit.",
            new AcceptableValueRange<float>(10f, 1000f), OathboundPlugin.AdminOnly()));
        s_fullBonus = config.Bind("Guild XP", "FullBonus", 0.5f, new ConfigDescription(
            "Extra XP guild members share on top of the kill's own, as a fraction of it. The bonus grows linearly from 0 for one member in range to this for FullBonusMembers members.",
            new AcceptableValueRange<float>(0f, 2f), OathboundPlugin.AdminOnly()));
        s_fullBonusMembers = config.Bind("Guild XP", "FullBonusMembers", 4, new ConfigDescription(
            "Guild members in range at which the XP bonus is complete. Additional members split the same total.",
            new AcceptableValueRange<int>(2, 16), OathboundPlugin.AdminOnly()));
    }

    public static IEnumerable<PatchPlan> Plan()
    {
        var routeDeath = Hooks.Method(typeof(Plugin), "RouteDeath", new[] { typeof(long), typeof(ZPackage) }, typeof(void));
        Hooks.Method(typeof(Plugin), "ReceiveReward", new[] { typeof(ZPackage) }, typeof(void));
        Hooks.Field(typeof(Plugin), "Instance", typeof(Plugin));
        Hooks.Field(typeof(Plugin), "_sessionSharedExperience", typeof(bool));
        Hooks.Once(routeDeath, $"\"{RewardRpc}\"", ci => ci.Is(OpCodes.Ldstr, RewardRpc));
        if (!BepInEx.Bootstrap.Chainloader.PluginInfos.ContainsKey(OathboundPlugin.GuildsGuid))
        {
            throw new HookMismatch("Guilds is not loaded, so there are no guild members to share with");
        }
        Hooks.Once(routeDeath, "ZRpc.Invoke", ci => ci.Calls(RpcInvoke));
        Hooks.Once(routeDeath, "Plugin.ReceiveReward", ci => ci.Calls(LocalReceive));
        VerifyGuildServer();
        yield return new PatchPlan(routeDeath) { Transpiler = Hooks.Patch(typeof(GuildExperience), nameof(RouteDeathTranspiler)) };
    }

    private static MethodInfo RpcInvoke => AccessTools.DeclaredMethod(typeof(ZRpc), nameof(ZRpc.Invoke), new[] { typeof(string), typeof(object[]) });

    private static MethodInfo LocalReceive => AccessTools.DeclaredMethod(typeof(Plugin), "ReceiveReward", new[] { typeof(ZPackage) });

    private static void VerifyGuildServer()
    {
        MethodInfo guildOf = Hooks.Method(typeof(GuildServer), nameof(GuildServer.GuildOf), new[] { typeof(long) }, typeof(Guild));
        if (!guildOf.IsStatic)
        {
            throw new HookMismatch("GuildServer.GuildOf is no longer static");
        }
        Hooks.Field(typeof(Guild), nameof(Guild.Members), typeof(List<Guilds.Member>));
        Hooks.Field(typeof(Guilds.Member), nameof(Guilds.Member.Pid), typeof(long));
    }

    private static IEnumerable<CodeInstruction> RouteDeathTranspiler(IEnumerable<CodeInstruction> instructions)
    {
        MethodInfo invoke = RpcInvoke, receive = LocalReceive;
        foreach (CodeInstruction instruction in instructions)
        {
            if (instruction.Calls(invoke))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.DeclaredMethod(typeof(GuildExperience), nameof(SendRemote));
            }
            else if (instruction.Calls(receive))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.DeclaredMethod(typeof(GuildExperience), nameof(SendLocal));
            }
            yield return instruction;
        }
    }

    /// <summary>Stands in for <c>peer.m_rpc.Invoke(method, args)</c> inside RouteDeath.</summary>
    private static void SendRemote(ZRpc rpc, string method, object[] args)
    {
        if (method != RewardRpc || args.Length != 1 || args[0] is not ZPackage reward || !TrySplit(reward))
        {
            rpc.Invoke(method, args);
        }
    }

    /// <summary>Stands in for <c>ReceiveReward(package)</c>, the listen-server host's own reward.</summary>
    private static void SendLocal(Plugin plugin, ZPackage reward)
    {
        if (!TrySplit(reward))
        {
            plugin.ReceiveReward(reward);
        }
    }

    private readonly struct Member(ZDOID character, ZNetPeer? peer, bool killer)
    {
        public readonly ZDOID Character = character;
        public readonly ZNetPeer? Peer = peer;
        public readonly bool Killer = killer;
    }

    /// <summary>
    /// Sends the guild's shares for the killer's reward package. False leaves the package to Oathbound:
    /// a shared-XP reward, a guildless killer, or a guild with nobody else near the kill, in
    /// which case the killer earns exactly what Oathbound computed.
    /// </summary>
    private static bool TrySplit(ZPackage reward)
    {
        reward.SetPos(0);
        ZDOID enemy = reward.ReadZDOID();
        ZDOID killer = reward.ReadZDOID();
        int experience = reward.ReadInt();
        bool melee = reward.ReadBool();
        bool killingBlow = reward.GetPos() >= reward.Size() || reward.ReadBool();
        reward.SetPos(0);

        if (!killingBlow || Plugin.Instance == null || Plugin.Instance._sessionSharedExperience)
        {
            return false;
        }
        List<Member>? members = MembersNear(killer, enemy);
        if (members == null || members.Count < 2)
        {
            return false;
        }

        int n = members.Count;
        double growth = Math.Min(1.0, (n - 1) / (double)(s_fullBonusMembers.Value - 1));
        double share = experience * (1.0 + s_fullBonus.Value * growth) / n;
        var paid = new List<int>(n);
        foreach (Member member in members)
        {
            int amount = Math.Min(MaxReward, RoundAtRandom(share));
            paid.Add(amount);
            var package = new ZPackage();
            package.Write(enemy);
            package.Write(member.Character);
            package.Write(amount);
            package.Write(member.Killer && melee);
            package.Write(member.Killer);
            if (member.Peer != null)
            {
                member.Peer.m_rpc.Invoke(RewardRpc, package);
            }
            else
            {
                package.SetPos(0);
                Plugin.Instance.ReceiveReward(package);
            }
        }
        s_log.LogInfo($"Guild kill XP: {enemy} worth {experience}, {n} members within {s_radius.Value:0} m, each {share:0.##}: {string.Join(", ", paid)}");
        return true;
    }

    /// <summary>
    /// The killer first, then every other guild member who is connected, alive and
    /// within the radius of the dead creature. Null when the killer is guildless.
    /// </summary>
    private static List<Member>? MembersNear(ZDOID killer, ZDOID enemy)
    {
        ZNet? net = ZNet.instance;
        ZDO? killerBody = killer.IsNone() ? null : ZDOMan.instance?.GetZDO(killer);
        ZDO? dead = ZDOMan.instance?.GetZDO(enemy);
        if (net == null || killerBody == null || dead == null)
        {
            return null;
        }
        List<ZNetPeer> peers = net.GetPeers();
        ZNetPeer? killerPeer = null;
        foreach (ZNetPeer peer in peers)
        {
            if (peer.m_characterID == killer)
            {
                killerPeer = peer;
                break;
            }
        }
        if (killerPeer == null && net.m_characterID != killer)
        {
            return null;
        }
        long killerPid = killerBody.GetLong(ZDOVars.s_playerID);
        Guild? guild = killerPid == 0 ? null : GuildServer.GuildOf(killerPid);
        if (guild == null)
        {
            return null;
        }

        Vector3 at = dead.GetPosition();
        var members = new List<Member>(guild.Members.Count) { new(killer, killerPeer, killer: true) };
        foreach (Guilds.Member member in guild.Members)
        {
            if (member.Pid == killerPid)
            {
                continue;
            }
            if (Shares(net.m_characterID, member.Pid, at))
            {
                members.Add(new Member(net.m_characterID, null, killer: false));
                continue;
            }
            foreach (ZNetPeer peer in peers)
            {
                if (Shares(peer.m_characterID, member.Pid, at))
                {
                    members.Add(new Member(peer.m_characterID, peer, killer: false));
                    break;
                }
            }
        }
        return members;
    }

    private static bool Shares(ZDOID character, long pid, Vector3 at)
    {
        ZDO? body = character.IsNone() ? null : ZDOMan.instance!.GetZDO(character);
        return body != null && body.GetLong(ZDOVars.s_playerID) == pid
            && !body.GetBool(ZDOVars.s_dead)
            && Vector3.Distance(body.GetPosition(), at) <= s_radius.Value;
    }

    /// <summary>Whole part always, the fraction as a chance, so every share averages exactly.</summary>
    private static int RoundAtRandom(double value)
    {
        int whole = (int)Math.Floor(value);
        return Rounding.NextDouble() < value - whole ? whole + 1 : whole;
    }
}
