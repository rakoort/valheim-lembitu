# ADR-0019: The server concept — MMORPG-lite for rival guilds that must cooperate

Date: 2026-10-04
Status: Accepted; amended by [ADR-0020](0020-oathbound-owns-class-level-talents-and-magic.md) and [ADR-0021](0021-callings-focus-professions-across-craft-land-and-road.md)
Supersedes: ADR-0006, ADR-0008, ADR-0012, ADR-0013; replaces the power-curve counts of ADR-0017 and
ADR-0018

Amended 2026-10-06 (owner): ADR-0033 replaces the tuning targets and month endpoint; ADR-0031 makes class respec free. Earlier values below are historical where annotated.

## Context

On 2026-10-04 the owner added thirty mods at once, removed Clan for Northarun/Guilds, and asked for
a review of every overlap. The review found three character-level systems, two magic systems, two
map-sharing systems and several mods that only make sense under different answers to the same
questions. The owner chose to settle the concept first and to judge mods against it afterwards:
no mod is kept because it is already pinned, and none is cut because it is new. This ADR is that
concept, recorded from a one-question-at-a-time interview the same day.

## Decision

**The goal.** A difficult but engaging experience that encourages cooperation and rewards both solo
and group play. It is not meant to run forever.

**Shape.** No PvP whatsoever. Guilds are rivals and cooperators at once, and the stack should give
incentives for both rather than hope for them.

**Scale.** Content is balanced around eight active players. A guild has three to five members; the
server caps a guild at five. There are at most three guilds, one per scored start region. Guilds form
in game, not before launch: every new player wakes at the sacrificial stones, guilds are founded
there, and a founded guild claims one of the three start regions as its members' home (owner,
2026-10-05; first written as "agreed before launch", and before that "does not cap how many guilds
exist").

**Difficulty (amended 2026-10-06, ADR-0033).** Harder than vanilla. Bosses are tuned for five
players, fixed at level 1 with 5× health; ordinary creatures keep 2× health, gain 75% per star
and roll modifiers on about 20% of spawns. Combat hard stays. A full guild can win alone;
inter-guild cooperation rests on the Market, parties and smaller guilds rather than forcing
every guild to borrow boss fighters. These replace the eight-player boss and two-player creature
targets. Nothing scales health, damage or raid chance with headcount. Biome levels, Karma,
modifiers and outpost-biome sieges still matter; party XP and crew sailing rewards are allowed. Deaths are costly: class-level XP loss, skill drain down to the boss-key floor (focus
professions excepted, ADR-0022) and a corpse run. Carried items and durability are not touched. (A
timed debuff after respawn was dropped the same day: no well-built mod provides one, and the other
three costs are enough.)

**Pace.** An actively playing group should kill ~~Fader~~ Kall Fimbulbringer in about one month
(ADR-0033, amended 2026-10-06). The server is open-ended
after that, but systems are sized for that month, not for a long endgame.

**Solo play.** Possible, much harder, and steered away from progression. A boss key goes only to the
players present at the kill, and guilds do not share keys, so a solo kill advances only that player.
Time alone should pay through building, gathering, professions and guild contributions instead.

**Feel: MMORPG-lite.** A harder base game with more progression systems. Seven pillars: character
level, a talent tree, professions, gear tiers, boss powers, guild progression and magic schools.
Anyone can do anything given time, but specialising is more efficient. Respec is free at the
Oathstone (ADR-0031, 2026-10-06; previously a meaningful XP cost). A late joiner catches up by being carried through re-kills and by party XP, never
by skipping content. (Corrected the same day: the boss-key skill floor only shields skills from
death drain; it never raises a skill, so it is no catch-up.)

**One owner per axis**, provisionally. Each pillar owns a different kind of power, and a mod that
reaches outside its axis has those parts switched off. To be revisited once the stack is chosen.

**Parties.** An intentional, invite-only group of up to eight that may mix guilds, separate from
guild membership. Party members share kill XP and see each other's map positions, nothing else. The
party's total XP lands above what one member would earn alone, rising from 100% for one member near
the kill to 150% for four or more (revised the same day from 110-125%, then from "150% for eight",
ADR-0022). Group-only bonuses count
anyone in the party, whatever their guild.

**World.** Vanilla portal rules: ore and metal travel by ship or cart, until the Ashlands' stone
portal, which carries everything as vanilla intends (kept deliberately the same day). Maps are
personal, shared by choice at a cartography table or through guild pins. Interfaces may show
readouts (hover stats, skill progress, clock, forecast) but no creature radar. Amended 2026-10-05:
Explorer 1.1.7 grants skill-gated live resource and dungeon markers, not saved automatic pins.
Biome unlocks are 1/10/20/30/40/50/60 and dungeons 10; marker range grows from 20 m at
level 1 to ~~64 m~~ 96 m at 100 (ADR-0032, 2026-10-06). BetterMap auto-pins are off. Raids from early on, with permanent base safety earned later
through guild progress. Raids are Oathbound's sieges, which replace vanilla's random raids (revised
the same day, ADR-0020). Creature modifiers, hunt events and regional pressure are in. (Seasons that
change spawns, farming and cold were scrapped the same day, with the Seasonality mod.)

**Economy.** One remote, server-wide market that works while the other side is offline. Personal
boss keys lock both crafting and equipping a biome's gear, so trade helps but never skips a boss.

**Building.** Precision and planning tools are welcome; every piece still costs full materials and
needs its station. Free-building tools are for admins only.

**The bar for mods.** The Shakedown decides: anything that loads clean and has no proven conflict is
tried there, and whatever misbehaves is cut before the Run world exists. A mod that fails at startup
or has a proven hard conflict is cut now. The Pack is the contract: everyone runs it, and a gameplay
mod is acceptable when the server locks its settings or it has none. Player-side settings that only
express preference, such as snapping behaviour or convenience automation, are allowed; settings
that change difficulty, combat or what one player gets over another are not (refined the same day,
when BetterArchery's unlockable ballistics were cut and preference settings were kept).
The 2026-10-06 Pack decision returns BetterArchery with gameplay locked by our plugin
(premium-review.md, #93), not an exception to this rule.

## What this supersedes

- **ADR-0008.** Clan is gone. Membership is Northarun/Guilds, and the party is a second, deliberately
  temporary grouping for XP and positions. Two groupings are acceptable here because they answer
  different questions: a guild owns land, vault and wards; a party only shares a hunt.
- **ADR-0012 and ADR-0013.** There is no PvP, so there is no stance and no stance-scoped corpse access.
- **ADR-0006.** The Trade Post, contracts, escrow and mailbox are replaced by an adopted remote
  market rather than built by us.
- **The power-curve counts in ADR-0017 and ADR-0018** give way to the seven pillars above. ADR-0018's
  separate starts stand, now for guilds instead of clans. Its world size does not: the world is
  radius 13250 with world stretch 1.325, biome stretch 1.25 and locations 1.75, about 1.76x vanilla
  area at vanilla density of points of interest (decided the same day).

ADR-0005 stands and is sharpened: personal keys are earned by presence and gate crafting and
equipping alike.

## Consequences

- Every pinned and newly added mod is judged against this concept. The interview's 2026-10-04
  research is kept in `local/mod-review-2026-10-04/`.
- Kill XP shared by party is not available off the shelf: EpicMMO's group XP reads the deprecated
  Smoothbrain/Groups API. A party mod has to be found, screened, or written.
- Tuning targets (five for bosses, about three for creatures in practice, ADR-0033) are measured
  in play, not argued.
- `CONTEXT.md` replaces the clan vocabulary with guild and party, and drops the stance and the Trade
  Post terms. `docs/rules.md` still describes the old design until the stack is chosen.
