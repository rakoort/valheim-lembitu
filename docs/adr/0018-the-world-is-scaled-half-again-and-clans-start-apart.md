# ADR-0018: The world is scaled up, clans start apart, and a third power curve is accepted

Decided 2026-09-17 (#86). A fresh world is generated at **radius 12500 with both stretch factors at
1.25** — the vanilla layout scaled up by a quarter. The first attempt that day used 15000 and 1.5 and
was rerolled at 1.25 before anyone built on it, which cost nothing but the generation time — each clan starts in its own place, and four
gameplay mods are adopted, one of which breaks ADR-0004's rule about power curves.

## The world

`JereKuusela/Expand_World_Size` 1.34.0 sets `World radius` to 12500 from vanilla's 10000, with
`Stretch world` and `Stretch biomes` at 1.25. The distinction matters: raising the radius alone tiles
more biome patches of the same size into a wider disc and pads the outside with Ocean, because
Ashlands and Deep North are placed by distance from centre. Scaling radius and stretch together
grows the layout itself, so each biome patch is a quarter wider and every journey between them a
quarter longer. Area rises about 1.56 times.

The owner's reasoning, recorded as given: each clan needs a viable start, and meeting another clan
should be a moment that changes how you play. Distance is what buys both.

**This is the least reversible decision in the project.** The values are baked into terrain when the
world generates. Changing them afterwards produces two incompatible halves of one map, so they are
fixed for the life of this world — a stronger constraint than ADR-0009's world-permanent mods, which
can at least coexist with a changed configuration.

**Every client must have the mod.** Clients generate terrain locally from the seed, so a client
without matching size settings gets different ground than the server. That makes Pack v12 mandatory
in a harder sense than a version handshake: the failure is wrong terrain, not a refused join.

The ordering this forces is worth stating, because getting it wrong wastes a world: install the
mods, boot once with the *current* world still present so nothing new generates, let the mods write
their configuration, apply and verify the overlay, and only then wipe and generate.

## Clans start apart

`Mushroom_Vikings/SeparateSpawns` 0.1.0 places each group in its own scored neighbourhood rather
than at the sacrificial stones — searching a configurable radius on a 25 m grid, keeping group
spawns at least 500 m apart, and scoring candidates for Black Forest proximity and burial chambers.
Upstream values are kept; the scaled world gives the search far more room than it needs.

It stores its layout per world UID and its groups in its own JSON file, so it is world-coupled:
removing it later returns everyone to the stones. Two things to watch on first boot, both unproven
here — it copies `m_startingGlobalKeys`, and this server blocks every global key (ADR-0005), and the
mod is at version 0.1.0 with a single release.

## A third power curve, accepted

`MidnightMods/ProgressivePowers` 0.3.3 makes Forsaken power mastery grow with use. ADR-0004 cut this
mod by name, on the reasoning that powers should stay vanilla and be gated per character by personal
keys, and that multipliers landing on one damage number should number two, not three. Character
level and gear are both back (ADR-0017), so this is knowingly the third.

What makes it tolerable rather than a reversal of the whole argument: mastery grows by *use* of a
power a character already earned through a personal key, so it deepens a gate the run already has
rather than adding a parallel ladder. What it costs is the clean claim ADR-0004 made. If damage
numbers become unreadable in play, this is the first mod to remove.

## Two smaller adoptions

`Vapok/AdventureBackpacks` 2.0.7 is **one-way**: the packs are registered items, so removing the mod
deletes every pack and its contents. It also overlaps AzuEPI's carrying capacity, which this run
pinned at zero extra rows deliberately — the backpack is now the answer to carrying capacity, and
that decision should not be re-litigated by adding rows later.

`ishid4/BetterArchery` 2.0.0 adds quivers and bow handling. It declares BepInEx 5.4.1501, the oldest
skew in the pack, recorded as a documented override in `scripts/stage-stack.sh`.

## Consequences

- Thirty-two pins. Every one of the five new packages was screened with
  `scripts/screen-bundled-libs.sh` before its pin landed, which is the practice #84 bought the hard
  way.
- The world in play is new. Everything built on the previous world is gone, by choice.
- Three power curves means the acceptance gate's damage question (#10) matters more than before, not
  less.
- If the scaled world proves too empty for twelve players, the fix is another wipe, not a setting.
  That is the accepted risk of this ADR.
