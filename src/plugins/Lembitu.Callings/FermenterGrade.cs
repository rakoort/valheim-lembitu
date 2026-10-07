using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>A fermenter stores only a prefab hash, so its owner stores the accepted base's grade
/// beside it in the ZDO. The inserting client's grade RPC follows vanilla's add RPC, as for
/// StationGrade. Tapping captures it separately before vanilla empties the barrel; delayed output
/// and destroyed-barrel drops are stamped before entering any inventory.</summary>
internal static class FermenterGrade
{
    private const string GradeRpc = "LembituCallings_BrewerGrade";
    private const string GradeKey = "lembitu.callings.brewers-grade.fermenter";
    private const string TappedGradeKey = "lembitu.callings.brewers-grade.tapped";
    private static readonly Dictionary<(ZDOID, long), (int Item, float Time)> Accepted = new();
    [ThreadStatic] private static int s_outputGrade;

    public static IEnumerable<PatchPlan> Plan()
    {
        Type barrel = typeof(Fermenter);
        Hooks.Field(barrel, "m_nview", typeof(ZNetView));
        Hooks.Field(barrel, "m_delayedTapItem", typeof(int));
        Hooks.Method(barrel, "GetContent", Type.EmptyTypes, typeof(int));
        var awake = Hooks.Method(barrel, "Awake", Type.EmptyTypes, typeof(void));
        yield return new PatchPlan(awake) { Postfix = Hooks.Patch(typeof(FermenterGrade), nameof(Awake)) };
        yield return new PatchPlan(Hooks.Method(barrel, "AddItem", new[] { typeof(Humanoid), typeof(ItemDrop.ItemData) }, typeof(bool)))
        { Postfix = Hooks.Patch(typeof(FermenterGrade), nameof(Added)) };
        yield return new PatchPlan(Hooks.Method(barrel, "RPC_AddItem", new[] { typeof(long), typeof(int), typeof(bool) }, typeof(void)))
        {
            Prefix = Hooks.Patch(typeof(FermenterGrade), nameof(BeforeAdd)),
            Postfix = Hooks.Patch(typeof(FermenterGrade), nameof(AfterAdd)),
        };
        yield return new PatchPlan(Hooks.Method(barrel, "RPC_Tap", new[] { typeof(long) }, typeof(void)))
        {
            Prefix = Hooks.Patch(typeof(FermenterGrade), nameof(BeforeTap)),
            Postfix = Hooks.Patch(typeof(FermenterGrade), nameof(AfterTap)),
        };
        yield return new PatchPlan(Hooks.Method(barrel, "DelayedTap", Type.EmptyTypes, typeof(void)))
        {
            Prefix = Hooks.Patch(typeof(FermenterGrade), nameof(BeforeOutput)),
            Finalizer = Hooks.Patch(typeof(FermenterGrade), nameof(AfterOutput)),
        };
        yield return new PatchPlan(Hooks.Method(barrel, "DropAllItems", Type.EmptyTypes, typeof(void)))
        {
            Prefix = Hooks.Patch(typeof(FermenterGrade), nameof(BeforeDrop)),
            Finalizer = Hooks.Patch(typeof(FermenterGrade), nameof(AfterOutput)),
        };
        yield return new PatchPlan(Hooks.Method(typeof(ItemDrop), nameof(ItemDrop.OnCreateNew), new[] { typeof(ItemDrop), typeof(bool) }, typeof(void)))
        { Postfix = Hooks.Patch(typeof(FermenterGrade), nameof(Created)) };
    }

    private static void Awake(Fermenter __instance)
    {
        ZNetView view = __instance.m_nview;
        if (view == null || view.GetZDO() == null) return;
        view.Register<int, int>(GradeRpc, (sender, item, grade) => Receive(__instance, sender, item, grade));
    }

    private static void Added(Fermenter __instance, Humanoid user, ItemDrop.ItemData item, bool __result)
    {
        if (__result && user == Player.m_localPlayer && __instance.m_nview != null && __instance.m_nview.IsValid())
            __instance.m_nview.InvokeRPC(GradeRpc, item.m_dropPrefab.name.GetStableHashCode(), BrewersGrade.Grade(item));
    }

    private static void BeforeAdd(Fermenter __instance, out int __state) => __state = __instance.GetContent();

    private static void AfterAdd(Fermenter __instance, long sender, int nameHash, int __state)
    {
        ZNetView view = __instance.m_nview;
        if (__state != 0 || view == null || !view.IsValid() || !view.IsOwner() || __instance.GetContent() != nameHash) return;
        view.GetZDO().Set(GradeKey, 1);
        if (Accepted.Count > 64)
        {
            var stale = new List<(ZDOID, long)>();
            foreach (var entry in Accepted)
                if (Time.time - entry.Value.Time > 30f) stale.Add(entry.Key);
            foreach (var key in stale) Accepted.Remove(key);
        }
        Accepted[(view.GetZDO().m_uid, sender)] = (nameHash, Time.time);
    }

    private static void Receive(Fermenter barrel, long sender, int item, int grade)
    {
        ZNetView view = barrel.m_nview;
        if (view == null || !view.IsValid() || !view.IsOwner() || grade < 1 || grade > 5) return;
        var key = (view.GetZDO().m_uid, sender);
        if (!Accepted.TryGetValue(key, out var accepted)) return;
        Accepted.Remove(key);
        if (accepted.Item == item && Time.time - accepted.Time <= 30f && barrel.GetContent() == item)
            view.GetZDO().Set(GradeKey, grade);
    }

    private static void BeforeTap(Fermenter __instance, out int __state) => __state = __instance.GetContent();

    private static void AfterTap(Fermenter __instance, int __state)
    {
        ZNetView view = __instance.m_nview;
        if (__state == 0 || view == null || !view.IsValid() || !view.IsOwner() || __instance.GetContent() != 0) return;
        view.GetZDO().Set(TappedGradeKey, view.GetZDO().GetInt(GradeKey, 1));
        view.GetZDO().Set(GradeKey, 1);
    }

    private static void BeforeOutput(Fermenter __instance, out int __state)
    {
        __state = s_outputGrade;
        s_outputGrade = __instance.m_nview.GetZDO().GetInt(TappedGradeKey, 1);
    }

    private static void BeforeDrop(Fermenter __instance, out int __state)
    {
        __state = s_outputGrade;
        s_outputGrade = __instance.m_nview.GetZDO().GetInt(GradeKey, 1);
    }

    private static Exception? AfterOutput(int __state, Exception? __exception)
    {
        s_outputGrade = __state;
        return __exception;
    }

    private static void Created(ItemDrop item)
    {
        if (s_outputGrade == 0 || !BrewersGrade.IsPotion(Utils.GetPrefabName(item.gameObject))) return;
        BrewersGrade.Stamp(item.m_itemData, s_outputGrade);
        item.SetQuality(item.m_itemData.m_quality);
    }
}
