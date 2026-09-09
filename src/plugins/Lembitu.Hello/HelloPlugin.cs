using System;
using System.Collections;
using System.Reflection;
using BepInEx;
using BepInEx.Configuration;
using ServerSync;
using UnityEngine;
using ValheimVersion = global::Version;

namespace Lembitu.Hello;

/// <summary>
/// Smallest plugin that proves the toolchain: it loads, it logs, it reports whether the game it is
/// running on matches the reference assemblies it was compiled against, and it broadcasts one
/// server-synced config value so a stale ServerSync build cannot go unnoticed.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class HelloPlugin : BaseUnityPlugin
{
    /// <summary>
    /// Valheim's version numbers are <c>const</c>, so the compiler inlines this value from
    /// lib/valheim/ at build time. It records which game build this DLL was compiled against.
    /// </summary>
    private const uint CompiledNetworkVersion = ValheimVersion.c_networkVersion;

    /// <summary>
    /// Constructing this patches the game (ServerSync patches on first use), so it happens once,
    /// lazily, when the plugin is loaded. Clients without the plugin are not turned away:
    /// <c>ModRequired</c> stays false, since a smoke test is not a requirement.
    /// </summary>
    private static readonly ConfigSync configSync = new(PluginInfo.Guid)
    {
        DisplayName = PluginInfo.Name,
        CurrentVersion = PluginInfo.Version,
    };

    /// <summary>
    /// A value ServerSync owns outright. Setting it runs the same
    /// <c>Broadcast(ZRoutedRpc.Everybody, …)</c> that a synced config entry does, but off a plain
    /// C# event, so a failure reaches our own <c>catch</c>. A config entry's does not: BepInEx
    /// invokes those handlers inside a <c>try/catch</c> that logs and swallows
    /// (<c>ConfigFile.OnSettingChanged</c>), which would leave us claiming success over an
    /// exception logged three lines earlier.
    /// </summary>
    private static readonly CustomSyncedValue<long> broadcastProbe = new(configSync, "broadcast probe", 0L);

    private void Awake()
    {
        Logger.LogInfo(
            $"{PluginInfo.Name} {PluginInfo.Version} loaded on {ValheimVersion.GetVersionString(false)} "
            + $"(built against network version {CompiledNetworkVersion})");

        object? live = LiveNetworkVersion();
        if (live is null)
        {
            Logger.LogWarning(
                "Version.c_networkVersion is gone from this game build; the reference assemblies in "
                + "lib/valheim/ are stale and inlined constants in our plugins may be wrong.");
        }
        else if (Convert.ToUInt64(live) != CompiledNetworkVersion)
        {
            Logger.LogError(
                $"Version skew: this server is network version {live}, plugins were built against "
                + $"{CompiledNetworkVersion}. Re-run scripts/extract-refs.sh and rebuild.");
        }

        ConfigEntry<int> syncedSetting = Config.Bind(
            "Smoke test",
            "Sync probe",
            0,
            "Set to the server's start time (Unix seconds) on every startup, to exercise ServerSync's "
            + "config broadcast. Never read by anything.");
        configSync.AddConfigEntry(syncedSetting);

        StartCoroutine(ProbeServerSync(syncedSetting));
    }

    /// <summary>
    /// Writes a synced config value and a synced custom value once the network is up. That is the
    /// code path that throws <c>MissingFieldException</c> when ServerSync was built against a
    /// pre-1.0 game (see docs/adr/0002-serversync-vendored-as-shared-source.md), so one log line
    /// per server start says which of the two we are running.
    /// </summary>
    private IEnumerator ProbeServerSync(ConfigEntry<int> syncedSetting)
    {
        // A dedicated server has ZNet within seconds of loading its world. A client may never get
        // one, so the probe gives up rather than spinning for the session; and only the source of
        // truth writes, since a client's write to a synced value is reverted by design.
        float deadline = Time.realtimeSinceStartup + 120f;
        while (ZNet.instance == null)
        {
            if (Time.realtimeSinceStartup > deadline)
            {
                yield break;
            }

            yield return null;
        }

        if (!ZNet.instance.IsServer())
        {
            yield break;
        }

        long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        try
        {
            // The config entry first, since that is what mods actually synchronise; then the custom
            // value, which is the one whose failure we can see (see broadcastProbe). Both broadcast
            // through the same code, so a stale build cannot fail the first and pass the second.
            syncedSetting.Value = (int)now;
            broadcastProbe.Value = now;
            Logger.LogInfo($"ServerSync broadcast ok (probe = {now})");
        }
        catch (Exception e)
        {
            Logger.LogError($"ServerSync broadcast failed on this game build: {e}");
        }
    }

    /// <summary>
    /// Reads the running game's own <c>c_networkVersion</c> constant out of assembly metadata.
    /// Constants are inlined at compile time, so the only way to see the live value is reflection.
    /// The value is left boxed: a game update may change its underlying type, and reporting the
    /// wrong number is worse than reporting the type we did not expect.
    /// </summary>
    private static object? LiveNetworkVersion() =>
        typeof(ValheimVersion)
            .GetField(nameof(ValheimVersion.c_networkVersion), BindingFlags.Public | BindingFlags.Static)
            ?.GetRawConstantValue();
}
