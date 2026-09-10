using HarmonyLib;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace ItemRequiresSkillLevel
{
    [HarmonyPatch]
    class Patches
    {
        internal static readonly List<string> ValheimLevelSystemList = new List<string> { "Intelligence", "Strength", "Focus", "Constitution", "Agility", "Level", "Magic", "Diligence" };

        private static bool TryGetReqForItem(ItemDrop.ItemData item, out SkillRequirement requirement)
        {
            requirement = null;
            if (item?.m_dropPrefab == null) return false;
            var hash = item.m_dropPrefab.name.GetStableHashCode();
            requirement = RequirementService.list.FirstOrDefault(x => x.StableHashCode == hash);
            return requirement != null;
        }

        private static bool TryGetReqForPrefabName(string prefabName, out SkillRequirement requirement)
        {
            requirement = null;
            if (string.IsNullOrEmpty(prefabName)) return false;
            var hash = prefabName.GetStableHashCode();
            requirement = RequirementService.list.FirstOrDefault(x => x.StableHashCode == hash);
            return requirement != null;
        }

        [HarmonyPatch]
        class ItemDropItemData
        {
            [HarmonyPatch(typeof(ItemDrop.ItemData), nameof(ItemDrop.ItemData.GetTooltip), new Type[] { typeof(int) })]
            [HarmonyPostfix]
            private static void GetToolTip(ItemDrop.ItemData __instance, int stackOverride, ref string __result)
            {
                if (!TryGetReqForItem(__instance, out var requirement) || requirement.Requirements == null) return;
                __result += GetTextEquip(requirement); // append equip gate info (incl. GlobalKeyReq line)
            }

            [HarmonyPatch(typeof(ItemDrop.ItemData), nameof(ItemDrop.ItemData.IsEquipable))]
            [HarmonyPostfix]
            private static void IsEquipable(ItemDrop.ItemData __instance, ref bool __result)
            {
                if (!TryGetReqForItem(__instance, out var requirement) || requirement.Requirements == null) return;

                // If any BlockEquip requirement fails IsAble => not equipable
                bool blocked = requirement.Requirements.Where(x => x.BlockEquip).Any(x => !IsAble(x));
                if (blocked)
                {
                    if ( ItemRequiresSkillLevel.ShowBlockMessages.Value && MessageHud.instance != null)
                        MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, ItemRequiresSkillLevel.cantequipmessage.Value);
                    __result = false;
                }
            }
        }

        [HarmonyPatch]
        class StartDrawPatch
        {
            [HarmonyPatch(typeof(Attack), nameof(Attack.StartDraw))]
            [HarmonyPrefix]
            internal static bool StartDraw(Humanoid character, ItemDrop.ItemData weapon)
            {
                if (!character.IsPlayer()) return true;
                if (string.IsNullOrEmpty(weapon?.m_shared?.m_ammoType)) return true;

                // If player already has an acceptable equipped ammo item, allow
                if (character.m_ammoItem is not null &&
                    character.m_ammoItem.IsEquipable() &&
                    character.GetInventory().GetItem(character.m_ammoItem.m_shared.m_name) is not null)
                {
                    return true;
                }

                // Auto-pick compatible ammo that passes IsEquipable()
                foreach (ItemDrop.ItemData item in character.GetInventory().m_inventory)
                {
                    if (!item.IsEquipable()) continue;
                    if (!(item.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Ammo || item.m_shared.m_itemType == ItemDrop.ItemData.ItemType.Consumable)) continue;
                    if (item.m_shared.m_ammoType != weapon.m_shared.m_ammoType) continue;
                    character.m_ammoItem = item;
                    return true;
                }
                if ( ItemRequiresSkillLevel.ShowBlockMessages.Value && MessageHud.instance != null)
                    MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, ItemRequiresSkillLevel.cantUseAmmomessage.Value);
                return false;
            }
        }

        [HarmonyPatch]
        class HumanoidPickUp
        {
            [HarmonyPatch(typeof(Humanoid), nameof(Humanoid.EquipItem))]
            [HarmonyPrefix]
            internal static bool EquipItem(Humanoid __instance, ItemDrop.ItemData item)
            {
                if (!__instance.IsPlayer()) return true;

                // Respect our IsEquipable() override (which considers skill + GlobalKeyReq)
                if (item.IsEquipable()) return true;

                // Optionally: message to user
                if (__instance == Player.m_localPlayer  && ItemRequiresSkillLevel.ShowBlockMessages.Value && MessageHud.instance != null)
                    MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, ItemRequiresSkillLevel.cantequipmessage.Value);                

                return false;
            }
        }

        [HarmonyPatch]
        class UpdateRecipeText
        {
            [HarmonyPatch(typeof(InventoryGui), nameof(InventoryGui.UpdateRecipe))]
            [HarmonyPostfix]
            internal static void UpdateRecipe_Post(ref InventoryGui __instance, Player player)
            {
                if (__instance == null) return;
                var selected = __instance.m_selectedRecipe;
                if (selected.Recipe == null || selected.Recipe.m_item == null) return;

                string prefabName = selected.Recipe.m_item.gameObject.name;
                if (!TryGetReqForPrefabName(prefabName, out var requirement) || requirement.Requirements == null) return;

                string craftText = GetTextCraft(requirement); // includes key line + skill lines
                __instance.m_recipeDecription.text += craftText;

                bool blockCraft = requirement.Requirements.Where(x => x.BlockCraft).Any(x => !IsAble(x));
                if (blockCraft)
                {
                    __instance.m_craftButton.interactable = false;
                }
            }
        }

        [HarmonyPatch]
        class PlayerShit
        {
            [HarmonyPatch(typeof(Player), nameof(Player.CanConsumeItem))]
            [HarmonyPostfix]
            internal static void CanConsumeItem(ItemDrop.ItemData item, ref bool __result)
            {
                if (!TryGetReqForItem(item, out var requirement) || requirement.Requirements == null) return;

                // vanilla checks already ran; if food is edible state fails there, keep vanilla outcome
                // apply our BlockEquip rules for consumables (your schema uses BlockEquip for use)
                bool blockUse = requirement.Requirements.Where(x => x.BlockEquip).Any(x => !IsAble(x));
                if (blockUse)
                {
                    if (ItemRequiresSkillLevel.ShowBlockMessages.Value && MessageHud.instance != null)
                        MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, ItemRequiresSkillLevel.canteatmessage.Value);
                    __result = false;
                }
            }
        }

        [HarmonyPatch]
        class Spawn
        {
            static bool hasSpawned = false;

            [HarmonyPatch(typeof(Game), nameof(Game.RequestRespawn))]
            [HarmonyPostfix]
            internal static void RequestRespawnItemRequires()
            {
                if (hasSpawned) return;

                if (ItemRequiresSkillLevel.GenerateListWithAllEquipableItems.Value)
                {
                    RequirementService.GenerateListWithAllEquipments();
                }
                hasSpawned = true;
            }
        }

        /// <summary>
        /// Ours. A rule naming a prefab the game does not have gates nothing at all, and nothing
        /// says so: the requirement is simply never found. The item database is the only place
        /// that can answer, and on a dedicated server this is the only evidence this mod produces
        /// at all — the gate itself runs on the client.
        ///
        /// The hook is <c>CopyOtherDB</c>, not <c>Awake</c>: the scene's own ObjectDB holds a
        /// handful of items, and the world's real database is copied over it afterwards. Reporting
        /// on <c>Awake</c> says every rule is broken and then contradicts itself a second later.
        /// </summary>
        [HarmonyPatch]
        class ItemDatabase
        {
            [HarmonyPatch(typeof(ObjectDB), nameof(ObjectDB.CopyOtherDB))]
            [HarmonyPostfix]
            internal static void CopyOtherDB() => RequirementService.ReportRulesAgainstItemDatabase();
        }

        // ------------------------------ CORE EVALUATOR ------------------------------

        public static bool IsAble(Requirement requirement)
        {
            if (Player.m_localPlayer == null) return true;

            // EpicMMO attributes
            if (requirement.EpicMMO)
            {
                int level = 0;
                if (requirement.Skill == "Level") level = EpicMMOSystem_API.GetLevel();
                else if (!string.IsNullOrEmpty(requirement.Skill)) level = EpicMMOSystem_API.GetAttribute(requirement.Skill);

                return level >= requirement.Level;
            }

            // Global / Player key
            if (!string.IsNullOrEmpty(requirement.GlobalKeyReq))
            {
                // Per-character, never world-wide. Personal keys are the fixed point (ADR-0005):
                // a rival clan gains nothing from your boss kill, so a key rule must ask what this
                // character has done. Upstream widened this to GameKeyType.Global when World
                // Advancement Progression was installed; that mod is cut. Whether #11's personal
                // keys are stored in this vanilla per-player key set or beside it is #11's call —
                // this is the code path it will answer through.
                const GameKeyType scope = GameKeyType.Player;
                if (ZoneSystem.instance && ZoneSystem.instance.CheckKey(requirement.GlobalKeyReq, scope))
                    return true;
                return false;
            }

            if (string.IsNullOrEmpty(requirement.Skill)) return requirement.Level <= 0;

            // ValheimLevelSystem custom texts
            if (ValheimLevelSystemList.Contains(requirement.Skill))
            {
                if (!Player.m_localPlayer.m_knownTexts.TryGetValue("player" + requirement.Skill, out string txt))
                    return true; // if not tracked, allow by default

                if (int.TryParse(txt, out var vlsLevel))
                    return vlsLevel >= requirement.Level;

                return true;
            }

            // Vanilla skills
            var skillPair = Player.m_localPlayer.GetSkills().m_skillData
                .FirstOrDefault(x => x.Key == FromName(requirement.Skill));

            if (skillPair.Value is null)
            {
                // try enum parse fallback (supports direct enum names in YAML)
                if (Enum.TryParse(requirement.Skill, out Skills.SkillType parsed))
                {
                    skillPair = Player.m_localPlayer.GetSkills().m_skillData.FirstOrDefault(x => x.Key == parsed);
                }
                else
                {
                    // unknown skill name -> treat as unmet (safer)
                    return false;
                }
            }

            // If still null, assume not learned yet; treat missing as 0 (fail if Level>0)
            if (skillPair.Value is null) return requirement.Level <= 0;

            return GetEffectiveVanillaSkillLevel(skillPair.Key, skillPair.Value) >= requirement.Level;
        }

        private static float GetEffectiveVanillaSkillLevel(Skills.SkillType skillType, Skills.Skill skill)
        {
            if (Player.m_localPlayer == null) return skill?.m_level ?? 0f;

            try
            {
                return Player.m_localPlayer.GetSkills().GetSkillLevel(skillType);
            }
            catch
            {
                return skill?.m_level ?? 0f;
            }
        }

        public static Skills.SkillType FromName(string englishName) => (Skills.SkillType)Math.Abs(englishName.GetStableHashCode());

        // -------------- UI TEXT HELPERS (now show GlobalKeyReq too) --------------

        public static string GetTextCraft(SkillRequirement requirement)
        {
            var requirements = requirement.Requirements.Where(x => x.BlockCraft).ToList();
            string cant = ItemRequiresSkillLevel.cantEquipColor.Value;
            string can = ItemRequiresSkillLevel.canEquipColor.Value;

            string str = "";
            foreach (var req in requirements)
            {
                bool ok = IsAble(req);
                string color = ok ? can : cant;

                if (!string.IsNullOrWhiteSpace(req.GlobalKeyReq))
                {
                    var label = string.IsNullOrWhiteSpace(req.ExhibitionName) ? req.GlobalKeyReq : req.ExhibitionName;
                    str += $"\nRequires <color={color}>{label}</color>";
                    continue;
                }

                string labelSkill = string.IsNullOrWhiteSpace(req.ExhibitionName) ? req.Skill : req.ExhibitionName;
                str += string.Format(ItemRequiresSkillLevel.RequiresText.Value, color, labelSkill, req.Level);
            }
            return str;
        }

        public static string GetTextEquip(SkillRequirement requirement)
        {
            var requirements = requirement.Requirements.Where(x => x.BlockEquip).ToList();
            string cant = ItemRequiresSkillLevel.cantEquipColor.Value;
            string can = ItemRequiresSkillLevel.canEquipColor.Value;

            string str = "";
            foreach (var req in requirements)
            {
                bool ok = IsAble(req);
                string color = ok ? can : cant;

                if (!string.IsNullOrWhiteSpace(req.GlobalKeyReq))
                {
                    var label = string.IsNullOrWhiteSpace(req.ExhibitionName) ? req.GlobalKeyReq : req.ExhibitionName;
                    str += $"\nRequires <color={color}>{label}</color>";
                    continue;
                }

                string labelSkill = string.IsNullOrWhiteSpace(req.ExhibitionName) ? req.Skill : req.ExhibitionName;
                str += string.Format(ItemRequiresSkillLevel.RequiresText.Value, color, labelSkill, req.Level);
            }
            return str;
        }
    }
}
