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
| BlacksmithingExpanded lock | With the server running, a non-admin player changes one of its settings locally; record whether the change takes effect. Its main settings carry no lock entry. | ADR-0024; whether a lock patch is needed. |

## Classes and parties (*plugin*)

| Check | Do and record | Feeds |
| --- | --- | --- |
| Respec and switch | Respec and a class switch each land at level 1; switching back does not restore the old class; unlocked classes stay unlocked. | ADR-0022. |
| Party XP | XP each member receives for one kill at party sizes 1, 2, 4 and 8, members in and out of 100 m, and a killer standing beyond 100 m (who still earns their share); the server logs every split as `Party kill XP:`. Whether partying feels worth it. | ADR-0022's 100% to 150% curve. |
| Gathering tools | A Rogue, Monk, Berserker, Highlander and Breaker can fish; a Monk's bare-handed mining and chopping raise Mining and Wood Cutting. Time a Monk's Mining and Wood Cutting against a pickaxe or axe user: the fist raises by Oathbound's 0.25 per gathering hit. | ADR-0022; the Monk's gather pace. |
| Oathbound at join | A client without Oathbound tries to join; record whether it is refused. | `docs/modstack.md`, "Where each mod runs". |

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
| `Combat hard` on top of CreatureManager | Whether creature damage feels doubled-up: the launch's world modifier stacks with CreatureManager's 1.2× and 1.5× damage. | ADR-0019's tuning targets; the launch modifier or `levels.yml`. |
| Class XP pace from creature health | Oathbound pays XP by a creature's maximum health, so CreatureManager's health multipliers also set class-level pace. Read alongside "Class level pace" above. | ADR-0022's no-cap decision. |
| Sieges and CreatureManager | Whether siege troops carry CreatureManager's health and modifiers, and whether defending a base raises Karma and Enforcers around it. | ADR-0020; `config/enforced/CreatureManager/karma.yml`. |
