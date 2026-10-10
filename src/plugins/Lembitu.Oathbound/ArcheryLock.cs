using System;
using System.Collections.Generic;
using Jotunn.Managers;
using Jotunn.Utils;
using BepInEx.Bootstrap;
using BepInEx.Configuration;
using BepInEx.Logging;
using UnityEngine;

namespace Lembitu.Oathbound;

/// <summary>Mirror only BetterArchery gameplay entries through Jotunn's admin-only config sync.
/// The quiver is not one of them: AzuExtendedPlayerInventory forces BetterArchery's Enable Quiver
/// off and keeps it off, because the quiver's extra rows collide with AzuEPI's slot rows.</summary>
internal static class ArcheryLock
{
    internal const string Guid = "ishid4.mods.betterarchery";
    internal const string RetrieveList = "ArrowWood=0.2;ArrowFlint=0.3;ArrowBronze=0.5;ArrowIron=0.7;ArrowObsidian=0.7;ArrowNeedle=0.1;ArrowFire=0;ArrowPoison=0.7>ArrowObsidian;ArrowSilver=0.5;ArrowFrost=0.7>ArrowObsidian;ArrowCarapace=0.7;ArrowCharred=0.7;BoltBone=0.3;BoltIron=0.5;BoltBlackmetal=0.7;BoltCarapace=0.7;BoltCharred=0.7";
    private static readonly List<Action<ConfigFile>> Bindings = new();
    private static readonly List<Action> Apply = new();
    private static readonly List<Action> Disconnect = new();

    public static void Configure(ConfigFile config)
    {
        Add(config, "Arrow Improvements", "Enable Arrow Improvements", true);
        Add(config, "Arrow Improvements", "Set Arrow Velocity", 70f);
        Add(config, "Arrow Improvements", "Set Arrow Gravity", 15f);
        Add(config, "Arrow Improvements", "Set Arrow Accuracy", 0f);
        Add(config, "Arrow Improvements", "Set Aim Direction", new Vector3(0f, 0.05f, 0f));
        Add(config, "Other", "Enable Bow Draw Movement Speed Reduction", true);
        Add(config, "Other", "Enable Crouch Bow Draw", true);
        Add(config, "Other", "Enable Crafting Wooden Arrow Everywhere", true);
        Add(config, "Retrievable Arrows", "Enable Retrievable Arrows", true);
        Add(config, "Retrievable Arrows", "Arrow Disappear Time", 60f);
        Add(config, "Retrievable Arrows", "Arrow Disappear On Hit", false);
        Add(config, "Retrievable Arrows", "Retrievable Arrow Solid Collider", false);
        Add(config, "Retrievable Arrows", "Arrow Auto Pickup", false);
        Add(config, "Retrievable Arrows", "Arrow Retrieve List", RetrieveList);
    }

    private static void Add<T>(ConfigFile config, string section, string key, T value)
    {
        ConfigEntry<T> ours = config.Bind("BetterArchery " + section, key, value,
            new ConfigDescription("Server gameplay rule; BetterArchery 2.0.2 default (2026-10-06, owner).", null, OathboundPlugin.AdminOnly()));
        Bindings.Add(target =>
        {
            if (!target.TryGetEntry(new ConfigDefinition(section, key), out ConfigEntry<T> theirs))
                throw new HookMismatch($"BetterArchery [{section}] {key} ({typeof(T).Name}) not found");
            bool writing = false;
            void Enforce()
            {
                if (writing) return;
                writing = true;
                try { theirs.Value = ours.Value; }
                finally { writing = false; }
            }
            EventHandler handler = (_, _) => Enforce();
            Apply.Add(Enforce);
            ours.SettingChanged += handler;
            theirs.SettingChanged += handler;
            Disconnect.Add(() => { ours.SettingChanged -= handler; theirs.SettingChanged -= handler; });
        });
    }

    public static void Enable(ManualLogSource log)
    {
        const string feature = "BetterArchery gameplay settings are server-locked";
        try
        {
            if (!Chainloader.PluginInfos.TryGetValue(Guid, out BepInEx.PluginInfo info) || !info.Instance.enabled)
                throw new HookMismatch("BetterArchery is not loaded or enabled");
            if (info.Metadata.Version.ToString() != "2.0.2")
                throw new HookMismatch($"BetterArchery {info.Metadata.Version}; verified release is 2.0.2");
            foreach (Action<ConfigFile> bind in Bindings) bind(info.Instance.Config);
            foreach (Action apply in Apply) apply();
            SynchronizationManager.OnConfigurationSynchronized += Synced;
            log.LogInfo($"{feature}: on (BetterArchery 2.0.2)");
        }
        catch (Exception error)
        {
            Disable();
            log.LogWarning($"{feature}: off: {error.Message}");
        }
    }

    private static void Synced(object sender, ConfigurationSynchronizationEventArgs args)
    {
        foreach (Action apply in Apply) apply();
    }

    public static void Disable()
    {
        SynchronizationManager.OnConfigurationSynchronized -= Synced;
        foreach (Action disconnect in Disconnect) disconnect();
        Disconnect.Clear();
        Apply.Clear();
    }
}
