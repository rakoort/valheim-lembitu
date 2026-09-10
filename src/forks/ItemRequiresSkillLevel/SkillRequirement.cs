using System;
using System.Collections.Generic;
using YamlDotNet.Serialization;
using System.Linq;
using System.IO;
using System.Text;
using UnityEngine;
using YamlDotNet.Serialization.NamingConventions;
using BepInEx;

namespace ItemRequiresSkillLevel
{
    public class SkillRequirement
    {
        [YamlMember(Alias = "PrefabName")]
        public string PrefabName { get; set; }

        [YamlIgnore]
        public int StableHashCode { get; set; }

        [YamlMember(Alias = "Requirements")]
        public List<Requirement> Requirements { get; set; }

        public static List<SkillRequirement> Parse(string yaml)
        {
            List<SkillRequirement> list = ParseString(yaml);
            if (list == null) return new List<SkillRequirement>();

            foreach (SkillRequirement skillRequirement in list)
            {
                if (skillRequirement.PrefabName != null)
                {
                    skillRequirement.StableHashCode = skillRequirement.PrefabName.GetStableHashCode();
                }
                
                if (skillRequirement.Requirements != null)
                {
                    foreach (var x in skillRequirement.Requirements)
                    {
                        if (string.IsNullOrEmpty(x.ExhibitionName))
                            x.ExhibitionName = string.IsNullOrEmpty(x.GlobalKeyReq) ? x.Skill : x.GlobalKeyReq;
                    }
                }
            }

            return list;
        }

        private static List<SkillRequirement> ParseString(string yaml)
        {
            var deserializer = new DeserializerBuilder()
                .WithNamingConvention(PascalCaseNamingConvention.Instance)
                .IgnoreUnmatchedProperties()
                .IgnoreFields()
                .Build();

            try
            {
                return deserializer.Deserialize<List<SkillRequirement>>(yaml) ?? new List<SkillRequirement>();
            }
            catch
            {
                try
                {
                    var document = deserializer.Deserialize<RequirementDocument>(yaml);
                    return document?.ToSkillRequirements() ?? new List<SkillRequirement>();
                }
                catch (System.Exception ex)
                {
                    UnityEngine.Debug.LogWarning($"[ItemRequiresSkillLevel] YAML Parsing Error: {ex.Message}");
                    return new List<SkillRequirement>();
                }
            }
        }
    }

    public class RequirementDocument
    {
        [YamlMember(Alias = "Requirements")]
        public List<SkillRequirement> Requirements { get; set; }

        [YamlMember(Alias = "RequirementGroups")]
        public List<RequirementGroup> RequirementGroups { get; set; }

        public List<SkillRequirement> ToSkillRequirements()
        {
            List<SkillRequirement> list = Requirements != null
                ? new List<SkillRequirement>(Requirements)
                : new List<SkillRequirement>();

            if (RequirementGroups == null) return list;

            foreach (RequirementGroup group in RequirementGroups)
            {
                if (group?.Prefabs == null || group.Requirements == null) continue;

                foreach (string prefab in group.Prefabs.Where(x => !string.IsNullOrWhiteSpace(x)))
                {
                    list.Add(new SkillRequirement
                    {
                        PrefabName = prefab,
                        Requirements = group.Requirements.Select(CloneRequirement).ToList()
                    });
                }
            }

            return list;
        }

        private static Requirement CloneRequirement(Requirement requirement) => new Requirement
        {
            Skill = requirement.Skill,
            Level = requirement.Level,
            BlockCraft = requirement.BlockCraft,
            BlockEquip = requirement.BlockEquip,
            EpicMMO = requirement.EpicMMO,
            GlobalKeyReq = requirement.GlobalKeyReq,
            ExhibitionName = requirement.ExhibitionName
        };
    }

    public class RequirementGroup
    {
        [YamlMember(Alias = "Prefabs")]
        public List<string> Prefabs { get; set; }

        [YamlMember(Alias = "Requirements")]
        public List<Requirement> Requirements { get; set; }
    }

    public class RequirementSampleDocument
    {
        [YamlMember(Alias = "Requirements")]
        public List<SkillRequirement> Requirements { get; set; }

        [YamlMember(Alias = "RequirementGroups")]
        public List<RequirementGroup> RequirementGroups { get; set; }
    }

    public class Requirement
    {
        [YamlMember(Alias = "Skill")]
        public string Skill { get; set; }
        [YamlMember(Alias = "Level")]
        public int Level { get; set; }
        [YamlMember(Alias = "BlockCraft")]
        public bool BlockCraft { get; set; }
        [YamlMember(Alias = "BlockEquip")]
        public bool BlockEquip { get; set; }
        [YamlMember(Alias = "EpicMMO")]
        public bool EpicMMO { get; set; }
        [YamlMember(Alias = "GlobalKeyReq")]
        public string GlobalKeyReq { get; set; }
        [YamlMember(Alias = "ExhibitionName")]
        public string ExhibitionName { get; set; }
    }

    public class RequirementService
    {
        public static List<SkillRequirement> list = new();

        public static void Init()
        {
            bool anyFileExists = Directory.GetFiles(Paths.ConfigPath, ItemRequiresSkillLevel.PluginGUID + "*.yml").Any() || File.Exists(ItemRequiresSkillLevel.ConfigPathOld);
            if (!anyFileExists)
            {
                // Ours, not upstream's. Upstream seeded this file with vanilla-skill and
                // defeated_* world-key rules; on this server the gate exists to stop a clan
                // handing a newcomer endgame gear, so it reads character level and attributes
                // from EpicMMOSystem (ADR-0004's second power curve, ADR-0005 for why world
                // progression is not consulted). The file is only written when no rule file
                // exists at all: config/enforced/ ships ours, so on our own server this is
                // documentation of the schema rather than live configuration.
                List<SkillRequirement> initials = new();
                initials.Add(new SkillRequirement
                {
                    PrefabName = "ArmorIronChest",
                    Requirements = new List<Requirement>() {
                        new Requirement
                        {
                            Skill = "Level",
                            Level = 20,
                            EpicMMO = true,
                            BlockCraft = true,
                            BlockEquip = true,
                            ExhibitionName = "Character Level"
                        }
                    }
                });
                initials.Add(new SkillRequirement
                {
                    PrefabName = "SwordIron",
                    Requirements = new List<Requirement>() {
                        new Requirement
                        {
                            Skill = "Strength",
                            Level = 15,
                            EpicMMO = true,
                            BlockEquip = true,
                            ExhibitionName = "Strength"
                        }
                    }
                });
                initials.Add(new SkillRequirement
                {
                    // The key path, which personal keys (#11) will answer through. The key is
                    // read from this character's own key set, never the world's.
                    PrefabName = "ArmorSilverChest",
                    Requirements = new List<Requirement>() {
                        new Requirement
                        {
                            GlobalKeyReq = "defeated_dragon",
                            BlockCraft = true,
                            BlockEquip = true,
                            ExhibitionName = "Moder defeated"
                        }
                    }
                });

                var serializer = new SerializerBuilder()
                .WithNamingConvention(PascalCaseNamingConvention.Instance)
                .Build();

                var sample = new RequirementSampleDocument
                {
                    Requirements = initials,
                    // A group applies one requirement to several prefabs. Deliberately a different
                    // tier from the rules above: upstream's sample gated the same three iron
                    // pieces twice, at two levels and under two labels, which is a schema example
                    // that teaches the reader the wrong thing.
                    RequirementGroups = new List<RequirementGroup>
                    {
                        new RequirementGroup
                        {
                            Prefabs = new List<string>
                            {
                                "ArmorBronzeChest",
                                "ArmorBronzeLegs",
                                "HelmetBronze"
                            },
                            Requirements = new List<Requirement>
                            {
                                new Requirement
                                {
                                    Skill = "Strength",
                                    Level = 5,
                                    BlockCraft = false,
                                    BlockEquip = true,
                                    EpicMMO = true,
                                    ExhibitionName = "Strength"
                                }
                            }
                        }
                    }
                };

                var yaml = serializer.Serialize(sample);

                using StreamWriter streamWriter = File.CreateText(ItemRequiresSkillLevel.ConfigPathNew);
                streamWriter.Write(new StringBuilder()
                        .AppendLine(yaml));
                streamWriter.Close();
            }
        }

        public static void GenerateListWithAllEquipments()
        {
            if (!File.Exists(ItemRequiresSkillLevel.AllItemsConfigPath))
            {
                List<SkillRequirement> initials = new();

                foreach (var item in ObjectDB.instance.m_items)
                {
                    ItemDrop itemDrop = item.GetComponent<ItemDrop>();
                    if (!itemDrop) continue;

                    if (itemDrop.m_itemData is null) continue;

                    if (itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Tool || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.OneHandedWeapon || (itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.TwoHandedWeapon || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Bow) || (itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Shield || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Helmet || (itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Chest || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Legs)) || (itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Shoulder || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Ammo || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Torch) || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Utility || itemDrop.m_itemData.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Consumable)
                    {
                        initials.Add(new SkillRequirement
                        {
                            PrefabName = item.name,
                            Requirements = new List<Requirement>() {
                            new Requirement()
                            {
                                Skill = "Blocking",
                                Level = 10,
                                BlockCraft = false,
                                BlockEquip = true                                
                            }
                            }
                        });
                    }
                }

                var serializer = new SerializerBuilder()
                .WithNamingConvention(PascalCaseNamingConvention.Instance)
                .Build();

                var yaml = serializer.Serialize(initials);

                using StreamWriter streamWriter = File.CreateText(ItemRequiresSkillLevel.AllItemsConfigPath);
                streamWriter.Write(new StringBuilder()
                        .AppendLine(yaml));
                streamWriter.Close();
            }
        }

        public static void Load()
        {
            list.Clear();

            foreach (KeyValuePair<string, string> yamlFile in ItemRequiresSkillLevel.YamlData.Value)
            {
                list.AddRange(SkillRequirement.Parse(yamlFile.Value));
            }

            // Ours. A rule the evaluator cannot make sense of does not fail loudly at runtime: an
            // unrecognised skill name hashes to a SkillType nobody has, so Patches.IsAble reports
            // the requirement as unmet and the item is blocked for everyone, for good. The only
            // place that is visible is here, at load.
            int rules = 0, unusable = 0;
            foreach (SkillRequirement requirement in list)
            {
                if (requirement.Requirements == null) continue;
                foreach (Requirement rule in requirement.Requirements)
                {
                    rules++;
                    if (CanBeMet(rule)) continue;
                    unusable++;
                    ItemRequiresSkillLevel.Log.LogWarning(
                        $"{requirement.PrefabName}: '{rule.Skill}' is not a character attribute, a vanilla skill or a key, so this requirement can never be met and the item stays blocked");
                }
            }

            ItemRequiresSkillLevel.Log.LogInfo(
                $"Loaded {list.Count} item rules ({rules} requirements) from {ItemRequiresSkillLevel.YamlData.Value.Count} file(s){(unusable > 0 ? $", {unusable} unusable" : "")}");
            ReportRulesAgainstItemDatabase();
        }

        /// <summary>
        /// Ours. Names every rule prefab the item database does not have. Runs when the database
        /// appears and again on every rule reload once it exists, because either can happen first.
        /// The names are read out of <c>ObjectDB.m_items</c> rather than looked up with
        /// <c>GetItemPrefab</c>: that resolves through a hash dictionary the game fills after
        /// <c>Awake</c>, so asking it this early reports every rule as missing.
        /// </summary>
        public static void ReportRulesAgainstItemDatabase()
        {
            if (list.Count == 0) return;

            List<GameObject> items = ObjectDB.instance?.m_items;
            if (items == null || items.Count == 0)
            {
                ItemRequiresSkillLevel.Log.LogInfo($"{list.Count} item rules loaded before the item database; they will be checked when it appears");
                return;
            }

            HashSet<string> known = new();
            foreach (GameObject item in items)
            {
                if (item != null) known.Add(item.name);
            }

            int matched = 0;
            foreach (SkillRequirement requirement in list)
            {
                if (string.IsNullOrEmpty(requirement.PrefabName)) continue;
                if (known.Contains(requirement.PrefabName))
                {
                    matched++;
                    continue;
                }

                ItemRequiresSkillLevel.Log.LogWarning(
                    $"No item named '{requirement.PrefabName}' exists among the {known.Count} in this world's database, so its {requirement.Requirements?.Count ?? 0} requirement(s) gate nothing");
            }

            ItemRequiresSkillLevel.Log.LogInfo($"{matched} of {list.Count} item rules match an item in this world's database");
        }

        /// <summary>
        /// Whether anything can satisfy this requirement. Mirrors the branches of
        /// <see cref="Patches.IsAble" />, in the same order.
        /// </summary>
        private static bool CanBeMet(Requirement rule)
        {
            if (rule.EpicMMO) return true;
            if (!string.IsNullOrEmpty(rule.GlobalKeyReq)) return true;
            // No skill named: IsAble passes it when the level is zero or less, which is a rule
            // that gates nothing rather than one that can never be met.
            if (string.IsNullOrEmpty(rule.Skill)) return true;
            if (Patches.ValheimLevelSystemList.Contains(rule.Skill)) return true;
            return Enum.TryParse(rule.Skill, out Skills.SkillType _);
        }
    }
}
