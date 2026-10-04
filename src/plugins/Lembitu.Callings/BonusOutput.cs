using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// Herbalist and Fishing give their producer extra output that grows linearly with level (ADR-0022,
/// ADR-0024): about 1.5 extra items per tonic, elixir or mead-base craft and 1.25 extra fish per landed
/// catch at 100. One roll per craft or catch: the whole part of the expectation is given and the
/// fraction is a chance, so the average is exact. The copies keep the item's identity and quality,
/// consume nothing and raise no skill.
/// </summary>
internal static class BonusOutput
{
    /// <summary>Herbalist's own products (Herbalist Plugin._herbalistPotions).</summary>
    private static readonly HashSet<string> HerbalistProducts = new(StringComparer.Ordinal)
    {
        "BH_BeserkerElixer", "BH_DefenderElixer", "BH_GhostElixer", "BH_HeavyLifterElixer", "BH_JumpElixer",
        "BH_LargeEitrTonic", "BH_LargeHealthTonic", "BH_LargeStaminaTonic", "BH_LearningElixer", "BH_MediumEitrTonic",
        "BH_MediumHealthTonic", "BH_MediumStaminaTonic", "BH_MinorEitrTonic", "BH_MinorHealthTonic", "BH_MinorStaminaTonic",
        "BH_RunnerElixer", "BH_SlowFallElixer",
    };

    private static readonly System.Random Roll = new();

    /// <summary>The Herbalist craft in progress, filled in when DoCrafting actually adds the product.</summary>
    private sealed class Craft(string item, int crafts)
    {
        public string Item { get; } = item;
        public int Crafts { get; } = crafts;
        public bool Added { get; set; }
        public int Quality { get; set; }
        public int Variant { get; set; }
        public long CrafterId { get; set; }
        public string CrafterName { get; set; } = "";
        public bool Cheated { get; set; }
    }

    [ThreadStatic] private static Craft? s_craft;

    public static IEnumerable<PatchPlan> HerbalistPlan()
    {
        var doCrafting = Hooks.Method(typeof(InventoryGui), "DoCrafting", new[] { typeof(Player) }, typeof(void));
        var addItem = Hooks.Method(typeof(Inventory), nameof(Inventory.AddItem),
            new[] { typeof(string), typeof(int), typeof(int), typeof(int), typeof(long), typeof(string), typeof(Vector2i), typeof(bool), typeof(bool), typeof(bool) },
            typeof(ItemDrop.ItemData));
        Hooks.Field(typeof(InventoryGui), "m_craftRecipe", typeof(Recipe));
        Hooks.Field(typeof(InventoryGui), "m_craftUpgradeItem", typeof(ItemDrop.ItemData));
        Hooks.Field(typeof(InventoryGui), "m_multiCrafting", typeof(bool));
        Hooks.Field(typeof(InventoryGui), "m_multiCraftAmount", typeof(int));
        yield return new PatchPlan(doCrafting)
        {
            Prefix = Hooks.Patch(typeof(BonusOutput), nameof(BeforeCrafting), Priority.First),
            Postfix = Hooks.Patch(typeof(BonusOutput), nameof(AfterCrafting), Priority.Last),
        };
        yield return new PatchPlan(addItem) { Postfix = Hooks.Patch(typeof(BonusOutput), nameof(AfterAddItem)) };
    }

    public static IEnumerable<PatchPlan> FishingPlan()
    {
        var catchFish = Hooks.Method(typeof(FishingFloat), nameof(FishingFloat.Catch), new[] { typeof(Fish), typeof(Character) }, typeof(string));
        Hooks.Field(typeof(Fish), nameof(Fish.m_pickupItem), typeof(GameObject));
        Hooks.Field(typeof(Fish), nameof(Fish.m_pickupItemStackSize), typeof(int));
        yield return new PatchPlan(catchFish)
        {
            Prefix = Hooks.Patch(typeof(BonusOutput), nameof(BeforeCatch)),
            Postfix = Hooks.Patch(typeof(BonusOutput), nameof(AfterCatch)),
        };
    }

    /// <summary>Herbalist's tonics and elixirs and every vanilla mead base, the barley wine base included.</summary>
    public static bool IsHerbalistProduct(string item) =>
        HerbalistProducts.Contains(item) || item.StartsWith("MeadBase", StringComparison.Ordinal) || item == "BarleyWineBase";

    private static void BeforeCrafting(InventoryGui __instance, Player player)
    {
        s_craft = null;
        Recipe recipe = __instance.m_craftRecipe;
        if (player != Player.m_localPlayer || recipe == null || recipe.m_item == null || __instance.m_craftUpgradeItem != null)
        {
            return;
        }
        string item = recipe.m_item.gameObject.name;
        if (IsHerbalistProduct(item))
        {
            s_craft = new Craft(item, __instance.m_multiCrafting ? __instance.m_multiCraftAmount : 1);
        }
    }

    /// <summary>Vanilla DoCrafting adds the product through this overload only when the craft succeeds.</summary>
    private static void AfterAddItem(string name, int quality, int variant, long crafterID, string crafterName, bool cheated, ItemDrop.ItemData __result)
    {
        Craft? craft = s_craft;
        if (craft == null || craft.Added || __result == null || name != craft.Item)
        {
            return;
        }
        craft.Added = true;
        craft.Quality = quality;
        craft.Variant = variant;
        craft.CrafterId = crafterID;
        craft.CrafterName = crafterName;
        craft.Cheated = cheated;
    }

    private static void AfterCrafting(Player player)
    {
        Craft? craft = s_craft;
        s_craft = null;
        if (craft == null || !craft.Added)
        {
            return;
        }
        int extra = Extra(craft.Crafts * Settings.HerbalistExtraAt100 * player.GetSkillFactor(Professions.Herbalist));
        if (extra == 0)
        {
            return;
        }
        player.GetInventory().AddItem(craft.Item, extra, craft.Quality, craft.Variant, craft.CrafterId, craft.CrafterName, craft.Cheated);
        DamageText.instance.ShowText(DamageText.TextType.Bonus, player.transform.position + Vector3.up, $"+{extra}", player: true);
    }

    private static void BeforeCatch(Fish fish, Character owner, out ItemDrop.ItemData? __state)
    {
        __state = null;
        if (fish == null || owner == null || owner != Player.m_localPlayer)
        {
            return;
        }
        ItemDrop? drop = fish.GetComponent<ItemDrop>();
        GameObject? prefab = drop != null ? ObjectDB.instance.GetItemPrefab(Utils.GetPrefabName(fish.gameObject)) : fish.m_pickupItem;
        ItemDrop? template = drop != null ? drop : prefab?.GetComponent<ItemDrop>();
        if (prefab == null || template == null)
        {
            return;
        }
        __state = template.m_itemData.Clone();
        __state.m_dropPrefab = prefab;
        __state.m_stack = drop != null ? 1 : fish.m_pickupItemStackSize;
    }

    private static void AfterCatch(Character owner, ItemDrop.ItemData? __state, ref string __result)
    {
        if (__state == null || owner is not Player player)
        {
            return;
        }
        int extra = Extra(Settings.FishingExtraAt100 * player.GetSkillFactor(Skills.SkillType.Fishing));
        for (int i = 0; i < extra; i++)
        {
            ItemDrop.ItemData copy = __state.Clone();
            if (player.GetInventory().CanAddItem(copy))
            {
                player.GetInventory().AddItem(copy);
            }
            else
            {
                ItemDrop.DropItem(copy, copy.m_stack, player.transform.position + Vector3.up, Quaternion.identity);
            }
        }
        if (extra > 0)
        {
            __result += $" (+{extra})";
        }
    }

    /// <summary>floor(mu) plus one more with probability frac(mu).</summary>
    private static int Extra(double expected)
    {
        if (expected <= 0)
        {
            return 0;
        }
        int whole = (int)Math.Floor(expected);
        return Roll.NextDouble() < expected - whole ? whole + 1 : whole;
    }
}
