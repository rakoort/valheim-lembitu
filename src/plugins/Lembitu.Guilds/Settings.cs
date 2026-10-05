using BepInEx.Configuration;

namespace Lembitu.Guilds;

/// <summary>Server-locked through Jotunn (IsAdminOnly), so every client uses the server's numbers.</summary>
internal static class Settings
{
    private static ConfigEntry<bool> s_enabled = null!;
    private static ConfigEntry<float> s_reconcileSeconds = null!;

    /// <summary>The whole bridge. Off, SeparateSpawns assigns every player randomly again; claims are
    /// no longer enforced but also never freed, so turning it back on restores the world's claims.</summary>
    public static bool Enabled => s_enabled.Value;

    /// <summary>How often the server re-derives SeparateSpawns' roster from Guilds' membership.</summary>
    public static float ReconcileSeconds => s_reconcileSeconds.Value;

    public static void Bind(ConfigFile config)
    {
        s_enabled = config.Bind("Bridge", "Enabled", true, new ConfigDescription(
            "Guilds claim SeparateSpawns' start regions and regions follow guild membership (ADR-0028). Off = SeparateSpawns assigns every player randomly again.",
            null, new ConfigurationManagerAttributes { IsAdminOnly = true }));
        s_reconcileSeconds = config.Bind("Bridge", "ReconcileSeconds", 2f, new ConfigDescription(
            "How often the server re-derives SeparateSpawns assignments from Guilds' membership. Joins, leaves, kicks and disbands apply within this window.",
            new AcceptableValueRange<float>(0.5f, 30f), new ConfigurationManagerAttributes { IsAdminOnly = true }));
    }
}
