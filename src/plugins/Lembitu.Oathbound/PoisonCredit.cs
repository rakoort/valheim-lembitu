using System.Collections.Generic;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// A creature that dies of poison pays its kill XP to the player who poisoned it. Oathbound 0.21.14
/// credits a kill to the attacker on the creature's last hit, and lends each burning tick the player
/// who set the fire (its BurningSourcePatch). Vanilla poison ticks carry no attacker
/// (SE_Poison.UpdateStatusEffect), and Oathbound lends them nobody, so with SharedExperience off a
/// poison kill paid no one. This gives poison the same credit as fire: the player whose hit set the
/// poison now running, read from the damage context Oathbound keeps for that hit, and used only by
/// Oathbound's kill-owner lookup. No hit gains an attacker, so nothing else mistakes a poison tick for
/// a player's blow. A poisoner who is no longer nearby is not found, as with fire.
/// </summary>
internal static class PoisonCredit
{
    private sealed class Credit(ZDOID player)
    {
        public ZDOID Player { get; } = player;
    }

    /// <summary>The poison now on a creature, credited to the player whose hit set it.</summary>
    private static readonly ConditionalWeakTable<SE_Poison, Credit> Sources = new();

    /// <summary>Poison ticks, credited while they can still become the creature's last hit.</summary>
    private static readonly ConditionalWeakTable<HitData, Credit> Ticks = new();

    /// <summary>The poison whose tick is being applied right now; ticks apply synchronously.</summary>
    private static SE_Poison? s_ticking;

    public static IEnumerable<PatchPlan> Plan()
    {
        MethodInfo addDamage = Hooks.Method(typeof(SE_Poison), nameof(SE_Poison.AddDamage), new[] { typeof(float) }, typeof(void));
        MethodInfo tick = Hooks.Method(typeof(SE_Poison), nameof(SE_Poison.UpdateStatusEffect), new[] { typeof(float) }, typeof(void));
        MethodInfo applyDamage = Hooks.Method(typeof(Character), nameof(Character.ApplyDamage),
            new[] { typeof(HitData), typeof(bool), typeof(bool), typeof(HitData.DamageModifier) }, typeof(void));
        MethodInfo owner = Hooks.Method(typeof(Plugin), nameof(Plugin.ExperienceHitOwner), new[] { typeof(HitData) }, typeof(Player));
        Hooks.Method(typeof(Plugin), nameof(Plugin.ExperienceOwner), new[] { typeof(Character) }, typeof(Player));
        Hooks.Field(typeof(Plugin), nameof(Plugin._experienceDamage), typeof(ConditionalWeakTable<Character, Plugin.DamageContext>));
        Hooks.Field(typeof(Plugin.DamageContext), nameof(Plugin.DamageContext.Hit), typeof(HitData));
        Hooks.Field(typeof(SE_Poison), nameof(SE_Poison.m_damageLeft), typeof(float));
        yield return new PatchPlan(addDamage)
        {
            Prefix = Hooks.Patch(typeof(PoisonCredit), nameof(BeforeAddDamage)),
            Postfix = Hooks.Patch(typeof(PoisonCredit), nameof(AfterAddDamage)),
        };
        yield return new PatchPlan(tick)
        {
            Prefix = Hooks.Patch(typeof(PoisonCredit), nameof(BeforeTick)),
            Finalizer = Hooks.Patch(typeof(PoisonCredit), nameof(AfterTick)),
        };
        yield return new PatchPlan(applyDamage) { Postfix = Hooks.Patch(typeof(PoisonCredit), nameof(AfterApplyDamage)) };
        yield return new PatchPlan(owner) { Postfix = Hooks.Patch(typeof(PoisonCredit), nameof(ResolveOwner)) };
    }

    /// <summary>Vanilla keeps the stronger poison: a new dose replaces the running one only if it is at least as large.</summary>
    private static void BeforeAddDamage(SE_Poison __instance, float __0, out bool __state)
    {
        __state = __0 >= __instance.m_damageLeft;
    }

    /// <summary>The poison that took over carries its own hit's credit, or none if no player set it.</summary>
    private static void AfterAddDamage(SE_Poison __instance, bool __state)
    {
        if (!__state)
        {
            return;
        }
        Sources.Remove(__instance);
        Player? poisoner = Poisoner(__instance.m_character);
        if (poisoner != null)
        {
            Sources.Add(__instance, new Credit(poisoner.GetZDOID()));
        }
    }

    /// <summary>AddPoisonDamage runs inside RPC_Damage, while Oathbound holds the hit that carried the poison.</summary>
    private static Player? Poisoner(Character victim)
    {
        Plugin? plugin = Plugin.Instance;
        if (plugin == null || victim == null || !plugin._experienceDamage.TryGetValue(victim, out Plugin.DamageContext context) || context.Hit == null)
        {
            return null;
        }
        return Plugin.ExperienceOwner(context.Hit.GetAttacker());
    }

    private static void BeforeTick(SE_Poison __instance, out SE_Poison? __state)
    {
        __state = s_ticking;
        s_ticking = __instance;
    }

    private static void AfterTick(SE_Poison? __state)
    {
        s_ticking = __state;
    }

    /// <summary>The tick vanilla just stored as the creature's last hit, before CheckDeath reads it.</summary>
    private static void AfterApplyDamage(Character __instance, HitData hit)
    {
        SE_Poison? poison = s_ticking;
        if (poison == null || poison.m_character != __instance || hit == null || hit.m_hitType != HitData.HitType.Poisoned
            || hit.HaveAttacker() || !Sources.TryGetValue(poison, out Credit credit))
        {
            return;
        }
        Ticks.Remove(hit);
        Ticks.Add(hit, credit);
    }

    private static void ResolveOwner(HitData? hit, ref Player? __result)
    {
        if (__result != null || hit == null || ZNetScene.instance == null || !Ticks.TryGetValue(hit, out Credit credit))
        {
            return;
        }
        GameObject poisoner = ZNetScene.instance.FindInstance(credit.Player);
        __result = poisoner != null ? poisoner.GetComponent<Player>() : null;
    }
}
