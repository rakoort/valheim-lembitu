# ADR-0032: Benefits, not blocks

Date: 2026-10-06
Status: Accepted; ships with Pack v17, native acceptance still required (#94–#96, #99)
Supersedes: ADR-0023 (the profession ladder)
Amends: ADR-0021, ADR-0024, ADR-0029 and ADR-0030 (profession goods, pace and mastery)

## Context

The ladder made specialists necessary by refusing recipes, while the smith's stamped bonus and
the cook's grade already made their goods worth buying. The alchemist still sold drinks whose
strength read the drinker's skill. The owner chose a maker's benefit instead of a craft block.
The first evening's profession log also showed that the initial pace would not reach mastery in
the month: three players, about 6.5 player-hours, Meadows only (`docs/wiki/shakedown.md`,
2026-10-06 first-evening basis). These are starting points from real but narrow play, not a
prediction proved through the whole Run.

## Decision

**The profession ladder leaves.** Radamanto/Item_Requirement, all 367 rules and the three named
level-40 exceptions leave the server and Pack. Nobody needs a profession level to craft or upgrade
an item. Specialists earn better goods, extra output and efficiency instead. Personal boss-key
locks stay. Herbalist's tonic tiers remain at 1; Explorer's per-biome marker levels remain perks,
not craft blocks. The Calling's 2 Land + 1 Craft + 1 Road quota, shadows, death protection and
steep non-focus curve are unchanged.

**Deep North gear needs the player's Fader key.** World Advancement Progression 1.0.0 knows no
Deep North material and offers no custom item list. `Lembitu.Callings` therefore refuses crafting
and equipping Deep North items without the private Fader key. The former generator's material
mapping and cited overrides generate the list, including Frost Foundry `*Uncooked` intermediates,
rather than maintaining a second hand-written list. Refusals use the WAP style and name the guide's
`boss-keys` page. Baits and Herbalist herbs remain without a key lock; the tonic-drinking rule stays.

**The brewer's grade travels with the drink.** Vanilla mead bases and finished meads, Herbalist
 tonics and elixirs carry grade 1 below Herbalist 25, then one more per 25 levels, grade 5 at 100.
It reads the brewer's real Herbalist level, never food, gear or elixir bonuses. As with dishes,
item quality separates stacks and a custom-data marker identifies the grade; the Market preserves
it and the fermenter carries a graded base into graded mead. The tooltip shows the grade.

Herbalist scaling reads `f = (grade − 1) / 4`, not the drinker's skill: tonic and elixir durations
multiply by `1 + 0.75 f`; healing, stamina and eitr mead cooldowns shorten by 10–80%; resist, Tasty
and Lingering meads last 1.25–2 times as long. The one-hour floor for those meads leaves. Old or
looted ungraded potions count as grade 1. Elixir strength settings remain ADR-0024's; this changes
who supplies the scaling, not the elixir's base effect.

For potion effects, vanilla’s additive ten-second skill duration is removed so grade scaling
is exactly the configured duration times (1 + 0.75 f), not that plus another bonus (integrator
decision, 2026-10-06; Herbalist decompile 322, 2926, 2954).

**Pace has three targets.** A steady Land focus masters a little before Fader, Road at Fader and
Craft at Kall. The same target holds within each group, so ADR-0030's 1.25× profession band still
judges the combined pace and perks. Professions keep their own way of earning XP. The model adds
about ten hours for the Deep North: Fader around 55 hours, Kall around 65, not measured deadlines.
The first-evening jump is toned down 33% from the full jump:

| Setting | Before v17 | v17 |
| --- | --- | --- |
| WoodCuttingSkillGainRate | 1 | 1.9 |
| PickaxesSkillGainRate | 1 | 1.9 |
| FarmingSkillGainRate | 1 | 2.7 |
| FishingSkillGainRate | 1 | 1.9 |
| AnimalTamingSkillGainRate | 1 | 1.9 |
| ExplorerSkillGainRate | 1 | 2.9 |
| VoyagerSkillGainRate | 4 | 11.8 |
| HaulingXPRate | 0.2 | 0.6 |
| HaulingCarryWeightXPRate | 3 | 6.7 |
| BlacksmithingSkillGainRate | 1 | 3.8 |
| HerbalistSkillGainRate | 1 | 4.6 |
| CookingSkillGainRate | 1 | 4 |

These are ImpactfulSkills SkillRates, except the two Hauling settings in its Hauling section.
Blacksmithing is on top of ADR-0030's 1.75× BlacksmithingExpanded XP and Herbalist on top of its
Exp Gain Factor 2. Native proof must identify Animal Handling (`midnightsfx.animalwhisper`) and
show the smith, herbalist and Explorer multipliers in raw `Profession XP:` figures; the skill hook
runs after mod rates (`SkillHooks.cs:26–29`).

**Master, not god.** Mastery is worth reaching, without making its owner a second combat curve:

| Profession | Setting | Before v17 → v17 |
| --- | --- | --- |
| Mining | MiningLootFactor; RockBreakerMaxChance | 1.67 → 2; 0.05 → 0.10 |
| Wood Cutting | WoodCuttingLootFactor; Log splitter ChanceAt100 | 1.67 → 2; 0.3 → 0.5 |
| Farming | GatheringLuckLevels | 50,70,90 → 50,70,90,100 |
| Fishing | Perks FishingExtraAt100 | 1.25 → 2 |
| Animal Handling | TamedAnimalLootIncreaseFactor; AnimalBonusStarChance | 2.5 → 3; 0.25 → 0.4 |
| Exploration | Explorer markers RangeAt100; Explorer Radius Increase Per Level | 64 → 96; 2 → 3 |
| Sailing | VoyagerSailingSpeedFactor; VoyagerCuttingMinAngle | 1.5 → 2; 15 → 10 |
| Hauling | HaulingMaxWeightBonus; HaulingCartMassReduction | 100 → 150; 0.8 → 0.9 |
| Blacksmithing | damage % / armour / block per tier | 1 / 0.5 / 1 → 2 / 1 / 2 |
| Herbalist | Perks HerbalistExtraAt100 | 1.5 → 2 |
| Cooking | Cook grade FoodBonusPerGrade | 0.025 → 0.05 |

The smith's settings live in BlacksmithingExpanded, reveal in Explorer, and marker range, log
splitter, Fishing, Herbalist and cook grade in Callings; the rest live in ImpactfulSkills. The
cook's shelf life stays +12.5% per grade above 1. Work meals still lend ten perk levels, never
maker grades; no recipe rung remains to read them. Generated-config acceptable ranges must be
checked before shipping these values.

## Consequences

- A guild buys from a master because the goods are better or arrive faster, not because a novice
  is forbidden to make them. Trade remains an advantage rather than a compulsory dependency.
- Removing the ladder must not open the Deep North prematurely: the generated personal-key rule
  is part of the same cutover, including the foundry path.
- After every play session, read profession XP and boss party size, duration and deaths; record
  them in `docs/wiki/shakedown.md` (#100). Correct each profession toward its group target weekly.
- Native acceptance covers grade boundaries, a cross-client fermenter, Market round-trips,
  ungraded drinks with a skilled drinker, refusal without Fader's key and success with it, and a
  low-profession character crafting formerly gated goods when the personal key permits it.
