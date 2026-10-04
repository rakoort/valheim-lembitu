using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Utils;

namespace Lembitu.Oathbound;

/// <summary>
/// Adapts LionAndOtter/Oathbound where it has no setting (ADR-0020, ADR-0022): respec and class switch
/// start over at level 1, kill XP is split within the killer's party, and every class may use the
/// gathering tools. Patches Oathbound at runtime; each feature verifies its own hooks first and
/// switches off alone if an Oathbound release moved them.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(OathboundGuid)]
[BepInDependency(SocialSystemGuid, BepInDependency.DependencyFlags.SoftDependency)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class OathboundPlugin : BaseUnityPlugin
{
    private const string OathboundGuid = "local.warrior.rpg";
    internal const string SocialSystemGuid = "M2Valheim.SocialSystem";

    /// <summary>The Oathbound release every hook below was read from (docs/modstack.md).</summary>
    private const string VerifiedOathbound = "0.21.14";

    private Harmony? _harmony;

    internal static ConfigurationManagerAttributes AdminOnly() => new() { IsAdminOnly = true };

    private void Awake()
    {
        ManualLogSource log = Logger;
        PartyExperience.Configure(Config, log);

        BaseUnityPlugin oathbound = Chainloader.PluginInfos[OathboundGuid].Instance;
        if (!oathbound.enabled)
        {
            log.LogError("Oathbound switched itself off, so nothing here is patched.");
            return;
        }
        string running = Chainloader.PluginInfos[OathboundGuid].Metadata.Version.ToString();
        if (running != VerifiedOathbound)
        {
            log.LogWarning($"Oathbound {running} is running; these hooks were read from {VerifiedOathbound}. Each feature re-verifies its own.");
        }

        _harmony = new Harmony(PluginInfo.Guid);
        Hooks.Enable(_harmony, log, "Respec resets the class to level 1", ClassReset.RespecPlan);
        Hooks.Enable(_harmony, log, "Class switch resets both classes to level 1", ClassReset.SwitchPlan);
        Hooks.Enable(_harmony, log, "Class switch asks for confirmation", ClassReset.SwitchConfirmationPlan);
        Hooks.Enable(_harmony, log, "Oathstone labels describe the reset", ClassReset.LabelPlan);
        Hooks.Enable(_harmony, log, "Kill XP is split within the killer's party", PartyExperience.Plan);
        Hooks.Enable(_harmony, log, "Every class may equip the fishing rod", GatheringTools.FishingRodPlan);
        Hooks.Enable(_harmony, log, "A Monk's bare hands raise Mining and Wood Cutting", GatheringTools.MonkGatheringPlan);
    }

    private void OnDestroy() => _harmony?.UnpatchSelf();
}
