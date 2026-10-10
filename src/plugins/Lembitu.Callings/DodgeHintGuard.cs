using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// Zen_ModLib 1.14.21's FixShowDodgeKeyHint rewrites the dodge key hint after
/// <c>KeyHints.ApplySettings</c> and sets its children 2 and 3 without checking they exist.
/// DodgeShortcut 1.4.0 rebuilds that hint with fewer children at <c>KeyHints.Awake</c>, so Zen's
/// rewrite throws. Vanilla calls <c>KeyHints.ApplySettings</c> from <c>Settings.ApplyAndClose</c>
/// before <c>PlatformPrefs.Save</c> and <c>CloseSettings</c>, so Accept saved nothing (volumes
/// included) and the menu stayed open (reported 2026-10-10). The rewrite now runs only on the full
/// vanilla hint; DodgeShortcut keeps writing its own key into the rebuilt one.
/// Zen's "Update KeyHints" switch does not reach this patch.
/// </summary>
internal static class DodgeHintGuard
{
    /// <summary>Zen's rewrite touches child indices 2 and 3.</summary>
    private const int ChildrenZenRewrites = 4;

    public static IEnumerable<PatchPlan> Plan()
    {
        Type fix = AccessTools.TypeByName("Zen.FixVanilla.FixShowDodgeKeyHint")
            ?? throw new HookMismatch("Zen.FixVanilla.FixShowDodgeKeyHint not found");
        var rewrite = Hooks.Method(fix, "KeyHints_ApplySettings", new[] { typeof(KeyHints) }, typeof(void));
        Hooks.Field(typeof(KeyHints), nameof(KeyHints.m_combatHints), typeof(GameObject));
        yield return new PatchPlan(rewrite) { Prefix = Hooks.Patch(typeof(DodgeHintGuard), nameof(OnlyOnFullHint)) };
    }

    // Zen's parameter is itself named __instance, which Harmony reserves, so it is read positionally.
    private static bool OnlyOnFullHint(object[] __args)
    {
        Transform? dodge = (__args[0] as KeyHints)?.m_combatHints?.transform.Find("Keyboard/Dodge");
        return dodge == null || dodge.childCount >= ChildrenZenRewrites;
    }
}
