# Premium review — 2026-10-04

Synthesis of eight static reviews of the Pack against ADR-0019 to ADR-0024 and a one-month Run
(8 players, ~50-60 h each to Fader). Nothing here was run in game; every number is a candidate for
the Shakedown. Detailed evidence, citations and gaps live in the handbacks:

| Handback | Scope |
| --- | --- |
| [AuditPace](AuditPace.md) | Pillar pace per biome: class level, professions vs ladder, EpicLoot, guild level, boss powers |
| [AuditCombat](AuditCombat.md) | Effective HP/damage chain, stacking, added creatures, sieges, companions, Pack-rule locks |
| [AuditEconomy](AuditEconomy.md) | Coin flow, focus-slot coverage, gate-coverage holes, Hauling, profession balance |
| [AuditUX](AuditUX.md) | Keybind collisions, HUD regions, onboarding gaps, client seeds |
| [StackHealth](StackHealth.md) | Pin drift, Azumatt to Hexium, open upstream bugs, performance candidates |
| [ScoutUI](ScoutUI.md) | Thunderstore UI/UX/QoL candidates |
| [ScoutContent](ScoutContent.md) | Thunderstore world, boss, creature and event candidates |
| [ScoutMeta](ScoutMeta.md) | Thunderstore achievements, stats, onboarding, moderation, anti-tamper |

## 1. Fix before the Shakedown (no design change)

1. **Guilds 1.2.2 → 1.2.3.** 1.2.2 can deactivate banner territory after a reconnect or world
   restart; 1.2.3's changelog fixes it (StackHealth §drift).
2. **BlacksmithingExpanded's main settings are synced but never locked.** Its main `ConfigSync` has
   no locking entry and never sets `IsLocked`; only its bundled SkillManager is locked
   (AuditCombat §2). No config key closes this. Options: a narrow lock patch in `Lembitu.Callings`,
   which already hooks this mod's skill manager, or an upstream release.
3. **Azumatt's six mods moved to Hexium with real fixes.** AzuCraftyBoxes 1.8.27 skips chests open by
   others (possible dupe) and fixes failed-craft item loss; AzuEPI 2.6.1 fixes duplicate custom-slot
   items, backpacks taking the cape slot and unequip after relog. `scripts/stage-stack.sh:236-246`
   only knows Thunderstore, and five of the six packages declare no licence (ProximityVoiceChat
   1.0.3 withdrew its MIT licence), so redistribution in the Pack needs the author's permission
   (StackHealth §Hexium).
4. **Keybind collisions.** B is push-to-talk and Oathbound's spell selector/companion call; H is
   AzuHoverStats' toggle, an Oathbound action and PlanBuild mirror; Extra Snaps takes Q/E; F4 opens
   both DetailedLevels and Extra Snaps' grid. A seed in `config/client/` fixes this without a mod
   (AuditUX §1). Seeds overwrite a player's own bindings when a new Pack is extracted over an install.
5. **ServerQuickConnect ships pointing at localhost** with the button text "Connect Vikings Server".
   Seed the hostname, port and "Join Lembitu"; leave the password blank (AuditUX §3).
6. **Comment and doc corrections.** EpicLoot overlay says 92% of items roll the minimum effect count;
   the staged table weights are 80/18/2 (AuditPace §2). AdditiveDamageModifier's "always takes a
   quarter" is a resistance-stage floor only (AuditCombat §4). `docs/modstack.md:103` credits
   ServersideQoL, removed 2026-09-17. `docs/modstack.md:265-268` describes one crafting gate;
   Item_Requirement is a second. AzuEPI's overlay comment still names PvPBiomeDominions.

## 2. Balance decisions (values ready, owner decides)

| # | Finding | Proposal |
| --- | --- | --- |
| 1 | Guild level is unreachable in a month: L20 costs 273,556 XP and L30 2.58 million; the pace model reaches about L14 at Fader. Donations at 50 coins/XP are irrelevant (AuditPace §1, AuditEconomy §3) | `LevelXpGrowth = 1.15` (L20 near Fader) or `LevelXpBase = 500`, `LevelXpGrowth = 1.12` (about L27 at Fader; materials become the gate). `DonationCoinsPerXp = 10` (package default) |
| 2 | EpicLoot's 0.6 modifier divides the no-drop weight and multiplies the drop weights, so odds fall to 0.36×: a 15% drop becomes 6%, the 50% boss shard 26% (`EpicLoot.cs:17081-17099`) | Keep 0.6 knowingly, or `Global Drop Rate Modifier = 0.7746` for "60% as likely" |
| 3 | Solo out-earns parties per kill. A 3-player party member gets 38% of a kill, so the party must kill 2.6× faster to match a soloist (`PartyExperience.cs:157-159`) | Keep the 150% cap but reach it at four players: `[Party] FullPartySize = 4` (two players 58% each, three 44%, four 37.5%). Alternative `FullPartyBonus = 1` (200% total) |
| 4 | Effective difficulty is well above the 2×/8× floors: ordinary creatures 2.2-6.4× HP, bosses 8.4-16.9× HP before Karma, player damage ×0.85. Karma's +3 levels also apply to bosses, putting a Meadows boss at 20× (AuditCombat §1) | `Boss Modifiers = Max1`; Karma thresholds `[90, 180]` (cap +2). Try in Shakedown: `Global.healthPerLevel 0.75`, `Global.damagePerLevel 0.15`, `Boss.damagePerLevel 0.05` |
| 5 | Backpacks out-carry Hauling: contents weigh half, and carry bonus multiplies by quality, so a quality-4 Mistlands pack gives +120 against Hauling's +100 at 100 (AuditEconomy §5) | All six packs `Weight Multiplier = 1`, `Carry Bonus = 0` (or 0.85 if harsh). Do not take 2.2.9 without review: it adds infinite quality scaling |
| 6 | SeedBed grows biome crops anywhere, bypassing Farming's level-60 any-biome reward (AuditEconomy §4) | Remove before the launch world, or accept the bypass |
| 7 | Focus 60 needs about 5,700 raw XP. At plausible rates a smith reaches Ashlands at about 44 and a herbalist at about 37 (AuditPace, conditional) | Measure first. Ready values: smith `XP per craft 2.5`, `per smelt 1.875`, `per upgrade 7.5`, `first craft 25`; Herbalist `Exp Gain Factor 3.5` |
| 8 | Three players cover all eleven professions (6 Land slots for 5, 3 Craft, 3 Road), so a guild never needs another guild's specialist (AuditEconomy §1) | Accept trade as comparative advantage (recommended), or change the quotas |
| 9 | Herbalist herbs are unknown to World Advancement Progression, so late tonics are not boss-key locked for the drinker (AuditEconomy §4) | Map them in a plugin, or accept consumables as tradeable past keys |
| 10 | SeaAnimals creatures get scaling and class XP but no EpicLoot table (name lookup only) | EpicLoot aliases: `SA_BlueShark→Tier0Mob`, `SA_Crocodile→Tier3Mob`, `SA_HammerHeadShark→Tier5Mob`, `SA_TigerShark→Tier7Mob` |
| 11 | SaunaMod meads last 1.2×, a free boost beside Herbalist | `[Mead] DurationMultiplier = 1` |

## 3. Onboarding without mods

The HUD says "Visit an Oathstone" but never says kills earn no class XP before an oath, or that the
Calling is chosen with stars in the skills window. Proposal: identical vanilla sign clusters at each
guild start (route, controls, no oath = no class XP), at the Oathstone (oath, 2 Land + 1 Craft + 1
Road), and at the crafting/market area (ladder rungs, craft vs use, personal keys, party within
100 m). Rewrite World Advancement Progression's blocked-action message to name the cause (AuditUX §3).

## 4. Thunderstore candidates

All shortlisted DLLs passed `scripts/screen-bundled-libs.sh` and ship no preloader patcher. None is
runtime-proven here.

| Wave | Mod | Why |
| --- | --- | --- |
| Try first | Ab5oluteZer0/CraftingSearch 1.0.2 | Recipe search; no settings, no new owner |
| Try first | Marins/CompactStatusEffects 1.1.2 | Readable buff names and timers for Oathbound + Herbalist + powers |
| Try first | RDMods/CustomMainMenu 1.5.0 | Lembitu logo, changelog and loading tips that teach the rules; replace its bundled Discord invite |
| Try first | Bagr/DamageMeter 3.7.0 + Bagr/CrewStats 1.4.1 | Boss-night recaps, death recaps, weekly profession recognition; observers only, client-reported |
| Try first | zolantris/ValheimScalability 1.0.0, Balrond/balrond_core_optimizer 0.2.1 | Rendering and CPU trials for heavy builds; A/B on the worst base |
| Trial, low maturity | Rollstuhltreter/OceanAdventures 1.0.0 | Ocean encounters on vanilla assets, server-owned; contracts and metal rewards off. First release 2026-10-03 |
| Consider | Biozip/HoverCompare 0.5.0 | Gear comparison; EpicLoot untested, keep `ReplaceGameTooltip=false` |
| Consider | Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock 1.4.15 | Current-container only; area ranges server-locked at 0 |
| Consider | Crystal/BetterChat 1.6.4 | Its cut reason (Clan) expired; Guilds' `/g` prefix still shares `Chat.InputText` |
| Consider | Skitale/ValheimAdminForge 0.5.0 | Server-authorised moderation and audit log; boss spawn off |
| Consider | RustyMods/Almanac 3.8.0 | Codex and guide NPC only; its currency, store, lottery, market and bounties off |
| Reject | ExtendedBosses, BossAdd, OdinsHollow, BiomeLords, BlightedWorldHeart, RtD packs, Mists of Avalor, ValheimBuildCamera, InventorySort, Chatter, RtDQuestForge, SealedTombstone, DiscoveryJournal | Headcount scaling, unsynced settings, stale ServerSync, second gear/magic owners, or Pack-rule breaks; reasons in the scout handbacks |

No maintained server-side character storage exists: both ServerCharacters packages are deprecated.
Progression stays client-owned (ADR-0010).

**Correction to ScoutContent.** Several rejections say a mod "reads world keys, which this server
blocks". On clients, World Advancement Progression answers `ZoneSystem.GetGlobalKey` from the local
player's private keys (`KeyManager.cs:354-366`), so client-side gates follow personal progress; only
checks run on the dedicated server see no keys. SeaAnimals' six key-gated creatures (Orca, Dolphin,
Crocodile on Eikthyr; WhiteShark, HammerHead, TigerShark on Bonemass) therefore spawn for players
who hold the key, assuming the zone owner holds it. Unofficial_EpicLoot_BountyAdditions' boss
rotation deserves a recheck on the same basis.

## 5. Add to the Shakedown

- Guild XP per member-hour and level at each boss, per guild.
- Class XP per hour solo against parties of two, three and four.
- Expand_World_Size open issues #28 (no swimming past the old edge) and #29 (rejoin hang in the
  extended area) on the exact 13,250 m world.
- OdinShip warship ballistas, tames and Oathbound companions at boss fights.
- Siege commander HP against CreatureManager scaling.
