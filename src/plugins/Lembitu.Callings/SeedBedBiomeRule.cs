using System;
using System.Collections.Generic;
using System.Reflection;
using BepInEx.Bootstrap;
using BepInEx.Configuration;
using HarmonyLib;
using SeedBed.Functions;

namespace Lembitu.Callings;

/// <summary>
/// A seed bed is a planter that follows soil's rules (ADR-0022): SeedBed 1.2.9 checks only ward
/// access, the seed and the seed count before a bed accepts seeds, so a bed grew any crop in any
/// biome and bypassed Farming's level-60 reward. The bed's biome is compared with the biomes of the
/// vanilla Plant on the cultivator piece that takes that seed, the same comparison Plant itself makes
/// (`(biome & m_biome) == 0`); a seed with no such piece is allowed. Below ImpactfulSkills'
/// FarmingBiomeUnrestrictedLevel (60 in our overlay; read live when reachable) the bed refuses, as
/// soil refuses, with a message that names the rule.
///
/// SeedBed's synced conversions are set to soil's yields in config/enforced/blacks7ar.SeedBed.yml.
/// </summary>
internal static class SeedBedBiomeRule
{
    private const string ImpactfulSkillsGuid = "MidnightsFX.ImpactfulSkills";
    private const int FallbackLevel = 60;

    private static readonly Dictionary<string, Heightmap.Biome> SeedBiomes = new(StringComparer.Ordinal);
    private static bool _built;
    private static ConfigEntry<int>? _unrestricted;

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin("blacks7ar.SeedBed", "1.2.9", "SeedBed");
        MethodBase useItem = Hooks.Method(typeof(Germination), "UseItem",
            new[] { typeof(Humanoid), typeof(ItemDrop.ItemData) }, typeof(bool));
        MethodBase addItem = Hooks.Method(typeof(Germination), "AddItem",
            new[] { typeof(Humanoid), typeof(ItemDrop.ItemData), typeof(int) }, typeof(bool));
        yield return new PatchPlan(useItem) { Prefix = Hooks.Patch(typeof(SeedBedBiomeRule), nameof(BeforeUseItem)) };
        yield return new PatchPlan(addItem) { Prefix = Hooks.Patch(typeof(SeedBedBiomeRule), nameof(BeforeAddItem)) };
    }

    // A refusal handles item-on-bed use, so vanilla cannot eat the seed or replace our message.
    // Ordinary E interaction goes straight to AddItem and is guarded separately below.
    private static bool BeforeUseItem(Germination __instance, Humanoid user, ItemDrop.ItemData item, ref bool __result)
    {
        if (!Refuses(__instance, user, item))
        {
            return true;
        }
        __result = true;
        return false;
    }

    private static bool BeforeAddItem(Germination __instance, Humanoid user, ItemDrop.ItemData item, ref bool __result)
    {
        if (!Refuses(__instance, user, item))
        {
            return true;
        }
        __result = false;
        return false;
    }

    private static bool Refuses(Germination bed, Humanoid user, ItemDrop.ItemData item)
    {
        Heightmap.Biome grows = BiomesOf(item);
        if (grows == Heightmap.Biome.None)
        {
            return false;
        }
        Heightmap.Biome here = Heightmap.FindBiome(bed.transform.position);
        if (here == Heightmap.Biome.None || (here & grows) != 0)
        {
            return false;
        }
        if (user is not Player planter || planter.GetSkillLevel(Skills.SkillType.Farming) >= UnrestrictedLevel())
        {
            return false;
        }
        planter.Message(MessageHud.MessageType.Center,
            $"{LocalizedName(item)} cannot grow in this biome. Farming {UnrestrictedLevel()} lifts the rule, as it does for soil. Guide: Profession ladder (ladder).");
        return true;
    }

    private static Heightmap.Biome BiomesOf(ItemDrop.ItemData item)
    {
        Build();
        string seed = item.m_dropPrefab != null ? item.m_dropPrefab.name : "";
        return seed.Length > 0 && SeedBiomes.TryGetValue(seed, out Heightmap.Biome biome) ? biome : Heightmap.Biome.None;
    }

    /// <summary>
    /// The cultivator pieces that take each seed: every network prefab carrying both a Piece (whose
    /// requirements name the seed) and a Plant (whose m_biome is where it grows). Built on first use,
    /// when ZNetScene and every mod's pieces are loaded; plants added later are picked up by the next
    /// session, and a seed without a piece never enters the map, which allows it.
    /// </summary>
    private static void Build()
    {
        if (_built || ZNetScene.instance == null)
        {
            return;
        }
        _built = true;
        foreach (UnityEngine.GameObject prefab in ZNetScene.instance.m_prefabs)
        {
            Plant? plant = prefab.GetComponent<Plant>();
            Piece? piece = prefab.GetComponent<Piece>();
            if (plant == null || piece == null || piece.m_resources == null)
            {
                continue;
            }
            foreach (Piece.Requirement requirement in piece.m_resources)
            {
                if (requirement.m_resItem == null)
                {
                    continue;
                }
                string seed = requirement.m_resItem.gameObject.name;
                SeedBiomes[seed] = SeedBiomes.TryGetValue(seed, out Heightmap.Biome biomes)
                    ? biomes | plant.m_biome
                    : plant.m_biome;
            }
        }
    }

    /// <summary>ImpactfulSkills' live FarmingBiomeUnrestrictedLevel, 60 when it is not reachable.</summary>
    private static int UnrestrictedLevel()
    {
        if (_unrestricted == null
            && Chainloader.PluginInfos.TryGetValue(ImpactfulSkillsGuid, out BepInEx.PluginInfo info)
            && info.Instance is BepInEx.BaseUnityPlugin plugin
            && plugin.Config.TryGetEntry(new ConfigDefinition("Farming", "FarmingBiomeUnrestrictedLevel"), out ConfigEntry<int> entry))
        {
            _unrestricted = entry;
        }
        return _unrestricted?.Value ?? FallbackLevel;
    }

    private static string LocalizedName(ItemDrop.ItemData item) =>
        Localization.instance.Localize(item.m_shared.m_name);
}
