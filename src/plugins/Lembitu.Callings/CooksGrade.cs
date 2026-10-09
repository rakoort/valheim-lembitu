using System;
using System.Collections.Generic;
using System.Globalization;
using FineDining;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// The cook's grade (ADR-0029): a dish made at a Cooking station carries the grade of the cook who
/// made it, 1 below the first step of Cooking levels and one more per step, 5 at 100 with the
/// default 25. Grade 2 and up gives health, stamina, eitr and regeneration a bonus and a longer shelf
/// life. The grade reads the cook's real Cooking level, never a bonus from food or gear.
///
/// The grade lives in two places. Item quality keeps grades in separate stacks, because Valheim
/// stacks by name, quality and world level only (<c>Inventory.FindFreeStackItem</c>), and it travels
/// through the Market, whose item record copies quality and custom data. A custom-data marker is what
/// the effects read, so a fish caught at quality 3 is never mistaken for a graded dish.
///
/// FineDining computes every food's stats and its shelf life, so the effects hook it: the eaten
/// dish's scale, which FineDining keeps per eaten food (<see cref="EatenScales"/> carries it through a
/// relog), and the lifetime rule it assigns when a dish first enters an inventory.
/// </summary>
internal static class CooksGrade
{
    public const string FineDiningGuid = "sighsorry.FineDining";
    public const string Marker = "lembitu.callings.cooks-grade";

    /// <summary>Whether FineDining's food and shelf-life hooks are on; without them a grade does nothing.</summary>
    public static bool FoodOn { get; set; }

    /// <summary>The craft in progress whose product is a graded dish.</summary>
    private sealed class Craft(string prefab, int grade)
    {
        public string Prefab { get; } = prefab;
        public int Grade { get; } = grade;
    }

    [ThreadStatic] private static Craft? s_craft;

    /// <summary>Items a cooking station turns into an edible dish: doughs, uncooked pies, raw cuts.</summary>
    private static HashSet<string>? s_stationInputs;

    public static IEnumerable<PatchPlan> CraftPlan()
    {
        var doCrafting = Hooks.Method(typeof(InventoryGui), "DoCrafting", new[] { typeof(Player) }, typeof(void));
        var addByName = Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem),
            new[] { typeof(string), typeof(int), typeof(int), typeof(int), typeof(long), typeof(string), typeof(Vector2i), typeof(bool), typeof(bool), typeof(bool) },
            typeof(ItemDrop.ItemData));
        var addItem = Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem), new[] { typeof(ItemDrop.ItemData) }, typeof(bool));
        var addItemAt = Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem), new[] { typeof(ItemDrop.ItemData), typeof(Vector2i) }, typeof(bool));
        Hooks.Field(typeof(InventoryGui), "m_craftRecipe", typeof(Recipe));
        Hooks.Field(typeof(InventoryGui), "m_craftUpgradeItem", typeof(ItemDrop.ItemData));
        Hooks.Field(typeof(CraftingStation), nameof(CraftingStation.m_craftingSkill), typeof(Skills.SkillType));
        yield return new PatchPlan(doCrafting)
        {
            Prefix = Hooks.Patch(typeof(CooksGrade), nameof(BeforeCrafting), Priority.First),
            Finalizer = Hooks.Patch(typeof(CooksGrade), nameof(AfterCrafting)),
        };
        yield return new PatchPlan(addByName) { Prefix = Hooks.Patch(typeof(CooksGrade), nameof(GradeQuality)) };
        yield return new PatchPlan(addItem) { Prefix = MarkFirst() };
        yield return new PatchPlan(addItemAt) { Prefix = MarkFirst() };
    }

    /// <summary>FineDining's own first prefix on these adds fixes the lifetime, so the marker must already be there.</summary>
    private static HarmonyMethod MarkFirst()
    {
        HarmonyMethod mark = Hooks.Patch(typeof(CooksGrade), nameof(MarkAdded), Priority.First);
        mark.before = new[] { FineDiningGuid };
        return mark;
    }

    /// <summary>The grade's bonus to food stats and its longer shelf life, through FineDining.</summary>
    public static IEnumerable<PatchPlan> FoodPlan()
    {
        Pinned.Pin(FineDiningGuid, "1.1.4", "FineDining");
        var effect = Hooks.Method(typeof(FoodRules), nameof(FoodRules.CalculateFoodEffect),
            new[] { typeof(ItemDrop.ItemData), typeof(int), typeof(bool), typeof(float), typeof(bool), typeof(int) }, typeof(FoodEffect));
        var resolve = Hooks.Method(typeof(SpoilagePolicy), nameof(SpoilagePolicy.Resolve), new[] { typeof(ItemDrop.ItemData) }, typeof(ResolvedSpoilageRule));
        yield return new PatchPlan(effect) { Postfix = Hooks.Patch(typeof(CooksGrade), nameof(GradeFoodEffect)) };
        yield return new PatchPlan(resolve) { Postfix = Hooks.Patch(typeof(CooksGrade), nameof(GradeShelfLife)) };
    }

    public static IEnumerable<PatchPlan> TooltipPlan()
    {
        var tooltip = Hooks.Method(typeof(ItemDrop.ItemData), nameof(ItemDrop.ItemData.GetTooltip),
            new[] { typeof(ItemDrop.ItemData), typeof(int), typeof(bool), typeof(float), typeof(int), typeof(bool) }, typeof(string));
        yield return new PatchPlan(tooltip) { Postfix = Hooks.Patch(typeof(CooksGrade), nameof(AfterTooltip)) };
    }

    /// <summary>1 below the first step, one more per step of the cook's real Cooking level.</summary>
    public static int GradeOf(Player player)
    {
        float level = player.GetSkills().GetSkill(Skills.SkillType.Cooking).m_level;
        int step = Settings.LevelsPerGrade;
        int max = 1 + 100 / step;
        return Mathf.Clamp(1 + (int)(level / step), 1, max);
    }

    public static float FoodFactor(int grade) => 1f + (grade - 1) * Settings.FoodBonusPerGrade;

    public static float ShelfFactor(int grade) => 1f + (grade - 1) * Settings.ShelfLifePerGrade;

    /// <summary>A graded dish: the marker says 2 or more and the item is still a dish.</summary>
    public static bool TryGetGrade(ItemDrop.ItemData? item, out int grade)
    {
        grade = 1;
        return item?.m_customData != null
            && item.m_customData.TryGetValue(Marker, out string value)
            && int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out grade)
            && grade >= 2;
    }

    /// <summary>Gives a dish its grade: the quality that separates stacks and the marker the effects read.</summary>
    public static void Stamp(ItemDrop.ItemData item, int grade)
    {
        item.m_quality = grade;
        item.m_customData ??= new Dictionary<string, string>();
        item.m_customData[Marker] = grade.ToString(CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Something a cook makes to be eaten: an edible dish, or an item a cooking station turns into
    /// one. Herbalist's products and mead bases are the alchemist's, and feasts are left ungraded.
    /// </summary>
    public static bool IsDish(string prefab)
    {
        if (prefab.Length == 0 || prefab.StartsWith("Feast", StringComparison.Ordinal) || BonusOutput.IsHerbalistProduct(prefab))
        {
            return false;
        }
        GameObject? item = ObjectDB.instance?.GetItemPrefab(prefab);
        ItemDrop? drop = item != null ? item.GetComponent<ItemDrop>() : null;
        return drop != null && (IsEdible(drop.m_itemData.m_shared) || StationInputs().Contains(prefab));
    }

    private static bool IsEdible(ItemDrop.ItemData.SharedData shared) =>
        shared.m_food + shared.m_foodStamina + shared.m_foodEitr > 0f;

    private static HashSet<string> StationInputs()
    {
        if (s_stationInputs != null)
        {
            return s_stationInputs;
        }
        var inputs = new HashSet<string>(StringComparer.Ordinal);
        if (ZNetScene.instance == null)
        {
            return inputs;
        }
        foreach (GameObject prefab in ZNetScene.instance.m_prefabs)
        {
            CookingStation? station = prefab != null ? prefab.GetComponent<CookingStation>() : null;
            if (station == null)
            {
                continue;
            }
            foreach (CookingStation.ItemConversion conversion in station.m_conversion)
            {
                if (conversion.m_from != null && conversion.m_to != null && IsEdible(conversion.m_to.m_itemData.m_shared))
                {
                    inputs.Add(conversion.m_from.gameObject.name);
                }
            }
        }
        return s_stationInputs = inputs;
    }

    private static void BeforeCrafting(InventoryGui __instance, Player player)
    {
        s_craft = null;
        Recipe recipe = __instance.m_craftRecipe;
        if (player != Player.m_localPlayer || recipe == null || recipe.m_item == null || __instance.m_craftUpgradeItem != null
            || recipe.m_craftingStation == null || recipe.m_craftingStation.m_craftingSkill != Skills.SkillType.Cooking)
        {
            return;
        }
        string prefab = recipe.m_item.gameObject.name;
        int grade = GradeOf(player);
        if (grade >= 2 && IsDish(prefab))
        {
            s_craft = new Craft(prefab, grade);
        }
    }

    private static Exception? AfterCrafting(Exception? __exception)
    {
        s_craft = null;
        return __exception;
    }

    /// <summary>DoCrafting adds its product by name; the product is made at the cook's grade.</summary>
    private static void GradeQuality(string name, ref int quality)
    {
        Craft? craft = s_craft;
        if (craft != null && name == craft.Prefab)
        {
            quality = craft.Grade;
        }
    }

    /// <summary>The by-name add places a fresh item through these; it carries the marker before it can merge.</summary>
    private static void MarkAdded(ItemDrop.ItemData item)
    {
        Craft? craft = s_craft;
        if (craft != null && item != null && item.m_quality == craft.Grade && item.m_dropPrefab != null && item.m_dropPrefab.name == craft.Prefab)
        {
            Stamp(item, craft.Grade);
        }
    }

    /// <summary>Scales everything the dish gives, so FineDining saves the grade with the eaten food.</summary>
    private static void GradeFoodEffect(ItemDrop.ItemData item, ref FoodEffect __result)
    {
        if (!TryGetGrade(item, out int grade))
        {
            return;
        }
        float f = FoodFactor(grade);
        FoodEffect e = __result;
        __result = new FoodEffect(e.FreshnessScale, e.AppliedScale * f, e.EffectiveScale * f, e.DiminishingScale,
            e.Health * f, e.Stamina * f, e.Eitr * f, e.Regen * f, e.IsChef, e.ChefMultiplier, e.FullCourseActive);
    }

    /// <summary>A graded dish's lifetime, read when FineDining first starts its clock.</summary>
    private static void GradeShelfLife(ItemDrop.ItemData item, ref ResolvedSpoilageRule __result)
    {
        if (__result.State != SpoilageRuleState.Enabled || __result.LifetimeTicks <= 0 || !TryGetGrade(item, out int grade))
        {
            return;
        }
        ResolvedSpoilageRule r = __result;
        __result = new ResolvedSpoilageRule(r.State, (long)Math.Round(r.LifetimeTicks * (double)ShelfFactor(grade)),
            r.ReplacementPrefab, r.Group, r.IsOverride, r.ExpiryAction);
    }

    private static void AfterTooltip(ItemDrop.ItemData item, bool crafting, ref string __result)
    {
        if (item?.m_dropPrefab == null)
        {
            return;
        }
        string prefab = item.m_dropPrefab.name;
        if (FoodOn && !crafting && TryGetGrade(item, out int grade))
        {
            __result += $"\n<color=orange>Cook's grade {grade}</color>: {Effect(item, grade)}";
        }
        else if (FoodOn && crafting && Player.m_localPlayer != null && IsDish(prefab))
        {
            int yours = GradeOf(Player.m_localPlayer);
            __result += yours >= 2
                ? $"\n<color=orange>Your cook's grade {yours}</color>: {Effect(item, yours)}"
                : $"\n<color=orange>Your cook's grade 1</color>: no bonus until Cooking {Settings.LevelsPerGrade}";
        }
        if (WorkMeals.TryGetMeal(prefab, out Profession profession))
        {
            __result += $"\n<color=orange>Work meal</color>: {profession.DisplayName} +{Settings.WorkMealBonus:0} while it lasts";
        }
    }

    /// <summary>What a grade gives this item; shelf life only for a dish FineDining lets spoil.</summary>
    private static string Effect(ItemDrop.ItemData item, int grade)
    {
        string food = $"{Percent(FoodFactor(grade))} health, stamina and eitr";
        return SpoilagePolicy.Resolve(item).State == SpoilageRuleState.Enabled
            ? $"{food}; keeps {Percent(ShelfFactor(grade))} longer"
            : food;
    }

    private static string Percent(float factor) => $"+{(factor - 1f) * 100f:0.#}%";
}
