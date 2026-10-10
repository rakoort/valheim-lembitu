# Premium review — balance and polish (2026-10-04)

A static review of the Pack against ADR-0019 to ADR-0024 and a one-month Run, followed by a
one-question-at-a-time interview with the owner. The research is first-party decompiles, configs and
upstream package metadata, kept in `local/premium-review-2026-10-04/` (summary in its `README.md`,
evidence in the eight handbacks beside it). Nothing in that research was run in game; the numbers it
proposes are Shakedown starting points, not measurements. Implementation is tracked in #87 (configs
and Pack), #88 (`Lembitu.Oathbound`), #89 (`Lembitu.Callings`), #90 (`Lembitu.Guide`) and #91
(`Lembitu.Guilds`).

## Decisions

### 2026-10-06 grilling, Pack v17

Owner decisions, before the v17 native gate (#99); the Run remains on v16 until cutover. The ADRs
are the authoritative policy records; this log indexes tickets and records the two Pack choices.
Earlier entries below retain dated history, not conflicting current instructions.

| Decision | Ticket | Record |
| --- | --- | --- |
| Each class keeps XP and talents; free switch/reset at the Oathstone, tree anywhere after first oath | #92 | ADR-0031 |
| BetterArchery returns with server-locked gameplay and personal UI preferences | #93 | Pack decision below |
| Item_Requirement and all 367 rules leave; Deep North crafting/equipping requires the personal Fader key | #94 | ADR-0032 |
| Brewer's grade replaces drinker-skill scaling; graded mead bases survive fermentation and Market | #95 | ADR-0032 |
| Land mastery before Fader, Road at Fader, Craft at Kall; toned pace and master-not-god ramps, band unchanged | #96 | ADR-0032 |
| Fixed level-1 five-player bosses, 1–4 modifiers; creature base health 2, +75% per star, about 20% traits; Combat hard stays; month ends at Kall, class power stays 80 | #97 | ADR-0033 |
| EpicLoot returns to stock apart from recipe-known drops and the SeaAnimals integration | #98 | Pack decision below |
| Ship everything together only after native acceptance; no live deployment in this work | #99 | Pack integration |
| Read XP and boss fights after every session, correct pace by group weekly | #100 | shakedown.md per-session watch |

**BetterArchery 2.0.2 returns** (ishid4, latest package dated 2026-09-20), reversing the
2026-10-04 cut for unsynced gameplay. Lembitu.Oathbound locks BetterArchery ConfigEntry objects
through server-locked Jotunn values at load, server arrival and local edit. Gameplay uses stock:
quiver on (turned off on 2026-10-10: AzuExtendedPlayerInventory forces it off, and a locked-on quiver
added two inventory rows that held any item; the lock no longer covers it); arrow improvements on,
velocity 70, gravity 15, accuracy 0, aim direction (0, 0.05, 0);
bow draw movement reduction, crouch draw and wooden arrows anywhere on; retrievable arrows on,
disappear time 60, disappear on hit off, solid collider off, auto pickup off and the package's
retrieve-list string unchanged. Quiver slot/model/HUD positions and hotkeys, Bow Zoom, draw-cancel
keys, crosshair toggles, sneak-damage readout and nocked-arrow visual stay player preferences.
Ranger True Flight (+10% projectile speed) and Snapshot (+50% for five seconds after dodge) stack
on top. Both client and server install it: its decompile registers quiver network prefabs in
ZNetScene (1171–1191), items in ObjectDB (1200–1222), and patches ObjectDB (3143–3158)
(/tmp/lembitu-research/ProgressionCluster/BetterArchery.cs, worker evidence). The declared
BepInEx 5.4.1501 dependency requires the documented stage-stack override. The live lock still needs
native proof (#93).

**EpicLoot returns to stock** (#98). The only deliberate server deviation is Item Drop Limits =
PlayerMustKnowRecipe: stock world-key filtering would stay at Meadows because this Run blocks
world keys. Global Drop Rate Modifier returns 0.6→1, Shard Stone Drop Ratio 0.1→0.2, Boss Trophy
Drop Mode Default→OnePerPlayerNearBoss (trophies, Wishbones and swamp keys per player within
100 m), Temper Fail Destroys Item true→false and Enable Bounty Limit true→false. Stock entries
the Run depends on may stay pinned under CONTEXT.md's Enforced config rule. The SeaAnimals
loot-table patch stays as an integration, not a balance override. Client seed restores Magic Blue,
Rare Yellow, Epic Purple, Legendary Teal, Mythic Orange, Ancient Red, Set Item #26ffff and Use
Generated Magic Item Names = true, including upgrading a player whose cfg still has muted colours.

### Earlier history

- **Trade between guilds is an optional advantage, not a dependency** (owner, 2026-10-04). Fact:
  three players cover all eleven professions under the 2 Land + 1 Craft + 1 Road quota
  (`src/plugins/Lembitu.Callings/Professions.cs`; `local/premium-review-2026-10-04/AuditEconomy.md`
  §1). Callings stay as they are; ADR-0021's wording was corrected.
- **At most three guilds** (owner, 2026-10-04), one per SeparateSpawns start region, agreed before
  launch. Fact: Guilds 1.2.2 has no guild-count setting (`Plugin.cs` binds none), so the limit is the
  roster's. ADR-0019, `CONTEXT.md` and `docs/rules.md` said the count was uncapped and now say three.
- **A typical guild reaches about level 20 by Fader** (owner, 2026-10-04): Guilds
  `[4 - Progression] LevelXpGrowth = 1.15`, base 1000 and max 30 unchanged; applied 2026-10-05 in
  `config/enforced/adrian.valheim.guilds.cfg` (#87). Fact: the
  stock 1.25 growth puts level 20 at 273,556 XP and a modelled guild of four at about level 14 by
  Fader; 1.15 puts level 20 at 88,211 XP (`AuditPace.md` §1, `AuditEconomy.md` §3, Guilds
  `Progress.cs:251-270`). Upgrade materials still gate each upgrade by biome.
- **Coin donations buy guild XP at 10 coins a point** (owner, 2026-10-04), the package default, in
  place of 50; applied 2026-10-05 (#87). Donated coins are destroyed (`Plugin.cs:211`), so the Market's coins
  feed guild progress and leave the economy; level 20 would still cost about 880,000 coins.
- **Founding a guild is free** (owner, 2026-10-05): Guilds `[2 - Server] CreateCost = 0` in place of
  the package's 1,000 coins; applied 2026-10-05 (#87). A new character has no coins and admins cannot
  create a guild (Guilds 1.2.2 `guildadmin` offers only list, disband, leader and kick), so at 1,000
  no guild, guild ward, vault or chat would exist until after some Black Forest play
  (`GuildServer.cs:834-909`).
- **Guilds form in game and claim start regions** (owner, 2026-10-05; ADR-0028): every new player
  wakes at the sacrificial stones; a founded guild's leader claims an unclaimed region at its portal
  stone in the ring, after a confirmation window; the region follows membership (join gives its
  respawn and portal, leave returns to the stones, disband frees it); beds override as in vanilla.
  A new plugin, `Lembitu.Guilds`, owns the bridge; implemented 2026-10-05 in `src/plugins/Lembitu.Guilds`
  (#91). Fact: SeparateSpawns assigns unrostered players to a random region with no setting to stop it
  (`GroupSpawnResolver.cs:158-177`). Native proof on 2026-10-05: a fresh guildless character woke at
  the stones (`~/lembitu-native-tests/20261005T164425Z-guilds91-final/guildless-stones.png`). The
  respawn screenshot was requested during the respawn transition and ended the scenario; completed respawn,
  claim UI, regional travel, leaving/disbanding, restart and missing-plugin refusal remain unproven.
  Two-guild races, non-leader claims and non-member travel require owner checks with two accounts.
- **Party XP reaches its 150% total at four members** (owner, 2026-10-04): `lembitu.oathbound.cfg`
  `[Party] FullPartySize = 4`, bonus 0.5 unchanged; applied 2026-10-05 in `Lembitu.Oathbound`. Two
  members earn about 58% of a
  kill each, three 44%, four 37.5%, eight 18.75%. Fact: under the linear curve to eight a three-player
  member earned 38%, so a party needed 2.6× a soloist's kill rate to match XP per hour
  (`src/plugins/Lembitu.Oathbound/PartyExperience.cs:157-159`; `AuditPace.md` §3). ADR-0019, ADR-0020
  and ADR-0022 amended.
- **Bosses keep up to four modifiers, without the three counter types** (owner, 2026-10-04, amended
  2026-10-05). `Boss Modifiers = Max4` stays; `levels.yml` sets `Boss.modifiers` chameleon, vortex and
  adaptive to chance 0; applied 2026-10-05 (#87). The first answer kept every type; the owner reopened it after the
  research in Lessons (Path of Exile's 2022 modifier cut, Diablo III's banned combinations): those three
  punish a group's class mix rather than its skill (`AuditCombat.md` §3).
- **Enforcers lose the same three counters; ordinary creatures keep them** (owner, 2026-10-05):
  `karma.yml` `Enforcer.modifiers` chameleon, vortex and adaptive to chance 0; applied 2026-10-05 (#87). Enforcers
  are group hunts like bosses; on ordinary creatures the counters are rare (about 0.44% per group
  roll each) and fights are short.
- **“Bosses for eight” (superseded 2026-10-06 by ADR-0033: five players)** (owner, 2026-10-05; `CONTEXT.md` tuning target,
  ADR-0019): eight average players with the biome's gear win on a first or second try, and six or
  seven skilled players can win. Grounded in Lessons: razor-edge tuning made about 1% of boss health
  decide job invitations in FFXIV.
- **Magic loot scarcity (superseded 2026-10-06 by #98: stock odds)** (owner, 2026-10-05). EpicLoot’s
  `Global Drop Rate Modifier = 0.6` divides the no-drop weight and multiplies the drop weights, so odds
  fall to 0.6² (`EpicLoot.cs:17081-17099`); boss tables have no empty outcome and still always drop.
  Kept as deliberate scarcity because bosses guarantee and smiths supply core gear; the overlay comment
  now states 0.36× and the staged weights (corrected 2026-10-05, #87: it carries no 92% claim any
  more — the staged MagicEffectsCount weights are 80/18/2).
- **Backpacks help carrying, but below Hauling** (owner, 2026-10-05): all six AdventureBackpacks tiers
  `Weight Multiplier = 0.85` (package 0.5) and `Carry Bonus` halved (package 5/10/15/20/25/30 per
  quality level). **Rounding decision (owner, 2026-10-05): round down to 2/5/7/10/12/15**, Meadows
  through Mistlands, because AdventureBackpacks 2.2.5 binds `Carry Bonus` as `ConfigEntry<int>`;
  fractional halves cannot be expressed. Applied in `config/enforced/vapok.mods.adventurebackpacks.cfg`
  (#87): Satchel 2, Rugged Backpack 5, Bloodbag Wetpack 7, Arctic Sherpa Pack 10, Lox Hide Knappsack 12,
  Explorers Wisppack 15. A quality-4 Mistlands pack then adds 60 carry instead of 120, under a Hauling
  master's +100 (`AuditEconomy.md` §5).
- **SeedBed stays as a planter with soil's rules and yields** (owner, 2026-10-05; ADR-0022): a bed
  refuses seeds whose plant cannot grow in its biome unless the planter has Farming 60, and its
  synced conversions match soil yields (for example barley and flax 5 → 10, carrot seeds 5 → 5, in
  place of 5 → 15); implemented 2026-10-05 in `Lembitu.Callings` and
  `config/enforced/blacks7ar.SeedBed.yml`. Fact: SeedBed 1.2.9
  has no biome check (`Germination.UseItem`, decompile `SeedBed.cs:852-874`) and defaults every
  entry to 5 → 15 (`SeedBed.cs:360-500`). The ten enforced conversions are exactly the game's ten
  cultivator Plants with grown Pickable yields (native prefab readout,
  `~/lembitu-native-tests/20261005T151436Z-callings/native-plant-pickable-soil.json`: barley and
  flax Pickable amount 2, carrot/onion/turnip 1, seed pieces and Mistlands mushrooms 3/1/1); the
  ten other enforced inputs have no cultivator piece and keep SeedBed's 5 → 15 defaults. In play
  the same session proved one full cycle: a Meadows bed refused barley at Farming 30 (E and
  item-on-bed paths, exact message) and at Farming 60 planted it, 5 in → 10 out.
- **Creatures hit like vanilla hard mode again** (owner, 2026-10-05): `levels.yml` `Global.damage 1.2
  → 1.0`, so ordinary creatures hit 1.5× vanilla at level 1 through `Combat hard` alone; bosses keep
  `Boss.damage 1.5` (2.25×); health untouched; applied 2026-10-05 (#87). The 1.2 had been raised on 2026-10-04
  for Oathbound's talents, but weapon-class talents add only about 5-15% (Lessons). With the per-level
  trim, an average Ashlands creature hits about 2.0× vanilla.
- **Our plugin locks BlacksmithingExpanded's settings** (owner, 2026-10-05; ADR-0022): its main
  config sync is synced but never locked (`AuditCombat.md` §2); `Lembitu.Callings` locks it at
  startup; implemented 2026-10-05. This replaces the Shakedown's "BlacksmithingExpanded lock" check with a
  fix.
- **Azumatt's six mods move to Hexium** (owner, 2026-10-05; ADR-0026): latest Hexium releases for
  all six, with a per-pin download source in staging and the lock's version and SHA-256 still
  verified; AzuEPI's renamed layout keys re-checked and ProximityVoiceChat's new global voice kept
  off; applied 2026-10-05 (#87): the six pins moved with a `Download sources` table,
  `stage-stack.sh` verifies each source URL names the pin's version and hashes the bytes as before,
  all six screened clean, AzuEPI 2.6.1 kept every pinned key (its new layout keys are unsynced
  client preferences), `Allow Global Voice` pinned Off, and the Hexium `cdn.hexium.gg` fetches ran
  for the real staging.
- **Drinking a tonic needs its biome's boss key, like food** (owner, 2026-10-05; ADR-0022):
  `Lembitu.Callings` maps Herbalist's herbs to biomes and refuses a tonic or elixir whose highest herb
  biome the drinker has no key for; implemented 2026-10-05. Fact: World Advancement Progression passes
  materials it does not know, and it knows no Herbalist herb (`AuditEconomy.md` §4). Native check
  2026-10-05 (`~/lembitu-native-tests/20261005T151436Z-callings/`): two `BH_LargeHealthTonic` drinks
  without a personal Mistlands key were refused with the exact rule message and consumed nothing; the
  permitted-drink and key-removal legs are unproven — the console refused `setprivatekey` to the
  native-admin client ("Unauthorized", `devcommands` stayed False), listed for the Shakedown with a
  server-side key grant.
- **Five additions for the Shakedown** (owner, 2026-10-05): Ab5oluteZer0/CraftingSearch 1.0.2,
  Marins/CompactStatusEffects 1.1.2, Bagr/DamageMeter 3.7.0 with Bagr/CrewStats 1.4.1,
  Crystal/BetterChat 1.6.4 and Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock 1.4.15; pinned,
  staged and screened 2026-10-05 (#87, with ConditionalConfigSync 1.0.6 as BetterChat's declared
  dependency); the in-play trial is the Shakedown's. Evidence and suggested settings: `ScoutUI.md` §§1-2, 6-7 and `ScoutMeta.md` §§2-3.
  BetterChat's 2026-09 cut reason (Clan owned chat) has expired, but Guilds' `/g` prefix shares
  `Chat.InputText`; Quick Stack works on the open container only, with both area ranges server-locked
  at 0. The owner removed CrewStats and DamageMeter from both Pack and server later
  on 2026-10-05 after CrewStats' window covered the inventory. Their overlays and
  keyboard seeds were removed too; the other four additions remain.
- **Two Pack additions from the progression sweep** (owner, 2026-10-06): dsoltyka/LiveExperienceTracker
  1.0.3, live skill-XP rows above the health bar, and Somedudethattrytomakemodwork/oathbound_addon
  1.0.1, stay/heel/recall orders for the Hunter's wolf. Both client-only; the addon's window key is
  seeded from G (vanilla 1.0's radial menu) to Y, free in vanilla and every staged plugin except
  AdventureBackpacks' Outward-Mode quick-drop. The rest of the 2026-10-06 sweep (all 12,684 Valheim
  packages, 251 post-1.0 progression candidates) found no new progression owner worth adopting.
  Native check 2026-10-06 (`~/lembitu-native-tests/20261006T072318Z-pack-additions/`): the full-Pack
  server install withheld both; a client installed from a freshly built Pack loaded both, the addon
  applied all seven patches and hooked Oathbound 0.21.14's `LateUpdate`, the Y seed survived first
  run, and the tracker painted an Explorer row. Wolf orders themselves need a Hunter with a wolf and
  are a Shakedown check.
- **The cook grades dishes, feeds the trades, and food spoils** (owner, 2026-10-06; ADR-0029): the
  cook's grade yes, at +2.5% food and +12.5% shelf life per grade above 1 (grade 5 at Cooking 100);
  feast fellowship dropped as a party reward rather than a cooking one; work meals yes, +10 to one
  Land or Road profession's perks while the meal lasts; FineDining's spoilage yes, with preserved
  dishes, cold land and the Icebox as storage, fresh food at 110%, a master's dish keeping longer
  and the package lifetimes kept. Implemented 2026-10-06 in `Lembitu.Callings` 0.4.0 and the
  FineDining overlay.
- **Two stack bugs fixed** (owner, 2026-10-06): a poison kill now pays Oathbound class XP to the
  player who poisoned (`Lembitu.Oathbound` 0.3.0), and Herbalist's mead scaling applies once per
  drink instead of compounding (`Lembitu.Callings` 0.4.0). Herbalist's own formula is kept as
  shipped, including its one-hour floor for resist, Tasty and Lingering meads, which leaves the
  drinker's skill no effect on meads shorter than 30 minutes; a cap or vanilla durations are the
  open alternatives.
- **The Calling choice is balanced by time saved, within a band** (owner, 2026-10-06; ADR-0030): a
  focus is judged by time saved per hour of play for a player alone, within each group, and the best
  pick may save at most 1.25 times the worst; Craft by how much its goods are wanted. Professions keep
  their own levelling; outliers are corrected perks first, both ends toward the middle, nothing
  trimmed before data. Work meals and EpicLoot keep counting for perks; EpicLoot is watched. The
  steep curve starts at 10 (was 30). Wood Cutting, Fishing and Hauling get milestones at 50 (log
  splitter, quick bite, steady overload). Smith and herbalist XP take half of the audit's step. An XP
  log and timed tasks measure it. The Run starts on 2026-10-06 without a separate Shakedown; this
  world is the Run's world.
- **The Calling gets a window; stars become markers** (owner, 2026-10-05; ADR-0021, ADR-0022): a
  Calling button in the skills window opens a window grouped Land / Craft / Road with the 2-1-1 quota,
  levels and what a focus changes; readable anywhere, changeable only within about 10 m of the
  Oathstone; the row stars stay as read-only markers; implemented 2026-10-05 in `Lembitu.Callings`.
  Native check 2026-10-05 (`~/lembitu-native-tests/20261005T151436Z-callings/`): the button opens the
  window and the first open sets `lembitu.callings.window-seen=1`; add/drop at the Oathstone works with
  the named confirmation (No reopens unchanged, Yes lands the skill on its shadow, 40 → 0); star hover
  shows a tooltip and star clicks change no Calling.
- **An in-game guide window in a new plugin, `Lembitu.Guide`** (owner, 2026-10-05; ADR-0027):
  chapters of short pages, a hotkey and an inventory button, shown on a character's first join, text in
  a server-synced file the admin edits; implemented 2026-10-05 (#90). Native proof in
  `~/lembitu-native-tests/20261005T161006Z-guide90d/`: a genuinely fresh character sees First steps
  once on this join, all seven chapter titles are legible, real F1 closes/opens/closes only the Guide,
  and normal W movement after close covers 5.781 m. Missing-Guide join refusal was observed in
  `~/lembitu-native-tests/20261005T123002Z-demo/` (server log lines 1529 and 1531). The final permitted script stopped when
  its Tab press left the inventory closed; inventory controls, live edits/client non-override and
  same-character rejoin remain unproven and are listed in the Shakedown. Signs were rejected for a
  real interface; Almanac was rejected as too broad.
- **Refusals name their cause and the guide page; firsts open their page once** (owner, 2026-10-05;
  ADR-0027): boss key, profession rung, class equipment rule or tonic key, each message written where
  the refusal is decided; first oath, first Calling window and first party open the matching page.
  Implemented in Guide's per-character firsts and the WAP/Item_Requirement refusal configuration;
  native refusal wording and first-oath/first-Calling auto-opening were not reached before the
  final script stopped. First party is the owner's end-of-build check with two Steam accounts.
- **Keyboard and mouse only** (owner, 2026-10-05): the Calling and Guide windows are built for
  keyboard and mouse, and the Pack states that controllers are not supported; Oathbound's own actions
  are keyboard-only already (`AuditUX.md` summary item 8).
- **Small Pack fixes, all accepted** (owner, 2026-10-05); applied 2026-10-05 (#87): Guilds 1.2.2 → 1.2.3
  (territory lost after reconnect or restart; 1.2.4 exists but is a feature release — name
  over-heads, corner posts — so it was not taken); client seeds for the accepted key layout: voice
  Mouse3, AzuHoverStats Delete, Extra Snaps brackets, DetailedLevels F8, PlanBuild Insert/Minus/Equals
  with RightAlt, and CompactStatusEffects Quote. Quick Stack uses Ctrl+U, restock Shift+U, sort LeftAlt+U and trash
  RightAlt+U, moving off SocialSystem's P, Oathbound's L, CraftyBoxes' Alt+O and HoverStats' Delete.
  Decompile audit covered all 77 staged managed plugin assemblies, vanilla's keyboard defaults in
  `assembly_utils` `ZInput.ResetKBMButtons`, and the full `assembly_valheim` code.
  Quote/U have no action bindings elsewhere. PageUp/PageDown were rejected because
  vanilla uses them for chat scroll; F10 also serves SaunaMod's optional editor.
  Quick Stack checks its modifiers and receives chords. F1 stays the Guide's. ServerQuickConnect
  points at the server with a blank password (`AuditUX.md` §§1, 3); SaunaMod pins
  `nekitker.saunamod.cfg` `[Mead] DurationMultiplier = 1`; EpicLoot aliases hostile SeaAnimals
  by biome (`AuditCombat.md` §5) through a server-synced patch file.
- **Housekeeping, all accepted** (owner, 2026-10-05): add the measurements these decisions depend on
  to `docs/wiki/shakedown.md`; correct the outdated comments and docs the review found; close #67
  and #82-#86 as superseded by the 2026-10-04 concept.
- **Three named ladder exceptions (retired 2026-10-06 by ADR-0032, #94)** (owner, 2026-10-05; ADR-0023): Runner
  (Swift) elixir at Herbalist 40, SeaAnimals' saddle at Animal Handling 40, OdinShip's caulked wood at
  Sailing 40; crafting only, through `scripts/generate-ladder.py` `ITEM_FLOORS` policy; regenerated
  2026-10-05 (#87) from the original native dump (SHA-256
  `3b3b956d67769a48da0bb3c8bc52ebaf0108f9839df15a02376a6e5d68ecd8ec`): exactly three added rules,
  no other rule or header changes (`AuditEconomy.md` §4).
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
  class level are untouched; implemented 2026-10-05 in `Lembitu.Oathbound`.
- **Spell growth is measured before it is trimmed** (owner, 2026-10-05; ADR-0025). Mage and Warlock
  spells keep 4% per power level, behind a server-locked setting in `Lembitu.Oathbound` (`[Power]
  SpellGrowth`, implemented 2026-10-05); the
  Shakedown lowers it only if casters fall outside the class band.
- **Companions start the Shakedown at 0.75× damage** (owner, 2026-10-05; ADR-0025): wolf, whelp
  and Warlock skeletons, through a server-locked multiplier in `Lembitu.Oathbound`
  (`[Companions] DamageMultiplier`, implemented 2026-10-05), on top of the
  power-level cap. Fact: a level-35 wolf has about 216 health and bites for 44 before talents
  (`HunterTree.cs:112-117`); companion kills earn the owner class XP (ADR-0022).
- **Combat difficulty is fixed whoever is online or present; rewards for grouping stay** (owner,
  2026-10-05; ADR-0019 sharpened). Party XP (150% at four) and the crew sailing bonus are kept as the
  incentive to group up. Difficulty moves only with biome, rolled level, Karma, modifiers and sieges
  by outpost biome.
- **Open check: Wishbone and Swamp key may drop once per player online** (superseded by v17). Vanilla
  gives a drop flagged `m_onePerPlayer` one copy per player connected to the server, present or not
  (`assembly_valheim` `CharacterDrop.cs:137-139`, decompiled 2026-10-05). EpicLoot's `Default` boss
  drop mode left that flag, which would have contradicted the then-decided one per kill. From v17 the
  owner chose stock `Boss Trophy Drop Mode = OnePerPlayerNearBoss`
  (`config/enforced/randyknapp.mods.epicloot.cfg:17-18`): one per player within 100 m of the kill, so
  the check no longer applies.
- **Trim damage growth, keep health growth** (owner, 2026-10-05): `levels.yml`
  `Global.damagePerLevel 0.25 → 0.15` and `Boss.damagePerLevel 0.1 → 0.05`; health growth and the Hard
  preset unchanged; applied 2026-10-05 (#87). Average Ashlands creature damage falls from about 2.8× to 2.4×
  vanilla; health stays about 7.6× effective. Grounded in the Lessons below: unfairness comes from
  damage spikes and stacked lethality, while tougher enemies are what grouping answers.
- **Karma caps at +2** (owner, 2026-10-05): `karma.yml` `thresholds: [90, 180]` in place of
  `[60, 120, 180]`; applied 2026-10-05 (#87). A flat +2 nearly triples a Meadows creature's health but adds about
  60% in the Ashlands, so the top tier fell hardest on early gatherers. Boss re-kill escalation stays.

## Exclusions

- **Not taken for the Shakedown** (owner, 2026-10-05): RDMods/CustomMainMenu,
  zolantris/ValheimScalability, Rollstuhltreter/OceanAdventures, Skitale/ValheimAdminForge,
  Biozip/HoverCompare and shudnal/Compass, each offered after the review (`ScoutUI.md`,
  `ScoutMeta.md`, `ScoutContent.md`, `StackHealth.md`).

## Lessons

- **Earlier 70-pin Pack key proof, partly retired** (native, 2026-10-05; #87): the
  client retained the corrected seeds and opened CompactStatusEffects with Quote.
  The same evidence also exercised CrewStats/DamageMeter, both removed later that
  day; their bindings are no longer part of the Pack. CompactStatusEffects still paints `Close (F8 / ESC)`
  caption; it is not the active binding. Use Quote or Escape. Evidence on astral-tricep:
  `~/lembitu-native-tests/20261005T131116Z-pack87-seeds-ui/` (generated config values, key events and
  the three screenshots). Full-Pack demo `20261005T123002Z-demo` verified all 337 enforced entries
  and joined the same Pack; its loader reported 69 loaded / 1 skipped / 0 failed server-side and
  71 loaded / 0 skipped / 0 failed client-side, with no missing game-member exceptions.

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
- **The #88 native boundary is explicit** (native, 2026-10-05): all three new features logged `on`,
  and Shieldbearer/Valkyrie bow refusals named their melee rule and the Oath and class page in
  `/home/ra/lembitu-native-tests/20261005T161527Z-oathbound88-final/acceptance88.json`; the
  Shieldbearer screenshot visibly shows the full message. A retained level-30 Mage with no keys
  had 29 available talent points in `20261005T135909Z-oathbound88` (`step-0012.json`). Class-power
  and companion ratios, and spell-growth/client-override behaviour remain **unproven**: the final
  scene teleport was refused before taking Mage, and the Hunter picker did not expose its button.
  These are Shakedown checks, not claims that startup or one spell hit proved the balance formulas.
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
