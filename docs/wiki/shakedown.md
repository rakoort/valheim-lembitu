# Shakedown: what to measure

The Shakedown was to be played on a world that will be discarded (`CONTEXT.md`). On 2026-10-06 the
owner started the Run without one (ADR-0030), so these checks are now made during the Run, on its
world. They measure what the decisions could only estimate (ADR-0019 to ADR-0033). Each check below
names what to do, what to record, and the decision it feeds. Record results in this page, dated, with
the pack version, and change the decision's ADR or overlay when a number moves. Lifting a weak pick
costs players nothing; a trim takes away what they chose, so trims come early and are announced.

`Lembitu.Oathbound` and `Lembitu.Callings` exist since 2026-10-04 (ADR-0022).
Pack v17 retires Item_Requirement and the ladder (ADR-0032). Every check marked *plugin* depends
on the plugins; their startup lines
(`<feature>: on`) belong in the record of the pack the Shakedown runs.

## Progression pace

| Check | Do and record | Feeds |
| --- | --- | --- |
| Class level pace | Each player's Oathbound class level at the end of every session, and which bosses are down. | ADR-0022: no talent cap and stock XP; revisit only if level 80 arrives well before Fader. |
| Focus pace by group | Read real level, focus, raw and earned XP after every session; Land masters a little before Fader, Road at Fader, Craft at Kall. Correct toward each group weekly, keeping its 1.25× band. | ADR-0032; #100. |
| Non-focus pace | A non-focus profession some player uses anyway: level reached and hours spent, from the `Profession XP:` lines (raw against earned). | ADR-0021's steep curve (full to 10, half to 60, quarter to 80, a tenth beyond). |
| Skill XP rows | Whether LiveExperienceTracker's rows above the health bar show a non-focus profession earning visibly less than a focus once past 10, and whether players read them. | ADR-0021's steep curve; the Pack's readouts. |
| Profession band | Per profession, raw XP per hour of play from the `Profession XP:` lines, and the time a standard task takes at levels 10, 30, 50 and 70 (timed on the test host). Within Land and within Road, the best pick may save at most 1.25 times the time of the worst; Craft is judged by how much its goods are wanted. Correct an outlier by perks first, both ends toward the middle. | ADR-0030's profession band. |
| XP lost before the Oathstone | Whether new players noticed that kills before choosing a class pay no class XP. | Player guidance in `docs/rules.md`. |

## Professions (*plugin* for Callings parts)

| Check | Do and record | Feeds |
| --- | --- | --- |
| No obvious best pick | After two weeks, ask which focus feels strongest/weakest and why; time fresh and high-level characters at the same gathering/taming/transport job and area revealed per pass. Watch Mining and Farming especially. | ADR-0024; `MidnightsFX.ImpactfulSkills.cfg` and `blacks7ar.Explorer.cfg`. |
| Explorer marker pace | Record Explorer level on entering each biome and whether resource/dungeon markers help exploration without replacing looking. Measure marker boundaries at 1/10/100 (20/about 27/96 m in v17), absence at 0, and whether the global cap of 20 hides useful mixed markers. | ADR-0019/0024; `blacks7ar.Explorer.cfg` and Callings `RangeAtLevel1`/`RangeAt100`. |
| Herbalist and Fishing bonus | Measure extra output at known effective levels, reaching two extra items per craft/catch at 100; copies keep maker grade or landed fish quality, with no extra XP. | ADR-0032; #96. |
| Benefits without craft blocks | With low profession level and the required personal key, craft and upgrade formerly gated goods and the three former level-40 exceptions. No Item_Requirement refusal remains. Craft/equip Deep North gear and Frost Foundry intermediates without Fader’s key (refused, boss-keys hint) and with it (allowed). | ADR-0032; #94. |
| Focus death protection | A focus keeps its level/progress through death; non-focus Blacksmithing, Herbalist and Explorer drain once only above the skill floor; dropping a focus lands on the confirmation's shadow level. | ADR-0022 (*plugin*). |
| Brewer’s grade | Craft at real Herbalist 24/25/49/50/74/75/99/100 with and without borrowed levels. Ferment a graded base across two clients, Market round-trip, relog and inspect stacks/tooltips. Same-grade drinks scale equally on low/high Herbalist drinkers; ungraded means grade 1; no resist/Tasty/Lingering hour floor. | ADR-0032; #95. |
| Elixirs | Whether Berserker (×1.25), Swift (×1.2), Fast Learner (×1.5) and the others are bought for hard fights without being mandatory. | ADR-0024; `config/enforced/blacks7ar.Herbalist.cfg`. |
| Smith's mastery bonus | Damage and armour on gear from a high-level smith against a fresh one; whether players notice and ask for a particular smith. | ADR-0024; `config/enforced/org.bepinex.plugins.blacksmithingexpanded.cfg`. |
| BlacksmithingExpanded lock | With the server running, a non-admin player changes one of its settings locally while connected; record that the change has no effect — `Lembitu.Callings` locks the sync at startup, so this is a fix verified in play, not an open check (#89). Verified 2026-10-05 in a native session: a connected non-admin's cfg edit to 9.9 plus `Config.Reload()` left the effective `Skill gain factor` at the server's 1.0 with `IsLocked` true (`smith-connected-before.json`, `smith-after-client-edit.json`); a Shakedown run only needs to repeat it with a second real player. | ADR-0022; the startup lock. |
| Seed beds and tonics in play | Not yet seen in game (2026-10-05 native run `20261005T151436Z-callings` hit its time box). Plant carrot seeds in a Meadows bed at Farming below 60 and at 60: both accepted, 5 seeds give 5 carrots. Mistlands mushrooms in a Meadows bed: refused below Farming 60, accepted at 60, 5 give 15. Press E at an empty bed with mixed seeds and record which it picks. Drink a large tonic with the Mistlands key: it is consumed and the bottle comes back. Proven 2026-10-05: the barley refusal on both paths, barley 5 → 10 at Farming 60, the tonic refusal without the key. | ADR-0022; `Lembitu.Callings` (#89). |
| Cook's grade | Food from a grade-5 cook against a grade-1 cook's in one fight; whether players ask for a particular cook and pay more for graded food on the Market; a graded dish through an oven owned by another player's client, and through a Market round-trip. Proven 2026-10-06 in one native session (`20261006T094335Z-cook`): grade 5 from a cauldron at Cooking 100 beside an ungraded stack at 20, ×1.21 food and 1.5× shelf life, grade-4 dough baked into grade-4 bread through an oven, the Farming work meal, and both graded scale and work meal after a relog. | ADR-0029; `[Cook grade]` in `lembitu.callings.cfg`. |
| Work meals | Which work meals players eat while working and whether one feels compulsory; whether a meal pushing a perk over a milestone (Mining 45 + 10 reaches area mining at 50) feels earned or cheap. | ADR-0029; `[Work meals]` in `lembitu.callings.cfg`. |
| Spoilage and storage | How much food rots per week, whether the Meadows-to-Swamp stretch before the Icebox feels punishing, whether guilds build a mountain storehouse, and whether preserved dishes see use on trips. | ADR-0029; `config/enforced/FineDining/Spoilage.yml` and `config/enforced/sighsorry.FineDining.cfg`. |
| Fresh food and tuning | Fights at the tuning targets with fresh food (110%) and v17 graded food (up to 132%) against the 2026-10-05 measurements, which assumed vanilla food. | ADR-0019's tuning targets; `Food Stat Scale` and `levels.yml`. |

## Classes and parties (*plugin*)

| Check | Do and record | Feeds |
| --- | --- | --- |
| Respec, switch and tree access | Reset talents at the stone (XP kept), switch away/back (both class records kept), spend points away from the stone, refuse reset/oath away from it. Fresh character: no Classes button until first oath at the stone; unlocks unchanged. | ADR-0031; #92. |
| Party XP | XP each member receives for one kill at party sizes 1, 2, 4 and 8, members in and out of 100 m, and a killer standing beyond 100 m (who still earns their share); the server logs every split as `Party kill XP:`. Whether partying feels worth it. | ADR-0022's 100% to 150% curve. |
| Gathering tools | A Rogue, Monk, Berserker, Highlander and Breaker can fish; a Monk's bare-handed mining and chopping raise Mining and Wood Cutting. Time a Monk's Mining and Wood Cutting against a pickaxe or axe user: the fist raises by Oathbound's 0.25 per gathering hit. | ADR-0022; the Monk's gather pace. |
| Wolf orders | As a Hunter, open the command window with Y and give each order: stay holds the wolf in place, heel keeps it from engaging, recall breaks a fight off. Repeat while another player stands nearer the wolf than its owner, and record whether orders still take effect. Note whether the Hunter's orders feel strong next to the Dragonsworn whelp and Warlock skeletons, which have none. | `docs/modstack.md` (Oathbound Addon, client-only); ADR-0025's class band. |
| Oathbound at join | A client without Oathbound tries to join; record whether it is refused. | `docs/modstack.md`, "Where each mod runs". |
| Our plugins at join | A client without one of `Lembitu.Oathbound`, `Lembitu.Callings`, `Lembitu.Guide` or `Lembitu.Guilds` tries to join. All four declare `EveryoneMustHaveMod`; on 2026-10-05 a client without `Lembitu.Guide` was refused with `Missing mod on client: Lembitu.Guide` (`~/lembitu-native-tests/20261005T123002Z-demo/`), so this repeats it with a player's real install. | `docs/modstack.md`, "Where each mod runs". |

## Difficulty and world

| Check | Do and record | Feeds |
| --- | --- | --- |
| Tuning targets | Every boss kill: party size, minutes, deaths. Ordinary fights: whether about three players handle a biome's creatures. | ADR-0033: bosses for five, creatures for about three in practice; `config/enforced/CreatureManager/levels.yml`; the `Combat hard` launch modifier. |
| Sieges | Sieges per play-week, their tier against the outpost's biome, structure damage taken, and whether the guild monster ward starves them. | ADR-0020; `Raids less` in `config/launch/launch.env.example`. |
| Crew sailing | Trip time on one route with one sailor and with a crew. | ADR-0024's crew bonus. |
| Market round-trip | List, buy and withdraw one smith-made item and one EpicLoot item; relog; check durability, maker and enchantments survived. | ADR-0023; Northarun/Marketplace. |
| Presence radius | At a boss kill, who got the key, the mastery credit and the party XP, with distances. Keys measure from the player controlling the boss, the other two from the boss. | ADR-0022; `config/enforced/MidnightsFX.ProgressivePowers.cfg`. |

## Accepted as configured, watched in play

CreatureManager and EpicLoot were initially kept on 2026-10-04; Pack v17 changes them under
ADR-0033 and the 2026-10-06 premium-review decision log. These interactions remain watched:

| Check | Do and record | Feeds |
| --- | --- | --- |
| EpicLoot profession effects | Which profession-touching magic effects players roll and wear: +Pickaxes, +Fishing, +Axes (which also counts for Wood Cutting), +Cooking and Crafting, more ore, bountiful harvest, harvest XP, sailing speed, carry weight, fishing luck (`EpicLoot.cs:30242-30268`). They raise perk levels, never the real level maker grades read (ADR-0032). Record whether enchanted gear lets a non-specialist feel like a specialist. | ADR-0024's "no obvious best pick"; an EpicLoot effect patch if it does. |
| `Combat hard` on top of CreatureManager | Whether creature damage feels doubled-up: the launch's world modifier stacks with CreatureManager's creature damage (1.0× from #87, was 1.2×) and boss damage (1.5×). | ADR-0019's tuning targets; the launch modifier or `levels.yml`. |
| Class XP pace from creature health | Oathbound pays XP by a creature's maximum health, so CreatureManager's health multipliers also set class-level pace. Read alongside "Class level pace" above. | ADR-0022's no-cap decision. |
| Sieges and CreatureManager | Whether siege troops carry CreatureManager's health and modifiers, and whether defending a base raises Karma and Enforcers around it. | ADR-0020; `config/enforced/CreatureManager/karma.yml`. |

## From the premium review (2026-10-05)

The decisions in `docs/wiki/premium-review.md` and ADR-0025 set starting values; these checks decide
whether they stand. Tickets #87 to #91 carry the changes.

Guide's final permitted native script (2026-10-05) proved fresh First steps, legible chapter titles,
real F1 opening/closing and normal movement after close, then stopped because its Tab press did
not open the inventory. The Guide checks below remain **unproven**, not failed plugin checks;
evidence: `~/lembitu-native-tests/20261005T161006Z-guide90d/`.

| Check | Do and record | Feeds |
| --- | --- | --- |
| Power level in play | Not yet seen in game (the 2026-10-05 native run, `20261005T161527Z-oathbound88-final`, stopped in its own setup). A class-level-30 Mage with no boss keys hits a target as hard as a level-10 Mage; after Eikthyr and the Elder it hits 2.16/1.36 as hard. A Hunter's wolf and a Dragonsworn whelp follow the same cap. With Oathbound's `Scaling/SpellPowerPerLevel` lowered on the server (from Pack v18; before it, our `[Power] SpellGrowth`), spell damage falls on a connected client and a client's own edit does nothing. Wolf, whelp and skeleton hits are 0.75 of Oathbound's. Proven on 2026-10-05: talent points at level 30 are untouched by the cap, the bow refusal names its rule and page, every feature logs `on`. | ADR-0025; `Lembitu.Oathbound` (#88). |
| Class band | At each biome, one player per class with the same gear tier and boss keys kills the same three creatures and one Enforcer; measure kill time, deaths and Eitr/potions spent, and observe attack effectiveness without a damage meter. | ADR-0025's ±25% band; Oathbound spell-growth and companion-damage settings. |
| Boss margin | Every boss: attempts to the first kill, group size, average gear tier. Five average players should win with margin; a smaller skilled group can win too (ADR-0033). | The tuning target in `CONTEXT.md`; `levels.yml` boss values. |
| Guild pace | Per guild: guild XP per member-hour by source, and guild level when each boss falls. | Guilds `LevelXpGrowth = 1.15` (#87). |
| Solo against party XP | Class XP per hour over a session solo and in parties of two, three and four in the same biome. | `FullPartySize = 4` (#87). |
| Craft pace | Raw and earned XP per play-hour for steady focus smiths, herbalists and cooks; verify v17 rate multipliers in the raw log and progress toward mastery at Kall, not an old recipe budget. | ADR-0032; #96, #100. |
| Karma on early biomes | Highest Karma level reached during Meadows and Black Forest gathering sessions. | Karma thresholds `[90, 180]` (#87). |
| Boss drops per player | One Bonemass and one Elder kill with two players present and one connected elsewhere: count Wishbones and swamp keys. | EpicLoot `Boss Trophy Drop Mode`; the open check in `docs/wiki/premium-review.md`. |
| Pets, tames and ships at bosses | At each boss, record companions, tames and warship ballistas present, kill time, and observed contribution or dominance; compare similar fights without them rather than a damage-meter share. | Tuning target; companion damage setting. |
| Guide inventory controls | Open inventory using the player's actual inventory binding; click Guide to open and again to close; close inventory and walk. Record the placement, open/close states and restored normal input. The native script's Tab press left inventory closed. | ADR-0027; unproven #90. |
| Guide live content authority | While connected with Guide open, edit the server's guide content file (deployed from `config/enforced/lembitu.guide.md`); observe the new text without relogging. Write conflicting client text and confirm it cannot replace the server's; restore the server file. | ADR-0027; unproven #90, script did not reach this step. |
| Guide same-character rejoin | Close Guide, log out and rejoin the same character. First steps must not auto-open; use F1 to open/close the rebuilt Guide and then walk normally. | ADR-0027; unproven #90, script did not reach this step. |
| Guide first oath | A character without the Oath and class seen marker takes its first oath through the Oathstone UI. Its matching Guide page opens once; close, reopen the oath UI and relog without another automatic opening. | ADR-0027; unproven #90, script did not reach this step. |
| Guide first Calling window | A character without the Calling seen marker opens skills, then Calling. Its matching Guide page opens once; close, reopen Calling and relog without another automatic opening. | ADR-0027; unproven #90, script did not reach this step. |
| Refusal guide pointers | Without a personal biome key, capture WAP refusal and Guide: Boss keys (boss-keys). Without Fader’s key, Deep North refusal names the same page. With keys and low profession level, former ladder recipes work. | ADR-0032; #94. |
| World edge | On the exact launch-size world, swim past the old world edge and rejoin while standing in the extended area. **2026-10-05 native result: PASS for the tested launch settings** (full Pack, Expand World Size 1.43, radius 13250, stretch 1.325). Meadows food and fixture Swim 100, no god mode; separate 3-second native swims crossed radii 9995→10003.126, 10415→10423.100 and 10495→10503.115, remaining swimming and alive, with stamina above 98 and no observed push-back. Fixtures positioned each crossing start, not the crossings. Same character `Ncf04fd32e45d` quit standing on Mistlands land at (11499.979, 67.997, 0.204), then rejoined at (11499.966, 67.965, 0.256), displacement 0.063 m, alive and not swimming; health was 76.131 before quit and 25 on rejoin. Evidence on astral-tricep: `~/lembitu-native-tests/20261005T150209Z-world-edge-survival/` (`summary.json`, `events.jsonl`, `old-*-before.png`, `old-*-after-0.png`, `extended-standing.png`, `extended-rejoined.png`, retained configs and logs). Logs contain CreatureManager Deathward checkpoint errors, OdinEye bind failure, microphone and CloudShadows initialization errors, and server `libParty.so` load failure; no Expand World Size error was found. This does not establish fish swimming, every sector, Ashlands or 2× radius behavior. | Upstream [#28](https://github.com/JereKuusela/valheim-expand_world_size/issues/28) (ghost water) and [#29](https://github.com/JereKuusela/valheim-expand_world_size/issues/29) (endless loading after extended-area disconnect) were not reproduced for this player at launch size; the size freeze. |
| Food after rejoin | Eat, quit, rejoin: whether food buffs and health survive. The 2026-10-05 world-edge run rejoined a fed character at 25 health (from 76), the no-food value; vanilla or a Pack interaction is not yet known (Venture_Logout_Tweaks restores status effects). The 2026-10-06 cook run (`20261006T094335Z-cook`) relaunched a client with carrot soup eaten and the soup was still there after the rejoin, at its graded scale; health after the rejoin was not recorded. | `docs/modstack.md`, Known interactions. |

## Before the first session: the owner's two-player checks

The test host has one Steam account, and the server refuses a second connection from it
(`ErrorBanned`, 2026-10-05), so every check that needs two players at once is the owner's, run on
the Shakedown server or a test server before players are invited (owner, 2026-10-05). Use two
characters on two Steam accounts, both installed from the published Pack.

| Check | Steps | Pass when |
| --- | --- | --- |
| Join button | Start a Pack-installed client and press "Join Lembitu" on the main menu. | It connects to `lembitu.astral.ee:2456` (from Pack v17; v16 used `85.253.16.237`) and asks for the password. |
| Acceptance gate | Two players: kill Eikthyr together; both log out and back in; build and use a ward, a portal pair and a raft. | Both hold the Eikthyr key after the reconnect; the ward refuses the other player until permitted; the portal and the raft work for both (`docs/modstack.md`, Acceptance gate). |
| Guild flow | Both new characters wake at the stones. A founds a guild and claims a region at its portal stone. B founds a second guild, tries A's stone, claims another region, then disbands. B joins A's guild and uses a free region's stone. B dies with no bed, uses A's region portal, leaves the guild, dies again with no bed. Restart the server. | B's claim on A's stone is refused; disbanding frees B's region; as a non-leader B gets no claim window; as A's member B respawns in A's region and passes its portal; after leaving B respawns at the stones; A's claim survives the restart (`Lembitu.Guilds`, ADR-0028). |
| Party page — owner, end of build | Use two separately licensed clients. On a character without `groups` recorded in `lembitu.guide.seen`, form a SocialSystem party through its UI. Close Guide, leave/rejoin the party, then relog. | Guilds, parties and the Market opens once on the first party; leaving/rejoining and relogging do not auto-open it again (`Lembitu.Guide`). |
| Wishbone and swamp key | With both connected and one of them away from the fight, kill Bonemass and the Elder. | Count Wishbones and swamp keys: one per kill matches the decision; one per connected player means EpicLoot's mode does not reach these two drops (`docs/wiki/premium-review.md`, open check). |

## Decisions

This page decides nothing on its own. Each check feeds the decision named in its row; a measured
number that moves changes that ADR, overlay or plugin setting, and the result is recorded here, dated,
with the pack version.

## Exclusions

Per-feature single-client scenario coverage is not part of the Shakedown; it was cancelled with the
plugins it was written for (`docs/modstack.md`, "Acceptance gate"). Checks that code alone settles
(the boss-power counts, the party share formula) are not repeated here.

## Lessons

No Shakedown session has been played yet. Results land here as they are measured.

## Per-session watch (#100)

After every play session, read the server's Profession XP: lines and boss fights. Record date,
Pack, players and reported play minutes, per-profession raw and earned XP/hour, real levels, focus
choices and boss keys. Raw XP includes mod rates; earned XP includes the steep curve. Zero activity
is not evidence of a bad multiplier. Watch Blacksmithing, Herbalist and Explorer raw figures
explicitly after v17; identify Animal Handling as midnightsfx.animalwhisper.

For every boss record party size, minutes, deaths, gear/biome and modifiers. Keep creature deaths
separate from boss deaths. Weekly, compare steady-focus progress to Land a little before Fader,
Road at Fader and Craft at Kall; correct outliers toward their group target while retaining
ADR-0030's 1.25× band. Record changes and reasons here; announce trims early. A session entry is
 dated evidence, not permission to deploy an untested Pack.

### First-evening basis — 2026-10-06, Pack v16

Source: live server docker logs lembitu, 39 Profession XP: reports, 17:32–19:54 server time,
as read by the integrator. Meadows only; three players: Trilby god 130 reported minutes, sins 150,
mr donk 110, totalling 390 minutes (6.5 player-hours). Rates already include ADR-0030's smith
1.75× and Herbalist factor 2. Raw XP per hour of reported play, not time actively working each
profession and not rates after the non-focus curve:

| Profession | Focus raw XP/hour (player) | Non-focus raw XP/hour (player) |
| --- | --- | --- |
| Wood Cutting | 143.4 (sins) | 45.5 (mr donk) |
| Exploration | 86.6 (Trilby god) | 50.6 (sins), 111.5 (mr donk) |
| Blacksmithing | 54.6 (sins) | 17.7 (Trilby god), 42.0 (mr donk) |
| Farming | 32.5 (Trilby god), 54.2 (mr donk) | 9.2 (sins) |
| Herbalist | 45.1 (Trilby god) | 6.4 (sins), 46.4 (mr donk) |
| Hauling | 12.4 (sins) | 36.1 (mr donk) |
| Cooking | 4.9 (mr donk) | 3.1 (sins) |
| Mining, Animal Handling, Sailing, Fishing | 0 (chosen by some, not practised) | — |

**Tonight's boss:** Eikthyr killed, but the owner reported it took too long. The logged
activeBosses 1→0 window was 19:21:55–19:35:13 (13 min 18 s), not a stopwatch measurement of
uninterrupted fighting. Eleven deaths among three players in about 2.5 hours of Meadows play
(odineye Player died lines), five during the boss window. The owner said Meadows creatures felt
about right. ADR-0033 lowers fixed boss health to 5×, keeps creature base health at 2× and reduces
star growth; later-biome outcomes remain unobserved.

The table grounds ADR-0032's toned pace jump, not proof that mastery targets have been met.
Pack v17 native acceptance and later session records must supply that proof.
