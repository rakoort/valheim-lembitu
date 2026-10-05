using System;
using System.Collections.Generic;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// EpicLoot 0.14.13's skills-dialog postfix reads related skills through GetSkillFactor even when
/// their magic-effect bonus is zero. Those reads create missing skills after vanilla has allocated
/// its rows; DetailedLevels 2.1.3 then indexes its enlarged list past those rows. If Setup grew the
/// local player's skill data, rebuild once from that new data so all row decorators can finish.
/// Never create skills here, retry recursively, or hide an exception when the list did not grow.
/// </summary>
internal static class SkillsWindowRebuild
{
    private static bool _rebuilding;

    public static IEnumerable<PatchPlan> Plan()
    {
        var setup = Hooks.Method(typeof(SkillsDialog), nameof(SkillsDialog.Setup), new[] { typeof(Player) }, typeof(void));
        Hooks.Field(typeof(Skills), nameof(Skills.m_skillData), typeof(Dictionary<Skills.SkillType, Skills.Skill>));
        yield return new PatchPlan(setup)
        {
            Prefix = Hooks.Patch(typeof(SkillsWindowRebuild), nameof(BeforeSetup), Priority.First),
            Finalizer = Hooks.Patch(typeof(SkillsWindowRebuild), nameof(AfterSetup), Priority.Last),
        };
    }

    private static void BeforeSetup(Player player, out int __state) =>
        __state = !_rebuilding && player != null && player == Player.m_localPlayer
            ? player.GetSkills().m_skillData.Count
            : -1;

    private static Exception? AfterSetup(SkillsDialog __instance, Player player, ref int __state, Exception? __exception)
    {
        if (__state < 0 || _rebuilding || player == null || player != Player.m_localPlayer
            || player.GetSkills().m_skillData.Count <= __state)
        {
            return __exception;
        }

        // A failed retry must propagate, including if Harmony invokes this finalizer again.
        __state = -1;
        _rebuilding = true;
        try
        {
            __instance.Setup(player);
            return null;
        }
        finally
        {
            _rebuilding = false;
        }
    }
}
