using System;
using BepInEx.Configuration;

namespace Lembitu.Callings;

/// <summary>Server-locked through Jotunn (IsAdminOnly), so every client uses the server's numbers.</summary>
internal static class Settings
{
    private static ConfigEntry<float> s_band1End = null!, s_band1Rate = null!;
    private static ConfigEntry<float> s_band2End = null!, s_band2Rate = null!;
    private static ConfigEntry<float> s_band3End = null!, s_band3Rate = null!;
    private static ConfigEntry<float> s_beyondRate = null!;
    private static ConfigEntry<float> s_oathstoneRange = null!;
    private static ConfigEntry<float> s_herbalistExtra = null!;
    private static ConfigEntry<float> s_fishingExtra = null!;
    private static ConfigEntry<float> s_explorerRangeAtLevel1 = null!, s_explorerRangeAt100 = null!;
    private static ConfigEntry<float> s_levelsPerGrade = null!, s_foodBonusPerGrade = null!, s_shelfLifePerGrade = null!;
    private static ConfigEntry<float> s_workMealBonus = null!;
    private static ConfigEntry<string> s_workMeals = null!;
    private static ConfigEntry<float> s_logSplitterLevel = null!, s_logSplitterChance = null!, s_logSplitterChanceAt100 = null!;
    private static ConfigEntry<float> s_quickBiteLevel = null!, s_quickBiteHookChance = null!;
    private static ConfigEntry<float> s_steadyOverloadLevel = null!, s_steadyOverloadLimit = null!;
    private static ConfigEntry<float> s_xpReportMinutes = null!;

    public static float ExplorerRangeAtLevel1 => s_explorerRangeAtLevel1.Value;
    public static float ExplorerRangeAt100 => s_explorerRangeAt100.Value;

    /// <summary>Cooking levels per step of the cook's grade; grade 1 lies below the first step.</summary>
    public static int LevelsPerGrade => Math.Max(1, (int)s_levelsPerGrade.Value);

    /// <summary>Extra health, stamina, eitr and regeneration per grade above 1.</summary>
    public static float FoodBonusPerGrade => s_foodBonusPerGrade.Value;

    /// <summary>Extra shelf life per grade above 1.</summary>
    public static float ShelfLifePerGrade => s_shelfLifePerGrade.Value;

    /// <summary>Levels a work meal adds to its profession while the meal lasts.</summary>
    public static float WorkMealBonus => s_workMealBonus.Value;

    /// <summary>"Dish:ProfessionKey" pairs, comma-separated.</summary>
    public static ConfigEntry<string> WorkMeals => s_workMeals;

    public static float OathstoneRange => s_oathstoneRange.Value;

    /// <summary>Expected extra items per Herbalist craft at skill 100; scales linearly with skill.</summary>
    public static float HerbalistExtraAt100 => s_herbalistExtra.Value;

    /// <summary>Expected extra fish per landed catch at skill 100; scales linearly with skill.</summary>
    public static float FishingExtraAt100 => s_fishingExtra.Value;

    /// <summary>Wood Cutting level from which a chop can split a whole fallen log.</summary>
    public static float LogSplitterLevel => s_logSplitterLevel.Value;

    /// <summary>The split chance per chop: ChanceAtLevel at LogSplitterLevel, rising linearly to ChanceAt100.</summary>
    public static float LogSplitterChance(float level) =>
        level < s_logSplitterLevel.Value ? 0f
        : Lerp(s_logSplitterChance.Value, s_logSplitterChanceAt100.Value, s_logSplitterLevel.Value, level);

    /// <summary>Fishing level from which a cast float draws fish faster.</summary>
    public static float QuickBiteLevel => s_quickBiteLevel.Value;

    /// <summary>The chance a fish choosing where to swim goes for a quick-bite float in range (vanilla 0.5).</summary>
    public static float QuickBiteHookChance => s_quickBiteHookChance.Value;

    /// <summary>Hauling level from which walking over the carry limit costs no stamina.</summary>
    public static float SteadyOverloadLevel => s_steadyOverloadLevel.Value;

    /// <summary>The steady overload holds up to this multiple of the carry limit.</summary>
    public static float SteadyOverloadLimit => s_steadyOverloadLimit.Value;

    /// <summary>Minutes of play between a client's profession XP reports.</summary>
    public static float XpReportMinutes => s_xpReportMinutes.Value;

    public static void Bind(ConfigFile config)
    {
        const string curve = "Steep curve";
        s_band1End = Bind(config, curve, "Band1End", 10f, "A non-focus profession below this level gains at Band1Rate.", 0f, 100f);
        s_band1Rate = Bind(config, curve, "Band1Rate", 1f, "Gain multiplier below Band1End.", 0f, 1f);
        s_band2End = Bind(config, curve, "Band2End", 60f, "Below this level (and from Band1End) a non-focus profession gains at Band2Rate.", 0f, 100f);
        s_band2Rate = Bind(config, curve, "Band2Rate", 0.5f, "Gain multiplier from Band1End to Band2End.", 0f, 1f);
        s_band3End = Bind(config, curve, "Band3End", 80f, "Below this level (and from Band2End) a non-focus profession gains at Band3Rate.", 0f, 100f);
        s_band3Rate = Bind(config, curve, "Band3Rate", 0.25f, "Gain multiplier from Band2End to Band3End.", 0f, 1f);
        s_beyondRate = Bind(config, curve, "BeyondRate", 0.1f, "Gain multiplier from Band3End on.", 0f, 1f);
        s_oathstoneRange = Bind(config, "Calling", "OathstoneRange", 10f, "Metres from the Oathstone within which the Calling can be changed in the skills window.", 1f, 100f);
        s_herbalistExtra = Bind(config, "Perks", "HerbalistExtraAt100", 1.5f, "Expected extra items per successful tonic, elixir or mead-base craft at Herbalist 100.", 0f, 10f);
        s_fishingExtra = Bind(config, "Perks", "FishingExtraAt100", 1.25f, "Expected extra fish per landed catch at Fishing 100.", 0f, 10f);
        s_explorerRangeAtLevel1 = Bind(config, "Explorer markers", "RangeAtLevel1", 20f, "Live marker range in metres at Explorer level 1; replaces Explorer Detection Radius on each tracker update.", 0f, 100f);
        s_explorerRangeAt100 = Bind(config, "Explorer markers", "RangeAt100", 64f, "Live marker range in metres at Explorer level 100; interpolated linearly from level 1.", 0f, 100f);
        s_levelsPerGrade = Bind(config, "Cook grade", "LevelsPerGrade", 25f, "Cooking levels per grade: a dish made below this level is grade 1, then one grade per step, grade 5 at 100 with the default.", 5f, 100f);
        s_foodBonusPerGrade = Bind(config, "Cook grade", "FoodBonusPerGrade", 0.025f, "Extra health, stamina, eitr and regeneration a dish gives per grade above 1.", 0f, 0.5f);
        s_shelfLifePerGrade = Bind(config, "Cook grade", "ShelfLifePerGrade", 0.125f, "Extra shelf life a dish gets per grade above 1, on FineDining's lifetime.", 0f, 1f);
        s_workMealBonus = Bind(config, "Work meals", "LevelBonus", 10f, "Levels a work meal adds to its profession's perks while the meal lasts; recipe rungs read the real level.", 0f, 50f);
        s_workMeals = config.Bind("Work meals", "Meals",
            "BoarJerky:Explorer, DeerStew:WoodCutting, Sausages:Pickaxes, CarrotSoup:Farming, SerpentStew:midnightsfx.voyager, WolfJerky:midnightsfx.hauling, BloodPudding:midnightsfx.animalwhisper, FishWraps:Fishing",
            new ConfigDescription("Comma-separated Dish:Profession pairs. Professions are the Calling keys of Land and Road professions: Pickaxes, WoodCutting, Farming, Fishing, midnightsfx.animalwhisper, Explorer, midnightsfx.voyager, midnightsfx.hauling.",
                null, new ConfigurationManagerAttributes { IsAdminOnly = true }));
        s_logSplitterLevel = Bind(config, "Log splitter", "Level", 50f, "Wood Cutting level from which a chop on a fallen log can split the whole log, its half logs included, into wood at once.", 0f, 100f);
        s_logSplitterChance = Bind(config, "Log splitter", "ChanceAtLevel", 0.1f, "The split chance per chop at Level.", 0f, 1f);
        s_logSplitterChanceAt100 = Bind(config, "Log splitter", "ChanceAt100", 0.3f, "The split chance per chop at Wood Cutting 100; linear from Level.", 0f, 1f);
        s_quickBiteLevel = Bind(config, "Quick bite", "Level", 50f, "Fishing level from which a cast float draws fish faster.", 0f, 100f);
        s_quickBiteHookChance = Bind(config, "Quick bite", "HookChance", 1f, "Chance a fish choosing where to swim heads for a quick-bite float in range; vanilla is 0.5. The bait still decides whether it bites.", 0f, 1f);
        s_steadyOverloadLevel = Bind(config, "Steady overload", "Level", 50f, "Hauling level from which walking over the carry limit costs no stamina.", 0f, 100f);
        s_steadyOverloadLimit = Bind(config, "Steady overload", "LoadLimit", 1.5f, "Multiple of the carry limit up to which the steady overload holds; above it vanilla's stamina drain applies.", 1f, 10f);
        s_xpReportMinutes = Bind(config, "XP log", "ReportMinutes", 10f, "Minutes of play between each client's profession XP report to the server log.", 0.5f, 120f);
    }

    /// <summary>The steep curve: how fast a non-focus profession at this level gains.</summary>
    public static float Rate(float level) =>
        level < s_band1End.Value ? s_band1Rate.Value
        : level < s_band2End.Value ? s_band2Rate.Value
        : level < s_band3End.Value ? s_band3Rate.Value
        : s_beyondRate.Value;

    private static float Lerp(float atLevel, float at100, float level, float current) =>
        level >= 100f ? at100 : UnityEngine.Mathf.Lerp(atLevel, at100, (current - level) / (100f - level));

    private static ConfigEntry<float> Bind(ConfigFile config, string section, string key, float value, string description, float min, float max) =>
        config.Bind(section, key, value, new ConfigDescription(description, new AcceptableValueRange<float>(min, max),
            new ConfigurationManagerAttributes { IsAdminOnly = true }));
}
