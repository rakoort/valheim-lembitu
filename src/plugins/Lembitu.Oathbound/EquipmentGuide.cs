using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;
using Warrior.Core;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// Refusals name their cause and the guide page (ADR-0027). Oathbound's class equipment rule already
/// says what the class keeps to; the message now also ends with the guide page that explains the
/// oath, in the fixed format every refusal message of ours shares.
/// </summary>
internal static class EquipmentGuide
{
    /// <summary>The page every class-equipment refusal ends with (fixed contract, Lembitu.Guide).</summary>
    public const string Page = " Guide: Oath and class (oath-and-class).";

    public static IEnumerable<PatchPlan> Plan()
    {
        // The only writer of the refusal text (Plugin.ClassEquipPatch notifies it on a refused equip).
        MethodInfo refusal = Hooks.Method(typeof(Plugin), "Refusal", new[] { typeof(ItemDrop.ItemData) }, typeof(string));
        Hooks.Field(typeof(Plugin), "_state", typeof(Progression));
        Hooks.Method(typeof(Plugin), "Describe", new[] { typeof(ItemDrop.ItemData), typeof(string) }, typeof(EquipmentItem));
        Hooks.Property(typeof(EquipmentItem), nameof(EquipmentItem.Bow), typeof(bool));
        yield return new PatchPlan(refusal) { Postfix = Hooks.Patch(typeof(EquipmentGuide), nameof(NamePage)) };
    }

    private static void NamePage(Plugin __instance, ItemDrop.ItemData item, ref string __result)
    {
        Progression state = __instance._state;
        if (__result == "That item cannot be equipped."
            && (state.ClassId == "shieldbearer" || state.ClassId == "valkyrie")
            && Plugin.Describe(item).Bow)
        {
            __result = state.ClassName + " fights in melee and never uses a bow.";
        }
        __result += Page;
    }
}
