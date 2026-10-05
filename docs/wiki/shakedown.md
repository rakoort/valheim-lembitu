# Shakedown: what to measure

The Shakedown is played on a world that will be discarded (`CONTEXT.md`). It exists to measure
what the 2026-10-04 decisions could only estimate (ADR-0019 to ADR-0024). Each check below names what
to do, what to record, and the decision it feeds. Record results in this page, dated, with the pack
version, and change the decision's ADR or overlay when a number moves.

`Lembitu.Oathbound`, `Lembitu.Callings` and the Item_Requirement rule file exist since 2026-10-04
(ADR-0022, ADR-0023). Every check marked *plugin* depends on them; their startup lines
(`<feature>: on`) belong in the record of the pack the Shakedown runs.

## Progression pace

| Check | Do and record | Feeds |
| --- | --- | --- |
| Class level pace | Each player's Oathbound class level at the end of every session, and which bosses are down. | ADR-0022: no talent cap and stock XP; revisit only if level 80 arrives well before Fader. |
| Focus pace against the ladder | Each focus profession's level when the group first reaches each biome. A rung a specialist cannot reach by the time the biome opens is a rung set too high. | ADR-0023's ten-per-biome ladder. |
| Non-focus pace | A non-focus profession some player uses anyway: level reached and hours spent. | ADR-0021's steep curve (full to 30, half to 60, quarter to 80, a tenth beyond). |
| XP lost before the Oathstone | Whether new players noticed that kills before choosing a class pay no class XP. | Player guidance in `docs/rules.md`. |

## Professions (*plugin* for Callings parts)

| Check | Do and record | Feeds |
| --- | --- | --- |
| No obvious best pick | After two weeks, ask each player which focus feels strongest and weakest, and why. Then time one fresh and one high-level character at the same job: wood or ore per minute on the same deposit, crops per planting round, taming time, trip time on one route with the same boat, area revealed per pass. Mining (area hit on every swing from 50, whole veins at 70) and Farming (planting twelve at once) are the two to watch. | ADR-0024's starting values in `config/enforced/MidnightsFX.ImpactfulSkills.cfg` and `com.milkwyzard.ExpertExplorer.cfg`. |
| Herbalist and Fishing bonus | Extra items per craft and fish per catch at a known skill level; whether the bonus copies quality. | ADR-0022's Callings bonus (about 1.5 and 1.25 at 100). |
| Ladder refusals | At a rung, crafting refuses below the level and works at it; World Advancement Progression's boss-key refusal still applies; an upgrade of a gated item is gated too; a buyer can wear or drink what they could not craft. | ADR-0023; Item_Requirement rule file. |
| Focus death protection | A focus keeps its level and progress through a death; a non-focus Blacksmithing or Herbalist drains 5% only above the skill floor; dropping a focus lands on the shadow level the confirmation named. | ADR-0022 (*plugin*). |
| Elixirs | Whether Berserker (×1.25), Swift (×1.2), Fast Learner (×1.5) and the others are bought for hard fights without being mandatory. | ADR-0024; `config/enforced/blacks7ar.Herbalist.cfg`. |
| Smith's mastery bonus | Damage and armour on gear from a high-level smith against a fresh one; whether players notice and ask for a particular smith. | ADR-0024; `config/enforced/org.bepinex.plugins.blacksmithingexpanded.cfg`. |
| BlacksmithingExpanded lock | With the server running, a non-admin player changes one of its settings locally while connected; record that the change has no effect — `Lembitu.Callings` locks the sync at startup, so this is a fix verified in play, not an open check (#89). Verified 2026-10-05 in a native session: a connected non-admin's cfg edit to 9.9 plus `Config.Reload()` left the effective `Skill gain factor` at the server's 1.0 with `IsLocked` true (`smith-connected-before.json`, `smith-after-client-edit.json`); a Shakedown run only needs to repeat it with a second real player. | ADR-0022; the startup lock. |

## Classes and parties (*plugin*)

| Check | Do and record | Feeds |
| --- | --- | --- |
| Respec and switch | Respec and a class switch each land at level 1; switching back does not restore the old class; unlocked classes stay unlocked. | ADR-0022. |
| Party XP | XP each member receives for one kill at party sizes 1, 2, 4 and 8, members in and out of 100 m, and a killer standing beyond 100 m (who still earns their share); the server logs every split as `Party kill XP:`. Whether partying feels worth it. | ADR-0022's 100% to 150% curve. |
| Gathering tools | A Rogue, Monk, Berserker, Highlander and Breaker can fish; a Monk's bare-handed mining and chopping raise Mining and Wood Cutting. Time a Monk's Mining and Wood Cutting against a pickaxe or axe user: the fist raises by Oathbound's 0.25 per gathering hit. | ADR-0022; the Monk's gather pace. |
| Oathbound at join | A client without Oathbound tries to join; record whether it is refused. | `docs/modstack.md`, "Where each mod runs". |
| Our plugins at join | A client without `Lembitu.Oathbound` and `Lembitu.Callings` tries to join; record whether Jotunn refuses it. Both declare `EveryoneMustHaveMod`, but no join has shown the refusal yet (owner's decision 2026-10-04 to check it here). | `docs/modstack.md`, "Where each mod runs". |
| Existing characters with ExpertExplorer | Each player's first join with a character made before ExpertExplorer was installed: it loads, joins and keeps its skills, and no `ArgumentNullException` appears in the client log. The `Lembitu.Callings` fix covers this load path by code reading only. | ADR-0022; `docs/modstack.md`, "Known interactions". |

## Difficulty and world

| Check | Do and record | Feeds |
| --- | --- | --- |
| Tuning targets | Every boss kill: party size, minutes, deaths. Ordinary fights: whether two players handle a biome's creatures. | ADR-0019: bosses for eight, creatures for two; `config/enforced/CreatureManager/levels.yml`; the `Combat hard` launch modifier. |
| Sieges | Sieges per play-week, their tier against the outpost's biome, structure damage taken, and whether the guild monster ward starves them. | ADR-0020; `Raids less` in `config/launch/launch.env.example`. |
| Crew sailing | Trip time on one route with one sailor and with a crew. | ADR-0024's crew bonus. |
| Market round-trip | List, buy and withdraw one smith-made item and one EpicLoot item; relog; check durability, maker and enchantments survived. | ADR-0023; Northarun/Marketplace. |
| Presence radius | At a boss kill, who got the key, the mastery credit and the party XP, with distances. Keys measure from the player controlling the boss, the other two from the boss. | ADR-0022; `config/enforced/MidnightsFX.ProgressivePowers.cfg`. |

## Accepted as configured, watched in play

CreatureManager and EpicLoot were reviewed against the 2026-10-04 decisions and kept as configured
(owner, 2026-10-04). Four interactions are watched rather than changed:

| Check | Do and record | Feeds |
| --- | --- | --- |
| EpicLoot profession effects | Which profession-touching magic effects players roll and wear: +Pickaxes, +Fishing, +Axes (which also counts for Wood Cutting), +Cooking and Crafting, more ore, bountiful harvest, harvest XP, sailing speed, carry weight, fishing luck (`EpicLoot.cs:30242-30268`). They raise the level the perks read, not the level the ladder reads. Record whether enchanted gear lets a non-specialist feel like a specialist. | ADR-0024's "no obvious best pick"; an EpicLoot effect patch if it does. |
| `Combat hard` on top of CreatureManager | Whether creature damage feels doubled-up: the launch's world modifier stacks with CreatureManager's creature damage (1.0× from #87, was 1.2×) and boss damage (1.5×). | ADR-0019's tuning targets; the launch modifier or `levels.yml`. |
| Class XP pace from creature health | Oathbound pays XP by a creature's maximum health, so CreatureManager's health multipliers also set class-level pace. Read alongside "Class level pace" above. | ADR-0022's no-cap decision. |
| Sieges and CreatureManager | Whether siege troops carry CreatureManager's health and modifiers, and whether defending a base raises Karma and Enforcers around it. | ADR-0020; `config/enforced/CreatureManager/karma.yml`. |

## From the premium review (2026-10-05)

The decisions in `docs/wiki/premium-review.md` and ADR-0025 set starting values; these checks decide
whether they stand. Tickets #87 to #90 carry the changes.

Guide's final permitted native script (2026-10-05) proved fresh First steps, legible chapter titles,
real F1 opening/closing and normal movement after close, then stopped because its Tab press did
not open the inventory. The Guide checks below remain **unproven**, not failed plugin checks;
evidence: `~/lembitu-native-tests/20261005T161006Z-guide90d/`.

| Check | Do and record | Feeds |
| --- | --- | --- |
| Class band | At each biome, one player per class (same gear tier and boss keys) kills the same three creatures and one Enforcer; record time, deaths, and Eitr or potions spent. | ADR-0025's ±25% band; the spell-growth and companion-damage settings of `Lembitu.Oathbound`. |
| Boss margin | Every boss: attempts to the first kill, group size, average gear tier. Eight average players should win on a first or second try; six or seven skilled players should be able to. | The tuning target in `CONTEXT.md`; `levels.yml` boss values. |
| Guild pace | Per guild: guild XP per member-hour by source, and guild level when each boss falls. | Guilds `LevelXpGrowth = 1.15` (#87). |
| Solo against party XP | Class XP per hour over a session solo and in parties of two, three and four in the same biome. | `FullPartySize = 4` (#87). |
| Smith and herbalist pace | Raw skill XP per play-hour for a focus smith and a focus herbalist, against the rung budget (rung 60 needs about 5,700 XP). Boost their gain only if a rung arrives after its biome opens. | ADR-0023's ladder; `AuditPace.md` candidate gains. |
| Karma on early biomes | Highest Karma level reached during Meadows and Black Forest gathering sessions. | Karma thresholds `[90, 180]` (#87). |
| Boss drops per player | One Bonemass and one Elder kill with two players present and one connected elsewhere: count Wishbones and swamp keys. | EpicLoot `Boss Trophy Drop Mode`; the open check in `docs/wiki/premium-review.md`. |
| Pets, tames and ships at bosses | At each boss: companions, tames and warship ballistas present, and their share of damage (DamageMeter). | Tuning target; companion damage setting. |
| Guide inventory controls | Open inventory using the player's actual inventory binding; click Guide to open and again to close; close inventory and walk. Record the placement, open/close states and restored normal input. The native script's Tab press left inventory closed. | ADR-0027; unproven #90. |
| Guide live content authority | While connected with Guide open, edit the server's guide content file (deployed from `config/enforced/lembitu.guide.md`); observe the new text without relogging. Write conflicting client text and confirm it cannot replace the server's; restore the server file. | ADR-0027; unproven #90, script did not reach this step. |
| Guide same-character rejoin | Close Guide, log out and rejoin the same character. First steps must not auto-open; use F1 to open/close the rebuilt Guide and then walk normally. | ADR-0027; unproven #90, script did not reach this step. |
| Guide first oath | A character without the Oath and class seen marker takes its first oath through the Oathstone UI. Its matching Guide page opens once; close, reopen the oath UI and relog without another automatic opening. | ADR-0027; unproven #90, script did not reach this step. |
| Guide first Calling window | A character without the Calling seen marker opens skills, then Calling. Its matching Guide page opens once; close, reopen Calling and relog without another automatic opening. | ADR-0027; unproven #90, script did not reach this step. |
| Refusal guide pointers | Without a personal biome boss key, attempt a WAP-gated craft and capture its cause plus `Guide: Boss keys (boss-keys).` With keys but below the profession rung, capture the Item_Requirement recipe tooltip naming skill/level plus `Guide: Profession ladder (ladder).` | ADR-0027; unproven #90, script did not reach these steps. |
| World edge | On the exact launch-size world, swim past the old world edge and rejoin while standing in the extended area. **2026-10-05 native result: PASS for the tested launch settings** (full Pack, Expand World Size 1.43, radius 13250, stretch 1.325). Meadows food and fixture Swim 100, no god mode; separate 3-second native swims crossed radii 9995→10003.126, 10415→10423.100 and 10495→10503.115, remaining swimming and alive, with stamina above 98 and no observed push-back. Fixtures positioned each crossing start, not the crossings. Same character `Ncf04fd32e45d` quit standing on Mistlands land at (11499.979, 67.997, 0.204), then rejoined at (11499.966, 67.965, 0.256), displacement 0.063 m, alive and not swimming; health was 76.131 before quit and 25 on rejoin. Evidence on astral-tricep: `~/lembitu-native-tests/20261005T150209Z-world-edge-survival/` (`summary.json`, `events.jsonl`, `old-*-before.png`, `old-*-after-0.png`, `extended-standing.png`, `extended-rejoined.png`, retained configs and logs). Logs contain CreatureManager Deathward checkpoint errors, OdinEye bind failure, microphone and CloudShadows initialization errors, and server `libParty.so` load failure; no Expand World Size error was found. This does not establish fish swimming, every sector, Ashlands or 2× radius behavior. | Upstream [#28](https://github.com/JereKuusela/valheim-expand_world_size/issues/28) (ghost water) and [#29](https://github.com/JereKuusela/valheim-expand_world_size/issues/29) (endless loading after extended-area disconnect) were not reproduced for this player at launch size; the size freeze. |
| Food after rejoin | Eat, quit, rejoin: whether food buffs and health survive. The 2026-10-05 world-edge run rejoined a fed character at 25 health (from 76), the no-food value; vanilla or a Pack interaction is not yet known (Venture_Logout_Tweaks restores status effects). | `docs/modstack.md`, Known interactions. |

## Before the first session: the owner's two-player checks

The test host has one Steam account, and the server refuses a second connection from it
(`ErrorBanned`, 2026-10-05), so every check that needs two players at once is the owner's, run on
the Shakedown server or a test server before players are invited (owner, 2026-10-05). Use two
characters on two Steam accounts, both installed from the published Pack.

| Check | Steps | Pass when |
| --- | --- | --- |
| Join button | Start a Pack-installed client and press "Join Lembitu" on the main menu. | It connects to `85.253.16.237:2456` and asks for the password. |
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
