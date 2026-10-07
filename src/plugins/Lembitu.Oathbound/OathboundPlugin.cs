using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Utils;

namespace Lembitu.Oathbound;

/// <summary>
/// Adapts LionAndOtter/Oathbound: oath changes stay at the Oathstone,
/// kill XP is split within the killer's party, a poison kill pays the poisoner,
/// and every class may use the gathering tools. Patches Oathbound at runtime; each feature verifies
/// its own hooks first and switches off alone if an Oathbound release moved them.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(OathboundGuid)]
[BepInDependency(SocialSystemGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(WorldAdvancementGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(ArcheryLock.Guid, BepInDependency.DependencyFlags.SoftDependency)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class OathboundPlugin : BaseUnityPlugin
{
    private const string OathboundGuid = "local.warrior.rpg";
    internal const string SocialSystemGuid = "M2Valheim.SocialSystem";
    internal const string WorldAdvancementGuid = "com.orianaventure.mod.WorldAdvancementProgression";

    /// <summary>The Oathbound release every hook below was read from (docs/modstack.md).</summary>
    private const string VerifiedOathbound = "0.21.14";

    /// <summary>The World Advancement Progression release the boss-key counts were read from.</summary>
    private const string VerifiedWorldAdvancement = "1.0.0";

    private Harmony? _harmony;

    internal static ConfigurationManagerAttributes AdminOnly() => new() { IsAdminOnly = true };

    private void Awake()
    {
        ManualLogSource log = Logger;
        PartyExperience.Configure(Config, log);
        ClassPower.Configure(Config);
        CompanionDamage.Configure(Config);
        ArcheryLock.Configure(Config);
        ArcheryLock.Enable(log);

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
        if (Chainloader.PluginInfos.TryGetValue(WorldAdvancementGuid, out BepInEx.PluginInfo? wap) && wap.Metadata.Version.ToString() != VerifiedWorldAdvancement)
        {
            log.LogWarning($"World Advancement Progression {wap.Metadata.Version} is running; the boss-key counts were read from {VerifiedWorldAdvancement}.");
        }

        _harmony = new Harmony(PluginInfo.Guid);
        Hooks.Enable(_harmony, log, "Oaths and free respec require the Oathstone; the tree opens anywhere after the first oath", OathAccess.Plan);
        Hooks.Enable(_harmony, log, "Kill XP is split within the killer's party", PartyExperience.Plan);
        Hooks.Enable(_harmony, log, "A poison kill pays the player who poisoned", PoisonCredit.Plan);
        Hooks.Enable(_harmony, log, "Every class may equip the fishing rod", GatheringTools.FishingRodPlan);
        Hooks.Enable(_harmony, log, "A Monk's bare hands raise Mining and Wood Cutting", GatheringTools.MonkGatheringPlan);
        Hooks.Enable(_harmony, log, "Class power follows boss keys", ClassPower.Plan);
        Hooks.Enable(_harmony, log, "Companion damage follows the server multiplier", CompanionDamage.Plan);
        Hooks.Enable(_harmony, log, "An equipment refusal names the guide page", EquipmentGuide.Plan);
    }

    private void OnDestroy()
    {
        ArcheryLock.Disable();
        _harmony?.UnpatchSelf();
    }
}
