# ScoutContent — world, boss, creature and event scouting

## Summary

1. **Try OceanAdventures 1.0.0 first, initially with contracts disabled.** It fills the genuinely thin ocean with cooperative sailing encounters and storm routes, uses vanilla assets/items, has server-owned encounter/reward decisions, and does not alter world generation. Disable progress-metal bonuses and extra quality rewards initially so sailing does not undermine hauling and the smith.
2. **Prefer curated CreatureManager Enforcers over another event director; advertised live hunts are unverified.** The 1.2.5 README advertises live hunts, but AuditCombat found no corresponding hunt subsystem in the staged 1.2.5 decompile. Do not promise scheduling or hunt commands from marketing. Existing outdoor/dungeon Enforcers remain useful for shared hunts.
3. **Consider a tightly reduced EliteCreaturesPack 0.6.1, not its defaults.** Slingshot greydwarfs and mimics are coherent mechanics; its new craftable weapons and global-key-based one-giant-per-mountain bookkeeping need explicit treatment. A creature-only cut is not proven available for every module.
4. **Consider Bestiary 1.2.1 only as a curated biome subset.** ServerSync locking is real and most ordinary drops are vanilla, but most later-biome creatures require world boss keys by default and therefore never spawn on this server. Set each chosen creature's `Required global key = None`; budget their resources and EpicLoot tables explicitly.
5. **Reject ExtendedBosses 0.8.11 for this Run despite attractive raid mechanics.** Its boss HP, add numbers, stars and even hardcoded nest count scale by nearby headcount. Turning `HealthPerPlayer` to zero does not remove those other paths.
6. **Reject BossAdd 1.2.0.** It binds local gameplay configs without a config-sync implementation; it also deletes Eikthyr summons on local respawn and extensively rewrites boss damage/death/stat paths already owned by the pack.
7. **Reject OdinsHollow 2.2.4 as shipped.** The actual DLL still reads `ZRoutedRpc.Everybody` in bundled ServerSync despite a same-day update. Its synchronized config is registered in startup, so the references are not merely dormant library baggage. It is also world-permanent and must precede launch-world creation if repaired and selected.
8. **Do not buy more endgame with extra progression pillars.** BiomeLords adds profession bypasses/inventory rows and active guardian powers; BlightedWorldHeart adds hundreds of affixed gear variants outside EpicLoot; RtDMythics adds another magic progression. These work against cohesion and a 50–60-hour Fader arc.
9. **Preserve existing re-kill incentives.** Fixed shared trophies/Wishbones/swamp keys already create repeat kills; the otherwise appealing Unofficial EpicLoot BountyAdditions boss slot is world-key-gated and does not work with blocked keys.
10. **Twelve candidates were downloaded and decompiled, all 13 shipped DLLs screened.** Only OdinsHollow failed stale-field screening. No builds, tests, servers, deployments or repository changes were made; these are static findings, not multiplayer acceptance.

## Evidence conventions and scope

All `S/<mod>/...` citations below mean `/tmp/lembitu-premium/ScoutContent/<mod>/...`; package READMEs were extracted from the exact downloaded version, not an unversioned page. Thunderstore package URLs are `https://thunderstore.io/c/valheim/p/<owner>/<name>/`; exact downloads use `https://thunderstore.io/package/download/<owner>/<name>/<version>/`. All twelve decompiled candidates were updated on or after 2026-09-09 in the supplied index.

The screen ran against all 13 downloaded managed DLLs, including BossAdd's AnimationSpeedManager. `S/screen.txt:1–10` reports only OdinsHollow (three stale references). A clean screen is **not** proof of Valheim 1.0.16 compatibility, Harmony interoperability, sync enforcement, or asset correctness. No `patchers/` files were found in these twelve archives; no claim is made for un-downloaded dependencies, notably BossAdd's MonsterDB.

The authoritative current settings are `config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg:36–38` (`BlockAllGlobalKeys = true`, private keys); `config/enforced/randyknapp.mods.epicloot.cfg:4–7,28–36` (personal recipe-aware drops, fixed boss quest-item rewards); and `config/enforced/sighsorry.CreatureManager.cfg:64–87` (Karma/Enforcers, suppression during real bosses). New creature prefabs do not automatically acquire an appropriate EpicLoot creature loot table merely because they are `Character`s. New craftable items need profession-ladder review and material-biome gate verification; “cloned from vanilla” does not establish enchantability or correct World Advancement Progression classification.

## 1 — TRY: Rollstuhltreter/OceanAdventures 1.0.0

**What:** Ghost ships, wreck cargo salvage, smugglers and stormfront sailing routes; optional Haldor contracts with personal equipment rewards.

**Verified:** `S/OceanAdventures/pkg/README.md:3–26` says vanilla assets, no world-generation changes, free encounters give resources/valuables rather than equipment, and contract holders alone receive guaranteed equipment although helpers can assist. Server controls encounters, rewards and saves (`:28–32`). Decompiled authority checks corroborate this: `src/OceanAdventures.Runtime/EncounterDirector.cs:253–258,1044–1048`; `ContractService.cs:290–295`; `NetworkBridge.cs:533–555` verifies protocol and server sender on clients. `src/OceanAdventures.Config/OceanAdventuresConfig.cs:151–154,197–204` starts remote sessions and withholds encounters until synchronization. This is custom authority/sync, not ServerSync; exact Pack-rule acceptance should be exercised by editing a connected client's settings.

**Progression/EpicLoot:** `src/OceanAdventures.Core/RewardRules.cs:22–58` selects the highest known recipe tier, grants quality 1 with an optional quality-2 upgrade. `src/OceanAdventures.Runtime/RewardService.cs:297–301,334–343` delivers ordinary item data and tracks a receipt. This is not an EpicLoot rarity roll. Vanilla resulting equipment should retain normal enchantable types [INFERENCE], but it can substitute for a smith-made item and contract recipe knowledge must be tested against WAP's locked recipe list. No world-global-key lookup was found in this package's source. No new base player weapons or profession recipes are advertised.

**Proposal:** Isolated try with `[Server] EnableContracts = false`; `[Rewards] ProgressMaterialChancePercent = 0`, `SecondContractEquipmentChancePercent = 0`, `ContractQualityUpgradeChancePercent = 0`, `CustomEncounterRewards =` empty. Preserve the default free-event cooldown/chance initially: `[Free Encounters] MinimumWaitAfterEventMinutes = 10`, `CheckForEventsEveryMinutes = 1`, `EventChanceAtEachCheckPercent = 15`. Exact keys: `OceanAdventuresConfig.cs:168–194`. With continuous eligibility, the default check probability gives about 6.7 minutes of checks after a cooldown [INFERENCE], not guaranteed regular events. Evaluate frequency on actual long-haul journeys before making this a central source of valuables.

**Overlap:** Its own storm/weather system, encounter NPC ship controllers and marked reward chests require a Sailing-profession check; do not assume the player's vanilla ship force is untouched because encounter ships are separate. Source includes `OceanAdventuresSailWind.cs` and special ship drivers; no blanket claim of Njord-like compatibility is made. Oathbound sieges remain the base-attack owner; no raid-system replacement is advertised. Smuggler kills may produce Karma in addition to event difficulty [UNVERIFIED].

**World permanence:** No generation locations/rooms, so no creation-time dependency; marked encounter ZDOs and its own world profile still need backup/removal handling. `OceanAdventuresRuntime.cs:319–327` explicitly loads its store and cleans marked ghost objects on server session startup.

**Confidence:** Medium-high static fit, low runtime maturity (first release 2026-10-03). **Shakedown:** storm cleanup/disconnect/restart, boats with focused Sailing, resource-gate rewards, cross-guild helpers, local config edit, no duplicate chest/receipt delivery. Not production-approved.

## 2 — CONSIDER: MilkyTeam/EliteCreaturesPack 0.6.1

**What:** Mimic chests, greydwarf slingers, rime giants, krakens, skeleton arsenals and crypt executioners, plus craftable weapons.

**Verified:** `src/EliteCreaturesPack/Settings.cs:19–33` binds a default-true `[1 - General] Lock Configuration` through custom SyncedConfiguration. `src/EliteCreaturesPack.Slinger/SlingerCreature.cs:21–24,43–60` clones a vanilla greydwarf, retains ordinary CharacterDrop and adds stones. `SlingerSpawns.cs:33–37` preserves selected min/max levels. `SlingerNestSpawnPatch.cs:7–15` patches `SpawnArea.SelectWeightedPrefab`, so spawner-based siege or Enforcer sources should be checked, not only wilderness spawns.

**Problems:** `src/EliteCreaturesPack.RimeGiant/RimeMountains.cs:23` relies on `GetGlobalKey("ecp_rimegiant_" + mountain)` to stop repeat giants. WAP blocks writes, so its promised “one giant per mountain ever” cannot be assumed [INFERENCE]. `RimeGiantSettings.cs:104–109` confirms that promise. `src/EliteCreaturesPack.Kraken/KrakenBoss.cs:13–15` also reads/writes a world boss-counter global key. These are bookkeeping rather than vanilla boss-unlock gates, but are still affected. `src/EliteCreaturesPack.Arsenal/ArsenalRecipes.cs:46–74` installs new weapon recipes; merely disabling skeleton spawns does not prove recipes disappear. `[7 - Bone Crossbow] Craftable = false` exists (`Crossbow/XbowItemSettings.cs:49`), but no complete gear-free master switch was established. New weapons need EpicLoot allowed-item/type proof and Item_Requirement rules, not an assumption.

**Proposal:** Consider only after proving a creature-only profile: retain slingers and mimics, set `[4 - Rime Giant] Enabled = false`, `[8 - Skeleton Arsenal] Enabled = false`, `[7 - Bone Crossbow] Craftable = false`, and disable remaining unwanted modules using their generated locked settings. Do not publish this partial profile as sufficient to remove all recipes. Avoid pairing with EliteCreaturesReborn: the latter is another affix/scaling owner, not needed with CreatureManager.

**World permanence:** Persistent custom creature/item prefabs; no sampled generation rooms/locations, but do not remove mid-Run without save cleanup. Rime giants specifically persist when disabled (`RimeGiantSettings.cs:104`). Settle selection before world creation under the Pack's conservative prefab-permanence rule.

**Confidence:** Medium. **Shakedown:** CreatureManager scaling/modifiers on each selected prefab, EpicLoot table coverage, Karma interactions, mimic readability/fairness and Oathbound summoned NPC discrimination.

## 3 — CONSIDER: Radamanto/Bestiary 1.2.1

**What:** Biome-specific creature variety, including animals and monsters, configurable spawn/damage/biome settings.

**Verified:** `src/Bestiary/BestiaryPlugin.cs:109–136` initializes ServerSync and registers the locking entry. `src/Bestiary/Creature_Registry.cs:38,65,92` starts ungated Meadows creatures, but `:119,154,177,204,231,258,285,312,347,374,401,428` puts later creatures behind vanilla global defeat keys. Embedded registration library `src/CreatureManager/Creature.cs:610` exposes each creature's **`Required global key`** setting, so the defaults are repairable without re-enabling global keys. This embedded prefab helper is distinct from sighsorry/CreatureManager.

**Loot:** Registry `:49–56,76–83,130–145,165–168,215–222,323–339` shows vanilla drops such as bone fragments, honey, QueenBee, finewood/acorns, raw fish, coins/ectoplasm, wolf fang and crystal. Honey/QueenBee and large finewood stacks should not turn wild hunts into superior profession farms. Custom trophies also exist (`:188–191`). WAP gates using gear, not these spawn schedules; do not call ungating spawns a personal-progress integration. EpicLoot requires deliberate new-prefab loot entries; no direct integration was established.

**Proposal:** Curate at most a few needed biome species, set each selected prefab's `Required global key = None`, disable others through their spawn settings, reduce chosen drops to vanilla-comparable output. Do not blanket enable all while leaving dead global-key gates. This is optional texture, not another required grind for the one-month path.

**World permanence:** Custom creature/trophy prefabs persist; no generation-room requirement found in reviewed registration code. Select before world creation; adding safely later or removing persistent instances is [UNVERIFIED].

**Overlap/confidence:** CreatureManager's Character level/stat/modifier paths and Karma economy are the relevant seams; no dynamic headcount code was found in the reviewed mod-specific registry. Medium static confidence; Shakedown must establish prefab scaling order, animation/network behavior and spawn density.

## 4 — REJECT: j1gA/ExtendedBosses 0.8.11

**What:** Raid-style vanilla bosses with phases, shield windows, adds, nests, threat, hazards and lieutenants. This is the strongest mechanical concept match but violates fixed difficulty.

**Evidence:** `src/ExtendedBosses/ExtendedBossesPlugin.cs:2782–2792` defines health per player, solo discounts, adds per player and headcount star thresholds. `:4034–4068` multiplies add numbers by actual headcount and grants stars. `:4071–4082` **hardcodes** one nest for solo and an extra nest for six-plus players. AddsPerPlayer has minimum 0.1 (`:2787`), so zeroing HP does not solve it; selecting Light does not remove the shared add multiplier. `[08 Sync] SyncConfig = true` does synchronize gameplay (`:6611`), but sync is not the blocker.

**Overlap:** `Character.RPC_Damage` (`:222–263`), `SpawnArea.SpawnOne` (`:19–35`), `Projectile.OnHit` (`:46–64`), Piece/DropOnDestroyed reward suppression all intersect existing combat/spawn systems. Vanilla assets avoid new weapon enchantability and new profession requirements; vanilla bosses preserve the standard personal-key/reward pathway more plausibly than custom bosses [INFERENCE], but no runtime proof.

**World permanence:** Temporary vanilla encounter objects, no custom location dependency established. **Proposal:** Reject for Run; reconsider only after upstream offers complete headcount-scaling disable across HP, adds, stars, nests and other mechanics. Confidence high; not something Shakedown can fix by configuration alone.

## 5 — REJECT: LJS/BossAdd 1.2.0

**Evidence:** `src/bossadd/Plugin.cs:30–49` directly binds all gameplay files then patches; no ServerSync/Jotunn synchronization implementation was found in this decompile. `:135–153` watches local death and deletes Eikthyr summons on respawn. The index also exposes a separate HotdogKnights/BossAddFix 1.0.0 documenting deletion of nearby tamed creatures of the summon type; that description is a discovery lead, not independent runtime proof.

**Overlap:** `bossadd.Patches/BossStatCharacterPatch.cs:7` patches Character.Awake; `BossStatLevelPatch.cs:6` SetLevel; Bonemass split/invulnerability/trigger patches target `Character.RPC_Damage` and OnDeath. CreatureManager already owns those stats, and Oathbound's death/kill rewards rely on clean deaths. New minion mechanics look attractive but the Pack-rule failure is decisive.

**World permanence:** No location generation established; temporary bosses/adds. MonsterDB 0.4.0 is a dependency, not screened here. **Proposal:** Reject, no config workaround. Confidence high on missing enforcement and overlap; no Shakedown needed to justify rejection.

## 6 — REJECT: Wubarrk/BlightedWorldHeart 1.1.2

**What:** Summonable stationary raid-heart with waves/sub-bosses, custom affixed loot.

**Evidence:** `pkg/README.md:31–37` advertises 360+ gear variants and Jotunn authority. `src/BlightedHeart/BlightedItemsManager.cs:496–514` creates new custom item names and multiplies physical damage independently of EpicLoot; `:515–525` constructs its own upgrade recipe costs. `BlightedWorldHeartAI.cs:365–370` takes fixed BossHP; `:728–730` sets sub-boss level/HP directly; `:285–289` counts players for loot. Reward-only headcount is allowed, so **do not reject it merely because its README says multiplayer scaling**.

**Actual mismatch:** Gear rarity/affixes become another owner, custom upgrade/craft gates need profession and WAP mappings, and the heart is custom AI rather than an ordinary Character (`BlightedHeartPlugin.cs:53`, TheHive clone), so CreatureManager's boss multipliers cannot be assumed to apply. Its `[General] Magic Damage Multiplier = 0.25` (`BlightedConfigManager.cs:158`) is an especially poor default for thirteen Oathbound classes: mage participation is heavily discounted. Wave kills add an additional Karma-pressure source [UNVERIFIED].

**World permanence:** Custom heart/item prefabs, no generation-location requirement established. Before-creation selection and permanent dependency if gear is distributed. **Proposal:** Reject for cohesion, not an unproven technical incompatibility. Confidence high.

## 7 — REJECT FOR RUN: TaegukGaming/BiomeLords 0.6.15

**What:** Summonable per-biome Lords, hunting counters, repeatable trophies with blessing charges.

**Verified:** README `:7–11,39–42` promises personal progress and enforced server configs. `src/BiomeLords.Config/LordConfig.cs:78` defaults `GlobalLordDefeats = false`, so it is **not fair to claim every Lord gate needs world keys**. Global mode reads `biomelords_defeated_*` (`src/BiomeLords.Util/LordDefeatStore.cs:46`) and must remain off. `LordConfig.cs:79` gives five blessing charges per trophy—a genuine repeat-kill incentive.

**Mismatch:** `LordConfig.cs:82–91` defaults include doubled food duration, 50% extra station output, carry cap 1000, two additional inventory rows, and active full-party restoration. These bypass Calling food/smith/road responsibilities, overlap AzuExtendedPlayerInventory and replace the passive-only guardian-power concept. BaseHealth/HealthMultiplier per Lord exist (`:99–102`) but stat interactions with CreatureManager remain unproven. Horn recipe requires new Item_Requirement rules (`:93`); trophies/utility items require WAP classification review. No new enchantable weapon was established in the reviewed surface.

**World permanence:** Custom creatures/trophies/pedestals/hall pieces; before-world decision, persistent saves. **Proposal:** Reject until a real boss-only profile can exclude blessings, active powers and inventory changes, not merely set a few bonus numbers to zero. Confidence high conceptual rejection; fair-fight mechanics would require Shakedown.

## 8 — REJECT AS SHIPPED: OdinPlus/OdinsHollow 2.2.4

**Evidence:** `S/screen.txt:1–8` finds three stale Everybody reads. `src/OdinsHollow/OdinsHollow.cs:59–64,99–103` constructs and registers synced/locking configs, making this library reachable. It cannot be accepted from its update date. `pkg/README.md:29–32,50–54,90–103` establishes generation locations, random rooms, configurable spawners/chests and recurring loot.

**World permanence:** **Yes—must land before creation.** Locations spawn at world creation; custom room/piece prefabs become save dependencies. README allows manual later placement but that does not satisfy this Pack's clean launch-world rule.

**Concept:** Custom cooperative dungeons could fit, but default greydwarf refill farms are not a premium raid tier and produce repeated resources/XP/Karma. Loot tables would need biome/recipe gating and EpicLoot reward design; no automatic WAP integration established. AzuCraftyBoxes/build-table conflicts are acknowledged (`README:19`). **Proposal:** Reject current binary; reconsider repaired release only if custom curated dungeons are intentionally wanted. Confidence high static blocker.

## 9 — REJECT FOR RUN: Wubarrk/Mists_of_Avalor 1.0.4

**What:** Procedural sky labyrinth, mutant mobs, keyed vaults, Warden, traps and custom greatsword.

**Evidence:** `src/MistsofAvalor/AvalorMazeGenerator.cs:243,1005` generates maze and records generation; `AvalorNet.cs:460–461` starts server generation on request. `AvalorPressurePlate.cs:34–65` damages 40/60/85% of current player health depending on difficulty; non-poison hits use raw `m_damage` rather than normal physical types. `AvalorMobModifier.cs:35–56` raises stars and multiplies HP; `AvalorMobDirector.cs:547–555` adds another Warden HP multiplier. These stack with CreatureManager instead of leaving it sole owner. `AvalorAssetManager.cs:273,656` registers custom items.

**Concept/Pack:** Torch exploration is compelling, but another affix layer, raw-percentage traps and custom combat reward are a poor short-arc integration. Jotunn/IsAdminOnly settings appear (`MistsofAvalorPlugin.cs:131–135`), but exact network-attribute arguments did not decode, so locking is not asserted from that alone. Custom sword enchantability/WAP material assignment/Item_Requirement remain unverified.

**World permanence:** **Yes—generated custom maze/pieces/prefabs**, even though generation is on demand rather than seed placement. Must select before launch under ADR-0009; removal needs cleanup. **Proposal:** Reject for this Run; not a claim that its traps are necessarily unfair at their intended balance. Confidence high on overlap, medium on Pack enforcement; Shakedown needed only if owner explicitly wants this separate dungeon experience.

## 10 — REJECT FOR MONTH ARC: TokiroDK/Imgjald_the_Crownless_Jarl 1.0.0

**Evidence:** `src/Imgjald/BossConfig.cs:69–83` exposes admin-only fixed 100,000 health, scale 5.4 (~19m), summon/leash settings; description expects vanilla multiplayer scaling, which CreatureManager disables here. Do not multiply its stated HP by vanilla nearby-player factors. `src/Imgjald/Rewards.cs:128–143` crafts `THSwordImgjald` from trophy/Gold/FrostCore, sets huge custom damage and a secondary nova, and registers a new guardian power (`:17`). `Plugin.cs:30–33` binds configuration and adds content. No explicit SynchronizationMode attribute appears in the reviewed plugin; network compatibility alone does not prove lock.

**Fit:** A final eight-player spectacle, but Deep North/100k raid content is beyond the stated Fader finish rather than filling the month arc. Sword requires profession gating and EpicLoot proof; material-biome inference from Gold/FrostCore is not guaranteed WAP classification. New guardian powers are outside ProgressivePowers' curated passive owner.

**World permanence:** Summoned boss plus custom sword/trophy/boss stone; no location generation established. Persistent prefab dependency if distributed. **Proposal:** Reject for launch; possible explicitly chosen post-Fader content after separate balance/compatibility proof. Confidence medium-high; first-day package with 22 index downloads offers no maturity evidence.

## 11 — REJECT: Angellmod/SunkenSpoils 0.3.0

**What:** Fishing treasure raises personal disturbance; serpents and shared storms follow.

**Evidence:** `src/SunkenSpoils/SunkenSpoilsPlugin.cs:439–459,462–533` binds ordinary local configs; no config-sync implementation found. Its network handlers synchronize disturbance/weather, **not configuration** (`:788–802,982–1021`). Loot eligibility calls `ZoneSystem.GetGlobalKey` (`:1687–1707`), so later rewards remain closed on this server. This is not solved by the existence of network RPCs. Personal reward scaling is explicit (`:523`), and one fisher can induce shared storms through server state.

**Overlap:** OceanAdventures storms/treasure, Karma serpent kills, profession Fishing economy. Vanilla item rewards avoid new weapons but ore loot bypasses intended acquisition if gates are removed. **World permanence:** No new locations/rooms established, runtime loot/serpents/weather. **Proposal:** Reject on Pack rule and global-key gates. Confidence high; Shakedown unnecessary for current rejection.

## 12 — REJECT CURRENT INTEGRATION: GreatColtini/Unofficial_EpicLoot_BountyAdditions 1.3.0

**What:** Expanded EpicLoot bounties and a rotating defeated-boss slot; very good conceptual re-kill incentive, wrong progression API for this server.

**Evidence:** `src/VanillaBounties/BountySelectionPatch.cs:95–115` requires all biome boss keys through `ZoneSystem.GetGlobalKey`. With keys blocked, the advertised boss rotation cannot qualify bosses. `VanillaBountiesPlugin.cs:45–46` defaults `Vanilla Drop Multiplier = 2` and `Guarantee Epic Loot Item = true`; existing choice was shared fixed rewards, not doubled quest-item output. `BossBountyEpicLootReward.cs:14–30` and `BossBountyEpicLootCategoryPatch.cs:6–11` force the first eligible gear result to remain an enchanted item, rather than EpicLoot's material/shard/unidentified outcome.

**Proposal:** Reject current integration. If upstream supports **personal keys**, reconsider with `[Boss Bounty Rewards] Vanilla Drop Multiplier = 1` and `Guarantee Epic Loot Item = false` first, preserving existing rarity/material economy. Do not re-enable world keys to make the bounty mod work.

**World permanence:** Vanilla bounty targets; no new generation/weapon dependency established. Jotunn SynchronizationMode and admin-only settings appear in source, exact attribute arguments unresolved; screen clean. **Confidence:** High on world-key blocker. Shakedown would settle bounty-credit and standard boss private-key interactions only after that blocker is fixed.

## Existing owner opportunity — CreatureManager 1.2.5 live hunts

Primary versioned README: `https://thunderstore.io/api/experimental/package/sighsorry/CreatureManager/1.2.5/readme/`, saved `S/CreatureManager-readme.json`. It advertises **Live Enforcer Hunts**, outdoor/dungeon encounters, bonus loot and custom boss examples; says Bonebeard, Vincent and Root Witch require MonsterLabZ while Vitrfell uses a packaged texture. That dependency distinction matters: do not sell the examples as free vanilla-only content. Existing enforced `karma.yml:73–76,91–118` already names outdoor/dungeon Enforcers and guaranteed bonus loot. Prefer curated shared hunts within that owner over installing a second raid system. Exact hunt configuration/commands and 1.2.5 decompile are left to AuditCombat; no claim of scheduled automated launch is made here. Existing Karma is pressure-triggered, **not a calendar**.
**Cross-audit correction:** AuditCombat inspected the staged DLL, identified version 1.2.5 (`/tmp/lembitu-premium/AuditCombat/CreatureManager.cs:41384`), and found no Boss Hunt/HuntEvent/config subsystem; hunt matches were MonsterAI hunt fields and Enforcer SetHuntPlayer. Therefore the README is not proof of an implemented live-hunt director. Restrict recommendations to verified existing Karma/Enforcers until exact upstream bytes and commands demonstrate otherwise.

## Notable rejects and narrower alternatives

- **Previously cut packages stay cut.** `docs/modstack.md:426–447,471–472` retains BossRules, MWL_AIO, Warfare, StarLevelSystem, ZenBossStone and Seasonality reasons. MWL 5.1.8's recent release and 190-location description do not establish resolution of the four defect tickets or remove world permanence. Max Dungeon Rooms was expressly removed (`:421–422`); no owner reversal. Do not smuggle a Seasons replacement in immediately after the calendar was rejected.
- **Marlthon/SeaAnimals 0.3.9:** versioned README explicitly lists global-key-based progression and says config sync is still in development. Reject current evidence, despite excellent thin-ocean theme; a curated gate-free, verified-locked fork/profile would be a different proposal. Primary `https://thunderstore.io/api/experimental/package/Marlthon/SeaAnimals/0.3.9/readme/` (saved JSON).
- **Marlthon/Corsairs 0.2.8:** README adds Plains boss island/camps and custom sword/shield; config sync still in development. World-permanent island locations and new EpicLoot/Item_Requirement needs make this higher integration burden than OceanAdventures. Reject current evidence; binaries were not screened/decompiled. Primary versioned API README saved `S/Corsairs-readme.json`.
- **Soloredis/RtDOcean 2.2.49:** README combines ocean creatures/boss with every-biome crops/cuisine, trinkets and relic progression. Consider only if a real ocean-only profile can be demonstrated; not a harmless creature pack. Index also contains Vercadi/RtDBalanceCompatibility 0.1.1 explicitly gating roaming Belzor on the **world Queen key**, which this server does not set. That helper is not a solution. Primary RtDOcean versioned README saved `S/RtDOcean-readme.json`; helper gate is index description only [UNVERIFIED implementation].
- **Soloredis/RtDLegends 1.3.67 / RtDMythics 1.3.32:** READMEs respectively add custom-metal gear ladders/dungeons/nine bosses, and magical weapons/foods/eight pixie minibosses with crystals/essence. Reject as second gear/magic progression rather than confuse attractive dungeon art with cohesive integration. Locations/runestones are world-permanent [INFERENCE from README], so would require pre-creation decision. Versioned API READMEs saved `S/RtDLegends-readme.json`, `S/RtDMythics-readme.json`.
- **shudnal/Seasons 1.10.4:** README describes server policy-based ConditionalConfigSync, winter/summer/character stats and global-key options. Technically more tunable is not a reason to override the owner's “fixed difficulty without calendar” decision. Reject for current concept; presentation-only atmosphere belongs with ScoutUI.
- **VentureValheim/Venture_Location_Reset 1.1.1:** a narrower dungeon-repeat alternative than new dungeon packs. README documents Jotunn config enforcement, default 30-game-day revisits, player-activity protections, optional ground/Leviathan resets and explicit tombstone/building-loss/manual reset and duplication warnings. **Consider only if the month actually exhausts nearby dungeon supply**, not pre-emptively: enlarged world + eight players is not evidence of exhaustion. Proposed restricted trial: `ResetGroundLocations = false`, keep player activity checks, no manual resets near graves/builds; exact reset category keys beyond README are unverified. Existing locations regenerate rather than introducing new ones; mutation is permanent and needs backups. Source: `https://thunderstore.io/api/experimental/package/VentureValheim/Venture_Location_Reset/1.1.1/readme/`, saved JSON. Not among the twelve decompiles.
- **Raid directors / PersistentRaids / ZenRaids:** index scouting surfaced these, but they solve vanilla raid persistence/biome/player-count conditions while Oathbound owns sieges. Reject extra raid director by default, especially minimum-player or headcount-adjusted odds. No implementation claim beyond index description.
- **Ezomic/Vandi 1.0.0:** index describes repeat-boss kills raising biome stars and boss difficulty. Do not adopt re-kill incentives that globally punish late joiners or turn boss nights into progressive difficulty escalation without an explicit owner decision; implementation not decompiled.

## Gaps

- Read-only contract forbids runtime acceptance. Every proposed try still needs a real dedicated-server plus same-Pack clients Shakedown; static screen-clean is not “works.”
- WAP material-biome inference, EpicLoot enchantability/loot-table coverage and Item_Requirement mappings are **not proven for any new custom weapon**. Settle by inspecting exact registered recipes/shared item types and existing WAP/EpicLoot code, then exercising craft/equip/enchant as a lower-key character. No new-weapon candidate is approved.
- New creatures' exact final HP/damage order under CreatureManager, spawn-template filtering, affix immunity and Karma attribution remain unverified. Use narrow creature-prefab rules and inspect actual stats; do not just multiply advertised base HP on paper.
- Jotunn attribute argument decode failed for several binaries without resolved references. `IsAdminOnly` marks alone are not sufficient enforcement evidence. Exact IL attributes/Jotunn runtime or client-edit Shakedown can settle this; current rejects do not rely solely on that uncertain point.
- Config-sync closure and patcher screening were done only for files inside the twelve archives, not every transitive dependency. No selection should be pinned before closure screening.
- The 50–60-hour/month assumption leaves little room for another required gear ladder. OceanAdventures frequency, optional hunts and nearby resource supply require observed session timings; do not promise an extra dungeon/boss chain is free in that budget.
- No audited fresh-world room/location candidate cleared all gates. Leaving vanilla geography with curated existing hunts is a positive cohesion choice, not a missing feature count.
