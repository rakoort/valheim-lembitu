using System;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>The maker's real Herbalist level travels as quality (stack identity) and a custom-data
/// marker (effect identity), just like the cook's grade. Old and looted drinks are grade 1.</summary>
internal static class BrewersGrade
{
    public const string Marker = "lembitu.callings.brewers-grade";
    private sealed class Craft(string prefab, int grade)
    {
        public string Prefab { get; } = prefab;
        public int Grade { get; } = grade;
    }
    [ThreadStatic] private static Craft? s_craft;
    [ThreadStatic] private static float? s_drinkFactor;

    public static int GradeOf(Player player) => Mathf.Clamp(
        1 + (int)(player.GetSkills().GetSkill(Professions.Herbalist).m_level / Settings.BrewerLevelsPerGrade), 1, 5);

    public static int Grade(ItemDrop.ItemData? item) =>
        item?.m_customData != null && item.m_customData.TryGetValue(Marker, out string value)
        && int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out int grade)
            ? Mathf.Clamp(grade, 1, 5) : 1;

    public static float Factor(ItemDrop.ItemData? item) => (Grade(item) - 1) / 4f;

    public static void Stamp(ItemDrop.ItemData item, int grade)
    {
        item.m_quality = Mathf.Clamp(grade, 1, 5);
        item.m_customData ??= new Dictionary<string, string>();
        item.m_customData[Marker] = item.m_quality.ToString(CultureInfo.InvariantCulture);
    }

    public static bool IsPotion(string prefab) => BonusOutput.IsHerbalistProduct(prefab)
        || prefab.StartsWith("Mead", StringComparison.Ordinal) || prefab == "BarleyWine";

    public static IEnumerable<PatchPlan> CraftPlan()
    {
        var craft = Hooks.Method(typeof(InventoryGui), "DoCrafting", new[] { typeof(Player) }, typeof(void));
        Hooks.Field(typeof(InventoryGui), "m_craftRecipe", typeof(Recipe));
        Hooks.Field(typeof(InventoryGui), "m_craftUpgradeItem", typeof(ItemDrop.ItemData));
        yield return new PatchPlan(craft)
        {
            Prefix = Hooks.Patch(typeof(BrewersGrade), nameof(BeforeCraft), Priority.First),
            Finalizer = Hooks.Patch(typeof(BrewersGrade), nameof(AfterCraft)),
        };
        var byName = Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem),
            new[] { typeof(string), typeof(int), typeof(int), typeof(int), typeof(long), typeof(string), typeof(Vector2i), typeof(bool), typeof(bool), typeof(bool) }, typeof(ItemDrop.ItemData));
        yield return new PatchPlan(byName) { Prefix = Hooks.Patch(typeof(BrewersGrade), nameof(Quality)) };
        foreach (Type[] args in new[] { new[] { typeof(ItemDrop.ItemData) }, new[] { typeof(ItemDrop.ItemData), typeof(Vector2i) } })
        {
            yield return new PatchPlan(Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem), args, typeof(bool)))
            { Prefix = Hooks.Patch(typeof(BrewersGrade), nameof(MarkAdded), Priority.First) };
        }
        yield return new PatchPlan(Hooks.Method(typeof(ItemDrop), nameof(ItemDrop.OnCreateNew), new[] { typeof(ItemDrop), typeof(bool) }, typeof(void)))
        { Postfix = Hooks.Patch(typeof(BrewersGrade), nameof(MarkDropped)) };
        yield return new PatchPlan(Hooks.Method(typeof(ItemDrop.ItemData), nameof(ItemDrop.ItemData.GetTooltip),
            new[] { typeof(ItemDrop.ItemData), typeof(int), typeof(bool), typeof(float), typeof(int), typeof(bool) }, typeof(string)))
        { Postfix = Hooks.Patch(typeof(BrewersGrade), nameof(Tooltip)) };
    }

    private static void BeforeCraft(InventoryGui __instance, Player player)
    {
        s_craft = null;
        Recipe recipe = __instance.m_craftRecipe;
        if (player == Player.m_localPlayer && recipe?.m_item != null && __instance.m_craftUpgradeItem == null
            && IsPotion(recipe.m_item.gameObject.name))
        {
            s_craft = new Craft(recipe.m_item.gameObject.name, GradeOf(player));
        }
    }

    private static Exception? AfterCraft(Exception? __exception)
    {
        s_craft = null;
        return __exception;
    }

    private static void Quality(string name, ref int quality)
    {
        if (s_craft != null && name == s_craft.Prefab) quality = s_craft.Grade;
    }

    private static void MarkAdded(ItemDrop.ItemData item)
    {
        if (s_craft != null && item?.m_dropPrefab != null && item.m_dropPrefab.name == s_craft.Prefab)
            Stamp(item, s_craft.Grade);
    }

    private static void MarkDropped(ItemDrop item)
    {
        if (s_craft != null && Utils.GetPrefabName(item.gameObject) == s_craft.Prefab)
        {
            Stamp(item.m_itemData, s_craft.Grade);
            item.SetQuality(s_craft.Grade);
        }
    }

    private static void Tooltip(ItemDrop.ItemData item, bool crafting, ref string __result)
    {
        if (item?.m_dropPrefab == null || !IsPotion(item.m_dropPrefab.name)) return;
        int grade = crafting && Player.m_localPlayer != null ? GradeOf(Player.m_localPlayer) : Grade(item);
        __result += $"\n<color=orange>{(crafting ? "Your brewer's grade" : "Brewer's grade")} {grade}</color>: effects use the brewer, not the drinker's Herbalist level.";
    }

    /// <summary>Only Herbalist's string-based skill accessor is replaced, only during drinking. Its
    /// tonic/elixir Setup methods run synchronously inside ConsumeItem and read the same factor.</summary>
    public static IEnumerable<PatchPlan> DrinkPlan()
    {
        Pinned.Pin("blacks7ar.Herbalist", "1.5.0", "Herbalist");
        var assembly = BepInEx.Bootstrap.Chainloader.PluginInfos["blacks7ar.Herbalist"].Instance.GetType().Assembly;
        Type extensions = assembly.GetType("SkillManager.SkillExtensions")
            ?? throw new HookMismatch("Herbalist SkillManager.SkillExtensions not found");
        var factor = Hooks.Method(extensions, "GetSkillFactor", new[] { typeof(Character), typeof(string) }, typeof(float));
        yield return new PatchPlan(factor) { Prefix = Hooks.Patch(typeof(BrewersGrade), nameof(DrinkFactor)) };
        // Herbalist passes its herb heal-duration bonus into every potion SetupStats. The Run
        // uses configured potion durations exactly; herbs retain their own bonus unchanged.
        foreach (string effectName in new[] { "Berserker", "Defender", "EitrTonic", "FastLearner", "Ghost",
            "HealthTonic", "HeavyLifter", "Jump", "SlowFall", "StaminaTonic", "Swift" })
        {
            Type effect = assembly.GetType("Herbalist.SE.SE_" + effectName)
                ?? throw new HookMismatch("Herbalist potion effect not found: " + effectName);
            Hooks.Field(effect, "m_bonusDuration", typeof(float));
            FieldInfo bonus = AccessTools.Field(effect, "m_bonusDuration");
            var scale = Hooks.Method(effect, effectName == "Defender" ? "ScaleWithPlayer" : "ScaleWithSkill",
                new[] { typeof(Player) }, typeof(void));
            Hooks.Once(scale, "potion duration bonus read", ci => ci.opcode == OpCodes.Ldfld && Equals(ci.operand, bonus));
            yield return new PatchPlan(scale) { Transpiler = Hooks.Patch(typeof(BrewersGrade), nameof(ConfiguredPotionDuration)) };
        }
        var consume = Hooks.Method(typeof(Player), nameof(Player.ConsumeItem),
            new[] { typeof(Inventory), typeof(ItemDrop.ItemData), typeof(bool) }, typeof(bool));
        HarmonyMethod before = Hooks.Patch(typeof(BrewersGrade), nameof(BeforeDrink), Priority.First);
        before.before = new[] { "blacks7ar.Herbalist" };
        yield return new PatchPlan(consume)
        {
            Prefix = before,
            Finalizer = Hooks.Patch(typeof(BrewersGrade), nameof(AfterDrink)),
        };
    }

    private static void BeforeDrink(ItemDrop.ItemData item, out float? __state)
    {
        __state = s_drinkFactor;
        s_drinkFactor = item?.m_dropPrefab != null && IsPotion(item.m_dropPrefab.name) ? Factor(item) : null;
    }

    private static Exception? AfterDrink(float? __state, Exception? __exception)
    {
        s_drinkFactor = __state;
        return __exception;
    }

    private static bool DrinkFactor(string name, ref float __result)
    {
        if (name != "Herbalist" || !s_drinkFactor.HasValue) return true;
        __result = s_drinkFactor.Value;
        return false;
    }

    private static IEnumerable<CodeInstruction> ConfiguredPotionDuration(IEnumerable<CodeInstruction> instructions)
    {
        MethodInfo adjusted = AccessTools.DeclaredMethod(typeof(BrewersGrade), nameof(PotionDurationBonus));
        foreach (CodeInstruction instruction in instructions)
        {
            yield return instruction;
            if (instruction.opcode == OpCodes.Ldfld && instruction.operand is FieldInfo field && field.Name == "m_bonusDuration")
                yield return new CodeInstruction(OpCodes.Call, adjusted);
        }
    }

    private static float PotionDurationBonus(float bonus) => s_drinkFactor.HasValue ? 0f : bonus;
}
