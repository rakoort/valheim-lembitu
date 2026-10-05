using System;
using System.Collections.Generic;
using System.Reflection;
using HarmonyLib;
using VentureValheim.Progression;

namespace Lembitu.Callings;

/// <summary>
/// Tonics follow the food rule for boss keys (ADR-0022). World Advancement Progression locks eating by
/// the biome of an item's materials but lets materials it does not know through, and it knows none of
/// Herbalist's herbs, so a tonic or elixir bought on the Market could be drunk without its biome's
/// boss key. Each herb is mapped to its biome the way the ladder generator maps it
/// (scripts/generate-ladder.py, from Herbalist 1.5.0 VegetationSetup.cs), and a tonic or elixir whose
/// highest-biome herb needs a boss key the drinker lacks is refused at vanilla item use, before
/// Herbalist's consume prefix can return an empty bottle for a drink that never happened.
/// </summary>
internal static class TonicKeys
{
    private sealed class Biome(string label, string bossKey, int rank)
    {
        public string Label { get; } = label;
        public string BossKey { get; } = bossKey;
        public int Rank { get; } = rank;
    }

    private static readonly Biome BlackForest = new("Black Forest", "defeated_eikthyr", 1);
    private static readonly Biome Swamp = new("Swamp", "defeated_gdking", 2);
    private static readonly Biome Mountain = new("Mountain", "defeated_bonemass", 3);
    private static readonly Biome Plains = new("Plains", "defeated_dragon", 4);
    private static readonly Biome Mistlands = new("Mistlands", "defeated_goblinking", 5);

    /// <summary>The ladder's herb rungs: rung 10n is the biome whose boss is n kills deep (ADR-0023).</summary>
    private static readonly Dictionary<string, Biome> BiomeOfHerb = new(StringComparer.Ordinal)
    {
        { "BH_Boswellia", BlackForest },
        { "BH_Bjorncap", BlackForest },
        { "BH_SkaldsIvy", BlackForest },
        { "BH_Chicory", Swamp },
        { "BH_LokisTrickcap", Swamp },
        { "BH_AslaugsHerb", Swamp },
        { "BH_Daisy", Mountain },
        { "BH_SeidrBlossoms", Mountain },
        { "BH_HelshadeFungus", Mountain },
        { "BH_Echinacea", Plains },
        { "BH_ThorsToadstool", Plains },
        { "BH_Lavender", Plains },
        { "BH_Valhallaberry", Mistlands },
        { "BH_NordicFirebloom", Mistlands },
    };

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin("blacks7ar.Herbalist", "1.5.0", "Herbalist");
        Pinned.Pin(SkillRules.WorldAdvancementProgressionGuid, "1.0.0", "World Advancement Progression");
        Hooks.Method(typeof(KeyManager), "HasKey", new[] { typeof(string) }, typeof(bool));
        Hooks.Property(typeof(KeyManager), "Instance", typeof(KeyManager));
        MethodBase use = Hooks.Method(typeof(Humanoid), nameof(Humanoid.UseItem),
            new[] { typeof(Inventory), typeof(ItemDrop.ItemData), typeof(bool) }, typeof(void));
        yield return new PatchPlan(use) { Prefix = Hooks.Patch(typeof(TonicKeys), nameof(BeforeUse)) };
    }

    private static bool BeforeUse(Humanoid __instance, ItemDrop.ItemData item)
    {
        if (__instance != Player.m_localPlayer || item == null)
        {
            return true;
        }
        Biome? needed = Needed(item);
        if (needed == null || KeyManager.Instance == null || KeyManager.Instance.HasKey(needed.BossKey))
        {
            return true;
        }
        __instance.Message(MessageHud.MessageType.Center,
            $"Needs your own {needed.Label} boss key to drink. Guide: Boss keys (boss-keys).");
        return false;
    }

    /// <summary>The biome of the highest-biome herb in the item's recipe, or null when the item is no
    /// Herbalist tonic or elixir, has no recipe, or its herbs are all unknown (they gate nothing, the
    /// way World Advancement Progression lets materials it does not know through).</summary>
    private static Biome? Needed(ItemDrop.ItemData item)
    {
        string name = item.m_dropPrefab != null ? item.m_dropPrefab.name : item.m_shared.m_name;
        if (!name.StartsWith("BH_", StringComparison.Ordinal)
            || !(name.EndsWith("Tonic", StringComparison.Ordinal) || name.EndsWith("Elixer", StringComparison.Ordinal)))
        {
            return null;
        }
        Recipe? recipe = ObjectDB.instance != null ? ObjectDB.instance.GetRecipe(item) : null;
        if (recipe?.m_resources == null)
        {
            return null;
        }
        Biome? highest = null;
        foreach (Piece.Requirement resource in recipe.m_resources)
        {
            if (resource.m_resItem == null
                || !BiomeOfHerb.TryGetValue(resource.m_resItem.gameObject.name, out Biome biome))
            {
                continue;
            }
            if (highest == null || biome.Rank > highest.Rank)
            {
                highest = biome;
            }
        }
        return highest;
    }
}
