using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;
using UnityEngine;
using UnityEngine.Audio;

namespace Lembitu.LevelUpSound;

/// <summary>
/// Turns EpicMMOSystem's level-up sound down to a fifth and puts it on terms the game's own audio
/// settings can reach. A player can silence it or raise it again from one client-side key.
///
/// The mod has no volume setting. Its two level-up prefabs, <c>LevelUpVFX</c> and
/// <c>LevelUpVFX2</c>, each carry an AudioSource at full volume with no output mixer group (read
/// from the <c>epicasset</c> bundle inside <c>EpicMMOSystem.dll</c> 1.9.67), so the clip bypasses
/// Valheim's SFX bus entirely: turning sound effects down in the game's menu does nothing to it.
/// Every other sound the mod ships is routed normally and needs no help.
///
/// Editing the prefab is what settles it, because the mod instantiates the prefab on each level-up
/// and an instance inherits the prefab's volume, so one edit covers every future level.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(EpicMmoGuid, BepInDependency.DependencyFlags.SoftDependency)]
public sealed class LevelUpSoundPlugin : BaseUnityPlugin
{
    internal const string EpicMmoGuid = "WackyMole.EpicMMOSystem";

    internal static ManualLogSource log = null!;
    internal static ConfigEntry<float> volume = null!;

    private readonly Harmony harmony = new(PluginInfo.Guid);

    private void Awake()
    {
        log = Logger;
        volume = Config.Bind("Sound", "Level-up volume", 0.2f, new ConfigDescription(
            "How loud EpicMMOSystem's level-up sound is, from 0 to 1. 0.2 is what this server " +
            "ships: the mod plays it at full volume through no mixer, which is why it drowns " +
            "everything else. 0 silences it. Any value above 0 is also routed through the game's " +
            "sound-effect mixer, so the Sound Effects slider applies to it, which it does not in " +
            "the mod as shipped. Client-side: it changes what you hear, nobody else.",
            new AcceptableValueRange<float>(0f, 1f)));
        volume.SettingChanged += (_, _) => LevelUpAudio.Apply();
        harmony.PatchAll();
    }

    private void OnDestroy() => harmony.UnpatchSelf();
}

/// <summary>Applies the configured volume to the mod's level-up prefabs.</summary>
internal static class LevelUpAudio
{
    private static readonly string[] Prefabs = { "LevelUpVFX", "LevelUpVFX2" };

    /// <summary>
    /// EpicMMOSystem registers its prefabs from a postfix on <c>ZNetScene.Awake</c>, and every
    /// Awake runs before any Start, so <c>Game.Start</c> is the first moment both prefabs are
    /// certain to exist without this plugin having to order itself against another mod's patch.
    /// </summary>
    [HarmonyPatch(typeof(Game), nameof(Game.Start))]
    private static class ApplyOnGameStart
    {
        private static void Postfix() => Apply();
    }

    internal static void Apply()
    {
        ZNetScene scene = ZNetScene.instance;
        if (scene == null) return;

        float level = LevelUpSoundPlugin.volume.Value;
        AudioMixerGroup? group = level > 0f ? SfxGroup() : null;

        foreach (string name in Prefabs)
        {
            GameObject prefab = scene.GetPrefab(name);
            if (prefab == null)
            {
                LevelUpSoundPlugin.log.LogInfo($"{name} is not registered; nothing to silence");
                continue;
            }

            foreach (AudioSource source in prefab.GetComponentsInChildren<AudioSource>(true))
            {
                float was = source.volume;
                source.volume = level;
                // An AudioSource that will not be heard should also not start: the prefab is
                // instantiated on the player's own skeleton and left to play itself.
                source.playOnAwake = level > 0f;
                if (group != null) source.outputAudioMixerGroup = group;
                LevelUpSoundPlugin.log.LogInfo(
                    $"{name}/{source.gameObject.name}: volume {was} -> {source.volume}, " +
                    $"mixer group {(source.outputAudioMixerGroup == null ? "none" : source.outputAudioMixerGroup.name)}");
            }
        }
    }

    /// <summary>
    /// The SFX group of the game's own mixer, which is what the Sound Effects slider drives
    /// through the <c>SfxVol</c> parameter (<c>AudioMan.SetSFXVolume</c>). Null means the group
    /// was not found, and then the volume still applies while the slider still does not.
    /// </summary>
    private static AudioMixerGroup? SfxGroup()
    {
        AudioMan audio = AudioMan.instance;
        if (audio == null || audio.m_masterMixer == null)
        {
            LevelUpSoundPlugin.log.LogWarning("no master mixer yet; level-up sound stays unrouted");
            return null;
        }

        AudioMixerGroup[] groups = audio.m_masterMixer.FindMatchingGroups("SFX");
        if (groups.Length == 0)
        {
            LevelUpSoundPlugin.log.LogWarning(
                "the game's mixer has no SFX group; level-up sound stays unrouted");
            return null;
        }
        return groups[0];
    }
}
