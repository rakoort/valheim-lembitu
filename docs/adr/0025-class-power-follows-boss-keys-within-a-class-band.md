# ADR-0025: Class power follows boss keys, within a class band

Date: 2026-10-05
Status: Accepted; not yet implemented
Amends: ADR-0020 and ADR-0022 (scope of `Lembitu.Oathbound`)

## Context

Oathbound 0.21.14 scales classes unevenly (`docs/wiki/premium-review.md`, Lessons). A weapon class's
weapon hits get only its tree's flat bonus, about 5-15%, so its damage comes from gear, which personal
boss keys and the profession ladder gate. Mage and Warlock spells grow 4% per class level (4.16× at
80), and Hunter and Dragonsworn companions grow with class level too. Class level comes from kills,
which no boss gates, so a caster or pet class could grind kills and outgrow the gear gate that holds
a weapon class back. That is the solo race ADR-0019 steers away from, and it widens the gap between
classes over the Run.

## Decision

**Classes may differ within a class band of ±25%** (owner, 2026-10-05): at the same biome, gear tier
and boss keys, every class should kill a standard enemy within 25% of the others' time during the
Run, each keeping its own strength. Equal classes were not the goal; a loose ±40% was rejected as
making a weak pick feel like a handicap, a tight ±15% as reducing classes to flavour.

**The power level is the class level, capped at ten per personal boss key** (owner, 2026-10-05): 10
before Eikthyr, 20 after him, and so on to 80 after Fader, the same ten-per-biome step as the
profession ladder (ADR-0023). Oathbound's level-scaled power reads the power level instead of the
class level. Talent points, class XP and the class level itself are untouched; capping talent points
too was rejected as a new hard lock on players who level without killing bosses.

**Spell growth stays at Oathbound's 4% per power level, behind a setting of ours** (owner,
2026-10-05). `Lembitu.Oathbound` exposes the rate as a server-locked setting defaulting to 4%, and
the Shakedown lowers it only if casters land outside the band. Trimming to 3% before any measurement
was rejected: Eitr sustain, not the rate, may be what limits a Mage.

**Companions start at 0.75× damage** (owner, 2026-10-05). The Hunter's wolf, the Dragonsworn whelp
and the Warlock's skeletons fight without costing their owner's actions and draw aggro, which is
worth most in fights tuned for two players. `Lembitu.Oathbound` applies a server-locked companion
damage multiplier, 0.75 for the Shakedown, on top of the power-level cap; the Shakedown moves it.

## Consequences

- `Lembitu.Oathbound` reads World Advancement Progression's personal keys, so it now hooks two mods.
  An Oathbound or World Advancement Progression bump re-checks it.
- The difficulty curve is tuned for weapon classes, whose power follows gear; casters and pet
  classes should find fights comfortable rather than trivial.
- The Shakedown measures the band with one benchmark per biome: each class kills the same standard
  creatures and one Enforcer, recording time, deaths and Eitr or potions spent.
