using System;
using System.Collections.Generic;
using System.Reflection.Emit;
using HarmonyLib;
using TMPro;
using UnityEngine;
using UnityEngine.UI;
using Warrior.Core;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// Respec and class switch start over at level 1 (ADR-0020 items 1 and 2, ADR-0022). Progression lives
/// on the client in Player.m_customData, and Oathbound persists it right after both calls, so zeroing the
/// records in a postfix is what gets saved.
/// </summary>
internal static class ClassReset
{
    public static IEnumerable<PatchPlan> RespecPlan()
    {
        var respec = Hooks.Method(typeof(Progression), nameof(Progression.Respec), Type.EmptyTypes, typeof(void));
        Hooks.Property(typeof(Progression), "Active", typeof(ClassProgress));
        Hooks.Property(typeof(ClassProgress), nameof(ClassProgress.Experience), typeof(int), setter: true);
        yield return new PatchPlan(respec) { Postfix = Hooks.Patch(typeof(ClassReset), nameof(AfterRespec)) };
    }

    public static IEnumerable<PatchPlan> SwitchPlan()
    {
        var switchClass = Hooks.Method(typeof(Progression), nameof(Progression.SwitchClass), new[] { typeof(string) }, typeof(bool));
        Hooks.Property(typeof(Progression), nameof(Progression.ClassId), typeof(string));
        Hooks.Property(typeof(Progression), "Active", typeof(ClassProgress));
        Hooks.Field(typeof(Progression), "_classes", typeof(Dictionary<string, ClassProgress>));
        Hooks.Field(typeof(ClassProgress), "Talents", typeof(HashSet<string>));
        Hooks.Property(typeof(ClassProgress), nameof(ClassProgress.Experience), typeof(int), setter: true);
        yield return new PatchPlan(switchClass)
        {
            Prefix = Hooks.Patch(typeof(ClassReset), nameof(BeforeSwitch)),
            Postfix = Hooks.Patch(typeof(ClassReset), nameof(AfterSwitch)),
        };
    }

    /// <summary>Taking an oath now costs the levels of two classes, so the button asks once more.</summary>
    public static IEnumerable<PatchPlan> SwitchConfirmationPlan()
    {
        var preview = Hooks.Method(typeof(Plugin), "PreviewClass", new[] { typeof(ClassDefinition) }, typeof(void));
        Hooks.Once(preview, "TakeOath button", ci => ci.Is(OpCodes.Ldstr, TakeOathButton));
        Hooks.Field(typeof(Plugin), "_classAction", typeof(RectTransform));
        Hooks.Field(typeof(Plugin), "_state", typeof(Progression));
        Hooks.Method(typeof(Progression), nameof(Progression.GetClassProgress), new[] { typeof(string) }, typeof(ClassProgress));
        Hooks.Property(typeof(Progression), nameof(Progression.Experience), typeof(int));
        Hooks.Property(typeof(Progression), nameof(Progression.Purchased), typeof(IReadOnlyCollection<string>));
        Hooks.Property(typeof(Progression), nameof(Progression.ClassName), typeof(string));
        Hooks.Property(typeof(ClassProgress), nameof(ClassProgress.Purchased), typeof(IReadOnlyCollection<string>));
        yield return new PatchPlan(preview) { Postfix = Hooks.Patch(typeof(ClassReset), nameof(AfterPreviewClass)) };
    }

    /// <summary>The tree's own words would otherwise promise a free reset and progress kept per class.</summary>
    public static IEnumerable<PatchPlan> LabelPlan()
    {
        var methods = new[]
        {
            Hooks.Method(typeof(Plugin), "RefreshTree", Type.EmptyTypes, typeof(void)),
            Hooks.Method(typeof(Plugin), "SwitchClass", new[] { typeof(string) }, typeof(bool)),
            Hooks.Method(typeof(Plugin), "CreateClassPicker", Type.EmptyTypes, typeof(void)),
        };
        for (int i = 0; i < methods.Length; i++)
        {
            string label = Relabels[i].Shipped;
            Hooks.Once(methods[i], $"\"{label}\"", ci => ci.Is(OpCodes.Ldstr, label));
        }
        foreach (var method in methods)
        {
            yield return new PatchPlan(method) { Transpiler = Hooks.Patch(typeof(ClassReset), nameof(Relabel)) };
        }
    }

    private const string TakeOathButton = "TakeOath";

    /// <summary>In the order of the methods in <see cref="LabelPlan"/>.</summary>
    private static readonly (string Shipped, string Ours)[] Relabels =
    {
        ("Reset for free", "Reset to level 1"),
        (" oath active. Each class keeps its own progress.", " oath active at level 1."),
        ("Every oath keeps its own progress. Only your active class earns EXP.",
            "Taking an oath restarts it, and the oath you leave, at level 1. Only your active class earns EXP."),
    };

    private static void AfterRespec(Progression __instance) => __instance.Active.Experience = 0;

    private static void BeforeSwitch(Progression __instance, out string __state) => __state = __instance.ClassId;

    private static void AfterSwitch(Progression __instance, bool __result, string __state)
    {
        if (!__result)
        {
            return;
        }
        // The records stay: Berserker, Highlander, Breaker and Dragonsworn count as unlocked while
        // their record exists (Progression.IsUnlocked).
        if (__state != "" && __instance._classes.TryGetValue(__state, out ClassProgress left))
        {
            Reset(left);
        }
        Reset(__instance.Active);
    }

    private static void Reset(ClassProgress progress)
    {
        progress.Experience = 0;
        progress.Talents.Clear();
    }

    private static void AfterPreviewClass(Plugin __instance, ClassDefinition definition)
    {
        Progression state = __instance._state;
        if (definition.Id == state.ClassId || (!HasProgress(state.Experience, state.Purchased.Count) && !HasProgress(state.GetClassProgress(definition.Id))))
        {
            return;
        }
        Button? button = TakeOath(__instance._classAction);
        if (button == null || !button.interactable)
        {
            return;
        }

        TMP_Text? label = button.GetComponentInChildren<TMP_Text>();
        string leaving = state.ClassName;
        Button.ButtonClickedEvent take = button.onClick;
        bool armed = false;
        button.onClick = new Button.ButtonClickedEvent();
        button.onClick.AddListener(() =>
        {
            if (armed)
            {
                take.Invoke();
                return;
            }
            armed = true;
            if (label != null)
            {
                label.text = state.ClassId == ""
                    ? $"Confirm: {definition.Name} restarts at level 1"
                    : $"Confirm: {leaving} and {definition.Name} restart at level 1";
            }
        });
    }

    private static bool HasProgress(ClassProgress progress) => HasProgress(progress.Experience, progress.Purchased.Count);

    private static bool HasProgress(int experience, int talents) => experience > 0 || talents > 0;

    /// <summary>
    /// PreviewClass clears the previous button by deactivating it and destroying it at the end of the
    /// frame, so the live button is the active child of that name.
    /// </summary>
    private static Button? TakeOath(RectTransform? action)
    {
        if (action == null)
        {
            return null;
        }
        foreach (Transform child in action)
        {
            if (child.name == TakeOathButton && child.gameObject.activeSelf)
            {
                return child.GetComponent<Button>();
            }
        }
        return null;
    }

    private static IEnumerable<CodeInstruction> Relabel(IEnumerable<CodeInstruction> instructions)
    {
        foreach (CodeInstruction instruction in instructions)
        {
            if (instruction.opcode == OpCodes.Ldstr && instruction.operand is string text)
            {
                foreach (var (shipped, ours) in Relabels)
                {
                    if (text == shipped)
                    {
                        instruction.operand = ours;
                    }
                }
            }
            yield return instruction;
        }
    }
}
