# ADR-0024: Profession perks, the alchemist's elixirs and the smith's mastery

Date: 2026-10-04
Status: Accepted; the perk settings below grow as the 2026-10-04 grilling settles them; Cooking
amended by [ADR-0029](0029-the-cook-grades-dishes-feeds-the-trades-and-food-spoils.md); milestones
for Wood Cutting, Fishing and Hauling and the smith's and herbalist's XP amended by
[ADR-0030](0030-the-calling-choice-is-balanced-by-time-saved-within-a-band.md)
Amends: ADR-0021 (profession mods add no combat power)

Amended 2026-10-06 (owner): ADR-0032 replaces the mastery values, ladder trade role and drinker-skill scaling. Earlier values below are historical where annotated.

## Context

ADR-0021 asked for each profession mod's best perks to sit above the full-speed band, and kept
combat out of the profession mods. ADR-0023 then put what professions make on a biome ladder, so
the ladder carries the need between guilds and the perks carry efficiency. The grilling's
PerkThresholds handback read every perk's key, default and formula in ImpactfulSkills 0.21.0,
Herbalist 1.5.0, BlacksmithingExpanded 1.2.4 and ExpertExplorer 1.7.0.

Herbalist ships eight elixirs with no level gate and every recipe on: Berserker (×5 damage),
Defender (very resistant, ×0.2 damage dealt), Invisibility, Fast Learner (×3 skill XP), Swift
(×5 speed), Jump (×2), Slow Fall and Heavy Lifter (double carry), each for 600 s
(`Herbalist.cs:2722-3265`). BlacksmithingExpanded stamps crafted weapons, armour and shields with
bonuses that reach +40% damage on a level-100 smith's four-star weapon, add an elemental rider from
level 75, and give every crafter +5% per upgrade level whatever their skill
(`BlacksmithingExpanded.cs:4741-4776, 5048-5198`). The owner chose to keep both kinds of power and
balance them so that an alchemist is as essential as a smith.

## Decision

**The alchemist sells power by the dose; the smith sells it by the item.** The former ladder
trade role is retired (2026-10-06, ADR-0032): anyone can craft when personal keys permit it;
maker grades and stamped bonuses make specialist goods better. Potions are used up every fight.

**All eight elixirs stay, retuned to boss-fight strength** (`config/enforced/blacks7ar.Herbalist.cfg`):

| Elixir | Shipped | Run |
| --- | --- | --- |
| Berserker | ×5 damage | ×1.25 damage |
| Swift | ×5 speed | ×1.2 speed |
| Jump | ×2 | ×1.5 |
| Fast Learner | ×3 skill XP, half health | ×1.5 skill XP, half health |
| Defender | very resistant, deals ×0.2 | as shipped |
| Invisibility | 600 s | 60 s |
| Heavy Lifter | double carry, 600 s | 60 s |
| Slow Fall | 600 s | as shipped |

Defender's, Invisibility's and Heavy Lifter's effects are fixed in code, so duration is their only
lever: Invisibility becomes an escape rather than a stroll through the Mistlands, Heavy Lifter long
enough to load a cart without replacing Hauling. ~~Durations grow with the drinker's skill~~
Replaced 2026-10-06 by brewer-grade scaling (ADR-0032), up to ×1.75 at grade 5.

**A master smith's gear is modestly better.** BlacksmithingExpanded's bonuses follow the smith's
level only: ~~+1% damage, +0.5 armour and +1 block per ten levels~~ Replaced 2026-10-06
by ADR-0032's mastery settings; no per-upgrade extra or elemental rider.
(`config/enforced/org.bepinex.plugins.blacksmithingexpanded.cfg`). Who made a piece matters on the
Market, as with the alchemist, without a second large combat curve on EpicLoot and Oathbound. Its
efficiency perks (durability, smelting and kiln speed, ore saving, extra item) stay as shipped.

**Power perks switch on at milestone levels, not craft requirements** (ADR-0032).
The old comparison with ladder rungs is retired. The steep curve starts at 10 (ADR-0030).
Explorer's information unlocks still follow each biome from level 1:

| Level | Perks |
| --- | --- |
| 40 | Cooking bonus servings, honey bonus, mining critical hits, area harvesting, planting several at once, faster paddling |
| 50 | Hives in any biome, boat damage reduction, area mining, better wind angles; log splitter, quick bite and steady overload (`Lembitu.Callings`, ADR-0030) |
| 60 | Crops in any biome |
| 70 | Whole-vein mining, extra star on tamed animals, no ram damage to your ship |

The growth-timer readout stays at 12: it is information, not power. ImpactfulSkills'
`ScaleCraftedEquipmentQuality` is turned off with the rest of its Crafting perks, because
high-quality ingredients would otherwise bypass maker-stamped gear benefits.

**Felt growth, and no profession an obvious best pick.** What matters is that a focus visibly makes
the character more capable as it rises, and that no profession a player chooses is clearly better
than the others; the exact multiplier is secondary (owner, 2026-10-04). Every profession therefore
has a steady perk that grows with each level, switch-on milestones above, and a trade role:
better maker-stamped goods or raw volume (ADR-0032). A first attempt to tune every master to exactly 2.5×
the main job of a novice, counting vanilla's own skill effects, was dropped: vanilla tool damage
already gives Wood Cutting and Mining about 2.3×, so their mod perks would have vanished; vanilla
crafting speed already puts Cooking at 3.1×; and Hauling and Sailing could not get there at all
(the grilling's PerkCalibration handback). Instead the outliers come to the middle, counting only
what the mods add on top of vanilla:

Historical starting values below; mastery ramps superseded 2026-10-06 by ADR-0032.

| Profession | Package at 100 | Run at 100 |
| --- | --- | --- |
| Wood Cutting | chop ×2.2, wood ×3 | chop ×1.5, wood ×1.67; log splitter at 50 (ADR-0030) |
| Mining | dig ×2.2, ore ×2 | dig ×1.5, ore ×1.67; its unlocks stay |
| Animal Handling | taming 7×, slaughter yield 3×, honey 2× | each 2.5× |
| Hauling | +50 carry | +100 carry; carts unchanged; steady overload at 50 (ADR-0030) |
| Exploration | 200 m reveal (ExpertExplorer, retired 2026-10-05) | Explorer: 100..300 m reveal; live markers 20 m at level 1 to 64 m at 100, biome unlocks 1/10/20/30/40/50/60, dungeons 10 |
| Herbalist | nothing for the maker | about 1.5 extra items per craft (`Lembitu.Callings`) |
| Fishing | nothing for the maker | about 1.25 extra fish per catch (`Lembitu.Callings`); quick bite at 50 (ADR-0030) |
| Sailing | sail force ×2.5, rowing ×3, better wind angles from 50 | as shipped |
| Farming, Blacksmithing | — | as shipped |
| Cooking | bonus servings at 40 | bonus servings at 40, plus the cook's grade and work meals (ADR-0029); Cooking XP for eating and the eater's decay reduction off |

**Njord leaves the stack so that Sailing owns ship speed.** Njord replaced vanilla propulsion with its
own force and zeroed vanilla sail and rowing force, with no setting that restores them
(`Njord.source.cs:7045-7123`). Voyager's sail force, rowing and wind-angle perks multiply exactly
those forces, so under Njord a Sailing focus gained only damage protection and would have been the
obvious worst pick. With vanilla propulsion back, a master sailor's ship visibly moves faster; ships
lose Njord's 1.5× steering and its shipwright vendor. The Shakedown judges the result by playing
each focus. Mining (an area hit on every swing from 50, whole veins at 70) and Farming (planting
twelve at once) are the two to watch; whichever feels like the obvious pick is trimmed then.

**A crew sails faster.** With vanilla propulsion back, Voyager's passenger bonus works: every other
passenger adds up to 25% sail force from their own Sailing skill. It is kept as a reward for crewing
a ship together. ADR-0019's ban on headcount scaling is about difficulty (creature health, damage,
raid odds), not about rewards for playing together.

**Exploration owns the map reveal, aboard as on foot (amended 2026-10-05).** Explorer
1.1.7 replaces ExpertExplorer. BetterMap alone sets `Minimap.m_exploreRadius` to the
100 m baseline before each `UpdateExplore`; Explorer never writes that field, instead multiplying the
Minimap.Explore's argument by 1 + skillFactor × ~~2~~ 3 (ADR-0032, 2026-10-06: 100..400 m).
Voyager's reveal multiplier remains 0: the explorer maps; the sailor moves fast.
Explorer's live-marker unlocks keep their biome thresholds (ADR-0032: Meadows 1 because 0 disables it, then
10/20/30/40/50/60; dungeons/caves 10). Callings' server-locked `RangeAtLevel1 = 20`
and RangeAt100 ~~64~~ 96 m (ADR-0032, 2026-10-06) replace each tracker's creation-time radius on every
update, interpolating linearly over levels 1..100. `Max Pin = 20` is a shared cap
across resource and dungeon types, chosen to leave room for mixed markers without
using the maximum 50. BetterMap auto-pins are off; Explorer markers are not saved.

**This amends ADR-0021.** Profession mods still add no combat perk to a skill. The alchemist's
elixirs and the smith's mastery bonus are combat power sold as goods.

## Consequences

- Herbalist's own tonic tiers stay at the minimum, 1. The former Item_Requirement craft gate is
  retired 2026-10-06 (ADR-0032). The highest-biome herb still supplies the personal key for drinking:
  minor tonics Black Forest, medium health/eitr Mountains, medium stamina Plains, large Mistlands.
- Fast Learner speeds vanilla skills only, never Oathbound class XP, and `Lembitu.Callings` applies
  the steep curve after it, so a non-focus profession stays slow relative to a focus.
- BlacksmithingExpanded stamps its bonuses on an item when it is crafted and reapplies them on load
  even after its switches change (`BlacksmithingExpanded.cs:3758-3805`), so its overlay must be in
  force before the Shakedown crafts anything.
- BlacksmithingExpanded's main settings are server-synced but have no lock entry
  (`BlacksmithingExpanded.cs:4338-4344`). Since 2026-10-05 `Lembitu.Callings` locks that sync at
  startup (ADR-0022, #89); a connected non-admin's local edit and reload left the server's values in
  force in the native check of that day.
- The numbers are a starting point for the Shakedown, not measurements.
