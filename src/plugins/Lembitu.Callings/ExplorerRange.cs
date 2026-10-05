using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

internal static class ExplorerRange
{
    public const string Guid = "blacks7ar.Explorer";

    public static IEnumerable<PatchPlan> Plan()
    {
        Type tracker = AccessTools.TypeByName("Explorer.Patches.Tracker")
            ?? throw new HookMismatch("Explorer.Patches.Tracker not found");
        Hooks.Field(tracker, "m_trackRange", typeof(float));
        var update = Hooks.Method(tracker, "Update", Type.EmptyTypes, typeof(void));
        yield return new PatchPlan(update) { Prefix = Hooks.Patch(typeof(ExplorerRange), nameof(BeforeUpdate)) };
    }

    private static void BeforeUpdate(ref float ___m_trackRange)
    {
        Player player = Player.m_localPlayer;
        if (player == null) return;
        float level = player.GetSkillFactor(Professions.Explorer) * 100f;
        ___m_trackRange = Mathf.Lerp(Settings.ExplorerRangeAtLevel1, Settings.ExplorerRangeAt100,
            Mathf.Clamp01((level - 1f) / 99f));
    }
}
