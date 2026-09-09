using System;
using System.Reflection;
using BepInEx;
using ValheimVersion = global::Version;

namespace Lembitu.Hello;

/// <summary>
/// Smallest plugin that proves the toolchain: it loads, it logs, and it reports whether the game
/// it is running on matches the reference assemblies it was compiled against.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class HelloPlugin : BaseUnityPlugin
{
    /// <summary>
    /// Valheim's version numbers are <c>const</c>, so the compiler inlines this value from
    /// lib/valheim/ at build time. It records which game build this DLL was compiled against.
    /// </summary>
    private const uint CompiledNetworkVersion = ValheimVersion.c_networkVersion;

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
