using System;
using System.Collections.Generic;
using BepInEx.Logging;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// Work meals (ADR-0029): while a chosen dish is one of the eater's foods, one Land or Road
/// profession counts as some levels higher, so its perks reach further. A status effect carries the
/// bonus and shows it, and its time follows the food, which FineDining saves with the player, so the
/// bonus survives a relog, leaves with the food and is never a consume effect: vanilla refuses to
/// consume an item whose consume effect is active, which would stop re-eating the dish at half time.
/// Recipe rungs read the real level (Item_Requirement), and so does the cook's grade.
/// </summary>
internal static class WorkMeals
{
    private const string EffectPrefix = "LembituWorkMeal_";

    private static ManualLogSource s_log = null!;
    private static string s_parsedFrom = "";
    private static Dictionary<string, Profession> s_meals = new(StringComparer.Ordinal);
    private static readonly Dictionary<string, SE_Stats> Templates = new(StringComparer.Ordinal);
    private static float s_nextSync;

    public static void Configure(ManualLogSource log) => s_log = log;

    public static IEnumerable<PatchPlan> Plan()
    {
        var eatFood = Hooks.Method(typeof(Player), nameof(Player.EatFood), new[] { typeof(ItemDrop.ItemData) }, typeof(bool));
        var updateFood = Hooks.Method(typeof(Player), "UpdateFood", new[] { typeof(float), typeof(bool) }, typeof(void));
        Hooks.Field(typeof(Player), "m_foods", typeof(List<Player.Food>));
        Hooks.Field(typeof(StatusEffect), "m_time", typeof(float));
        Hooks.Field(typeof(SE_Stats), nameof(SE_Stats.m_skillLevel), typeof(Skills.SkillType));
        Hooks.Field(typeof(SE_Stats), nameof(SE_Stats.m_skillLevelModifier), typeof(float));
        yield return new PatchPlan(eatFood) { Postfix = Hooks.Patch(typeof(WorkMeals), nameof(AfterEat)) };
        yield return new PatchPlan(updateFood) { Postfix = Hooks.Patch(typeof(WorkMeals), nameof(AfterUpdateFood)) };
    }

    /// <summary>The profession a dish feeds, from the server-locked meal list.</summary>
    public static bool TryGetMeal(string prefab, out Profession profession) => Meals().TryGetValue(prefab, out profession);

    private static Dictionary<string, Profession> Meals()
    {
        string raw = Settings.WorkMeals.Value ?? "";
        if (raw == s_parsedFrom)
        {
            return s_meals;
        }
        var meals = new Dictionary<string, Profession>(StringComparer.Ordinal);
        foreach (string pair in raw.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
        {
            string[] parts = pair.Split(':');
            if (parts.Length != 2 || !Professions.TryGet(parts[1].Trim(), out Profession profession))
            {
                s_log.LogWarning($"Work meal '{pair.Trim()}' is not Dish:Profession with a known profession; ignored.");
                continue;
            }
            if (profession.Group == ProfessionGroup.Craft)
            {
                s_log.LogWarning($"Work meal '{pair.Trim()}' feeds a Craft profession; work meals are for Land and Road. Ignored.");
                continue;
            }
            meals[parts[0].Trim()] = profession;
        }
        Templates.Clear();
        s_meals = meals;
        s_parsedFrom = raw;
        return meals;
    }

    private static void AfterEat(Player __instance, bool __result)
    {
        if (__result && __instance == Player.m_localPlayer)
        {
            Sync(__instance);
        }
    }

    private static void AfterUpdateFood(Player __instance)
    {
        if (__instance != Player.m_localPlayer || Time.time < s_nextSync)
        {
            return;
        }
        s_nextSync = Time.time + 1f;
        Sync(__instance);
    }

    /// <summary>One effect per fed profession, lasting exactly as long as its longest-lasting meal.</summary>
    private static void Sync(Player player)
    {
        Dictionary<string, Profession> meals = Meals();
        var fed = new Dictionary<Profession, Player.Food>();
        foreach (Player.Food food in player.m_foods)
        {
            if (meals.TryGetValue(food.m_name, out Profession profession)
                && (!fed.TryGetValue(profession, out Player.Food other) || food.m_time > other.m_time))
            {
                fed[profession] = food;
            }
        }
        SEMan seman = player.GetSEMan();
        foreach (Profession profession in meals.Values)
        {
            int hash = (EffectPrefix + profession.Key).GetStableHashCode();
            StatusEffect? active = seman.GetStatusEffect(hash);
            if (!fed.TryGetValue(profession, out Player.Food food))
            {
                if (active != null)
                {
                    seman.RemoveStatusEffect(hash, quiet: true);
                }
                continue;
            }
            active ??= seman.AddStatusEffect(Template(profession, food));
            if (active != null)
            {
                active.m_ttl = active.m_time + food.m_time;
            }
        }
    }

    private static SE_Stats Template(Profession profession, Player.Food food)
    {
        float bonus = Settings.WorkMealBonus;
        if (Templates.TryGetValue(profession.Key, out SE_Stats template) && template != null && template.m_skillLevelModifier == bonus)
        {
            return template;
        }
        template = ScriptableObject.CreateInstance<SE_Stats>();
        template.name = EffectPrefix + profession.Key;
        template.m_name = $"Work meal: {profession.DisplayName} +{bonus:0}";
        template.m_tooltip = $"{profession.DisplayName} counts as {bonus:0} levels higher while this meal lasts. Recipes still need your own level.";
        template.m_icon = food.m_item.GetIcon();
        template.m_skillLevel = profession.Type;
        template.m_skillLevelModifier = bonus;
        Templates[profession.Key] = template;
        return template;
    }
}
