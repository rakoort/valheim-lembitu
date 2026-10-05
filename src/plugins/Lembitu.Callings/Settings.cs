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

    public static float ExplorerRangeAtLevel1 => s_explorerRangeAtLevel1.Value;
    public static float ExplorerRangeAt100 => s_explorerRangeAt100.Value;

    public static float OathstoneRange => s_oathstoneRange.Value;

    /// <summary>Expected extra items per Herbalist craft at skill 100; scales linearly with skill.</summary>
    public static float HerbalistExtraAt100 => s_herbalistExtra.Value;

    /// <summary>Expected extra fish per landed catch at skill 100; scales linearly with skill.</summary>
    public static float FishingExtraAt100 => s_fishingExtra.Value;

    public static void Bind(ConfigFile config)
    {
        const string curve = "Steep curve";
        s_band1End = Bind(config, curve, "Band1End", 30f, "A non-focus profession below this level gains at Band1Rate.", 0f, 100f);
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
    }

    /// <summary>The steep curve: how fast a non-focus profession at this level gains.</summary>
    public static float Rate(float level) =>
        level < s_band1End.Value ? s_band1Rate.Value
        : level < s_band2End.Value ? s_band2Rate.Value
        : level < s_band3End.Value ? s_band3Rate.Value
        : s_beyondRate.Value;

    private static ConfigEntry<float> Bind(ConfigFile config, string section, string key, float value, string description, float min, float max) =>
        config.Bind(section, key, value, new ConfigDescription(description, new AcceptableValueRange<float>(min, max),
            new ConfigurationManagerAttributes { IsAdminOnly = true }));
}
