# Recipe gates and tradable quality — RecipeGatesAndQuality

Research date: 2026-10-04. Research only; repository/configuration unchanged. Versions examined: WackyItemRequiresSkillLevel 1.4.7, Item_Requirement 1.1.3, DataForge 1.3.5; reused pinned decompiles for WAP 1.0.0, ImpactfulSkills 0.21.0, BlacksmithingExpanded 1.2.4, Herbalist 1.5.0, EpicLoot 0.14.13.

## Executive finding

**Recommend Radamanto/Item_Requirement 1.1.3 as the common crafting gate, not WackyItemRequiresSkillLevel.** It checks the actual `DoCrafting` action in addition to disabling the button; Wacky only disables the button. Both accept vanilla skills and stable-hash SkillManager skills. Radamanto compares earned `m_level`; Wacky uses effective `GetSkillLevel`, deliberately including status-effect skill bonuses. Earned profession mastery is a better basis for permanent recipe access.

**Neither is a server-authoritative anti-cheat gate.** They synchronize and lock server policy, but evaluate the local player's skill on the client. This satisfies the stated same-Pack / server-locked-settings rule, not server-side verification of inventory creation. Do not describe it as dedicated-server enforcement.

**Quality is not a single implemented profession feature across this pool.** Smith-made durability metadata can travel with the item; EpicLoot already has item-bound gear rarity. ImpactfulSkills carries ingredient quality into equipment quality or increased output quantity, not superior crafted food. Its cooking degradation perk belongs to the eater. Herbalist potion potency/duration commonly belongs to the consumer, not the producer. A cohesive four-reward system therefore still has genuine product-quality gaps.

## Sources and reproducibility

New extracted packages/decompiles: `/tmp/lembitu-prof/RecipeGatesAndQuality/{wacky.cs,rad.cs,data.cs}` and subdirectories `wacky/`, `rad/`, `data/`. These paths are line-cited below. Existing decompiles are `/tmp/lembitu-research/ProgressionCluster/`. For brevity, **P** means that directory and **R** means `/tmp/lembitu-prof/RecipeGatesAndQuality/`.

Primary package sources:
- https://thunderstore.io/package/download/WackyMole/WackyItemRequiresSkillLevel/1.4.7/
- https://thunderstore.io/package/download/Radamanto/Item_Requirement/1.1.3/
- https://thunderstore.io/package/download/sighsorry/DataForge/1.3.5/
- https://thunderstore.io/api/experimental/package/WackyMole/WackyItemRequiresSkillLevel/
- https://thunderstore.io/api/experimental/package/Radamanto/Item_Requirement/
- DataForge upstream source linked by its packaged README: https://github.com/sighsorry1029/DataForge (`R/data/README.md:423-424`).

Observed binary proof: downloaded/extracted Radamanto 1.1.3; extracted cached Wacky 1.4.7 and DataForge 1.3.5; decompiled all three with ilspycmd. Ran `scripts/screen-bundled-libs.sh --dir /tmp/lembitu-prof/RecipeGatesAndQuality`: **clean: no stale game-member reference found in 3 library(ies)**. This is a stale-reference screen, not proof of working Unity/Harmony behavior. No game session, marketplace round-trip or project-wide tests were run.

Primary API observations: Radamanto 1.1.3 uploaded 2026-10-02T18:11:55Z and depends on BepInExPack 5.4.2351; Wacky 1.4.7 uploaded 2026-09-13T16:31:50Z and depends on 5.4.2350 (`R/rad-meta.json:1`, `R/wacky-meta.json:1`, URLs above). Both current target versions remain latest in those responses. Downloads/rating excluded from judgment.

## 1. Gate mod comparison

### WackyMole/WackyItemRequiresSkillLevel 1.4.7

**Coverage:** cross-profession exclusive recipes and usage restrictions; no XP system, no quality/efficiency/convenience products of its own.

- Server policy: `CustomSyncedValue` YAML and locking configuration; root `BepInEx/config/WackyMole.ItemRequiresSkillLevel*.yml`, plus old `Detalhes...` file accepted (`R/wacky.cs:225-272`). Presentation-only `ShowBlockMessages` is explicitly unsynced, not a gameplay setting (`:241`).
- Crafting authority: postfix `InventoryGui.UpdateRecipe` appends requirements and only sets craft button `interactable = false` (`:430-454`). The Harmony hook enumeration contains no `DoCrafting` gate. Thus **UI-only for crafting**, unlike its `Humanoid.EquipItem` prefix and consume check (`:407-473`). Alternate crafting callers can bypass this restriction [INFERENCE].
- Vanilla/modded skills: searches `Skills.m_skillData` by `abs(stableHash(Skill))`, then parses vanilla enum name; evaluates `GetSkillLevel`, falling back to raw `m_level` (`:568-613`). This matches Blacksmithing's registration algorithm (`P/BlacksmithingExpanded.cs:3265-3285`) and Herbalist's exact skill ID (`P/Herbalist.cs:223-225,1578`). Exact case/name matters for the stable hash. Missing skill denies positive requirements (`R/wacky.cs:574-590`).
- Config supports per-prefab Requirements and RequirementGroups/Prefabs, `Skill`, `Level`, `BlockCraft`, `BlockEquip`, `EpicMMO`, `GlobalKeyReq`, `ExhibitionName` (`:770-807`). Requirements combine as AND where active (`:449`).
- WAP special handling: detects WAP GUID, uses `ZoneSystem.CheckKey` with different key type when WAP exists (`:220-227,543-550`). This is not a replacement for WAP's recipe/material lock. Avoid duplicating boss-key policy here.
- Quality/EpicLoot: no own quality metadata. Changelog claims startup/EpicLoot fix in 1.4.3, IsEquipable fix in 1.4.4, status-effect skill bonuses in 1.4.5 and Deep North update in 1.4.7 (`R/wacky/CHANGELOG.md:13-17`). These are source claims, not a exercised EpicLoot compatibility result.
- Code quality: simple prefix/postfix restrictions rather than crafting transpiler, defensive file read warnings and `GetSkillLevel` fallback (`R/wacky.cs:252-269,601-607`). But linear requirement lookup and two skill-data scans per check (`:516-518,568-585`); primarily UI/event work, not demonstrated frame bottleneck. Effective-skill gating can allow temporary gear/food bonuses to satisfy mastery [INFERENCE]. Most important defect for this task is absence of action-level crafting enforcement.
- Maintenance: release metadata above; changelog active Deep North update. No sibling-family behavior was assumed from the author's name.

### Radamanto/Item_Requirement 1.1.3

**Coverage:** same common exclusive-recipe role; no separate XP, no product quality.

- Authority distinction: synchronized YAML (`R/rad.cs:777`), `General/LockConfiguration = true` and ServerSync locking (`:799-845`). Action-level client prefix `InventoryGui.DoCrafting` returns false when CanCraft fails; UI postfix also disables craft button (`:663-703`). All skill evaluation uses `Player.m_localPlayer` (`:973-1009`). Therefore **server-locked policy, client action enforcement, not server validation**.
- Modded skills: stable-hash lookup followed by vanilla enum fallback, same hash as SkillManager; compares raw `Skill.m_level` (`:986-1014`). `Skill: Herbalist` and `Skill: Blacksmithing` are supported by code although README only lists vanilla/EpicMMO names. README's narrower advertised list (`R/rad/README.md:23-57,123`) is documentation scope, not contradictory implementation evidence.
- Missing skill returns false (`R/rad.cs:1005-1007`); no local player returns true (`:973-976`), explicitly confirming it cannot validate profession level on headless server. EpicMMO rules are silently inactive when that plugin is unavailable, with warning during load (`:949-970,1321-1335`). **Always use `EpicMMO: false` here.** VLS names read saved known text and missing VLS data permits access (`:978-984`); do not use this path for professions.
- Format: `BepInEx/config/ItemRequirement/radamanto.ItemRequirement.<identifier>.yml`; default `.main.yml`. Plain YAML list of `{PrefabName, Requirements:[{Skill,Level,BlockCraft,BlockEquip,EpicMMO}]}` (`:781-789,865-881,1342-1372`; `R/rad/README.md:59-119`). No quality-specific gate, no recipe-ID-specific gate, no build-piece gate, no alternative-skill OR: active requirements are all AND (`R/rad.cs:1033-1046`). It gates **result prefab**, including every selected recipe producing that prefab (`:691-703`).
- Code quality: null guards around selected recipe/item, dictionary index rebuilt after parsing, deterministic file enumeration excluding generated ALLITEMS helper (`:691-703,865-881,1282-1330`). No crafting transpiler. Skill scans remain linear, but on action/UI checks. Watcher disposal and 300ms debounce are present (`:793-797,849-862,927-934`). Broad swallowed I/O exceptions reduce diagnosability (`:825-842,883-885,916-924`). First duplicate prefab wins rather than merging rules (`:1316-1320`): keep one owner for each prefab in configuration. No custom save state, so gate removal does not strand items.
- Combat leakage: itself adds none. Set `BlockEquip: false` so customers can consume/use purchased profession outputs without having the producing skill. WAP equipment restrictions remain independent.
- EpicLoot interaction: checks prefab only, not rarity/metadata; cannot say “Legendary requires Blacksmithing 75” while allowing the same normal prefab. EpicLoot custom enchanting operations are not proven to call InventoryGui.DoCrafting; **do not assume this gates its enchanting UI**. No reason to add both gate mods.
- Maintenance: 1.1.1 claims Deep North update, 1.1.2 new Cooking/Farming/Crafting/Dodge/Ride translations, 1.1.3 Vikings Archer compatibility optimization (`R/rad/CHANGELOG.md:5-16`). Backpacks compatibility listed as removed in 1.1.3, so AdventureBackpacks integration must not be presumed (`:16`).

## 2. DataForge 1.3.5: requirements versus quality

**Not a profession gate.** Complete recipe input schema has recipe, override/remove, station, one-ingredient mode, sort weight, upgrade-only flag, resources, qualityBonus; no profession skill/level predicate (`R/data.cs:13337-13469`). Resource `ExactQuality` refers to item upgrade material quality, not player mastery (`:13474-13482`; `R/data/README.md:126-147`).

**Can represent distinct tradable product tiers through different cloned prefabs** [INFERENCE], not automatically award quality according to crafter skill. Item schema exposes MaxQuality, food fields and per-level equipment stats (`R/data.cs:8784,10494-10498,11437-11439`). README demonstrates cloning a named mead from `MeadHealthMajor` (`R/data/README.md:350-369`). Separate prefabs provide an unambiguous product identity for Market and a separate gate target, whereas modifying shared food stats changes every copy, not just master-crafted copies.

`qualityBonus` means **extra output quantity from ingredient quality**. It computes `(input item quality - 1) * amountPerLevel`, rounded up (`R/data.cs:15205-15244,15352-15354`), and adds it to Recipe.GetAmount (`:15801-15810`). It does not set resulting item quality or encode crafter level. It overlaps ImpactfulSkills's ingredient-quality output amount and resource-consumption patches (`P/ImpactfulSkills.cs:969-970,4769-4832`). Leave DataForge qualityBonus unset for recipes already handled by ImpactfulSkills, or disable one path; stacking is [INFERENCE], exact patch ordering untested.

Code quality in this slice: explicit recipe-entry models; guards and warnings for invalid qualityBonus targets (`R/data.cs:15156-15192`); fast zero-rule count exit and targeted inventory lookup (`:15205-15244`). It patches Recipe.GetAmount and Player.ConsumeResources, so this is an active runtime mechanic, not merely data. README explicitly says Harmony/UI/multiplayer RPC behavior still requires game verification (`R/data/README.md:420-421`). Broader DataForge save/sync architecture was not independently re-audited here.

## 3. Composition with WAP

WAP's DoCrafting prefix at Harmony priority 200 chooses **LockCooking**, not LockCrafting, for `piece_cauldron`, `piece_preptable`, and `piece_MeadCauldron`; other stations use LockCrafting. It checks recipe/material/boss keys and returns false on failure (`P/VentureValheim.Progression.cs:1082-1103`). **Keep LockCooking enabled too**, or alchemy/food biome protection is not equivalent to ordinary forging protection.

Radamanto's default-priority bool prefix returns only permission and never forces WAP true (`R/rad.cs:681-703`). Both prefixes veto the same original action; logically permission is **boss/biome AND profession** [INFERENCE from Harmony prefix semantics; not exercised in game]. Wacky UI-only restriction has weaker composition because action calls outside the button still encounter WAP but not Wacky.

Important subtlety: both use selected/current recipe but different fields (`m_selectedRecipe.Recipe` versus `m_craftRecipe`). Standard UI consistency is assumed [INFERENCE]; custom crafting callers and selected-recipe mutation need a scoped game check. Herbalist also patches DoCrafting, including its own skill-name tier gate and XP postfix (`P/Herbalist.cs:1552-1598`), so do not duplicate inconsistent thresholds for BH_minor/BH_medium/BH_large products.

WAP drain loops every entry in `Skills.m_skillData` with no vanilla-enum whitelist, resetting accumulator and applying boss floor; Raise patches every Skills.Skill instance (`P/VentureValheim.Progression.cs:3187-3239`). Thus genuine SkillManager skills stored there receive floor/drain. These two gate mods merely read skills and neither bypasses death. Plain own-XP frameworks remain outside this guarantee.

## 4. Which quality survives sale?

| Candidate | Observed mechanism | Tradable quality conclusion |
|---|---|---|
| BlacksmithingExpanded 1.2.4 | Serialized ItemData fields include maker level, durability, armor/damage/block bonuses; ItemData.Value stores into item.m_customData. Load reapplies bonuses (`P/BlacksmithingExpanded.cs:1733-1738,1771-1811,3696-3794`). | Item-bound, therefore ordinary transfer can retain it [INFERENCE]; Market must retain customData. Best allowed noncombat use is durability on tools. Not merely higher current owner skill. |
| EpicLoot 0.14.13 | Rarity enum Magic/Rare/Epic/Legendary/Mythic/Ancient; MagicItemComponent serializes JSON to CustomItemData.Value, saves and deserializes on load (`P/EpicLoot.cs:19712-19720,20368-20462`). | Existing gear-tier axis, distinct from vanilla upgrade `m_quality`. Tradable if customData preserved [INFERENCE]. Do not add Smith damage/armor tier on top. |
| ImpactfulSkills 0.21.0 fish processing | Quality ingredient selection affects extra Recipe amount; equipment craft writes pending quality into Inventory.AddItem quality argument, capped by item/station (`P/ImpactfulSkills.cs:4350-4415,4580-4606,4811-4832`). | Fish ingredient quality is meaningful; fish-to-food gives **quantity**, not a higher-quality food stack. Fish-to-equipment can produce actual vanilla item quality, e.g. fishing hat per config description (`:668`). |
| ImpactfulSkills cooking | UpdateFood reduction reads local eater's Cooking skill (`P/ImpactfulSkills.cs:3972-4002`). Bonus food amounts are skill-gated (`:4611-4615`). | Efficiency/personal convenience, **not a master chef's transferable food quality**. A novice consuming master-made ordinary food does not inherit chef skill. |
| Herbalist 1.5.0 | Effects set duration/heal/eitr according to player GetSkillFactor; ConsumeItem modifies shared effect TTL based on consumer (`P/Herbalist.cs:975-977,1389-1392,2208-2228`). | Consumer potency, not stored producer quality. Built-in minor/medium/large recipes are distinct products, but no crafter-specific serialized strength established. Shared effect TTL mutation also deserves runtime scrutiny. |
| DataForge 1.3.5 | Clones and shared prefab overrides; ingredient qualityBonus increases quantity. | Can supply deliberately separate named tier prefabs [INFERENCE], not automatic maker-quality persistence. |

Blacksmithing combat-off settings verified in code: `Stats/Enable damage bonus=false`, `Stats/Enable armor bonus=false`, `Elemental/Enable elemental bonus=false`, `Shields/Enable shield bonus=false` (`P/BlacksmithingExpanded.cs:4748-4749,4760,4770`). Leave durability true (`:4747`). Consider whitelist tools only; station virtual-level bonus (`:4731`) can overlap BetterStations and removes normal workstation effort, so choose one owner. Disable Smith smelter/kiln speed perks if BetterStations owns them (`:4720-4721`). Existing stored damage metadata is applied separately from acquisition toggles (`:3787` etc.); disabling acquisition settings is not demonstrated to sanitize already-created bonus gear.

**Market preservation is unknown in this slice.** Ordinary ItemData save support is not proof Northarun/Marketplace retains customData, vanilla quality, or custom prefabs in remote listing/withdrawal. Verify one actual Smith tool and one EpicLoot item through sale/withdrawal/relog. No claim here that this was done.

## 5. Concrete exclusive-recipe proposals

These are proposed policy, not applied changes. Keep baseline tools/food/meads available; gate a narrow premium subset. Set only BlockCraft, never BlockEquip, so specialists sell useful output to non-specialists. Death can drop temporary access until retraining; recipes are not permanent unlock records.

| Profession | Premium candidates in current vanilla/mod pool | Proposed threshold and caveat |
|---|---|---|
| Smithing | Black-metal pickaxe / selected late tool; durable tools from Smith | Blacksmithing 50. Gear stays boss-gated and EpicLoot-owned; do not gate ordinary early pickaxes. Gates cannot isolate upgrade quality 4 versus quality 1 of same prefab. |
| Cooking | Fish wraps and fish-and-bread; chosen late feast recipe after in-game prefab discovery | Cooking 40 / 60. Food remains ordinary unless distinct DataForge premium prefab is intentionally authored. |
| Farming | Cultivator premium replacement or selected premium crop recipe | Farming 40; **gap:** PlantEverything/SeedBed planting is build/piece use, not InventoryGui recipe crafting, so neither gate can gate their plant placement directly. Do not pretend gated cultivator equals exclusive crops. |
| Alchemy | Major healing mead base, lingering stamina mead base; Herbalist large potions already tiered | Herbalist 50 / 60. Gate **mead base**, not fermented output, because Fermenter output is outside this gate. Existing healing mead clone example confirms `MeadHealthMajor`; exact mead-base prefab names must be read from current game's recipe dump before deployment. Preserve WAP LockCooking. |
| Gathering | Late pickaxe belongs to Smith, so do not duplicate it as Gathering ownership | **gap:** no independent premium gathered-resource recipe established. A DataForge refined-material clone would be added content, not existing item pool. |
| Fishing | Fishing hat; advanced biome bait recipe | Fishing 50 / 35. Bait exact prefab and whether TheFisher bait passes normal crafting remain to verify. Keep basic bait open. Hat quality inheritance optionally disabled to avoid combat-stat inflation. |
| Animal handling | Premium husbandry feed / bee product | **gap:** no suitable existing craftable premium feed established; honey harvesting/taming/breeding are not DoCrafting. Do not gate novice access to honey or all mead production under Riding and call that Animal handling. |
| Exploration/travel | Selected AdventureBackpacks upgrade or premium sailing/travel supply | Hauling 50 candidate; **gap:** exact backpack result prefab and custom crafting path unverified; Radamanto removed a former Backpacks compatibility. Boats are build pieces and cannot use this recipe gate. |

### Example rule set for recommended gate

Path if adopted: `BepInEx/config/ItemRequirement/radamanto.ItemRequirement.professions.yml`.

The syntax is confirmed against `R/rad.cs:1342-1369` and packaged README:80-119. Prefab IDs below are proposed vanilla names [INFERENCE], not confirmed against a running 1.0.16 ObjectDB dump; thresholds are design proposals. This avoids claiming an install-ready file where recipe identity is not verified.

```yaml
- PrefabName: PickaxeBlackMetal
  Requirements:
  - Skill: Blacksmithing
    Level: 50
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
- PrefabName: FishWraps
  Requirements:
  - Skill: Cooking
    Level: 40
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
- PrefabName: FishAndBread
  Requirements:
  - Skill: Cooking
    Level: 60
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
- PrefabName: MeadBaseHealthMajor
  Requirements:
  - Skill: Herbalist
    Level: 50
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
- PrefabName: MeadBaseStaminaLingering
  Requirements:
  - Skill: Herbalist
    Level: 60
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
- PrefabName: HelmetFishing
  Requirements:
  - Skill: Fishing
    Level: 50
    BlockCraft: true
    BlockEquip: false
    EpicMMO: false
```

Runtime acceptance still needed: below/at threshold crafting; real second-gate boss lock; death drain and floor; consumed/traded product use by novice; skill bonus gear does not unlock earned-level rules; prefab spelling against ObjectDB; no duplicate prefab configs; EpicLoot custom UI treated independently.

## 6. Proposed cohesive slice stack / eight profession ownership map

This table chooses exactly one owning mod per profession for coordination, **not a finding that all eight are complete**. Common gate is Radamanto; DataForge is common data authoring, not an additional owner. E = efficiency, Q = transferable product quality, X = exclusive recipe, C = convenience. Cells outside deeply inspected quality/gate paths are [INFERENCE] provisional allocations for dispatcher/family researchers.

| Profession | Exactly one proposed owner | Reward coverage evidenced in this slice | Switches / unresolved gaps |
|---|---|---|---|
| Smithing | BlacksmithingExpanded | Q durability metadata; X via Radamanto; E station resource/speed config; C longer tool life | Disable damage/armor/elemental/shield; tool whitelist; no duplicate BetterStations speed or virtual station levels. Market persistence unverified. |
| Cooking | ImpactfulSkills | E extra servings; X via Radamanto; C personal degradation reduction; Q **absent** | Transferable premium food needs distinct product or another mechanism; eater buff is not chef quality. |
| Farming | ImpactfulSkills | Ownership allocation [INFERENCE]; gate can read Farming | No claim of exclusive planting or product Q. PlantEverything/SeedBed remain content/QoL, not second skill owners. |
| Alchemy | Herbalist | X built-in tiers + Radamanto vanilla mead bases; potency is consumer-based, not Q | E/C broader perks outside this slice; innate potion tier gate overlaps DoCrafting; need separate master product quality. |
| Gathering | ImpactfulSkills | Vanilla skill gate compatibility; broader E/C [INFERENCE] | No suitable X or Q product proven. Smith owns crafted premium pickaxe. |
| Fishing | ImpactfulSkills | E ingredient-quality yield; Q actual fish/equipment quality carry-through; X hat/bait candidate | Disable ScaleCraftedEquipmentQuality if noncombat-only policy disallows upgraded equipment; avoid DataForge duplicate quantity bonus. TheFisher remains fish content, not additional skill owner. |
| Animal handling | ImpactfulSkills | Ownership allocation [INFERENCE] | No suitable X or Q established in current item pool. No honest complete four-reward claim. |
| Exploration/travel | ImpactfulSkills | Hauling convenience config (`P/ImpactfulSkills.cs:557-559`); X backpack candidate unverified | ExpertExplorer/Njord can remain map/handling QoL only if their skill/perk duplication is disabled; E/Q/X gaps need family evidence. |

Dispatcher may replace provisional owners with family/framework findings. The definitive slice choice is **one common earned-skill recipe gate, existing gear rarity kept separate, no fictional producer quality**.

## Coverage gaps, specifically bounded

1. No actual 1.0.16 game runtime in this research environment: stale screen clean does not clear selected recipe behavior, Harmony ordering or UI compatibility.
2. Exact prefab identities for proposal set need current ObjectDB/recipe export. Vanilla logical item names are concrete candidates, example YAML IDs are [INFERENCE]. Neither gate's generated ALLITEMS helper enumerates all consumables, so use full game/DataForge recipe reference rather than only equipable helper.
3. Northarun/Marketplace transport of quality/customData/custom prefabs not inspected or exercised. Item-bound durability/EpicLoot JSON support is necessary, not sufficient.
4. EpicLoot enchanting/crafting UI bypass and advanced backpacks crafting path unverified; no rarity-specific gate exists in the inspected gate schema.
5. Animal handling, farming, gathering and exploration have no sourced complete premium-recipe/product-quality solution here. Treat these as real design gaps, not “quality = more yield”.
6. Gate-family author consistency beyond the target binaries/changelogs was not studied; package upkeep dates and concrete code behavior are the maintenance evidence, not author reputation.
