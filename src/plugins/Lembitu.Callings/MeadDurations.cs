using System;
using System.Collections.Generic;
using System.Reflection;
using BepInEx.Bootstrap;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// Herbalist 1.5.0 scales a mead by the drinker's Herbalist skill in a Player.ConsumeItem prefix
/// (Herbalist.Patches.PlayerPatch.ConsumeItem_Prefix): healing, stamina and eitr meads get a cooldown
/// 10% to 80% shorter, resist, Tasty and Lingering meads last 1.25 to 2 times longer and at least an
/// hour. It writes the result into the item's shared status effect, so every drink, and every attempt
/// the cooldown refuses, starts from the last result: cooldowns shrank toward a tenth per drink and
/// durations grew by a quarter or more, until the game restarted. This puts each effect's own duration
/// back before Herbalist's prefix and again after the drink, so every drink gets Herbalist's formula
/// once, from the base value. Herbalist's own lists say which meads it scales.
/// </summary>
internal static class MeadDurations
{
    private const string HerbalistGuid = "blacks7ar.Herbalist";

    /// <summary>Each scaled effect's duration from before any drink, by effect asset.</summary>
    private static readonly Dictionary<StatusEffect, float> BaseTtl = new();

    private static HashSet<string> s_scaled = new(StringComparer.Ordinal);

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin(HerbalistGuid, "1.5.0", "Herbalist");
        Assembly herbalist = Chainloader.PluginInfos[HerbalistGuid].Instance.GetType().Assembly;
        Type plugin = herbalist.GetType("Herbalist.Plugin") ?? throw new HookMismatch("Herbalist.Plugin not found");
        Type patch = herbalist.GetType("Herbalist.Patches.PlayerPatch") ?? throw new HookMismatch("Herbalist.Patches.PlayerPatch not found");
        Hooks.Method(patch, "ConsumeItem_Prefix", new[] { typeof(Player).MakeByRefType(), typeof(ItemDrop.ItemData) }, typeof(void));
        Hooks.Field(plugin, "_ToReduceCooldown", typeof(HashSet<string>));
        Hooks.Field(plugin, "_ToIncreaseDuration", typeof(HashSet<string>));
        var scaled = new HashSet<string>(StringComparer.Ordinal);
        scaled.UnionWith((HashSet<string>)AccessTools.Field(plugin, "_ToReduceCooldown").GetValue(null));
        scaled.UnionWith((HashSet<string>)AccessTools.Field(plugin, "_ToIncreaseDuration").GetValue(null));
        s_scaled = scaled;

        MethodInfo consume = Hooks.Method(typeof(Player), nameof(Player.ConsumeItem),
            new[] { typeof(Inventory), typeof(ItemDrop.ItemData), typeof(bool) }, typeof(bool));
        HarmonyMethod before = Hooks.Patch(typeof(MeadDurations), nameof(Reset), Priority.First);
        before.before = new[] { HerbalistGuid };
        yield return new PatchPlan(consume)
        {
            Prefix = before,
            Finalizer = Hooks.Patch(typeof(MeadDurations), nameof(Restore)),
        };
    }

    private static void Restore(ItemDrop.ItemData item) => Reset(item);

    /// <summary>The first sight of an effect comes before any drink of it, so its duration then is the base.</summary>
    private static void Reset(ItemDrop.ItemData item)
    {
        if (item?.m_dropPrefab == null || !s_scaled.Contains(item.m_dropPrefab.name))
        {
            return;
        }
        StatusEffect effect = item.m_shared.m_consumeStatusEffect;
        if (effect == null)
        {
            return;
        }
        if (BaseTtl.TryGetValue(effect, out float ttl))
        {
            effect.m_ttl = ttl;
        }
        else
        {
            BaseTtl[effect] = effect.m_ttl;
        }
    }
}
