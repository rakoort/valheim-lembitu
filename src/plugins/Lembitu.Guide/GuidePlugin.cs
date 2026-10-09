using System;
using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Logging;
using Jotunn.Managers;
using Jotunn.Utils;
using UnityEngine;

namespace Lembitu.Guide;

/// <summary>
/// The in-game guide window (ADR-0027): chapters of short pages teaching the Run's rules, opened by
/// a hotkey and an inventory button and shown once on a character's first join, with its text in a
/// server-synced file the admin edits. It patches nothing: it hooks only the inventory and its own
/// file, reads the first-oath, first-Calling and first-party state rather than patching the mods
/// that own it, and every feature verifies what it leans on and switches off alone.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(OathboundGuid, BepInDependency.DependencyFlags.SoftDependency)]
[BepInDependency(SocialSystemGuid, BepInDependency.DependencyFlags.SoftDependency)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class GuidePlugin : BaseUnityPlugin
{
    internal const string OathboundGuid = "local.warrior.rpg";
    internal const string SocialSystemGuid = "M2Valheim.SocialSystem";

    /// <summary>The releases every read below was verified against (docs/modstack.md).</summary>
    private const string VerifiedOathbound = "0.22.0";
    private const string VerifiedSocialSystem = "1.0.5";

    internal static ManualLogSource ClientLog = null!;

    internal static bool IsHeadless => GUIManager.IsHeadless();

    internal static ConfigurationManagerAttributes AdminOnly() => new() { IsAdminOnly = true };

    private void Awake()
    {
        ManualLogSource log = Logger;
        ClientLog = log;
        Settings.Bind(Config);
        GuideContent.Configure(log);

        WarnIfPinnedPluginMoved(log, OathboundGuid, VerifiedOathbound);
        WarnIfPinnedPluginMoved(log, SocialSystemGuid, VerifiedSocialSystem);

        ContentSync.Verify(log);
        Feature(log, "Server-synced guide content", ContentSync.Enable);
        Feature(log, "Guide window", GuideWindow.Verify);
        Feature(log, "Inventory guide button", InventoryButton.Verify);
        Feature(log, "First-join page", Firsts.VerifyFirstJoin);
        Feature(log, "First-oath page", Firsts.VerifyOath);
        Feature(log, "First-Calling page", Firsts.VerifyCalling);
        Feature(log, "First-party page", Firsts.VerifyParty);
    }

    /// <summary>The same wording as Hooks.Enable: a feature states why it is off or that it is on.</summary>
    private static void Feature(ManualLogSource log, string feature, Action verify)
    {
        try
        {
            verify();
        }
        catch (Exception error)
        {
            log.LogWarning($"{feature}: off, hook not verified: {error.Message}");
            return;
        }
        log.LogInfo($"{feature}: on");
    }

    private void Update()
    {
        ContentSync.Tick(Time.unscaledDeltaTime);
        GuideWindow.Tick();
        InventoryButton.Tick();
        Firsts.Tick();
    }

    private void WarnIfPinnedPluginMoved(ManualLogSource log, string guid, string verified)
    {
        if (!Chainloader.PluginInfos.TryGetValue(guid, out BepInEx.PluginInfo? info))
        {
            return;
        }
        string running = info.Metadata.Version.ToString();
        if (running != verified)
        {
            log.LogWarning($"{info.Metadata.Name} {running} is running; the state read here was verified from {verified}.");
        }
    }
}
