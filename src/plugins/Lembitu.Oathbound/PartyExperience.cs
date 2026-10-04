using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;
using SocialSystem.Core;
using SocialSystem.Server;
using UnityEngine;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// A kill pays the killer's party (ADR-0022). Oathbound's server-side RouteDeath keeps its validation,
/// its once-per-death guard and its per-creature XP; only the send of the killer's reward is
/// replaced. With SharedExperience off the killer is the only recipient Oathbound computes, so that
/// one send is where the party split happens. Membership and positions come from SocialSystem's
/// server, never from the party ID a client publishes on its character.
/// </summary>
internal static class PartyExperience
{
    private const string RewardRpc = "Warrior_Reward_1";

    /// <summary>The largest reward Oathbound's client accepts (Plugin.ReceiveReward).</summary>
    private const int MaxReward = 3250;

    private static readonly System.Random Rounding = new();

    private static ConfigEntry<float> s_radius = null!;
    private static ConfigEntry<float> s_fullPartyBonus = null!;
    private static ConfigEntry<int> s_fullPartySize = null!;
    private static ManualLogSource s_log = null!;

    public static void Configure(ConfigFile config, ManualLogSource log)
    {
        s_log = log;
        s_radius = config.Bind("Party", "Radius", 100f, new ConfigDescription(
            "Metres from the dead creature within which a connected party member shares its XP. The same radius World Advancement Progression uses for boss keys and ProgressivePowers for mastery credit.",
            new AcceptableValueRange<float>(10f, 1000f), OathboundPlugin.AdminOnly()));
        s_fullPartyBonus = config.Bind("Party", "FullPartyBonus", 0.5f, new ConfigDescription(
            "Extra XP a full party shares on top of the kill's own, as a fraction of it. The bonus grows linearly from 0 for one member in range to this for FullPartySize members.",
            new AcceptableValueRange<float>(0f, 2f), OathboundPlugin.AdminOnly()));
        s_fullPartySize = config.Bind("Party", "FullPartySize", 8, new ConfigDescription(
            "Members in range at which the party bonus is complete: SocialSystem's party cap.",
            new AcceptableValueRange<int>(2, 16), OathboundPlugin.AdminOnly()));
    }

    public static IEnumerable<PatchPlan> Plan()
    {
        var routeDeath = Hooks.Method(typeof(Plugin), "RouteDeath", new[] { typeof(long), typeof(ZPackage) }, typeof(void));
        Hooks.Method(typeof(Plugin), "ReceiveReward", new[] { typeof(ZPackage) }, typeof(void));
        Hooks.Field(typeof(Plugin), "Instance", typeof(Plugin));
        Hooks.Field(typeof(Plugin), "_sessionSharedExperience", typeof(bool));
        Hooks.Once(routeDeath, $"\"{RewardRpc}\"", ci => ci.Is(OpCodes.Ldstr, RewardRpc));
        if (!BepInEx.Bootstrap.Chainloader.PluginInfos.ContainsKey(OathboundPlugin.SocialSystemGuid))
        {
            throw new HookMismatch("SocialSystem is not loaded, so there are no parties to split with");
        }
        Hooks.Once(routeDeath, "ZRpc.Invoke", ci => ci.Calls(RpcInvoke));
        Hooks.Once(routeDeath, "Plugin.ReceiveReward", ci => ci.Calls(LocalReceive));
        VerifySocialServer();
        yield return new PatchPlan(routeDeath) { Transpiler = Hooks.Patch(typeof(PartyExperience), nameof(RouteDeathTranspiler)) };
    }

    private static MethodInfo RpcInvoke => AccessTools.DeclaredMethod(typeof(ZRpc), nameof(ZRpc.Invoke), new[] { typeof(string), typeof(object[]) });

    private static MethodInfo LocalReceive => AccessTools.DeclaredMethod(typeof(Plugin), "ReceiveReward", new[] { typeof(ZPackage) });

    private static void VerifySocialServer()
    {
        Hooks.Field(typeof(SocialServer), nameof(SocialServer.Instance), typeof(SocialServer));
        Hooks.Field(typeof(SocialServer), "_sessions", typeof(SessionRegistry));
        Hooks.Field(typeof(SocialServer), "_parties", typeof(PartyService));
        Hooks.Method(typeof(PartyService), nameof(PartyService.GetParty), new[] { typeof(long) }, typeof(Party));
        Hooks.Property(typeof(Party), nameof(Party.Members), typeof(IReadOnlyList<CharacterRef>));
        Hooks.Field(typeof(CharacterRef), nameof(CharacterRef.PlayerId), typeof(long));
        Hooks.Property(typeof(SessionRegistry), nameof(SessionRegistry.All), typeof(Dictionary<long, ServerSession>.ValueCollection));
        Hooks.Method(typeof(SessionRegistry), nameof(SessionRegistry.TryGetByPlayer), new[] { typeof(long), typeof(ServerSession).MakeByRefType() }, typeof(bool));
        Hooks.Property(typeof(ServerSession), nameof(ServerSession.Kind), typeof(SessionKind));
        Hooks.Property(typeof(ServerSession), nameof(ServerSession.Peer), typeof(ZNetPeer));
        Hooks.Property(typeof(ServerSession), nameof(ServerSession.PlayerId), typeof(long));
        Hooks.Method(typeof(ServerSession), nameof(ServerSession.GetPosition), Type.EmptyTypes, typeof(Vector3));
    }

    private static IEnumerable<CodeInstruction> RouteDeathTranspiler(IEnumerable<CodeInstruction> instructions)
    {
        MethodInfo invoke = RpcInvoke, receive = LocalReceive;
        foreach (CodeInstruction instruction in instructions)
        {
            if (instruction.Calls(invoke))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.DeclaredMethod(typeof(PartyExperience), nameof(SendRemote));
            }
            else if (instruction.Calls(receive))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.DeclaredMethod(typeof(PartyExperience), nameof(SendLocal));
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
    /// Sends the party's shares for the killer's reward package. False leaves the package to Oathbound:
    /// a shared-XP reward, a killer outside any party, or a party with nobody else near the kill, in
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
        double growth = Math.Min(1.0, (n - 1) / (double)(s_fullPartySize.Value - 1));
        double share = experience * (1.0 + s_fullPartyBonus.Value * growth) / n;
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
        s_log.LogInfo($"Party kill XP: {enemy} worth {experience}, {n} members within {s_radius.Value:0} m, each {share:0.##}: {string.Join(", ", paid)}");
        return true;
    }

    /// <summary>
    /// The killer first, then every other member of the killer's party who is connected, alive and
    /// within the radius of the dead creature. Null when the killer is in no party.
    /// </summary>
    private static List<Member>? MembersNear(ZDOID killer, ZDOID enemy)
    {
        SocialServer social = SocialServer.Instance;
        ServerSession? killerSession = social._sessions.All.FirstOrDefault(s => CharacterOf(s) == killer);
        Party? party = killerSession == null ? null : social._parties.GetParty(killerSession.PlayerId);
        ZDO? dead = ZDOMan.instance?.GetZDO(enemy);
        if (killerSession == null || party == null || dead == null)
        {
            return null;
        }

        Vector3 at = dead.GetPosition();
        var members = new List<Member> { new(killer, killerSession.Peer, killer: true) };
        foreach (CharacterRef member in party.Members)
        {
            if (member.PlayerId == killerSession.PlayerId
                || !social._sessions.TryGetByPlayer(member.PlayerId, out ServerSession session)
                || session.Kind == SessionKind.Virtual)
            {
                continue;
            }
            ZDOID character = CharacterOf(session);
            ZDO? body = character.IsNone() ? null : ZDOMan.instance!.GetZDO(character);
            if (body == null || body.GetBool(ZDOVars.s_dead) || Vector3.Distance(session.GetPosition(), at) > s_radius.Value)
            {
                continue;
            }
            members.Add(new Member(character, session.Peer, killer: false));
        }
        return members;
    }

    private static ZDOID CharacterOf(ServerSession session) => session.Kind switch
    {
        SessionKind.Remote => session.Peer.m_characterID,
        SessionKind.Local => ZNet.instance != null ? ZNet.instance.m_characterID : ZDOID.None,
        _ => ZDOID.None,
    };

    /// <summary>Whole part always, the fraction as a chance, so every share averages exactly.</summary>
    private static int RoundAtRandom(double value)
    {
        int whole = (int)Math.Floor(value);
        return Rounding.NextDouble() < value - whole ? whole + 1 : whole;
    }
}
