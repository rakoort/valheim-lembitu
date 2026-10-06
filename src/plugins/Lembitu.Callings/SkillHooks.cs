using System;
using System.Collections.Generic;
using System.Linq;
using BepInEx.Logging;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// The steep curve, shadow levels and focus protection on death (ADR-0021, ADR-0022).
/// </summary>
internal static class SkillHooks
{
    private static ManualLogSource s_log = null!;

    public static void Configure(ManualLogSource log) => s_log = log;

    public static IEnumerable<PatchPlan> RecordPlan()
    {
        var load = Hooks.Method(typeof(Player), nameof(Player.Load), new[] { typeof(ZPackage) }, typeof(void));
        Hooks.Field(typeof(Player), nameof(Player.m_customData), typeof(Dictionary<string, string>));
        yield return new PatchPlan(load) { Postfix = Hooks.Patch(typeof(SkillHooks), nameof(AfterLoad)) };
    }

    /// <summary>
    /// Runs last among the prefixes on Skills.RaiseSkill, so ImpactfulSkills' per-skill rates and any
    /// learning bonus such as the Fast Learner elixir are already in <c>factor</c>. Every profession
    /// skill reaches this method: vanilla skills directly, the Jotunn and bundled-manager skills through
    /// Player.RaiseSkill.
    /// </summary>
    public static IEnumerable<PatchPlan> GainPlan()
    {
        var raise = Hooks.Method(typeof(Skills), nameof(Skills.RaiseSkill), new[] { typeof(Skills.SkillType), typeof(float) }, typeof(void));
        Hooks.Method(typeof(Skills), "GetSkill", new[] { typeof(Skills.SkillType) }, typeof(Skills.Skill));
        Hooks.Field(typeof(Skills), "m_player", typeof(Player));
        yield return new PatchPlan(raise) { Prefix = Hooks.Patch(typeof(SkillHooks), nameof(BeforeRaise), Priority.Last) };
    }

    /// <summary>
    /// A first prefix records every focus's level and progress, and every bundled-manager profession
    /// whether focus or not; a last finalizer puts them back after everything else on Skills.OnDeath
    /// has run, World Advancement Progression's drain and the bundled skill managers' own death
    /// handling included (those take their skill out of the list for the death, apply their own loss
    /// and put it back in their finalizers). In the same step the shadows drain, and so does a
    /// non-focus bundled-manager profession, by World Advancement Progression's rule. Their own loss
    /// setting therefore never counts: BlacksmithingExpanded files it under a section named after a
    /// localization key that is not resolved when the file is written (`[skill_1208107160]`), so no
    /// overlay can reliably pin it.
    /// </summary>
    public static IEnumerable<PatchPlan> DeathPlan()
    {
        var onDeath = Hooks.Method(typeof(Skills), nameof(Skills.OnDeath), Type.EmptyTypes, typeof(void));
        Hooks.Field(typeof(Skills), "m_skillData", typeof(Dictionary<Skills.SkillType, Skills.Skill>));
        Hooks.Field(typeof(Skills), nameof(Skills.m_DeathLowerFactor), typeof(float));
        Hooks.Field(typeof(Game), nameof(Game.m_skillReductionRate), typeof(float));
        yield return new PatchPlan(onDeath)
        {
            Prefix = Hooks.Patch(typeof(SkillHooks), nameof(BeforeDeath), Priority.First),
            Finalizer = Hooks.Patch(typeof(SkillHooks), nameof(AfterDeath), Priority.Last),
        };
    }

    private static void AfterLoad(Player __instance) => CallingStore.Forget(__instance);

    private static void BeforeRaise(Skills __instance, Skills.SkillType skillType, ref float factor, bool __runOriginal)
    {
        Player player = __instance.m_player;
        if (!__runOriginal || factor <= 0f || player == null || player != Player.m_localPlayer || !Professions.TryGet(skillType, out _))
        {
            return;
        }
        Skills.Skill skill = __instance.GetSkill(skillType);
        if (skill.m_info == null)
        {
            return;
        }
        Calling calling = CallingStore.Of(player);
        float raw = skill.m_info.m_increseStep * factor;
        if (calling.TryGetShadow(skillType, out Shadow shadow))
        {
            SkillRules.Raise(shadow, raw * Settings.Rate(shadow.Level));
            CallingStore.Save(player);
            XpLog.Record(skillType, raw, raw);
        }
        else
        {
            float rate = Settings.Rate(skill.m_level);
            factor *= rate;
            XpLog.Record(skillType, raw, raw * rate);
        }
    }

    private sealed class Kept(Skills.SkillType type, float level, float accumulator)
    {
        public Skills.SkillType Type { get; } = type;
        public float Level { get; } = level;
        public float Accumulator { get; } = accumulator;
    }

    private static void BeforeDeath(Skills __instance, out List<Kept>? __state)
    {
        __state = null;
        Player player = __instance.m_player;
        if (player == null || player != Player.m_localPlayer)
        {
            return;
        }
        __state = new List<Kept>();
        Calling calling = CallingStore.Of(player);
        foreach (Skills.SkillType type in calling.Focuses.Select(f => f.Key).Union(new[] { Professions.Blacksmithing, Professions.Herbalist, Professions.Explorer }))
        {
            if (__instance.m_skillData.TryGetValue(type, out Skills.Skill skill))
            {
                __state.Add(new Kept(type, skill.m_level, skill.m_accumulator));
            }
        }
    }

    private static Exception? AfterDeath(Skills __instance, List<Kept>? __state, Exception? __exception)
    {
        if (__state == null)
        {
            return __exception;
        }
        Player player = __instance.m_player;
        Calling calling = CallingStore.Of(player);
        float factor = __instance.m_DeathLowerFactor * Game.m_skillReductionRate;

        foreach (Kept kept in __state)
        {
            if (__instance.m_skillData.TryGetValue(kept.Type, out Skills.Skill skill))
            {
                skill.m_level = kept.Level;
                skill.m_accumulator = kept.Accumulator;
            }
        }
        foreach (var focus in calling.Focuses)
        {
            focus.Value.Level = SkillRules.Drained(focus.Value.Level, factor);
            focus.Value.Accumulator = 0f;
        }
        var drained = new List<string>();
        foreach (Skills.SkillType bundled in new[] { Professions.Blacksmithing, Professions.Herbalist, Professions.Explorer })
        {
            if (!calling.IsFocus(bundled) && __instance.m_skillData.TryGetValue(bundled, out Skills.Skill skill))
            {
                float before = skill.m_level;
                skill.m_level = SkillRules.Drained(before, factor);
                skill.m_accumulator = 0f;
                drained.Add($"{(Professions.TryGet(bundled, out Profession p) ? p.Key : bundled.ToString())} {before:0.##}->{skill.m_level:0.##}");
            }
        }
        CallingStore.Save(player);
        s_log.LogInfo($"Death: kept {calling.Focuses.Count()} focus skill(s); shadows {string.Join(", ", calling.Focuses.Select(f => f.Value.Level.ToString("0.##")))}; drained {(drained.Count == 0 ? "no bundled skill" : string.Join(", ", drained))}");
        return __exception;
    }
}
