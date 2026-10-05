# Premium review — balance and polish (2026-10-04)

A static review of the Pack against ADR-0019 to ADR-0024 and a one-month Run, followed by a
one-question-at-a-time interview with the owner. The research is first-party decompiles, configs and
upstream package metadata, kept in `local/premium-review-2026-10-04/` (summary in its `README.md`,
evidence in the eight handbacks beside it). Nothing in that research was run in game; the numbers it
proposes are Shakedown starting points, not measurements. Implementation is tracked in #87 (configs
and Pack), #88 (`Lembitu.Oathbound`), #89 (`Lembitu.Callings`), #90 (`Lembitu.Guide`) and #91
(`Lembitu.Guilds`).

## Decisions

- **Trade between guilds is an optional advantage, not a dependency** (owner, 2026-10-04). Fact:
  three players cover all eleven professions under the 2 Land + 1 Craft + 1 Road quota
  (`src/plugins/Lembitu.Callings/Professions.cs`; `local/premium-review-2026-10-04/AuditEconomy.md`
  §1). Callings stay as they are; ADR-0021's wording was corrected.
- **At most three guilds** (owner, 2026-10-04), one per SeparateSpawns start region, agreed before
  launch. Fact: Guilds 1.2.2 has no guild-count setting (`Plugin.cs` binds none), so the limit is the
  roster's. ADR-0019, `CONTEXT.md` and `docs/rules.md` said the count was uncapped and now say three.
- **A typical guild reaches about level 20 by Fader** (owner, 2026-10-04): Guilds
  `[4 - Progression] LevelXpGrowth = 1.15`, base 1000 and max 30 unchanged; to be applied. Fact: the
  stock 1.25 growth puts level 20 at 273,556 XP and a modelled guild of four at about level 14 by
  Fader; 1.15 puts level 20 at 88,211 XP (`AuditPace.md` §1, `AuditEconomy.md` §3, Guilds
  `Progress.cs:251-270`). Upgrade materials still gate each upgrade by biome.
- **Coin donations buy guild XP at 10 coins a point** (owner, 2026-10-04), the package default, in
  place of 50; to be applied. Donated coins are destroyed (`Plugin.cs:211`), so the Market's coins
  feed guild progress and leave the economy; level 20 would still cost about 880,000 coins.
- **Founding a guild is free** (owner, 2026-10-05): Guilds `[2 - Server] CreateCost = 0` in place of
  the package's 1,000 coins; to be applied (#87). A new character has no coins and admins cannot
  create a guild (Guilds 1.2.2 `guildadmin` offers only list, disband, leader and kick), so at 1,000
  no guild, guild ward, vault or chat would exist until after some Black Forest play
  (`GuildServer.cs:834-909`).
- **Guilds form in game and claim start regions** (owner, 2026-10-05; ADR-0028): every new player
  wakes at the sacrificial stones; a founded guild's leader claims an unclaimed region at its portal
  stone in the ring, after a confirmation window; the region follows membership (join gives its
  respawn and portal, leave returns to the stones, disband frees it); beds override as in vanilla.
  A new plugin, `Lembitu.Guilds`, owns the bridge; to be implemented (#91). Fact: SeparateSpawns assigns
  unrostered players to a random region with no setting to stop it (`GroupSpawnResolver.cs:158-177`).
- **Party XP reaches its 150% total at four members** (owner, 2026-10-04): `lembitu.oathbound.cfg`
  `[Party] FullPartySize = 4`, bonus 0.5 unchanged; to be applied. Two members earn about 58% of a
  kill each, three 44%, four 37.5%, eight 18.75%. Fact: under the linear curve to eight a three-player
  member earned 38%, so a party needed 2.6× a soloist's kill rate to match XP per hour
  (`src/plugins/Lembitu.Oathbound/PartyExperience.cs:157-159`; `AuditPace.md` §3). ADR-0019, ADR-0020
  and ADR-0022 amended.
- **Bosses keep up to four modifiers, without the three counter types** (owner, 2026-10-04, amended
  2026-10-05). `Boss Modifiers = Max4` stays; `levels.yml` sets `Boss.modifiers` chameleon, vortex and
  adaptive to chance 0; to be applied. The first answer kept every type; the owner reopened it after the
  research in Lessons (Path of Exile's 2022 modifier cut, Diablo III's banned combinations): those three
  punish a group's class mix rather than its skill (`AuditCombat.md` §3).
- **Enforcers lose the same three counters; ordinary creatures keep them** (owner, 2026-10-05):
  `karma.yml` `Enforcer.modifiers` chameleon, vortex and adaptive to chance 0; to be applied. Enforcers
  are group hunts like bosses; on ordinary creatures the counters are rare (about 0.44% per group
  roll each) and fights are short.
- **"Bosses for eight" means eight win with margin** (owner, 2026-10-05; `CONTEXT.md` tuning target,
  ADR-0019): eight average players with the biome's gear win on a first or second try, and six or
  seven skilled players can win. Grounded in Lessons: razor-edge tuning made about 1% of boss health
  decide job invitations in FFXIV.
- **Magic loot from creatures stays scarce: 0.36× the package's odds** (owner, 2026-10-05). EpicLoot's
  `Global Drop Rate Modifier = 0.6` divides the no-drop weight and multiplies the drop weights, so odds
  fall to 0.6² (`EpicLoot.cs:17081-17099`); boss tables have no empty outcome and still always drop.
  Kept as deliberate scarcity because bosses guarantee and smiths supply core gear; the overlay comment
  is to be corrected, along with its 92% minimum-effect claim (the staged weights are 80/18/2).
- **Backpacks help carrying, but below Hauling** (owner, 2026-10-05): all six AdventureBackpacks tiers
  `Weight Multiplier = 0.85` (package 0.5) and `Carry Bonus` halved (package 5/10/15/20/25/30 per
  quality level, so 2.5/5/7.5/10/12.5/15); to be applied. A quality-4 Mistlands pack then adds 60 carry
  instead of 120, under a Hauling master's +100 (`AuditEconomy.md` §5).
- **SeedBed stays as a planter with soil's rules and yields** (owner, 2026-10-05; ADR-0022): a bed
  refuses seeds whose plant cannot grow in its biome unless the planter has Farming 60, and its
  synced conversions match soil yields (for example barley and flax 5 → 10, carrot seeds 5 → 5, in
  place of 5 → 15); to be implemented in `Lembitu.Callings` and SeedBed's YAML. Fact: SeedBed 1.2.9
  has no biome check (`Germination.UseItem`, decompile `SeedBed.cs:852-874`) and defaults every
  entry to 5 → 15 (`SeedBed.cs:360-500`).
- **Creatures hit like vanilla hard mode again** (owner, 2026-10-05): `levels.yml` `Global.damage 1.2
  → 1.0`, so ordinary creatures hit 1.5× vanilla at level 1 through `Combat hard` alone; bosses keep
  `Boss.damage 1.5` (2.25×); health untouched; to be applied. The 1.2 had been raised on 2026-10-04
  for Oathbound's talents, but weapon-class talents add only about 5-15% (Lessons). With the per-level
  trim, an average Ashlands creature hits about 2.0× vanilla.
- **Our plugin locks BlacksmithingExpanded's settings** (owner, 2026-10-05; ADR-0022): its main
  config sync is synced but never locked (`AuditCombat.md` §2); `Lembitu.Callings` locks it at
  startup; to be implemented. This replaces the Shakedown's "BlacksmithingExpanded lock" check with a
  fix.
- **Azumatt's six mods move to Hexium** (owner, 2026-10-05; ADR-0026): latest Hexium releases for
  all six, with a per-pin download source in staging and the lock's version and SHA-256 still
  verified; AzuEPI's renamed layout keys re-checked and ProximityVoiceChat's new global voice kept
  off; to be implemented.
- **Drinking a tonic needs its biome's boss key, like food** (owner, 2026-10-05; ADR-0022):
  `Lembitu.Callings` maps Herbalist's herbs to biomes and refuses a tonic or elixir whose highest herb
  biome the drinker has no key for; to be implemented. Fact: World Advancement Progression passes
  materials it does not know, and it knows no Herbalist herb (`AuditEconomy.md` §4).
- **Five additions for the Shakedown** (owner, 2026-10-05): Ab5oluteZer0/CraftingSearch 1.0.2,
  Marins/CompactStatusEffects 1.1.2, Bagr/DamageMeter 3.7.0 with Bagr/CrewStats 1.4.1,
  Crystal/BetterChat 1.6.4 and Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock 1.4.15; to be
  pinned and tried. Evidence and suggested settings: `ScoutUI.md` §§1-2, 6-7 and `ScoutMeta.md` §§2-3.
  BetterChat's 2026-09 cut reason (Clan owned chat) has expired, but Guilds' `/g` prefix shares
  `Chat.InputText`; Quick Stack works on the open container only, with both area ranges server-locked
  at 0; DamageMeter's F-key defaults go through the keybind seed.
- **The Calling gets a window; stars become markers** (owner, 2026-10-05; ADR-0021, ADR-0022): a
  Calling button in the skills window opens a window grouped Land / Craft / Road with the 2-1-1 quota,
  levels and what a focus changes; readable anywhere, changeable only within about 10 m of the
  Oathstone; the row stars stay as read-only markers; to be implemented in `Lembitu.Callings`.
- **An in-game guide window in a new plugin, `Lembitu.Guide`** (owner, 2026-10-05; ADR-0027):
  chapters of short pages, a hotkey and an inventory button, shown on a character's first join, text in
  a server-synced file the admin edits; to be implemented. Signs were rejected for a real interface;
  Almanac was rejected as too broad.
- **Refusals name their cause and the guide page; firsts open their page once** (owner, 2026-10-05;
  ADR-0027): boss key, profession rung, class equipment rule or tonic key, each message written where
  the refusal is decided; first oath, first Calling window and first party open the matching page.
- **Keyboard and mouse only** (owner, 2026-10-05): the Calling and Guide windows are built for
  keyboard and mouse, and the Pack states that controllers are not supported; Oathbound's own actions
  are keyboard-only already (`AuditUX.md` summary item 8).
- **Small Pack fixes, all accepted** (owner, 2026-10-05); to be applied: Guilds 1.2.2 → 1.2.3
  (territory lost after reconnect or restart); client seeds for a conflict-free key layout (voice off B
  to mouse button 4, AzuHoverStats off H, Extra Snaps off Q/E, DetailedLevels off F4, PlanBuild off
  H/Q) and ServerQuickConnect pointed at the server with a blank password (`AuditUX.md` §§1, 3);
  SaunaMod `[Mead] DurationMultiplier = 1`; EpicLoot loot tables for hostile SeaAnimals by biome
  (`AuditCombat.md` §5).
- **Housekeeping, all accepted** (owner, 2026-10-05): add the measurements these decisions depend on
  to `docs/wiki/shakedown.md`; correct the outdated comments and docs the review found; close #67
  and #82-#86 as superseded by the 2026-10-04 concept.
- **Three Meadows-material items join the ladder by name** (owner, 2026-10-05; ADR-0023): Runner
  (Swift) elixir at Herbalist 40, SeaAnimals' saddle at Animal Handling 40, OdinShip's caulked wood at
  Sailing 40; crafting only, through `scripts/generate-ladder.py` policy; to be applied
  (`AuditEconomy.md` §4).
- **Boss re-kills escalate through Karma** (owner, 2026-10-04). Each boss kill adds 25 Karma plus
  level scaling (`config/enforced/CreatureManager/karma.yml` `gain`), and Karma levels apply to bosses
  as to any rolled creature (CreatureManager 1.2.5 `GetLevelBonus` and the level roll, decompile
  `CreatureManager.cs:13710-13727,17969-17983`); no setting exempts bosses. A night of repeat kills
  therefore summons each boss higher until Karma decays (15 minutes after the last gain, then 30 a
  minute). The review proposed zero boss Karma so carried late joiners meet the same fight; the owner
  kept the escalation.
- **Classes may differ, within ±25%** (owner, 2026-10-05). At the same biome, gear tier and boss
  keys, every class should kill a standard enemy within 25% of the others' time during the Run (class
  levels 1-40), each keeping its own strength. Recorded in `CONTEXT.md` as the class band; the
  Shakedown measures it.
- **Class power follows boss keys** (owner, 2026-10-05; ADR-0025). Oathbound's level-scaled power
  reads a power level: the class level capped at ten per personal boss key. Talent points, XP and the
  class level are untouched; to be implemented in `Lembitu.Oathbound`.
- **Spell growth is measured before it is trimmed** (owner, 2026-10-05; ADR-0025). Mage and Warlock
  spells keep 4% per power level, behind a server-locked setting in `Lembitu.Oathbound`; the
  Shakedown lowers it only if casters fall outside the class band.
- **Companions start the Shakedown at 0.75× damage** (owner, 2026-10-05; ADR-0025): wolf, whelp
  and Warlock skeletons, through a server-locked multiplier in `Lembitu.Oathbound`, on top of the
  power-level cap. Fact: a level-35 wolf has about 216 health and bites for 44 before talents
  (`HunterTree.cs:112-117`); companion kills earn the owner class XP (ADR-0022).
- **Combat difficulty is fixed whoever is online or present; rewards for grouping stay** (owner,
  2026-10-05; ADR-0019 sharpened). Party XP (150% at four) and the crew sailing bonus are kept as the
  incentive to group up. Difficulty moves only with biome, rolled level, Karma, modifiers and sieges
  by outpost biome.
- **Open check: Wishbone and Swamp key may drop once per player online.** Vanilla gives a drop flagged
  `m_onePerPlayer` one copy per player connected to the server, present or not
  (`assembly_valheim` `CharacterDrop.cs:137-139`, decompiled 2026-10-05). EpicLoot's `Default` boss
  drop mode leaves that flag, and its code tests the flag on exactly these two items
  (EpicLoot 0.14.13 `CharacterDrop_GenerateDropList_Patch`), which suggests vanilla sets it. That
  would contradict the decided one per kill (`config/enforced/randyknapp.mods.epicloot.cfg:31-36`).
  Settle with one Bonemass and one Elder kill while two players are connected.
- **Trim damage growth, keep health growth** (owner, 2026-10-05): `levels.yml`
  `Global.damagePerLevel 0.25 → 0.15` and `Boss.damagePerLevel 0.1 → 0.05`; health growth and the Hard
  preset unchanged; to be applied. Average Ashlands creature damage falls from about 2.8× to 2.4×
  vanilla; health stays about 7.6× effective. Grounded in the Lessons below: unfairness comes from
  damage spikes and stacked lethality, while tougher enemies are what grouping answers.
- **Karma caps at +2** (owner, 2026-10-05): `karma.yml` `thresholds: [90, 180]` in place of
  `[60, 120, 180]`; to be applied. A flat +2 nearly triples a Meadows creature's health but adds about
  60% in the Ashlands, so the top tier fell hardest on early gatherers. Boss re-kill escalation stays.

## Exclusions

- **Not taken for the Shakedown** (owner, 2026-10-05): RDMods/CustomMainMenu,
  zolantris/ValheimScalability, Rollstuhltreter/OceanAdventures, Skitale/ValheimAdminForge,
  Biozip/HoverCompare and shudnal/Compass, each offered after the review (`ScoutUI.md`,
  `ScoutMeta.md`, `ScoutContent.md`, `StackHealth.md`).

## Lessons

- **Oathbound's power is uneven by class** (research, 2026-10-05; Oathbound 0.21.14 decompile under
  `/tmp/lembitu-fit/ClassOverhauls/`, and the shipped `dist/plugins/Oathbound/PLAYER-GUIDE.md`).
  Weapon hits of weapon classes get only the tree's flat damage bonus (`Plugin.cs:2015-2040`,
  `MartialAttackPatch`); class abilities gain 1% per level and Monk fists the same
  (`ClassMagic.cs:215`, `MartialCombat.cs:68-75`). Mage and Warlock spells need no staff
  (`TryCastSpell`, `Plugin.cs:11256-11335`; guide line 123) and gain 4% per level, 4.16× at 80
  (`ClassMagic.cs:220-251`; guide line 77); Mage spells add up to 25% from Elemental Magic
  (`Plugin.cs:12008`) and Ember Bolt fires 1, 2 or 4 bolts by talent (`MageTuning.cs:7`). The Mage
  tree gives 20 Eitr at its root and 85 when full, before food (guide line 123). Mage and Warlock may
  use any weapon; only metal armour is barred (`Equipment.cs:63-67`). The Hunter's wolf has
  80 + 4 × (level − 1) health and 10 + (level − 1) bite damage before talents (`HunterTree.cs:112-117`).
  Not measured in play: Eitr sustain, bolt hit rates and pet uptime.
- **What other games established about balance** (research, 2026-10-05; five handbacks in
  `local/premium-review-2026-10-04/Research-*.md`, each with full citations). Facts only; the
  decisions above are the owner's.
  - *Fixed difficulty and grouping.* Vanilla Valheim adds 30% effective enemy health and 4% damage per
    extra player within 100 m, up to five (`Game.cs` `m_healthScalePerPlayer`, decompiled from the
    1.0.12 reference assembly). In 2005 WoW, grouping rose where content was too hard to solo, yet
    characters that never grouped levelled about twice as fast (Ducheneaut et al., CHI 2006).
    Diablo III cut extra-player health from 70% to 50% because solo felt more efficient (patch
    1.0.8). Blizzard's Flex raids left fixed raid sizes over roster and scheduling friction, keeping
    a fixed size only for razor-edge tuning ("Flex Lives", 2013).
  - *Group XP.* Documented party pools: FFXI 120/135/160% for 2/3/4 players; Lineage II Chronicle 3
    raised two- and four-member bonuses to +30% and +50% to help small parties; Ragnarok +25% per
    extra member. No source sets a threshold that changes behaviour.
  - *Difficulty curves.* No source gives a safe growth rate or one-shot frequency. Challenge-skill
    balance is a framework, not a number (Chen 2007; a 2023 preregistered study found no enjoyment
    difference across easy, balanced and hard). Practitioners tie fairness to readable, telegraphed
    attacks and to relative budgets such as share of monster health per hit (Blizzard stat squish;
    God of War GDC 2019). Iron Gate states Valheim gets harder further in. Path of Exile's Delirium
    fixes cut stacked lethality and modifier count and added clearer warnings.
  - *Escalation.* Documented escalation systems are opt-in or timed (Hades' Pact, Delirium depth,
    Risk of Rain's timer); persistent regional kill pressure like Karma has no measured precedent.
  - *Class balance.* No co-op game publishes a damage band. WoW accepts distinct strengths but warns
    that razor-edge checks cause class stacking; FFXIV traced job exclusion to about 1% excess boss
    health. Companion fixes are documented: Warframe halved Wukong's autonomous clone damage, WoW
    Season of Discovery cut pet stat inheritance when pets passed twice a player's health, Diablo IV
    capped minion scaling, Path of Exile tied minion power to gear. A 40-player study found
    complementary roles raised social engagement (Harris 2019).
  - *Affixes and loot.* Path of Exile cut rare monsters from two (up to four) modifiers to one because
    hard pairs came too often (2022). Diablo III removed Invulnerable Minions and banned Jailer with
    Knockback, Nightmarish or Vortex because gear could not overcome them (1.0.4). Scarcity and
    dry-streak protection are separable: Diablo IV guaranteed a boss legendary at level 35+, and
    Diablo III's Loot 2.0 cut useless results rather than rarity.
