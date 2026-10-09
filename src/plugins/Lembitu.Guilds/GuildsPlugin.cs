using BepInEx;
using BepInEx.Bootstrap;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Utils;

namespace Lembitu.Guilds;

/// <summary>
/// Guilds form in game and claim SeparateSpawns' start regions (ADR-0028). Every new player wakes at
/// the sacrificial stones, beside the Oathstone: SeparateSpawns' random assignment is held back for
/// anyone whose guild holds no region. A guild leader claims one of the three regions at its portal
/// stone in the ring, after a confirmation window naming the region and where it lies; the region
/// then follows membership — bedless respawn and portal — until the member leaves or the guild
/// disbands, and a bed always overrides it. Membership is read from Guilds' server state only.
/// Patches SeparateSpawns where it has no setting; reads Guilds' server store directly. Each feature
/// verifies its own hooks at startup and switches off alone on a mismatch.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency(Jotunn.Main.ModGuid)]
[BepInDependency(SeparateSpawnsGuid)]
[BepInDependency(GuildsGuid)]
[NetworkCompatibility(CompatibilityLevel.EveryoneMustHaveMod, VersionStrictness.Minor)]
public sealed class GuildsPlugin : BaseUnityPlugin
{
    private const string SeparateSpawnsGuid = "abortipus.separatespawns";
    private const string GuildsGuid = "adrian.valheim.guilds";

    /// <summary>The releases every hook below was read from (docs/modstack.md).</summary>
    private const string VerifiedSeparateSpawns = "0.1.1";
    private const string VerifiedGuilds = "1.5.1";

    private Harmony? _harmony;
    private static ManualLogSource s_log = null!;
    private static ZRoutedRpc? s_registeredRpc;

    private void Awake()
    {
        s_log = Logger;
        Settings.Bind(Config);
        Claims.Configure(Logger);
        Bridge.Configure(Logger);
        ClaimPortal.Configure(Logger);

        WarnOnVersion(SeparateSpawnsGuid, VerifiedSeparateSpawns);
        WarnOnVersion(GuildsGuid, VerifiedGuilds);

        _harmony = new Harmony(PluginInfo.Guid);
        Bridge.HoldOn = Hooks.Enable(_harmony, Logger, "Guildless players hold the stones", Bridge.HoldPlan);
        ClaimPortal.ClaimOn = Hooks.Enable(_harmony, Logger, "Leaders claim start regions at the portal stones", ClaimPortal.Plan);
        Bridge.FollowOn = Hooks.Enable(_harmony, Logger, "A guild's region follows its members", Bridge.FollowPlan);
    }

    private void Update()
    {
        RegisterRpcs();
        ClaimPortal.ClientTick();
        Bridge.Tick();
    }

    /// <summary>ZRoutedRpc is rebuilt with every world, so the claim RPCs re-register against it.</summary>
    private static void RegisterRpcs()
    {
        ZRoutedRpc? rpc = ZRoutedRpc.instance;
        if (rpc == null || s_registeredRpc == rpc)
        {
            return;
        }
        ClaimPortal.ResetHoverOwners();
        rpc.Register<string>("lembitu.guilds ClaimRegion", ClaimPortal.RPC_ClaimRegion);
        rpc.Register<ZPackage>("lembitu.guilds ClaimResult", ClaimPortal.RPC_ClaimResult);
        rpc.Register<string>("lembitu.guilds Claimed", ClaimPortal.RPC_Claimed);
        rpc.Register<string>("lembitu.guilds RegionOwners", ClaimPortal.RPC_RegionOwners);
        rpc.Register<ZPackage>("lembitu.guilds RegionOwnersResult", ClaimPortal.RPC_RegionOwnersResult);
        s_registeredRpc = rpc;
    }

    private static void WarnOnVersion(string guid, string verified)
    {
        if (!Chainloader.PluginInfos.TryGetValue(guid, out BepInEx.PluginInfo? info))
        {
            return;
        }
        string running = info.Metadata.Version.ToString();
        if (running != verified)
        {
            s_log.LogWarning($"{info.Metadata.Name} {running} is running; these hooks were read from {verified}. Each feature re-verifies its own.");
        }
    }

    private void OnDestroy() => _harmony?.UnpatchSelf();
}
