using BepInEx.Bootstrap;

namespace Lembitu.Callings;

/// <summary>
/// A feature that reads a mod the Pack pins instead of hooking it states the pin before it touches
/// anything: staging a different build than the one the rules were verified against is exactly how a
/// check silently stops checking. The version is compared release by release, so a republished
/// package with the same numbers still counts.
/// </summary>
internal static class Pinned
{
    public static void Pin(string guid, string version, string name)
    {
        if (!Chainloader.PluginInfos.TryGetValue(guid, out BepInEx.PluginInfo info))
        {
            throw new HookMismatch($"{name} is not loaded");
        }
        // The game assembly declares its own global-namespace Version, which shadows System.Version
        // for the bare name; BepInPlugin's Version is System.Version, so spell it out.
        System.Version actual = info.Metadata.Version;
        System.Version expected = System.Version.Parse(version);
        if (actual.Major != expected.Major || actual.Minor != expected.Minor || actual.Build != expected.Build)
        {
            throw new HookMismatch($"pinned {name} {version}, staging has {actual}");
        }
    }

    /// <summary>The version staging carries, for a log line; "not loaded" when absent.</summary>
    public static string Loaded(string guid, string name) =>
        Chainloader.PluginInfos.TryGetValue(guid, out BepInEx.PluginInfo info) ? $"{name} {info.Metadata.Version}" : $"{name} not loaded";
}
