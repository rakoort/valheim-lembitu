using BepInEx.Bootstrap;
using UnityEngine;
using VentureValheim.Progression;

namespace Lembitu.Callings;

/// <summary>
/// How a skill gains and drains, so a shadow level and a bundled-manager skill follow exactly the rules
/// a vanilla skill follows. World Advancement Progression replaces both (Skills.Skill.Raise and
/// Skills.LowerAllSkills) when its skill manager is on; its own methods are called here rather than
/// copied, so its floor, ceiling and drain settings apply unchanged.
/// </summary>
internal static class SkillRules
{
    public const string WorldAdvancementProgressionGuid = "com.orianaventure.mod.WorldAdvancementProgression";

    private static readonly bool s_wapLoaded = Chainloader.PluginInfos.ContainsKey(WorldAdvancementProgressionGuid);

    /// <summary>Vanilla Skills.Skill.GetNextLevelRequirement.</summary>
    public static float Requirement(float level) => Mathf.Pow(Mathf.Floor(level + 1f), 1.5f) * 0.5f + 0.5f;

    /// <summary>Advances a shadow by one gain, as Skills.Skill.Raise would advance a skill.</summary>
    public static void Raise(Shadow shadow, float increase)
    {
        if (s_wapLoaded && Wap.ManagesSkills)
        {
            Wap.Raise(shadow, increase);
            return;
        }
        if (shadow.Level >= 100f)
        {
            return;
        }
        shadow.Accumulator += increase * Game.m_skillGainRate;
        if (shadow.Accumulator >= Requirement(shadow.Level))
        {
            shadow.Level = Mathf.Clamp(shadow.Level + 1f, 0f, 100f);
            shadow.Accumulator = 0f;
        }
    }

    /// <summary>The level a skill at <paramref name="level"/> keeps after a death drain of <paramref name="factor"/>.</summary>
    public static float Drained(float level, float factor) =>
        s_wapLoaded && Wap.ManagesSkills ? Wap.Drained(level, factor) : level - level * factor;

    public static string RuleSource => s_wapLoaded && Wap.ManagesSkills
        ? "World Advancement Progression's skill manager"
        : "vanilla skill rules";

    /// <summary>Only touched when World Advancement Progression is loaded.</summary>
    private static class Wap
    {
        public static bool ManagesSkills => ProgressionConfiguration.Instance.GetEnableSkillManager();

        /// <summary>SkillsManager.Patch_Skills_Skill_Raise.</summary>
        public static void Raise(Shadow shadow, float increase)
        {
            SkillsManager manager = SkillsManager.Instance;
            float gain = manager.GetSkillAccumulationGain(shadow.Level, manager.GetSkillGainCeiling(), increase);
            if (shadow.Accumulator + gain >= Requirement(shadow.Level))
            {
                shadow.Level = manager.NormalizeSkillLevel(shadow.Level + 1f);
                shadow.Accumulator = 0f;
            }
            else
            {
                shadow.Accumulator += gain;
            }
        }

        /// <summary>SkillsManager.Patch_Skills_LowerAllSkills.</summary>
        public static float Drained(float level, float factor)
        {
            if (!ProgressionConfiguration.Instance.GetAllowSkillDrain())
            {
                return level;
            }
            SkillsManager manager = SkillsManager.Instance;
            return manager.NormalizeSkillLevel(level - manager.GetSkillDrain(level, manager.GetSkillDrainFloor(), factor));
        }
    }
}
