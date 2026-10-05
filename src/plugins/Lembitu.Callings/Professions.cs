using System;
using System.Collections.Generic;
using System.Linq;
using BepInEx.Logging;
using Jotunn.Managers;

namespace Lembitu.Callings;

internal enum ProfessionGroup
{
    Craft,
    Land,
    Road,
}

/// <param name="key">Stable name stored in the Calling record: the vanilla enum name, the Jotunn
/// identifier, or the English name a bundled skill manager hashes.</param>
internal sealed class Profession(string key, ProfessionGroup group, Skills.SkillType type)
{
    public string Key { get; } = key;
    public ProfessionGroup Group { get; } = group;
    public Skills.SkillType Type { get; } = type;

    /// <summary>The name the skills window shows for this skill.</summary>
    public string DisplayName => Localization.instance.Localize("$skill_" + Type.ToString().ToLower());
}

/// <summary>
/// The eleven profession skills of ADR-0021 and how many of each group a Calling holds: two Land, one
/// Craft and one Road.
/// </summary>
internal static class Professions
{
    /// <summary>ImpactfulSkills' Jotunn identifiers; Explorer uses its bundled skill manager.</summary>
    private static readonly string[] JotunnIdentifiers =
    {
        "midnightsfx.animalwhisper", "midnightsfx.voyager", "midnightsfx.hauling",
    };

    public static readonly IReadOnlyList<Profession> All = new[]
    {
        Vanilla(Skills.SkillType.Pickaxes, ProfessionGroup.Land),
        Vanilla(Skills.SkillType.WoodCutting, ProfessionGroup.Land),
        Vanilla(Skills.SkillType.Farming, ProfessionGroup.Land),
        Vanilla(Skills.SkillType.Fishing, ProfessionGroup.Land),
        Hashed("midnightsfx.animalwhisper", ProfessionGroup.Land),
        Hashed("Blacksmithing", ProfessionGroup.Craft),
        Hashed("Herbalist", ProfessionGroup.Craft),
        Vanilla(Skills.SkillType.Cooking, ProfessionGroup.Craft),
        Hashed("Explorer", ProfessionGroup.Road),
        Hashed("midnightsfx.voyager", ProfessionGroup.Road),
        Hashed("midnightsfx.hauling", ProfessionGroup.Road),
    };

    public static readonly Skills.SkillType Blacksmithing = Hash("Blacksmithing");
    public static readonly Skills.SkillType Herbalist = Hash("Herbalist");
    public static readonly Skills.SkillType Explorer = Hash("Explorer");

    private static readonly Dictionary<Skills.SkillType, Profession> ByType = All.ToDictionary(p => p.Type);
    private static readonly Dictionary<string, Profession> ByKey = All.ToDictionary(p => p.Key, StringComparer.Ordinal);

    public static int Quota(ProfessionGroup group) => group == ProfessionGroup.Land ? 2 : 1;

    public static string Describe(ProfessionGroup group) => group switch
    {
        ProfessionGroup.Craft => "Craft",
        ProfessionGroup.Land => "Land",
        _ => "Road",
    };

    public static bool TryGet(Skills.SkillType type, out Profession profession) => ByType.TryGetValue(type, out profession);

    public static bool TryGet(string key, out Profession profession) => ByKey.TryGetValue(key, out profession);

    /// <summary>
    /// Jotunn and the bundled skill managers both derive a skill's type as |GetStableHashCode| of its
    /// identifier (Jotunn SkillConfig.Identifier; SkillManager.Skill.fromName). Checks ImpactfulSkills
    /// with Jotunn and Explorer with its own assembly's bundled registry, so a missing or renamed
    /// profession is seen at startup rather than silently ceasing to count.
    /// </summary>
    public static void VerifySkills(ManualLogSource log)
    {
        foreach (string identifier in JotunnIdentifiers)
        {
            Skills.SkillDef? def = SkillManager.Instance.GetSkill(identifier);
            if (def == null)
            {
                log.LogWarning($"Profession skill {identifier} is not registered with Jotunn; it will not count.");
            }
            else if (def.m_skill != Hash(identifier))
            {
                log.LogError($"Profession skill {identifier} resolves to {(int)def.m_skill}, not {(int)Hash(identifier)}.");
            }
        }
        if (BepInEx.Bootstrap.Chainloader.PluginInfos.TryGetValue(ExplorerRange.Guid, out var explorer))
        {
            Type? manager = explorer.Instance.GetType().Assembly.GetType("SkillManager.Skill");
            var registry = manager == null ? null : HarmonyLib.AccessTools.Field(manager, "skills")?.GetValue(null) as System.Collections.IDictionary;
            if (registry == null || !registry.Contains(Explorer))
                log.LogError("Profession skill Explorer is not registered with its bundled skill manager; it will not count.");
            else
                log.LogInfo($"Profession skill Explorer registered as {(int)Explorer} with its bundled skill manager.");
        }
        else log.LogWarning("Explorer is not loaded; the Exploration profession will not count.");
    }

    private static Profession Vanilla(Skills.SkillType type, ProfessionGroup group) => new(type.ToString(), group, type);

    private static Profession Hashed(string key, ProfessionGroup group) => new(key, group, Hash(key));

    private static Skills.SkillType Hash(string identifier) => (Skills.SkillType)Math.Abs(identifier.GetStableHashCode());
}
