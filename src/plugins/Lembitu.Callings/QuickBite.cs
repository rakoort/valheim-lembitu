using System.Collections.Generic;
using System.Reflection;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// Fishing's milestone (ADR-0030): from Fishing 50 fish come to your float sooner. A fish only looks
/// for a float when it picks a new place to swim, and vanilla sends it there half the time
/// (Fish.FindFloat, m_baseHookChance 0.5). A float cast at Fishing 50 or above is marked on its ZDO,
/// because the fish's AI runs on whichever client owns the fish and cannot see the fisher's skill; a
/// fish that sees a marked float in range heads for it at the quick-bite chance instead. The bait test
/// that decides whether the fish bites is untouched, so the biome baits still gate the biome fish.
/// </summary>
internal static class QuickBite
{
    private const string Mark = "lembitu.callings.quickbite";

    public static IEnumerable<PatchPlan> Plan()
    {
        MethodInfo setup = Hooks.Method(typeof(FishingFloat), nameof(FishingFloat.Setup),
            new[] { typeof(Character), typeof(Vector3), typeof(float), typeof(HitData), typeof(ItemDrop.ItemData), typeof(ItemDrop.ItemData) }, typeof(void));
        MethodInfo findFloat = Hooks.Method(typeof(Fish), "FindFloat", System.Type.EmptyTypes, typeof(FishingFloat));
        Hooks.Field(typeof(FishingFloat), "m_nview", typeof(ZNetView));
        Hooks.Field(typeof(Fish), nameof(Fish.m_baseHookChance), typeof(float));
        yield return new PatchPlan(setup) { Postfix = Hooks.Patch(typeof(QuickBite), nameof(AfterSetup)) };
        yield return new PatchPlan(findFloat)
        {
            Prefix = Hooks.Patch(typeof(QuickBite), nameof(BeforeFindFloat)),
            Finalizer = Hooks.Patch(typeof(QuickBite), nameof(AfterFindFloat)),
        };
    }

    /// <summary>On the fisher's client, which owns the float it just cast.</summary>
    private static void AfterSetup(FishingFloat __instance, Character owner)
    {
        ZNetView nview = __instance.m_nview;
        if (owner == null || owner != Player.m_localPlayer || nview == null || !nview.IsValid()
            || owner.GetSkillLevel(Skills.SkillType.Fishing) < Settings.QuickBiteLevel)
        {
            return;
        }
        nview.GetZDO().Set(Mark, true);
    }

    /// <summary>On the fish's owner: a marked float in range raises this fish's chance for this pick only.</summary>
    private static void BeforeFindFloat(Fish __instance, out float __state)
    {
        __state = __instance.m_baseHookChance;
        Vector3 position = __instance.transform.position;
        foreach (FishingFloat ff in FishingFloat.GetAllInstances())
        {
            ZNetView nview = ff.m_nview;
            if (nview != null && nview.IsValid() && nview.GetZDO().GetBool(Mark)
                && Vector3.Distance(position, ff.transform.position) <= ff.m_range)
            {
                __instance.m_baseHookChance = Mathf.Max(__state, Settings.QuickBiteHookChance);
                return;
            }
        }
    }

    private static void AfterFindFloat(Fish __instance, float __state)
    {
        __instance.m_baseHookChance = __state;
    }
}
