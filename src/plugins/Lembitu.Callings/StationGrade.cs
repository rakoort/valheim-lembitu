using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// A graded dough, uncooked pie or raw cut keeps its grade through a cooking station (ADR-0029). A
/// station keeps only item names in its slots, so the grade is written beside the slot in the
/// station's ZDO. The inserting client sends the grade after vanilla has sent the item, and the
/// station's owner pairs it with the slot that sender's item just filled: RPCs from one sender reach
/// the owner in order, and a local owner runs both at once. The owner stamps whatever the slot
/// spawns, FineDining's auto-eject included, and what the station drops when it is destroyed.
/// </summary>
internal static class StationGrade
{
    private const string GradeRpc = "LembituCallings_CookGrade";
    private const string SlotKey = "lembitu.callings.cooks-grade.slot";

    /// <summary>The slot a sender's item last filled at a station, until its grade arrives.</summary>
    private sealed class Filled(int slot, string item, float time)
    {
        public int Slot { get; } = slot;
        public string Item { get; } = item;
        public float Time { get; } = time;
    }

    private sealed class Pending(string item, int grade)
    {
        public string Item { get; } = item;
        public int Grade { get; } = grade;
    }

    private static readonly Dictionary<(ZDOID, long), Filled> LastFilled = new();
    [ThreadStatic] private static Pending? s_spawn;
    [ThreadStatic] private static Queue<Pending>? s_drops;

    public static IEnumerable<PatchPlan> Plan()
    {
        Type station = typeof(CookingStation);
        var awake = Hooks.Method(station, "Awake", Type.EmptyTypes, typeof(void));
        var cookItem = Hooks.Method(station, "CookItem", new[] { typeof(Humanoid), typeof(ItemDrop.ItemData) }, typeof(bool));
        var addItem = Hooks.Method(station, "RPC_AddItem", new[] { typeof(long), typeof(string), typeof(bool) }, typeof(void));
        var setSlot = Hooks.Method(station, "SetSlot", new[] { typeof(int), typeof(string), typeof(float), typeof(CookingStation.Status), typeof(bool) }, typeof(void));
        var spawnItem = Hooks.Method(station, "SpawnItem", new[] { typeof(string), typeof(int), typeof(Vector3), typeof(bool) }, typeof(void));
        var dropAll = Hooks.Method(station, "DropAllItems", Type.EmptyTypes, typeof(void));
        var onCreateNew = Hooks.Method(typeof(ItemDrop), nameof(ItemDrop.OnCreateNew), new[] { typeof(ItemDrop), typeof(bool) }, typeof(void));
        Hooks.Method(station, "GetFreeSlot", Type.EmptyTypes, typeof(int));
        Hooks.Method(station, "GetItemConversion", new[] { typeof(string) }, typeof(CookingStation.ItemConversion));
        Hooks.Field(station, "m_nview", typeof(ZNetView));
        yield return new PatchPlan(awake) { Postfix = Hooks.Patch(typeof(StationGrade), nameof(AfterAwake)) };
        yield return new PatchPlan(cookItem)
        {
            Prefix = Hooks.Patch(typeof(StationGrade), nameof(BeforeCookItem)),
            Postfix = Hooks.Patch(typeof(StationGrade), nameof(AfterCookItem)),
        };
        yield return new PatchPlan(addItem)
        {
            Prefix = Hooks.Patch(typeof(StationGrade), nameof(BeforeAddItem)),
            Postfix = Hooks.Patch(typeof(StationGrade), nameof(AfterAddItem)),
        };
        yield return new PatchPlan(setSlot) { Postfix = Hooks.Patch(typeof(StationGrade), nameof(AfterSetSlot)) };
        yield return new PatchPlan(spawnItem)
        {
            Prefix = Hooks.Patch(typeof(StationGrade), nameof(BeforeSpawn)),
            Finalizer = Hooks.Patch(typeof(StationGrade), nameof(AfterSpawn)),
        };
        yield return new PatchPlan(dropAll)
        {
            Prefix = Hooks.Patch(typeof(StationGrade), nameof(BeforeDropAll)),
            Finalizer = Hooks.Patch(typeof(StationGrade), nameof(AfterDropAll)),
        };
        yield return new PatchPlan(onCreateNew) { Postfix = Hooks.Patch(typeof(StationGrade), nameof(AfterCreateNew)) };
    }

    private static int SlotGrade(CookingStation station, int slot) =>
        station.m_nview != null && station.m_nview.IsValid() ? station.m_nview.GetZDO().GetInt(SlotKey + slot) : 0;

    private static void AfterAwake(CookingStation __instance)
    {
        ZNetView nview = __instance.m_nview;
        if (nview == null || nview.GetZDO() == null)
        {
            return;
        }
        nview.Register<string, int>(GradeRpc, (sender, item, grade) => ReceiveGrade(__instance, sender, item, grade));
    }

    private static void BeforeCookItem(Humanoid user, ItemDrop.ItemData item, out int __state)
    {
        __state = item != null ? item.m_stack : 0;
    }

    /// <summary>Only an item CookItem actually took from the inventory went into a slot.</summary>
    private static void AfterCookItem(CookingStation __instance, Humanoid user, ItemDrop.ItemData item, int __state)
    {
        if (user != Player.m_localPlayer || !CooksGrade.TryGetGrade(item, out int grade) || __instance.m_nview == null || !__instance.m_nview.IsValid())
        {
            return;
        }
        bool taken = !user.GetInventory().ContainsItem(item) || item.m_stack < __state;
        if (taken)
        {
            __instance.m_nview.InvokeRPC(GradeRpc, item.m_dropPrefab.name, grade);
        }
    }

    private static void BeforeAddItem(CookingStation __instance, out int __state)
    {
        __state = __instance.GetFreeSlot();
    }

    private static void AfterAddItem(CookingStation __instance, long sender, string itemName, int __state)
    {
        ZNetView nview = __instance.m_nview;
        if (__state < 0 || nview == null || !nview.IsValid() || nview.GetZDO().GetString("slot" + __state) != itemName)
        {
            return;
        }
        if (LastFilled.Count > 64)
        {
            Prune();
        }
        LastFilled[(nview.GetZDO().m_uid, sender)] = new Filled(__state, itemName, Time.time);
    }

    private static void ReceiveGrade(CookingStation station, long sender, string item, int grade)
    {
        ZNetView nview = station.m_nview;
        if (nview == null || !nview.IsValid() || !nview.IsOwner() || grade < 2)
        {
            return;
        }
        var key = (nview.GetZDO().m_uid, sender);
        if (!LastFilled.TryGetValue(key, out Filled filled))
        {
            return;
        }
        LastFilled.Remove(key);
        if (filled.Item == item && nview.GetZDO().GetString("slot" + filled.Slot) == item)
        {
            nview.GetZDO().Set(SlotKey + filled.Slot, grade);
        }
    }

    private static void Prune()
    {
        var stale = new List<(ZDOID, long)>();
        foreach (KeyValuePair<(ZDOID, long), Filled> entry in LastFilled)
        {
            if (Time.time - entry.Value.Time > 30f)
            {
                stale.Add(entry.Key);
            }
        }
        foreach ((ZDOID, long) key in stale)
        {
            LastFilled.Remove(key);
        }
    }

    /// <summary>An emptied slot, or a fresh item placed in it, starts without a grade.</summary>
    private static void AfterSetSlot(CookingStation __instance, int slot, string itemName, float cookedTime, CookingStation.Status status)
    {
        if ((itemName == "" || (cookedTime == 0f && status == CookingStation.Status.NotDone)) && SlotGrade(__instance, slot) != 0)
        {
            __instance.m_nview.GetZDO().Set(SlotKey + slot, 0);
        }
    }

    private static void BeforeSpawn(CookingStation __instance, string name, int slot)
    {
        int grade = SlotGrade(__instance, slot);
        s_spawn = grade >= 2 && CooksGrade.IsDish(name) ? new Pending(name, grade) : null;
    }

    private static Exception? AfterSpawn(Exception? __exception)
    {
        s_spawn = null;
        return __exception;
    }

    /// <summary>A destroyed station drops cooked, raw and burnt items slot by slot, in slot order.</summary>
    private static void BeforeDropAll(CookingStation __instance)
    {
        s_drops = null;
        for (int i = 0; i < __instance.m_slots.Length; i++)
        {
            int grade = SlotGrade(__instance, i);
            if (grade < 2)
            {
                continue;
            }
            __instance.GetSlot(i, out string itemName, out float _, out CookingStation.Status status, out bool _);
            string dropped = status switch
            {
                CookingStation.Status.Done => __instance.GetItemConversion(itemName)?.m_to?.gameObject.name ?? "",
                CookingStation.Status.NotDone => itemName,
                _ => "",
            };
            if (dropped.Length > 0 && CooksGrade.IsDish(dropped))
            {
                (s_drops ??= new Queue<Pending>()).Enqueue(new Pending(dropped, grade));
            }
        }
    }

    private static Exception? AfterDropAll(Exception? __exception)
    {
        s_drops = null;
        return __exception;
    }

    private static void AfterCreateNew(ItemDrop item)
    {
        string name = item.m_itemData.m_dropPrefab != null ? item.m_itemData.m_dropPrefab.name : Utils.GetPrefabName(item.gameObject);
        Pending? pending = s_spawn;
        if (pending == null && s_drops != null && s_drops.Count > 0 && s_drops.Peek().Item == name)
        {
            pending = s_drops.Dequeue();
        }
        if (pending == null || pending.Item != name)
        {
            return;
        }
        CooksGrade.Stamp(item.m_itemData, pending.Grade);
        item.SetQuality(pending.Grade);
    }
}
