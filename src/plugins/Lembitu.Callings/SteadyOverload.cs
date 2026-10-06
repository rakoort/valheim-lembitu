using System.Collections.Generic;
using System.Reflection;

namespace Lembitu.Callings;

/// <summary>
/// Hauling's milestone (ADR-0030): from Hauling 50, walking while over the carry limit costs no
/// stamina, up to 1.5 times the limit. Vanilla's encumbrance otherwise drains 10 stamina a second
/// while moving and stops the player when stamina runs out (Player.UpdateStats, Player.CanMove); being
/// over the limit still means no running, jumping or dodging. Above the load limit vanilla's drain
/// applies, so one trip never carries everything. The level is read the way every perk reads it.
/// </summary>
internal static class SteadyOverload
{
    private static Skills.SkillType s_hauling;

    public static IEnumerable<PatchPlan> Plan()
    {
        if (!Professions.TryGet("midnightsfx.hauling", out Profession hauling))
        {
            throw new HookMismatch("the Hauling profession is not registered");
        }
        s_hauling = hauling.Type;
        MethodInfo updateStats = Hooks.Method(typeof(Player), "UpdateStats", new[] { typeof(float) }, typeof(void));
        Hooks.Field(typeof(Player), nameof(Player.m_encumberedStaminaDrain), typeof(float));
        yield return new PatchPlan(updateStats)
        {
            Prefix = Hooks.Patch(typeof(SteadyOverload), nameof(BeforeUpdateStats)),
            Finalizer = Hooks.Patch(typeof(SteadyOverload), nameof(AfterUpdateStats)),
        };
    }

    private static void BeforeUpdateStats(Player __instance, out float __state)
    {
        __state = -1f;
        if (__instance != Player.m_localPlayer || !__instance.IsEncumbered()
            || __instance.GetSkillLevel(s_hauling) < Settings.SteadyOverloadLevel
            || __instance.GetInventory().GetTotalWeight() > __instance.GetMaxCarryWeight() * Settings.SteadyOverloadLimit)
        {
            return;
        }
        __state = __instance.m_encumberedStaminaDrain;
        __instance.m_encumberedStaminaDrain = 0f;
    }

    private static void AfterUpdateStats(Player __instance, float __state)
    {
        if (__state >= 0f)
        {
            __instance.m_encumberedStaminaDrain = __state;
        }
    }
}
