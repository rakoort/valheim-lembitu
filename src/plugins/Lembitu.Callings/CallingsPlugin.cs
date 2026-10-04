using BepInEx;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Utils;

namespace Lembitu.Callings;

/// <summary>
/// Professions and the Calling (ADR-0021, ADR-0022): four focus professions marked in the skills window
/// at the Oathstone, the steep curve for every other profession, shadow levels, focus protection on
/// death, one death drain for every profession skill, and the Herbalist and Fishing bonus output. It
/// also keeps ExpertExplorer, the Exploration profession's mod, from aborting a new character's first
/// save. Hooks vanilla, World Advancement Progression, ExpertExplorer and the bundled skill managers,
/// never Oathbound, so an Oathbound release cannot break it.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(SkillRules.WorldAdvancementProgressionGuid, BepInDependency.DependencyFlags.SoftDependency)]
// Loaded first so its types resolve when the save fix is verified in Awake.
[BepInDependency(ExplorationSave.ExpertExplorerGuid, BepInDependency.DependencyFlags.SoftDependency)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class CallingsPlugin : BaseUnityPlugin
{
    private Harmony? _harmony;

    private void Awake()
    {
        ManualLogSource log = Logger;
        Settings.Bind(Config);
        CallingStore.Configure(log);
        SkillHooks.Configure(log);

        _harmony = new Harmony(PluginInfo.Guid);
        Hooks.Enable(_harmony, log, "The Calling record follows the character", SkillHooks.RecordPlan);
        Hooks.Enable(_harmony, log, "Steep curve and shadow levels", SkillHooks.GainPlan);
        Hooks.Enable(_harmony, log, "Focus protection and profession drain on death", SkillHooks.DeathPlan);
        Hooks.Enable(_harmony, log, "Calling stars in the skills window", CallingStars.Plan);
        Hooks.Enable(_harmony, log, "Herbalist bonus output", BonusOutput.HerbalistPlan);
        Hooks.Enable(_harmony, log, "Fishing bonus output", BonusOutput.FishingPlan);
        Hooks.Enable(_harmony, log, "New characters survive ExpertExplorer's first save", ExplorationSave.Plan);
    }

    /// <summary>After every plugin's Awake, so the profession mods have registered their skills.</summary>
    private void Start()
    {
        Professions.VerifyJotunnSkills(Logger);
        Logger.LogInfo($"Shadow levels and profession drains follow {SkillRules.RuleSource}.");
    }

    private void OnDestroy() => _harmony?.UnpatchSelf();
}
