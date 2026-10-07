using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Warrior.Core;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>Keep the tree portable, but oath changes and free respec at a real Oathstone.</summary>
internal static class OathAccess
{
    private static readonly HashSet<Oathstone> Stones = new();

    public static IEnumerable<PatchPlan> Plan()
    {
        Hooks.Field(typeof(Plugin), "_state", typeof(Progression));
        Hooks.Field(typeof(Plugin), "_classMenuButton", typeof(Button));
        Hooks.Property(typeof(Plugin), "ClassSettingsReady", typeof(bool));
        Hooks.Property(typeof(Plugin), "MenuClassAccess", typeof(bool));
        Hooks.Method(typeof(Oathstone), nameof(Oathstone.InRange), new[] { typeof(Player), typeof(float) }, typeof(bool));
        yield return new PatchPlan(Hooks.Method(typeof(Oathstone), "Awake", Type.EmptyTypes, typeof(void))) { Postfix = Hooks.Patch(typeof(OathAccess), nameof(Register)) };
        yield return new PatchPlan(Hooks.Method(typeof(Oathstone), "OnDestroy", Type.EmptyTypes, typeof(void))) { Prefix = Hooks.Patch(typeof(OathAccess), nameof(Unregister)) };
        yield return new PatchPlan(Hooks.Method(typeof(Plugin), "get_OathstoneAccess", Type.EmptyTypes, typeof(bool))) { Postfix = Hooks.Patch(typeof(OathAccess), nameof(StoneAccess)) };
        yield return new PatchPlan(Hooks.Method(typeof(Plugin), "ClassAccessInRange", new[] { typeof(Player), typeof(float) }, typeof(bool))) { Postfix = Hooks.Patch(typeof(OathAccess), nameof(TreeAccess)) };
        yield return new PatchPlan(Hooks.Method(typeof(Plugin), "SwitchClass", new[] { typeof(string) }, typeof(bool))) { Prefix = Hooks.Patch(typeof(OathAccess), nameof(BeforeOath)) };
        yield return new PatchPlan(Hooks.Method(typeof(Progression), nameof(Progression.Respec), Type.EmptyTypes, typeof(void))) { Prefix = Hooks.Patch(typeof(OathAccess), nameof(BeforeRespec)) };
        yield return new PatchPlan(Hooks.Method(typeof(Plugin), "TickClassAccessButton", Type.EmptyTypes, typeof(void))) { Postfix = Hooks.Patch(typeof(OathAccess), nameof(HideUntilOath)) };
    }

    private static void Register(Oathstone __instance) => Stones.Add(__instance);
    private static void Unregister(Oathstone __instance) => Stones.Remove(__instance);
    private static void StoneAccess(Plugin __instance, ref bool __result) => __result = __instance.ClassSettingsReady;
    private static void TreeAccess(Plugin __instance, ref bool __result)
    {
        if (__instance.MenuClassAccess) __result = __instance.ClassSettingsReady;
    }
    private static bool AtStone()
    {
        Player player = Player.m_localPlayer;
        if (player != null)
        {
            foreach (Oathstone stone in Stones)
                if (stone != null && stone.InRange(player)) return true;
            player.Message(MessageHud.MessageType.Center, "Visit the Oathstone to take an oath or reset talents.");
        }
        return false;
    }
    private static bool BeforeOath(ref bool __result)
    {
        if (AtStone()) return true;
        __result = false;
        return false;
    }
    private static bool BeforeRespec() => AtStone();
    private static void HideUntilOath(Plugin __instance)
    {
        if (__instance._state.ClassId == "" && __instance._classMenuButton != null)
            __instance._classMenuButton.gameObject.SetActive(false);
    }
}
