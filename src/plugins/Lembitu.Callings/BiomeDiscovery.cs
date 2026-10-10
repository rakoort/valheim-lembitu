using System;
using System.Collections.Generic;
using BepInEx.Configuration;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// Explorer 1.1.7 still patches <c>Player.AddKnownBiome</c> as if it took a <c>Heightmap.Biome</c>.
/// Valheim 1.0.17 passes a <c>BiomeSector</c> and calls it at every biome change
/// (<c>Player.UpdateBiome</c>), so Explorer's "already known" test compares a misread value with the
/// game's biome names, never matches, and pays its new-biome XP on every crossing: a portal trip
/// between two biomes paid it twice (reported 2026-10-10). Its prefix is skipped and the reward is
/// paid here instead, once, for a biome the game has not recorded for this character yet.
/// </summary>
internal static class BiomeDiscovery
{
    private static ConfigEntry<float> s_newBiomeExp = null!;

    public static IEnumerable<PatchPlan> Plan()
    {
        Type patches = AccessTools.TypeByName("Explorer.Patches.PlayerPatch")
            ?? throw new HookMismatch("Explorer.Patches.PlayerPatch not found");
        var broken = Hooks.Method(patches, "AddKnownBiome_Prefix",
            new[] { typeof(Player), typeof(Heightmap.Biome).MakeByRefType() }, typeof(void));
        Type plugin = AccessTools.TypeByName("Explorer.Plugin")
            ?? throw new HookMismatch("Explorer.Plugin not found");
        Hooks.Field(plugin, "_newBiomeExp", typeof(ConfigEntry<float>));
        s_newBiomeExp = (ConfigEntry<float>)AccessTools.DeclaredField(plugin, "_newBiomeExp").GetValue(null)
            ?? throw new HookMismatch("Explorer.Plugin._newBiomeExp is not bound yet");
        var add = Hooks.Method(typeof(Player), "AddKnownBiome", new[] { typeof(BiomeSector) }, typeof(void));
        Hooks.Field(typeof(Player), "m_knownBiome", typeof(HashSet<string>));
        yield return new PatchPlan(broken) { Prefix = Hooks.Patch(typeof(BiomeDiscovery), nameof(SkipExplorersReward)) };
        yield return new PatchPlan(add) { Prefix = Hooks.Patch(typeof(BiomeDiscovery), nameof(RewardNewBiome)) };
    }

    private static bool SkipExplorersReward() => false;

    /// <summary>Runs before the game records the biome, so an unrecorded name is a real discovery.</summary>
    private static void RewardNewBiome(Player __instance, BiomeSector biome, HashSet<string> ___m_knownBiome)
    {
        if (__instance != Player.m_localPlayer || biome == null || ___m_knownBiome.Contains(biome.GetName())) return;
        __instance.RaiseSkill(Professions.Explorer, s_newBiomeExp.Value);
    }
}
