using System;
using System.Collections.Generic;
using BepInEx.Bootstrap;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>Herbalist's mead formula, once from the base duration and using the brewer's grade.
/// Replaces its consume prefix because that prefix applies a one-hour floor and mutates shared
/// effects cumulatively. Shared assets are restored even when drinking throws or is refused.</summary>
internal static class MeadDurations
{
    private const string HerbalistGuid = "blacks7ar.Herbalist";
    private static readonly Dictionary<StatusEffect, float> BaseTtl = new();
    private static HashSet<string> s_longer = new(StringComparer.Ordinal);
    private static HashSet<string> s_cooldown = new(StringComparer.Ordinal);

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin(HerbalistGuid, "1.5.0", "Herbalist");
        var assembly = Chainloader.PluginInfos[HerbalistGuid].Instance.GetType().Assembly;
        Type plugin = assembly.GetType("Herbalist.Plugin") ?? throw new HookMismatch("Herbalist.Plugin not found");
        Type patch = assembly.GetType("Herbalist.Patches.PlayerPatch") ?? throw new HookMismatch("Herbalist.Patches.PlayerPatch not found");
        var upstream = Hooks.Method(patch, "ConsumeItem_Prefix", new[] { typeof(Player).MakeByRefType(), typeof(ItemDrop.ItemData) }, typeof(void));
        Hooks.Field(plugin, "_ToReduceCooldown", typeof(HashSet<string>));
        Hooks.Field(plugin, "_ToIncreaseDuration", typeof(HashSet<string>));
        s_longer = new HashSet<string>((HashSet<string>)AccessTools.Field(plugin, "_ToIncreaseDuration").GetValue(null), StringComparer.Ordinal);
        s_cooldown = new HashSet<string>((HashSet<string>)AccessTools.Field(plugin, "_ToReduceCooldown").GetValue(null), StringComparer.Ordinal);
        yield return new PatchPlan(upstream) { Prefix = Hooks.Patch(typeof(MeadDurations), nameof(ReplaceUpstream)) };
        var consume = Hooks.Method(typeof(Player), nameof(Player.ConsumeItem),
            new[] { typeof(Inventory), typeof(ItemDrop.ItemData), typeof(bool) }, typeof(bool));
        HarmonyMethod before = Hooks.Patch(typeof(MeadDurations), nameof(Scale), Priority.First);
        before.before = new[] { HerbalistGuid };
        yield return new PatchPlan(consume)
        {
            Prefix = before,
            Finalizer = Hooks.Patch(typeof(MeadDurations), nameof(Restore)),
        };
    }

    private static bool ReplaceUpstream() => false;

    private static void Scale(ItemDrop.ItemData item)
    {
        if (item?.m_dropPrefab == null) return;
        string name = item.m_dropPrefab.name;
        if (!s_longer.Contains(name) && !s_cooldown.Contains(name)) return;
        StatusEffect effect = item.m_shared.m_consumeStatusEffect;
        if (effect == null) return;
        if (!BaseTtl.TryGetValue(effect, out float ttl)) BaseTtl[effect] = ttl = effect.m_ttl;
        float f = BrewersGrade.Factor(item);
        effect.m_ttl = ttl * (s_longer.Contains(name) ? 1.25f + 0.75f * f : 0.9f - 0.7f * f);
    }

    private static void Restore(ItemDrop.ItemData item)
    {
        StatusEffect? effect = item?.m_shared?.m_consumeStatusEffect;
        if (effect != null && BaseTtl.TryGetValue(effect, out float ttl)) effect.m_ttl = ttl;
    }
}
