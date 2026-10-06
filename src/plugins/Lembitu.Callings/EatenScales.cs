using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using FineDining;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// FineDining 1.1.3 saves its diet state with Unity's JsonUtility, which in this game build writes
/// only the slot fields and drops the list of eaten foods (seen 2026-10-06: the saved state is
/// <c>{"UnlockedFoodSlots":3,"AppliedBaseSlotScale":1.1}</c> after eating). After a relog every
/// eaten food falls back to the base scale, so a graded dish loses its grade and stale food comes
/// back fresh. This keeps each eaten food's scales under a key of our own and puts them back when
/// FineDining loads an empty list; if FineDining ever saves the list itself, its own copy wins.
/// </summary>
internal static class EatenScales
{
    public const string Key = "lembitu.callings.eaten-scales";

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin(CooksGrade.FineDiningGuid, "1.1.3", "FineDining");
        var save = Hooks.Method(typeof(FoodStateStore), nameof(FoodStateStore.SaveState), new[] { typeof(Player), typeof(PlayerFoodStateData) }, typeof(void));
        var load = Hooks.Method(typeof(FoodStateStore), "LoadState", new[] { typeof(Player) }, typeof(PlayerFoodStateData));
        Hooks.Field(typeof(PlayerFoodStateData), nameof(PlayerFoodStateData.Active), typeof(List<ActiveFoodData>));
        yield return new PatchPlan(save) { Postfix = Hooks.Patch(typeof(EatenScales), nameof(AfterSave)) };
        yield return new PatchPlan(load) { Postfix = Hooks.Patch(typeof(EatenScales), nameof(AfterLoad)) };
    }

    /// <summary>SaveState has just cached and serialized the state; our copy follows it.</summary>
    private static void AfterSave(Player player)
    {
        if (player == null)
        {
            return;
        }
        List<ActiveFoodData> active = FoodStateStore.GetState(player).Active;
        if (active.Count == 0)
        {
            player.m_customData.Remove(Key);
            return;
        }
        player.m_customData[Key] = string.Join(";", active.Select(Encode));
    }

    /// <summary>FineDining normalizes right after loading and drops any food the player no longer has.</summary>
    private static void AfterLoad(Player player, PlayerFoodStateData __result)
    {
        if (player == null || __result == null || !player.m_customData.TryGetValue(Key, out string saved))
        {
            return;
        }
        __result.Active ??= new List<ActiveFoodData>();
        if (__result.Active.Count > 0)
        {
            return;
        }
        foreach (string entry in saved.Split(';'))
        {
            if (TryDecode(entry, out ActiveFoodData food))
            {
                __result.Active.Add(food);
            }
        }
    }

    private static string Encode(ActiveFoodData f) => string.Join(",",
        f.Key, Number(f.AppliedScale), f.HasEffectBreakdown ? "1" : "0", Number(f.ChefMultiplier), Number(f.FreshnessScale), Number(f.DiminishingScale));

    private static string Number(float value) => value.ToString("R", CultureInfo.InvariantCulture);

    private static bool TryDecode(string entry, out ActiveFoodData food)
    {
        food = new ActiveFoodData();
        string[] parts = entry.Split(',');
        if (parts.Length != 6 || parts[0].Length == 0
            || !TryNumber(parts[1], out float applied) || !TryNumber(parts[3], out float chef)
            || !TryNumber(parts[4], out float freshness) || !TryNumber(parts[5], out float diminishing))
        {
            return false;
        }
        food.Key = parts[0];
        food.AppliedScale = applied;
        food.HasEffectBreakdown = parts[2] == "1";
        food.ChefMultiplier = chef;
        food.FreshnessScale = freshness;
        food.DiminishingScale = diminishing;
        return true;
    }

    private static bool TryNumber(string text, out float value) =>
        float.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out value);
}
