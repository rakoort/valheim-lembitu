using System;
using System.Collections.Generic;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// ExpertExplorer 1.7.0, the Exploration profession's mod, stores a version tag in the character's
/// custom data and reads it the first time it meets a character, on save and on load. Its old-format
/// check hands a missing tag straight to <c>Regex.IsMatch</c>, which throws on null. A brand-new
/// character has no tag yet, so its first save throws and the character is never written; a character
/// made before ExpertExplorer was installed meets the same check on load. A missing tag is answered the
/// way the check answers any tag that is not a version, "old format", and the old-format readers find
/// nothing to read on such a character (docs/modstack.md, "Known interactions").
/// </summary>
internal static class ExplorationSave
{
    public const string ExpertExplorerGuid = "com.milkwyzard.ExpertExplorer";

    public static IEnumerable<PatchPlan> Plan()
    {
        Type data = AccessTools.TypeByName("ExpertExplorer.PlayerExplorationData")
            ?? throw new HookMismatch("ExpertExplorer.PlayerExplorationData not found");
        var isLegacySave = Hooks.Method(data, "IsLegacySave", new[] { typeof(string) }, typeof(bool));
        yield return new PatchPlan(isLegacySave)
        {
            Prefix = Hooks.Patch(typeof(ExplorationSave), nameof(MissingTagIsOldFormat)),
        };
    }

    private static bool MissingTagIsOldFormat(string? versionString, ref bool __result)
    {
        if (versionString != null)
        {
            return true;
        }

        __result = true;
        return false;
    }
}
