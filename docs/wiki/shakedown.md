# Shakedown: what to measure

The Shakedown is played on a world that will be discarded (`CONTEXT.md`). It exists to measure
what the 2026-10-04 decisions could only estimate (ADR-0019 to ADR-0024). Each check below names what
to do, what to record, and the decision it feeds. Record results in this page, dated, with the pack
version, and change the decision's ADR or overlay when a number moves.

Before the Shakedown starts, `Lembitu.Oathbound`, `Lembitu.Callings` and the Item_Requirement rule
file must exist (ADR-0022, ADR-0023). Every check marked *plugin* depends on them.

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
| Party XP | XP each member receives for one kill at party sizes 1, 2, 4 and 8, members in and out of 100 m; whether partying feels worth it. | ADR-0022's 100% to 150% curve. |
| Gathering tools | A Rogue, Monk, Berserker, Highlander and Breaker can fish; a Monk's bare-handed mining and chopping raise Mining and Wood Cutting. | ADR-0022. |
| Oathbound at join | A client without Oathbound tries to join; record whether it is refused. | `docs/modstack.md`, "Where each mod runs". |

## Difficulty and world

| Check | Do and record | Feeds |
| --- | --- | --- |
| Tuning targets | Every boss kill: party size, minutes, deaths. Ordinary fights: whether two players handle a biome's creatures. | ADR-0019: bosses for eight, creatures for two; `config/enforced/CreatureManager/levels.yml`; the `Combat hard` launch modifier. |
| Sieges | Sieges per play-week, their tier against the outpost's biome, structure damage taken, and whether the guild monster ward starves them. | ADR-0020; `Raids less` in `config/launch/launch.env.example`. |
| Crew sailing | Trip time on one route with one sailor and with a crew. | ADR-0024's crew bonus. |
| Market round-trip | List, buy and withdraw one smith-made item and one EpicLoot item; relog; check durability, maker and enchantments survived. | ADR-0023; Northarun/Marketplace. |
| Presence radius | At a boss kill, who got the key, the mastery credit and the party XP, with distances. Keys measure from the player controlling the boss, the other two from the boss. | ADR-0022; `config/enforced/MidnightsFX.ProgressivePowers.cfg`. |
