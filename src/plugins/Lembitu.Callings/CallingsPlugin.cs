using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Utils;

namespace Lembitu.Callings;

/// <summary>
/// Professions and the Calling (ADR-0021, ADR-0022): four focus professions chosen in the Calling
/// window at the Oathstone, the steep curve for every other profession, shadow levels, focus
/// protection on death, one death drain for every profession skill, and the Herbalist and Fishing
/// bonus output. Beyond its own skills it follows soil's rules for SeedBed's beds, refuses Herbalist
/// tonics whose biome's boss key the drinker lacks, and locks BlacksmithingExpanded's settings. It
/// grows Explorer's live marker range with its skill. The cook (ADR-0029): dishes carry the cook's
/// grade through crafting and cooking stations, which FineDining turns into stronger food and a
/// longer shelf life, and work meals raise a profession while they last. Hooks vanilla, World
/// Advancement Progression, SeedBed, Explorer, FineDining, Zen_ModLib, DodgeShortcut and the bundled
/// skill managers, never Oathbound, so an Oathbound release cannot break it.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(SkillRules.WorldAdvancementProgressionGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(SmithLock.BlacksmithingExpandedGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency("blacks7ar.SeedBed", BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency("blacks7ar.Herbalist", BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(ExplorerRange.Guid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(CooksGrade.FineDiningGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency("ZenDragon.Zen.ModLib", BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency("Searica.Valheim.DodgeShortcut", BepInDependency.DependencyFlags.SoftDependency)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class CallingsPlugin : BaseUnityPlugin
{
    private Harmony? _harmony;
    private bool _deepNorthOn;
    private void Awake()
    {
        ManualLogSource log = Logger;
        Settings.Bind(Config);
        CallingStore.Configure(log);
        SkillHooks.Configure(log);
        WorkMeals.Configure(log);
        XpLog.Configure(log);

        _harmony = new Harmony(PluginInfo.Guid);
        Hooks.Enable(_harmony, log, "The Calling record follows the character", SkillHooks.RecordPlan);
        Hooks.Enable(_harmony, log, "Steep curve and shadow levels", SkillHooks.GainPlan);
        Hooks.Enable(_harmony, log, "Focus protection and profession drain on death", SkillHooks.DeathPlan);
        Hooks.Enable(_harmony, log, "The skills window survives skills created while it opens", SkillsWindowRebuild.Plan);
        Hooks.Enable(_harmony, log, "Calling stars in the skills window", CallingStars.Plan);
        Hooks.Enable(_harmony, log, "Calling window in the skills dialog", CallingWindow.Plan);
        Hooks.Enable(_harmony, log, $"Seed beds follow the soil's rules ({Pinned.Loaded("blacks7ar.SeedBed", "SeedBed")})", SeedBedBiomeRule.Plan);
        Hooks.Enable(_harmony, log, $"Herbalist tonics need their biome's boss key ({Pinned.Loaded("blacks7ar.Herbalist", "Herbalist")}, {Pinned.Loaded(SkillRules.WorldAdvancementProgressionGuid, "World Advancement Progression")})", TonicKeys.Plan);
        _deepNorthOn = Hooks.Enable(_harmony, log, "Deep North personal Fader-key locks", DeepNorthKeys.Plan);
        if (_deepNorthOn) DeepNorthKeys.Enable(log);
        Hooks.Enable(_harmony, log, "Potions carry the brewer's grade", BrewersGrade.CraftPlan);
        Hooks.Enable(_harmony, log, "Brewer's grade through fermentation", FermenterGrade.Plan);
        Hooks.Enable(_harmony, log, "Herbalist drinks use the brewer's grade", BrewersGrade.DrinkPlan);
        Hooks.Enable(_harmony, log, $"Mead durations use the brewer's grade without a floor ({Pinned.Loaded("blacks7ar.Herbalist", "Herbalist")})", MeadDurations.Plan);
        SmithLock.Enable(log);
        Hooks.Enable(_harmony, log, "Herbalist bonus output", BonusOutput.HerbalistPlan);
        Hooks.Enable(_harmony, log, "Fishing bonus output", BonusOutput.FishingPlan);
        Hooks.Enable(_harmony, log, "Explorer markers reach further as the skill grows", ExplorerRange.Plan);
        Hooks.Enable(_harmony, log, "Explorer pays new-biome XP once per biome, not per crossing", BiomeDiscovery.Plan);
        Hooks.Enable(_harmony, log, "Settings save and close despite Zen's dodge key hint rewrite", DodgeHintGuard.Plan);
        Hooks.Enable(_harmony, log, "The dodge key works while chat is shown but not typed in", DodgeChatFocus.Plan);
        Hooks.Enable(_harmony, log, "Dishes carry the cook's grade", CooksGrade.CraftPlan);
        Hooks.Enable(_harmony, log, "The cook's grade through cooking stations", StationGrade.Plan);
        CooksGrade.FoodOn = Hooks.Enable(_harmony, log, $"The cook's grade in food stats and shelf life ({Pinned.Loaded(CooksGrade.FineDiningGuid, "FineDining")})", CooksGrade.FoodPlan);
        Hooks.Enable(_harmony, log, $"Eaten food keeps its scale through a relog ({Pinned.Loaded(CooksGrade.FineDiningGuid, "FineDining")})", EatenScales.Plan);
        Hooks.Enable(_harmony, log, "Dish tooltips show grade and work meal", CooksGrade.TooltipPlan);
        Hooks.Enable(_harmony, log, "Work meals", WorkMeals.Plan);
        Hooks.Enable(_harmony, log, "Log splitter for Wood Cutting", LogSplitter.Plan);
        Hooks.Enable(_harmony, log, "Quick bite for Fishing", QuickBite.Plan);
        Hooks.Enable(_harmony, log, "Steady overload for Hauling", SteadyOverload.Plan);
        XpLog.On = Hooks.Enable(_harmony, log, "Profession XP log", XpLog.Plan);
    }

    /// <summary>After every plugin's Awake, so the profession mods have registered their skills.</summary>
    private void Start()
    {
        Professions.VerifySkills(Logger);
        Logger.LogInfo($"Shadow levels and profession drains follow {SkillRules.RuleSource}.");
    }

    private void Update()
    {
        XpLog.Tick(UnityEngine.Time.unscaledDeltaTime);
        if (_deepNorthOn) DeepNorthKeys.Tick(UnityEngine.Time.unscaledDeltaTime);
    }

    private void OnDestroy() => _harmony?.UnpatchSelf();
}
