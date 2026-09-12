using System;
using System.Reflection;
using BepInEx;
using HarmonyLib;

namespace Lembitu.BossRules;

[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInDependency("sighsorry.BossRules")]
public sealed class BossRulesPlugin : BaseUnityPlugin
{
    private readonly Harmony harmony = new(PluginInfo.Guid);

    private void Awake()
    {
        const string targetName = "BossRules.AltarReferenceGenerator:TryAutoRefreshReferenceConfigurationFile";
        MethodInfo target = AccessTools.Method(targetName)
            ?? throw new MissingMethodException(targetName);
        harmony.Patch(target, prefix: new HarmonyMethod(typeof(BossRulesPlugin), nameof(IsReferenceAuthority)));
        Logger.LogInfo("BossRules altar reference generation restricted to the native world authority.");
    }

    // ServerSync still considers a connecting client authoritative before its first config sync.
    // The reference scan eagerly loads every location, blocking the handshake on large content packs.
    // Native authority is already known here; dedicated servers and local hosts retain the scan.
    private static bool IsReferenceAuthority() => ZNet.instance != null && ZNet.instance.IsServer();

    private void OnDestroy() => harmony.UnpatchSelf();
}
