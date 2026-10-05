using System;
using System.Reflection;
using BepInEx.Logging;

namespace Lembitu.Callings;

/// <summary>
/// BlacksmithingExpanded's settings are locked by us (ADR-0022). Its main ConfigSync sends settings
/// from the server but registers no locking entry and never sets IsLocked; only its bundled skill
/// manager is locked (BlacksmithingExpanded 1.2.4 decompile, local/premium-review-2026-10-04/
/// AuditCombat.md §2), so a client could change the smith's gear bonuses against the Pack rule. At
/// startup the main sync's IsLocked is set the way its own skill manager sets it: a locked client
/// broadcasts nothing, a locked server accepts sync pushes from admins only, and the server stays the
/// source of truth. There is no Harmony patch; the lock is one property write on the mod's own sync.
/// </summary>
internal static class SmithLock
{
    public const string BlacksmithingExpandedGuid = "org.bepinex.plugins.blacksmithingexpanded";
    public const string Version = "1.2.4";

    public static void Enable(ManualLogSource log)
    {
        const string feature = "BlacksmithingExpanded's settings are locked";
        try
        {
            Pinned.Pin(BlacksmithingExpandedGuid, Version, "BlacksmithingExpanded");
            Type pluginType = BepInEx.Bootstrap.Chainloader.PluginInfos[BlacksmithingExpandedGuid].Instance.GetType();
            FieldInfo field = pluginType.GetField("configSync", BindingFlags.Static | BindingFlags.NonPublic)
                ?? throw new HookMismatch($"{pluginType.Name}.configSync not found");
            object sync = field.GetValue(null)
                ?? throw new HookMismatch($"{pluginType.Name}.configSync is null");
            PropertyInfo isLocked = sync.GetType().GetProperty("IsLocked")
                ?? throw new HookMismatch("ServerSync.ConfigSync.IsLocked not found");
            if (!(bool)isLocked.GetValue(sync)!)
            {
                isLocked.SetValue(sync, true);
            }
            log.LogInfo($"{feature}: on (BlacksmithingExpanded {Version})");
        }
        catch (Exception error)
        {
            log.LogWarning($"{feature}: off, {error.Message}");
        }
    }
}
