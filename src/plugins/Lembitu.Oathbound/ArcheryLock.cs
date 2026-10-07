using System;
using System.Collections.Generic;
using HarmonyLib;
using Jotunn.Managers;
using Jotunn.Utils;
using BepInEx.Bootstrap;
using BepInEx.Configuration;
using BepInEx.Logging;
using UnityEngine;

namespace Lembitu.Oathbound;

/// <summary>Mirror only BetterArchery gameplay entries through Jotunn's admin-only config sync.</summary>
internal static class ArcheryLock
{
    internal const string Guid = "ishid4.mods.betterarchery";
    internal const string RetrieveList = "ArrowWood=0.2;ArrowFlint=0.3;ArrowBronze=0.5;ArrowIron=0.7;ArrowObsidian=0.7;ArrowNeedle=0.1;ArrowFire=0;ArrowPoison=0.7>ArrowObsidian;ArrowSilver=0.5;ArrowFrost=0.7>ArrowObsidian;ArrowCarapace=0.7;ArrowCharred=0.7;BoltBone=0.3;BoltIron=0.5;BoltBlackmetal=0.7;BoltCarapace=0.7;BoltCharred=0.7";
    private static readonly List<Action<ConfigFile>> Bindings = new();
    private static readonly List<Action> Apply = new();
    private static readonly List<Action> Disconnect = new();

    public static void Configure(ConfigFile config)
    {
        Add(config, "Quiver", "Enable Quiver", true);
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
            RestoreQuiverAssets(info.Instance.GetType());
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

    // BetterArchery skips loading its quiver bundle when an old local cfg disables the quiver.
    // Our dependency has already run Awake, but ZNetScene/ObjectDB have not: restore the same
    // prefabs before their registration hooks, rather than leave a locked-on quiver without items.
    private static void RestoreQuiverAssets(Type plugin)
    {
        var prefabs = (Dictionary<string, GameObject>)AccessTools.Field(plugin, "Prefabs").GetValue(null);
        if (prefabs.Count != 0) return;
        object recipes = AccessTools.Field(plugin, "Recipes").GetValue(null)
            ?? throw new HookMismatch("BetterArchery quiver recipes unavailable");
        var list = (System.Collections.IEnumerable)AccessTools.Field(recipes.GetType(), "recipes").GetValue(recipes);
        using var stream = plugin.Assembly.GetManifestResourceStream(plugin.Assembly.GetName().Name + ".quiverassets")
            ?? throw new HookMismatch("BetterArchery quiver assets unavailable");
        AssetBundle bundle = AssetBundle.LoadFromStream(stream);
        if (bundle == null) throw new HookMismatch("BetterArchery quiver bundle did not load");
        try
        {
            foreach (object recipe in list)
            {
                string item = (string)AccessTools.Field(recipe.GetType(), "item").GetValue(recipe);
                if (bundle.Contains(item)) prefabs.Add(item, bundle.LoadAsset<GameObject>(item));
            }
        }
        finally { bundle.Unload(false); }
    }

    public static void Disable()
    {
        SynchronizationManager.OnConfigurationSynchronized -= Synced;
        foreach (Action disconnect in Disconnect) disconnect();
        Disconnect.Clear();
        Apply.Clear();
    }
}
