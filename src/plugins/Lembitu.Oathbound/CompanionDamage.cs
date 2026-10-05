using System.Collections.Generic;
using System.Reflection;
using BepInEx.Configuration;
using HarmonyLib;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// Companions start the Shakedown at 0.75× damage (ADR-0025): the Hunter's wolf, the Dragonsworn
/// whelp and the Warlock's skeletons fight without costing their owner's actions and draw aggro,
/// which is worth most in fights tuned for two players. The multiplier is server-locked and applies
/// on top of the power-level cap that ClassPower puts on the companion stat formulas.
/// </summary>
internal static class CompanionDamage
{
    private static ConfigEntry<float> s_multiplier = null!;

    public static void Configure(ConfigFile config)
    {
        s_multiplier = config.Bind("Companions", "DamageMultiplier", 0.75f, new ConfigDescription(
            "Damage multiplier for the Hunter's wolf, the Dragonsworn whelp and the Warlock's skeletons, on top of the power-level cap (ADR-0025).",
            new AcceptableValueRange<float>(0f, 4f), OathboundPlugin.AdminOnly()));
    }

    public static IEnumerable<PatchPlan> Plan()
    {
        MethodInfo rpcDamage = Hooks.Method(typeof(Character), "RPC_Damage", new[] { typeof(long), typeof(HitData) }, typeof(void));
        Hooks.Method(typeof(Plugin), nameof(Plugin.IsHunterPet), new[] { typeof(Character) }, typeof(bool));
        Hooks.Method(typeof(Plugin), nameof(Plugin.IsDragonWhelp), new[] { typeof(Character) }, typeof(bool));
        Hooks.Method(typeof(Plugin), nameof(Plugin.IsBloodSummon), new[] { typeof(Character) }, typeof(bool));
        yield return new PatchPlan(rpcDamage) { Prefix = Hooks.Patch(typeof(CompanionDamage), nameof(ScaleHit)) };
    }

    /// <summary>
    /// A hit reaches a character exactly once, on the machine that owns it: vanilla Character.Damage
    /// RPCs the hit to the ZDO owner, and RPC_Damage applies it there. Scaling at that one point
    /// catches every companion hit exactly once on every machine — the wolf's and whelp's
    /// stat-rescaled attacks (Oathbound rescales them in SEMan.ModifyAttack on the pet owner's
    /// client), the wolf's commanded bite, the whelp's dive and the skeletons, all of which build
    /// their own HitData on the owner's client and arrive here.
    /// </summary>
    private static void ScaleHit(Character __instance, HitData hit)
    {
        if (hit == null || s_multiplier.Value == 1f)
        {
            return;
        }
        Character? attacker = hit.GetAttacker();
        if (attacker == null || (!Plugin.IsHunterPet(attacker) && !Plugin.IsDragonWhelp(attacker) && !Plugin.IsBloodSummon(attacker)))
        {
            return;
        }
        hit.m_damage.Modify(s_multiplier.Value);
    }
}
