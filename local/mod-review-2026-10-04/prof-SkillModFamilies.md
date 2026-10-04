# Profession skill-mod families — evidence handback

Research date: 2026-10-04. Target: Valheim 1.0.16/network 40, BepInExPack 5.4.2351, Jotunn 2.30.2. Research only; no repository source/configuration changed.

## Executive finding

**ImpactfulSkills is the most cohesive starting point in this slice, but there is no verified, configuration-only stack satisfying the complete brief.** It already joins cooking, farming, gathering, animals, sailing and hauling through ordinary Valheim skill progression and consistent server-admin settings. Its forging can replace BlacksmithingExpanded, avoiding a second smithing system. However, exclusive profession recipes and tradeable quality are mostly absent, its planting layout exposes some client-local gameplay settings, and the available alchemy owners bypass WAP death drain. Fishing's strongest candidate also has client-local bait YAML.

The decisive incompatibility is not simply “custom skill versus vanilla skill.” **Bundled `SkillManager.Skill` and `Jotunn.Managers.SkillManager` behave differently.** Blacks7ar skills, BlacksmithingExpanded, and PotionPlus use a bundled manager which removes custom skill entries during `Skills.OnDeath`, applies its own loss, then restores entries. WAP therefore cannot drain/floor them. Setting their death-loss percentage to match vanilla does not restore WAP ownership.

### Evidence notation / scope

- `I` below means `/tmp/lembitu-research/ProgressionCluster/ImpactfulSkills.cs` (0.21.0).
- `B` means `/tmp/lembitu-research/ProgressionCluster/BlacksmithingExpanded.cs` (1.2.4).
- `H` means `/tmp/lembitu-research/ProgressionCluster/Herbalist.cs` (1.5.0).
- `E` means `/tmp/lembitu-research/ProgressionCluster/ExpertExplorer.cs` (1.7.0).
- New decompiles are under `/tmp/lembitu-prof/SkillModFamilies/`; abbreviated filenames in the sections resolve there.
- Findings attributed to these files are **observed source behavior**, not live-server verification. `[INFERENCE]` identifies predicted runtime effects or suitability. Formula smoke results below are executable translations of the cited expressions, not Unity/Harmony runtime proof.
- Reward kinds: efficiency = production/yield/waste; quality = better **tradeable produced items**, not merely the user's stronger consumption effect; exclusive = profession-level recipe gate, not station-tier content; convenience = operational ease/information/carrying.

## 1. WAP composition: the shared contract

WAP source: `/tmp/lembitu-research/GroupsWorldCluster/WAP-code/VentureValheim.Progression/SkillsManager.cs:9-35` iterates `Skills.m_skillData` in `LowerAllSkills`. `:38-62` owns `Skills.Skill.Raise` accumulation and its ceiling. It does not filter custom skill types. Its actual “floor” is a **drain eligibility threshold**, not a hard clamp: `:139-158` returns percentage/absolute drain if level exceeds floor; `:170-173` clamps only to zero and the maximum. [INFERENCE] A level just above the boss floor can cross below it on one death. This differs from the owner's phrase “down to a floor”; report the difference rather than silently assuming hard-clamp semantics.

Jotunn 2.30.2 manager was independently decompiled: `/tmp/lembitu-prof/SkillModFamilies/JotunnSkillManager.cs:16-59` enumerates its patches (registration, validity, get-skill, console cheats), with **no death interception**. Registration is `:98-107`. Thus enabled ImpactfulSkills/ExpertExplorer custom skills stay in the ordinary dictionary for WAP to process, unlike the bundled manager below.

Bundled death bypass is explicit:

| Mod | Source showing removal, own loss and restoration |
|---|---|
| BlacksmithingExpanded 1.2.4 | `B:3428-3459`; hook installation `B:3324` |
| Herbalist 1.5.0 | `H:21526-21557`; hook installation `H:21422` |
| Fermenting 1.1.8 | `Fermenting-Fermenting.cs:2523-2554`; installation `:2434` |
| BeeKeeper 1.1.0 | `BeeKeeper-BeeKeeper.cs:2578-2610`; installation `:2489` |
| Hunting 1.4.5 | `Hunting-Hunting.cs:3358,3447` (same bundled OnDeath manager) |
| Explorer 1.1.7 | `Explorer-Explorer.cs:3296,3385` (same bundled OnDeath manager) |
| PotionPlus 4.3.8 | `PotionPlus-PotionsPlus.cs:827,916-949`; direct loss/removal `:929-932` |

The blacks7ar default custom death loss is zero; examples `Fermenting-Fermenting.cs:132-137`, `BeeKeeper-BeeKeeper.cs:158-165`, `Explorer-Explorer.cs:221-226`. Even zero loss still removes the entry, so it means immunity rather than “delegate death loss to WAP.” XP gain through RaiseSkill still composes with WAP's Raise patch; death behavior does not. No supported config switch to stop the bundled OnDeath interception was found.

ImpactfulSkills itself freezes only **disabled** custom skills on death: `I:4710-4737`; hidden-skill set is AnimalHandling, Voyager, Hauling and Forging, `I:4742-4764`. Enabled skills remain WAP-owned. Hidden skill XP is suppressed (`I:4691-4698`), a deliberate preservation behavior, not a second active profession XP store.

Formula smoke executed inline:

| Input | WAP alone (5% drain, floor 40) | Bundled manager + WAP |
|---|---:|---:|
| Level 80, own loss 0% | 76 | 80 |
| Level 41, own loss 10% | 38.95 | 36.9 |
| Level 80, own loss 5% | 76 | 76 (accidental equality, not floor compatibility) |

## 2. ImpactfulSkills 0.21.0 — complete domain and switch review

### Scope and ownership

| Domain | Skills / source | Rewards actually supplied | Boundaries / overlap |
|---|---|---|---|
| Woodcutting | Vanilla WoodCutting; `I:516-518` | Efficiency: chop damage, more wood | Gathering owner. Not weapon melee damage: tree/log surface is `I:8126-8304`. |
| Mining | Vanilla Pickaxes; `I:519-543` | Efficiency: resource damage/yield, crit, whole-vein break; convenience: AOE | Gathering owner. Optional drop filtering and fractional-drop behavior. Resource boosts, not a separate miner XP bank. |
| Cooking | Vanilla Cooking; `I:555-556,697-710` | Efficiency: bonus food; convenience: XP streak; personal food-degradation bonus | No chef-created food-quality metadata identified. Degradation uses eater's Cooking (`I:3995-4002`), not cook provenance. Eat-XP rewards consumption rather than profession work. |
| Farming (named “Gathering” in enable keys) | Vanilla Farming; `I:596-624` | Efficiency: pickable luck, planting stamina reduction; convenience: AOE harvest/scythe reach, multiplant/grid, biome freedom, growth timer | No exclusive recipe gate or tradeable superior crop quality identified. Covers wild pickables as well as cultivated crops; don't confuse with mining/woodcutting profession. Overlaps PlantEverything/SeedBed grid/biome/timer features. |
| AnimalHandling | Jotunn skill; registration `I:3672-3678`; config `I:580-595` | Efficiency: faster taming, slaughter/honey yield; convenience: hive biome freedom; quality: extra stars | Extra stars strengthen combat pets too, so strict no-combat setup loses this quality reward. Breeding grants nearby XP. One joined animal/bees skill, unlike separate Hunting/BeeKeeper. |
| Voyager | Jotunn skill `I:7859-7865`; config `I:625-639` | Efficiency/convenience: sailing and rowing speed, closer-to-headwind sailing, onboard reveal radius | XP while sailing, not generic walking exploration. Overlaps Njord ship handling and all radius mods while aboard. Boat damage reduction/impact immunity also change survivability. |
| Hauling | Jotunn skill `I:6077-6083`; config `I:557-569` | Convenience: carry capacity and cart mass reduction; progression through moving loaded goods | Duplicates SkilledCarryWeight carry/cart perks; overlaps backpack weight reduction mechanically. |
| Crafting | Vanilla Crafting; `I:652-668` | Efficiency: bonus output/material returns; convenience: durability preservation | Broad crafting, not just metalwork. Duplicates B extra-item generation, effective durability, and economic material saving, though material return and smelter fuel-saving target different operations. |
| Forging | Jotunn skill `I:5397-5412`; config `I:669-696` | Station-level bonuses, refinement chances, masterwork item combat stats, lightweight equipment | Closest standalone smith skill inside same owner. Masterwork adds damage/armor/block; lightweight can add combat stats and reduce equip movement penalty. Needs separate neutralization below. |
| Fishing | Vanilla Fishing-related recipe integration; `I:726-729` | Higher-quality fish recipe yields; lowest-quality-first ingredient use; equipment quality inheritance | Not a fishing XP/perk owner: these use ingredient quality, not profession-level exclusivity. Quality inheritance affects Ashlands equipment too unless explicitly disabled. |
| Knowledge Sharing / SkillRates | `I:711-719`; custom skill discovery `I:1626-1676` | Generic XP rate/catch-up for all skills | Combat progression leakage even if combat-perk switches off; Knowledge Sharing is already off in pinned pack. Other skills' rate entries must remain baseline. |
| WeaponSkills / Blocking / BloodMagic / Sneak / Run / Jump / Swimming | See below | Combat/body perks | Exclude from profession setup. |

### All Enable* switches, grouped

These are the actual bound switches, not inferred from a README. Source `I:510-730`.

- Diagnostics: `EnableDebugMode` (client only).
- Woodcutting: `EnableWoodcutting`.
- Mining: `EnableMining`, `EnableMiningCritHit`, `EnableMiningAOE`, `EnableMiningRockBreaker`; related booleans not beginning Enable are `SkillLevelBonusEnabledForMiningDropChance`, `ChanceForAOEOnHitScalesWithSkill`, Leviathan protection, drop exclusions/fraction handling.
- Run: `EnableRun`.
- Jump: `EnableJump`, `EnableFallDamageReduction`, `EnableFallDamageHeightBonus`.
- Cooking: `EnableCooking` (bound twice to same key), `EnableCookingDegradeReduction`, `EnableCookingBonusItems`, `EnableCookingStreak`, `EnableCookingEatXP`.
- Hauling: `EnableHauling`, `EnableCarryWeightBonus`, `EnableHaulingCartMassReduction`, `EnableHaulingCarryWeightXP`.
- BloodMagic: `EnableBloodMagic`.
- Sneak: `EnableStealth`, `EnableSneakBonusDamage`.
- Animals: `EnableAnimalWhisper`, `EnableBeeBonuses`, `EnableBeeBiomeUnrestricted`, `EnableAnimalBonusStar`.
- Farming: `EnableGathering`, `EnableGatheringAOE`, `EnableFarmingBiomeUnrestricted`, `EnableFarmingGrowthTimeDisplay` (client), `EnableFarmingMultiPlant`, `EnableSnappingToOtherPlants` (client).
- Voyager: `EnableVoyager`, `EnableFriendsRowSpeedBonus`, `EnableBoatDamageReduction`; non-Enable `VoyagerImpactResistance` is independently relevant.
- Weapons: `EnableWeaponSkill` (singular actual key).
- Blocking: `EnableBlocking`, `EnableParryStaminaGain`.
- Crafting: `EnableCrafting`, `EnableDurabilityLossPrevention`, `EnableDurabilitySaves`, `EnableBonusItemCrafting`, `EnableCraftBonusAsFraction`, `EnableMaterialReturns`.
- Forging: `EnableForging`, `EnableStationBonusTier1`, `EnableStationBonusTier2`, `EnableRefinementBonus`, `EnableMasterwork`, `EnableLightweight`.
- Global XP: `EnableKnowledgeSharing`.
- Swim: `EnableSwimming`, `EnableSwimStaminaCostReduction`.
- Ingredient scaling: `EnableQualityIngredientScaling`; non-Enable `ScaleCraftedEquipmentQuality`, `ScaleNonStackingCraftOutputs`, `RestrictQualityScalingToFish` must also be considered.

### Strict combat-off switches

1. `EnableWeaponSkill=false`: disables extra weapon stamina efficiency and parry XP, but **not equip/unequip speed**. `EquipSpeedHelper.Apply` ignores that switch (`I:8016-8030`) and is unconditionally injected into QueueEquipAction/QueueUnequipAction (`I:8034-8089`). Set **`WeaponSkillEquipSpeedFactor=0`** too. Default factor 2 yields one-third equip duration at skill 100 even when EnableWeaponSkill is false (formula smoke).
2. `EnableBlocking=false`, `EnableParryStaminaGain=false`: block power multiplier and stamina refunds; runtime guards `I:3914-3937`.
3. `EnableBloodMagic=false`: shield-damage XP, including friendly/tamed protected characters (`I:3945-3959`). It changes combat leveling rather than directly adding damage.
4. `EnableStealth=false`, `EnableSneakBonusDamage=false`: sneak speed/noise and backstab multiplier (`I:573-579`).
5. `EnableRun=false`: run-speed scaling (`I:544-545`).
6. `EnableJump=false`, `EnableFallDamageReduction=false`, `EnableFallDamageHeightBonus=false`: jump height and survivability (`I:546-554`).
7. `EnableSwimming=false`, `EnableSwimStaminaCostReduction=false`: swim speed/stamina (`I:720-725`). Travel-flavoured, but body/survival rather than a profession output; omit under strict body-skill exclusion.
8. `EnableKnowledgeSharing=false`, combat skill gain-rate multipliers baseline: avoid global combat XP acceleration (`I:711-719`).
9. `EnableMasterwork=false`; `MasterworkStatBonus=0` defensively. For a strict retained noncombat lightweight perk: `EnableLightweight=true`, **`LightweightMovementPenaltyReduction=0`, `LightweightNoPenaltyStatBonus=0`**, leaving item weight reduction only (`I:683-690,5331-5345`). Simpler exclusion is `EnableLightweight=false`, with less tradeable quality remaining.
10. `EnableRefinementBonus=false`, `EnableStationBonusTier1=false`, `EnableStationBonusTier2=false` for strict “no extra combat equipment power.” These do not directly add stats but enable equipment tiers/refinement earlier or more efficiently (`I:670-682,5377-5385,5707-5716`). WAP personal recipe locks still need their own composition verification; station tiers are not profession-exclusive recipe gates.
11. `EnableAnimalBonusStar=false`: extra stars change combat-capable tame creatures, not just farm meat yield (`I:593-595`).
12. `EnableBoatDamageReduction=false`, `VoyagerImpactResistance=false`: retain travel handling without boat combat survivability (`I:635-639`).
13. `EnableCookingDegradeReduction=false` if “every combat part off” includes food-stat sustain. This is eater-side longer-lasting health/stamina/eitr power, not a cook-created premium food (`I:3995-4002`). `EnableCookingEatXP=false` for work-based profession leveling.
14. `ScaleCraftedEquipmentQuality=false`: ingredient quality otherwise carries into combat equipment regardless of fish-only output restriction (`I:668,726-728,4589-4606`).

### Server authority / engineering

Server entries set Jotunn `ConfigurationManagerAttributes.IsAdminOnly=true` (`I:900-942`), while client bindings are explicitly not admin-only (`I:824-882`). XP grants use Player.RaiseSkill (`I:788-820`). RPC server receives claimed XP/location/range and forwards it without source-side validation (`I:796-811`); [INFERENCE] ordinary private-pack use is the assumption, not adversarial security.

**Literal pack-rule caveat:** Farming placement buffer, snap distance/style, snapping to other plants, orientation centering and random rotation are client bindings (`I:613-624`); `EnableFarmingGrowthTimeDisplay` is also client (`I:605`). These are not entirely cosmetic: they affect planting layout/convenience. The AOE hotkey is a user action, not a server perk setting (`I:515`). Merely shipping identical initial config does not lock those entries. Treat strict rejection vs acceptable input/layout preferences as an owner decision; do not call them all locked.

Quality is mixed but visibly more deliberate than the single-skill family: typed skill-rate discovery, cache/array reuse for quality ingredient counting (`I:1131-1160`), null guards, bounded server settings, compatibility hooks and diagnostic matching. However **many transpilers remain installed even with features off**, including combat targets, DoCrafting, planting, movement and ship simulation (`I:3977-3992,7933-8089`); configuration-off does not eliminate patch collision surface. Shared static crafting contexts need combination smoke with AzuCraftyBoxes/EpicLoot/WAP. More unified feature design, not intrinsically low-risk binaries.

## 3. BlacksmithingExpanded 1.2.4

**Rewards:** efficiency via extra eligible equipment and smelting/kiln infusion speed/resource economy; quality via persistent durability and weapon/armor/shield/elemental stats; convenience via station levels and durability. No profession-level exclusive recipe gate identified. Skill is bundled SkillManager Blacksmithing (`B:4533-4536`), RaiseSkill XP (`B:4974-4975`), but WAP death bypass above makes it fail the mandatory progression contract.

Combat knobs exist: `Stats/Enable damage bonus`, `Stats/Enable armor bonus`, `Elemental/Enable elemental bonus`, `Shields/Enable shield bonus`; also `Stats/Boost elemental weapons` and `Elemental/Add elemental at milestone` (`B:4748-4778`). Turn all combat knobs off, not only damage/armor. ServerSync-backed AddConfig is `B:4510-4517`. **Existing items are a cutover issue:** ApplyStoredStats reapplies serialized physical/elemental damage and shield fields without those enable checks (`B:3758-3805`); only durability/armor have checks there. [INFERENCE] switching bonuses off is not proven to neutralize already-crafted legacy gear.

Code is not a reason to keep it over cohesive forging. Positives: item null checks, bounded eligibility caches, custom serialized item data and per-item SharedData clone (`B:3618-3686,3696-3805`). Negatives: DoCrafting postfix does not verify actual craft success; it finds an inventory item by name/quality/durability and applies bonuses/XP (`B:3814-3889`). [INFERENCE] a failed/blocked craft can select an existing eligible item, and upgrading mismatches template quality selection. It sorts/allocates a List on each craft. Extra clone AddItem ignores result (`B:3852-3859`), so full-inventory reward handling is weak. Finalizer removes from a static activeItems dictionary (`B:3753-3756`), a lifetime/thread-risk pattern. No live duplication repro performed.

**Overlap:** I Crafting bonus items duplicates B extra item; I durability saves and B max durability stack to produce long-lived equipment; I material returns and B resource-saving improve the same economy but not necessarily same Harmony method. I Forging/B both patch `CraftingStation.GetLevel`, `InventoryGui.DoCrafting`, item stats/tooltips. Disable I Crafting **and** Forging if B is retained as sole smith owner; current “Forging off” alone is insufficient. Under the mandatory WAP contract, replacement with I is preferable to attempting a config-only B workaround.

## 4. Blacks7ar noncombat family

### Herbalist 1.5.0

This is **alchemy content and consumption skill**, not crop yield/farming. New herbs, mortar/pestle, tonic/elixir recipes; healing dandelion/thistle; tiered tonics (levels 1/30/60 defaults) and returned bottles. `H:223-295`; gates `H:1566-1598`. Exclusive gate adds rejection then returns true otherwise, so [INFERENCE] it can logically coexist with WAP rejection, but successful Harmony combinations are not proven. Prefix dereferences a failed TryGetValue's `value.m_level` and selected recipe fields without guarding (`H:1578-1593`). Postfix XP relies on static `_RequirementsMet`, not successful craft stats (`H:1553-1563`): [INFERENCE] false XP when another mod/WAP rejects or original fails is possible.

**Quality distinction:** status duration/heal/eitr/stamina scaling reads the **consumer's** Herbalist skill (`H:390-391,732-734,975-978,1390-1392`); not premium producer-stamped trade goods. Efficiency is modest bottle reuse, exclusive tiers present, convenience via tonic/utility content; all four desired rewards are not supplied as a coherent production system. XP from crafting and picking herbs is RaiseSkill, but bundled OnDeath fails WAP (`H:21526-21557`). Server lock/config sync exists (`H:226-227`), including per-recipe booleans.

Combat leakage is major: Berserker default overall damage multiplier 5 (`H:2722-2734`, damage application `H:425-428`); Defender and Ghost effects, learning/global skill gain, movement/jump/slow-fall elixirs, stamina/eitr/heal tonics. For strict setup disable each combat recipe via its `Recipe=false` setting; Berserker, Defender, Ghost and Learning should definitely not be enabled. Utility HeavyLifter overlaps hauling/backpacks, Runner/Jump overlap body/travel, so exclude those if another owner supplies equivalent perks. Recipe switches prevent new crafting, not proof that existing potion items lose effects. Even after trimming content, death bypass and consumer-side scaling remain decisive reasons against stock Herbalist as the selected profession owner.

### Hunting 1.4.5

Efficiency: wild animal drop yield; convenience: level-gated prey pins and optional enemy HP display. No taming/breeding/bees, exclusive recipes or tradeable quality. Server lock/settings `Hunting-Hunting.cs:187-217`; tiers `:218-245`; skill `:207-209`.

Drop logic explicitly excludes tamed animals (`:370-377`), so it does not duplicate I's tamed loot exactly; it does create a ninth, hunting-oriented skill outside the eight-profession taxonomy. XP/weapon logic patches Character.RPC_Damage and Projectile.OnHit (`:408-440,984-1027`) and accesses weapon skill state; enemy HP display is a combat-information perk (`:503-506`), switch it off if retained. Shared `_isHunting` context used by drop generation (`:377,413`) is a fragile cross-event association [INFERENCE], especially with multiple creatures/attackers. Sprite discovery repeats prefab/drop scans and `Resources.FindObjectsOfTypeAll<Sprite>().SingleOrDefault` (`:820-835`). Bundled death bypass rules it out. No direct bonus weapon damage demonstrated; do not mislabel it a weapon-damage mod merely because XP uses damage hooks.

### BeeKeeper 1.1.0

Efficiency: honey production speed and harvest output; convenience: capacity and timer; queen bee extra-drop chance. No taming/breeding, profession recipes or premium honey. Skill/lock/settings `BeeKeeper-BeeKeeper.cs:133-165`; production calculation `:347-368`; XP from harvest and timed checking `:252-290`.

Poor authority/performance choices: production time reads local player skill, mutates hive field (`:347-355`), so owner/server without local player does not have stable worker attribution [INFERENCE]. Every hive subscribes to config changes without removal (`:295-309`); `new System.Random()` per interaction (`:258`); hover/interaction prefixes duplicate vanilla operations (`:252-293`). It overlaps I bees on GetHoneyLevel/GetHoverText/RPC_Extract/Awake and yield. Separate bee XP undermines “Animal handling” cohesion. Bundled death bypass is explicit `:2578-2610`.

### Fermenting 1.1.8

Efficiency: faster fermentation/more output; convenience: timer. No premium potion quality or level-gated recipes. Skill/lock/settings `Fermenting-Fermenting.cs:104-143`. **Level 100 makes duration zero** (`:196-205`; expression smoke returned 0). GetStatus field-load transpiler replaces all matching loads (`:177-193`). Conversion postfix reads `Player.m_localPlayer.GetSkills()` before testing localPlayer and modifies shared conversion output (`:315-325`); [INFERENCE] dedicated-server null crash/last-viewer effects are plausible. Interact replacement reconstructs original behavior and has two prefixes; one dereferences localPlayer unguarded (`:211-252`). Bundled death bypass `:2523-2554`.

Stock Fermenting patches vanilla `Fermenter`; **BetterStations uses a different BetterFermenter class**, so same author does not mean same subsystem support. This is an explicit coverage split, not an assumed duplicate patch collision.

### Explorer 1.1.7

Convenience only: radius and resource/dungeon/cave pins at biome-specific skill thresholds. XP from revealing map, runestones, new locations and biomes; README `Explorer/README.md:15-27`, code settings `Explorer-Explorer.cs:195-263`. Skill/lock and XP factor consistent with siblings; death bypass likewise inconsistent with WAP (`:3296,3385`).

Custom discovery dedupe is loose: random labels and `m_customData.ContainsValue` using position.ToString or rune text (`:829-853,1249-1250`) rather than typed world-keyed discovery IDs. [INFERENCE] string formatting/cross-world reuse and accumulating broad ContainsValue scans are less robust than ExpertExplorer's versioned packages. It overlaps ExpertExplorer and Cartography radius and discovery XP, and I Voyager radius on boats. No sailing/hauling, recipes or production quality, so do not select it as full Exploration/travel owner.

### Body/combat siblings to avoid

These were fetched/decompiled to confirm scope, not expanded into profession candidates:

| Mod/current version | Scope / reason to omit | Primary evidence |
|---|---|---|
| Endurance 1.1.3 | Stamina pool/regen; combat/body leveling | https://thunderstore.io/api/experimental/package/blacks7ar/Endurance/ ; `Endurance-Endurance.cs` |
| Agility 1.1.9 | Attack/walk/run speed, jump force, fall damage toggle; combat/body | `Agility-Agility.cs:148-168,205-244,311-313`; https://thunderstore.io/api/experimental/package/blacks7ar/Agility/ |
| Wisdom 1.0.6 | Eitr pool/regen; direct magic combat overlap | https://thunderstore.io/api/experimental/package/blacks7ar/Wisdom/ ; `Wisdom-Wisdom.cs` |
| SNEAKer 1.1.8 | Sneak speed; body/sneak overlap | https://thunderstore.io/api/experimental/package/blacks7ar/SNEAKer/ ; `SNEAKer-SNEAKer.cs` |
| VikingsDoSwim 1.4.2 | Swim speed, stamina regen/consumption, diving | https://thunderstore.io/api/experimental/package/blacks7ar/VikingsDoSwim/ ; `VikingsDoSwim-VikingsDoSwim.cs` |

The package descriptions are author claims; no claim of complete Oathbound patch-order compatibility is made. Endurance/Agility/Wisdom also carry bundled OnDeath interception (`Endurance-Endurance.cs:2298,2387`, `Agility-Agility.cs:2549,2638`, `Wisdom-Wisdom.cs:2295,2384`).

## 5. Alternative travel / fishing owners

### ExpertExplorer 1.7.0

Jotunn Exploration skill, awarded for newly discovered locations/biomes (`E:523-528,614,1173-1184`); convenience via wider reveal, location names/pinning. No production efficiency, quality/exclusive recipes, sailing/hauling. Enabled skill should remain subject to WAP because Jotunn doesn't remove it on death (source reasoning, not a death smoke).

Server-admin main parameters (`E:499-503`), but radius/sailing preference logic must be harmonized with any ship mod (`E:1100-1114`). It has existing sailing-mod precedence, rather than a blanket “stack all multipliers” design. Versioned discovery save migration `E:224-307`, `m_customData` save/read `E:309-327`, Player Load/Save hooks `E:1157-1170`; stronger save design than Explorer. Risks: raw package count reads without bounds/recovery (`E:235-246`), null localPlayer on Explore (`E:1108`), UI duplicate failure logs but subsequent UpdateLocation writes m_LocationNameSmall unconditionally (`E:1122-1126,1147-1151`). Do not add it for exploration radius if I Voyager is supposed to be sole owner; removing it loses on-foot exploration XP/radius functionality, a real gap.

### CartographySkill 3.2.0

Custom **native Skills.SkillDef**, numeric skill id 1337, no bundled SkillManager (`CartographySkill-Advize_CartographySkill.cs:141-163,259-265`); tile reveal XP calls Player.RaiseSkill (`:82-105`). ServerSync lock/defaults `:383-421`. WAP can see the skill's normal dictionary entry; no death bypass in plugin.

Convenience only (map radius), no sailing, hauling, efficiency, quality or recipes. Compact prefix/postfix style rather than IL rewrites. **Lifecycle defect prediction:** radius resets to base on Minimap.Awake (`:72-79`), recalculated only by skill-level-up/cheat raise/cheat reset (`:110-119,165-192,269-277`); no Load/OnDeath/OnSpawned refresh call was located. [INFERENCE] radius can stay stale after death and start at base after reload until another level-up. Static tileCount persists across player/session transitions (`:89-105`), small progress contamination risk. TileDiscoveryRequirement is unvalidated and division occurs (`:98-105,407`), so zero config can break. More restrained code but not visibly better lifecycle polish than ExpertExplorer.

### SkilledCarryWeight 1.5.0

**Not a hauling skill:** no independent XP or custom skill registration. Adds capacity proportional to configured existing skills and makes carts lighter (`SkilledCarryWeight-SkilledCarryWeight.cs:142-175,325-355`). This means WAP affects contributing vanilla skill levels correctly but no standalone transport-work specialization exists. Defaults include Run/Jump/Swim/Sneak/Dodge/Ride/Farming/WoodCutting/Pickaxes (`:161-175`); combat/body progress yields logistics bonuses, so restrict to resource skills if selected. Convenience only; no quality, efficiency production or recipes.

Jotunn admin config binding (`:583-586`) and only hotkey/log verbosity unsynced (`:129,139`); narrow postfix approach for carry (`:325-339`), guards and clamped cart mass (`:349-355`) are relatively boring/maintainable. One collider allocation only on quick-cart key (`:178-203`) instead of every frame. It iterates all skill defs on each GetMaxCarryWeight (`:328-333`), no early max-bonus cache. Direct duplicate of I Hauling carry/cart and backpack advantages. Prefer I Hauling's work-based XP for cohesive professions.

### Trolling_Fishing 1.1.3

Uses vanilla Fishing, not independent XP. Efficiency: skill-scaled bite chance and extra drops. Convenience: rod-bound fish/bait bag, skill tiers, weight reduction, multiline casting. Settings/lock and explicit XP/stamina ratios `Trolling_Fishing-TrollingFishing.cs:6647-6668`; existing Fishing factor reads `:1719,2477,2489`. No premium fish-quality roll or exclusive fishing recipe gate demonstrated; vanilla fish quality plus I ingredient-quality recipes are a separate axis.

Code has substantial intentional integration: rod-bound bag overflow retained on shrink (`:6658`), EpicLoot/AzuCraftyBoxes hooks (`:6661-6670`), numerous inventory/save/requirement proxy patches (`:3220-3258,3343-3414,3585-3610`). [INFERENCE] that broad proxy surface is risky with remote marketplace item serialization and backpacks; explicit market-trade serialization smoke remains required. Per-frame UI patching also exists (`:3625-3739`). Set **Fishing Rod Bag AzuCraftyBoxes Aggressive Refresh=Off** to use public API only (`:6662`) if retained; avoids reflection into private cache.

**Authority gap is observed:** bait mapping loads `TrollingFishing.yml` from each client's local config (`:4345-4347,4366-4369,4441-4452`), and each client watches/reapplies it (`:6703-6711,6748-6768`). No application-side CustomSyncedValue instance for that YAML was located (only generic embedded ServerSync implementation). [INFERENCE] client-local bait rules can change gameplay despite synced main CFG; identical pack defaults do not lock it. Do not certify this mod under the strict settings rule until runtime/source clarification. No combat-stat additions identified in examined fishing paths; attack hooks are fishing/ammo plumbing, not weapon damage perks.

## 6. PotionPlus 4.3.8 — alchemy content route

SkillManager Alchemy registration `PotionPlus-PotionsPlus.cs:6268-6282`; XP and bonus crafted items via special cauldron/Incinerator and alchemy-table crafting (`:6316-6426,6430-6458`); ServerSync lock `:6946-6949`. Efficiency reward is extra output. No skill-gated exclusive recipe or producer-quality metadata demonstrated. It is a much larger **combat-content system**, not a pure noncombat alchemy layer: elemental/fortification/second-wind flasks; healing/stamina and stealth potions; group healing and elemental group buffs; Hellbroth elemental damage; wizard/warlock hats; dragon staff and smoke-screen projectile blocking; weapon oil; Philosopher Stone cheat-death (`:6287-6307,6970-7035`).

Generated ItemManager config can disable crafted items via **Crafting Station=Disabled** (`:4169,4225,4968`); combat numeric fields can also be neutralized for oil, damage and resistances (`:6996-6998,7022-7029`). This is not proof that every pre-existing item, special Incinerator output or equip status disappears when normal crafting is disabled. Full asset-bundle effects and special cauldron conversion path need catalog-level removal verification to claim combat-free.

Engineering strengths: crafting success check compares profile Crafts before awarding (`:6434-6444`), unlike B/H; exception-safe group effect reentry flag (`:7120-7135`). Risks: Incinerator coroutine transpiler finds compiler-generated MoveNext by name, injects private `<>4__this` and `uid` fields (`:6364-6395`), global current user UID can interleave, dictionaries have no evident cleanup, RPC handlers dereference localPlayer without guard (`:6322-6332`). Death bypass `:916-949` means **not WAP-compatible in stock form**, even if combat recipes are curated. Do not select it as current alchemy owner solely on content breadth.

## 7. BetterStations 1.0.9 interplay

No profession XP/skill at all. ServerSync lock `/tmp/lembitu-prof/SkillModFamilies/BetterStations.cs:1496-1500`; new pieces/industrial convenience, not the specialist reward engine.

**It bypasses sibling vanilla station patches by using new classes:** BetterFermenter derives directly from MonoBehaviour (`BetterStations.cs:94`); BetterSmelter likewise (`:637`), instead of vanilla Fermenter/Smelter subclasses. Fermenting's Harmony targets are vanilla Fermenter (`Fermenting-Fermenting.cs:177,211,256,316`); B smelting targets vanilla Smelter (`B:4083`). [INFERENCE] these profession rewards don't run on BetterStations replacements, creating specialist-unaware automation. BetterFermenter has its own hardcoded vanilla conversion list (`BetterStations.cs:174-299`), so it won't automatically discover arbitrary mod potion/mead conversions. Null-prefab GetComponent chains here are unguarded, a world/version compatibility risk. OnDestroy dropping/inventory buffering creates separate item lifecycle (`:302-333`), needing real economic smoke before using trade-relevant production.

Thus same author family is **not** enough for cohesion. Remove BetterStations from a skill-owned fermentation/smith-production path or verify explicit bridges; not a promised bridge in current binaries.

## 8. Maintenance / primary package evidence

Live Thunderstore experimental package metadata retrieved on 2026-10-04; cached JSON copies in `/tmp/lembitu-prof/SkillModFamilies/<Mod>.json`. API URL per row is primary author distribution metadata. Dates are package **updated** timestamps, not proof of tests or code quality.

| Package/version inspected | Last package update | API |
|---|---|---|
| MidnightMods/ImpactfulSkills 0.21.0 | 2026-10-01 | https://thunderstore.io/api/experimental/package/MidnightMods/ImpactfulSkills/ |
| OdinPlus/BlacksmithingExpanded 1.2.4 | 2026-09-29 | https://thunderstore.io/api/experimental/package/OdinPlus/BlacksmithingExpanded/ |
| blacks7ar/Herbalist 1.5.0 | 2026-09-14 | https://thunderstore.io/api/experimental/package/blacks7ar/Herbalist/ |
| blacks7ar/Hunting 1.4.5 | 2026-09-14 | https://thunderstore.io/api/experimental/package/blacks7ar/Hunting/ |
| blacks7ar/BeeKeeper 1.1.0 | 2026-09-14 | https://thunderstore.io/api/experimental/package/blacks7ar/BeeKeeper/ |
| blacks7ar/Fermenting 1.1.8 | 2026-09-14 | https://thunderstore.io/api/experimental/package/blacks7ar/Fermenting/ |
| blacks7ar/Explorer 1.1.7 | 2026-09-14 | https://thunderstore.io/api/experimental/package/blacks7ar/Explorer/ |
| MilkMediaProductions/ExpertExplorer 1.7.0 | 2026-09-10 | https://thunderstore.io/api/experimental/package/MilkMediaProductions/ExpertExplorer/ |
| Advize/CartographySkill 3.2.0 | 2026-09-11 | https://thunderstore.io/api/experimental/package/Advize/CartographySkill/ |
| Searica/SkilledCarryWeight 1.5.0 | 2026-09-15 | https://thunderstore.io/api/experimental/package/Searica/SkilledCarryWeight/ |
| sighsorry/Trolling_Fishing 1.1.3 | 2026-09-14 | https://thunderstore.io/api/experimental/package/sighsorry/Trolling_Fishing/ |
| OdinPlus/PotionPlus 4.3.8 | 2026-09-29 | https://thunderstore.io/api/experimental/package/OdinPlus/PotionPlus/ |
| blacks7ar/BetterStations 1.0.9 | 2026-09-20 | https://thunderstore.io/api/experimental/package/blacks7ar/BetterStations/ |

Current metadata matched all pinned versions. ImpactfulSkills declares BepInEx 5.4.2350/Jotunn 2.30.1; ExpertExplorer declares BepInEx 5.4.2333/Jotunn 2.30.0; Cartography/body/blacks7ar/sighsorry mostly BepInEx 5.4.2350; SkilledCarryWeight Jotunn 2.30.0. Metadata declaring older dependency minimums is not a current-runtime failure by itself. B/PotionPlus latest metadata have empty dependency arrays, despite plugin needing embedded helpers/Valheim runtime. Blacks7ar siblings have coordinated mid-September updates and consistent ServerSync/SkillManager conventions, but those conventions repeat the same WAP incompatibility and station authority problems. Download/rating counts were not used.

Binary scoped screen: first run over 13 newly downloaded candidate assemblies reported **clean: no stale game-member reference found in 13 library(ies)**. Expanded screen including pinned cache packages, BetterStations and Jotunn completed with **clean: no stale game-member reference found in 19 library(ies)** (74.11 seconds). This does not validate Harmony compiler-pattern matches, asset effects, or multiplayer station authority.

## 9. Proposed cohesive ownership map for this slice

This table names exactly one proposed mod owner per profession. **It is a conditional direction, not a compliant deployable recommendation**: failed conditions are explicit. An all-eight fully accepted stack cannot be truthfully returned from these stock packages. No source edits are proposed as completed work.

| Profession | Exactly one proposed owner | Rewards after strict trimming | Required switches / exclusions | Remaining gap / blocker |
|---|---|---|---|---|
| Smithing | ImpactfulSkills | Efficiency (Crafting returns/bonus output), convenience (durability); conditional tradeable lightweight quality | Replace B; EnableForging on; masterwork/refinement/station tiers off; lightweight only with movement/stat bonuses zero; equipment quality scaling off | Crafting and Forging are two skill domains under one mod, not one single smith XP curve. No profession recipe gates; narrow noncombat quality. |
| Cooking | ImpactfulSkills | Efficiency (bonus food); convenience (streak workflow) | DegradeReduction off under strict combat reading; EatXP off; no extra cooking-owner mods | No premium produced food and no exclusive recipes; cooking content baseline supplies recipes but not skill exclusivity. |
| Farming | ImpactfulSkills | Efficiency (yield/stamina), convenience (AOE/grid/timers) | No duplicate grids/biome freedoms from PlantEverything/SeedBed; choose one planting surface | Client-local planting settings fail literal lock requirement unless accepted as input/layout preferences; no crop quality/recipe gates. |
| Alchemy | Herbalist — **blocked stock candidate** | Exclusive tonic tiers, bottle reuse convenience; consumer-side effects are not tradable quality | Combat/learning/body recipe switches off; no PotionPlus/Fermenting second skill; BetterStations fermentation replacement excluded | Bundled death bypass cannot be fixed by config. No producer-quality system. Choosing Herbalist here records the closest scoped content match, not acceptance. |
| Gathering | ImpactfulSkills | Efficiency (wood/ore yield/damage), convenience (AOE/whole veins) | Woodcutting/Mining on; do not install separate miner/woodcutter owners | No superior materials/skill-exclusive recipes. Resource damage must remain resource-scoped. |
| Fishing | Trolling_Fishing — **authority-conditional** | Efficiency (bite/extra drops), convenience (bag/multiline) | Server lock on, private-cache aggressive refresh off; any I fish-to-food scaling must be classified ingredient/content integration, not second skill owner | Local bait YAML not server locked; no premium fish quality or exclusive recipes proved; market rod-bag serialization untested. |
| Animal handling | ImpactfulSkills | Efficiency (tame/slaughter/honey), convenience (hive freedom) | AnimalWhisper/Bee on; AnimalBonusStar off; no BeeKeeper/Hunting as separate animal owner | Strict no-combat trimming removes star-quality reward; no exclusive animal recipes. |
| Exploration and travel | ImpactfulSkills | Efficiency/convenience (Voyager sailing + Hauling work-based capacity/cart) | No ExpertExplorer/Explorer/Cartography radius owner, no SkilledCarryWeight; boat damage/impact immunity off; reconcile/remove Njord duplicated handling | Walking discovery/radius XP absent; two skills in one mod, no tradable quality or exclusive recipes. |

The closest *already-valid subset* is I's enabled native/Jotunn production/logistics skills with combat/body switches neutralized. The cohesive all-eight aspiration needs an external answer for alchemy/WAP and profession recipe/quality coverage; do not disguise those missing dimensions with several unrelated skill mods. If the alternative framework slice supplies one unified profession owner covering quality/gates and WAP, its cohesion advantage is material.

### Cross-stack nonduplication matrix

- **I Crafting + B:** same economic bonuses and DoCrafting/item surfaces; remove B or disable both I Crafting and Forging, not Forging alone.
- **I Animal + BeeKeeper:** honey output/hover/extraction/XP share targets; pick I for one animal skill.
- **I Animal + Hunting:** tamed vs wild drops are distinct, but ninth Hunting skill and combat HUD defeat eight-owner model; not a needed animal feature.
- **I Cooking/Crafting + Herbalist/PotionPlus:** DoCrafting prefix/postfix/transpiler overlap and potentially bonus crafted potions; craft skill/station classification must be checked, no promise of benign additive behavior.
- **I Voyager + ExpertExplorer/Explorer/Cartography:** radius overlap; Explorer/Cartography are not sailing mods. ExpertExplorer explicit sailing preference is evidence of partial coexistence, not one-owner design.
- **I Voyager + Njord:** duplicated ship handling; exact Njord interplay outside this slice's new binary examination.
- **I Hauling + SkilledCarryWeight/AdventureBackpacks:** carry/cart/weight benefits stack; backpack content can remain only if convenience overlap intentionally budgeted, not called a distinct profession perk.
- **Fermenting/B smith production + BetterStations:** not identical Harmony targets; separate replacement types bypass vanilla profession perks, which is worse for economic consistency than a simple duplicate multiplier.
- **Fish bags + AzuCraftyBoxes/EpicLoot/Market:** explicit first two integrations exist, market transfer fidelity still unknown.

## 10. Specific coverage gaps

1. No actual Valheim process/client-server session was launched for these packages. Binary screens and formula smoke are the exercised verification; Harmony order, timed production ownership, bag transfer and save-reload predictions remain runtime questions.
2. No configuration-only solution to bundled SkillManager death bypass was found; matching loss percentages is explicitly insufficient. Need external owner that does not remove skills during OnDeath, or a changed implementation (dispatcher decision).
3. WAP source itself is threshold floor semantics, not guaranteed clamp. Decide whether the owner's intended floor needs a separate investigation/change; this handback does not edit WAP.
4. Every profession receiving all four reward kinds is **not met** by this skill-mod route. Superior outputs and recipe gates are scarce; player-consumption scaling, station tiers and animal stars must not be miscounted as benign tradable quality/exclusive recipes.
5. Trolling_Fishing YAML authority and ImpactfulSkills client planting-layout settings prevent an unconditional strict pack-rule pass. No source claim that same initial config equals enforced settings.
6. PotionPlus asset-defined effects and special cauldron recipe-disable behavior were not exhaustively decoded. Its combat breadth and death bypass already disqualify stock selection; no fabricated “all combat content can be cleanly removed” claim.
7. Author support SLA/testing discipline and six-month maintenance likelihood remain unknown. Current release dates and decompiled conventions are observed; popularity was not used.
8. No repository publication, deployment, config edits, or push performed. Requested artifact: `local://prof-SkillModFamilies.md`.
