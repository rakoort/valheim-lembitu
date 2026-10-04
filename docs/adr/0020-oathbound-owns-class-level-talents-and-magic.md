# ADR-0020: Oathbound owns class level, talents and magic, adapted by a plugin of ours

Date: 2026-10-04
Status: Accepted
Amends: ADR-0010 (adopt rather than write plugins), ADR-0019 (one owner per axis)

## Context

ADR-0019 asks for a character level, a talent tree with limited points, costly respec, parties
that share kill XP at about 110-125% of solo, and deaths that are never cancelled. Twenty level,
class, talent and party mods were decompiled the same day (`local/mod-review-2026-10-04/fit-*.md`).
None fits as shipped. Every talent mod either cancels deaths (TalentTree's Last Bastion,
CaptainSkillTree's Berserker, ExperienceSystem's Second Life, Valheim_Ascended's Undying),
rewrites gear's combat numbers with no switch, or gives free respec. No mod shares party XP by
party size. EpicMMO was the best level mod but has no talents and reads only the deprecated
Smoothbrain/Groups for party XP.

The owner then allowed overlap between pillars where a mod is well built and can be tuned, and
chose `LionAndOtter/Oathbound` as the more involved and better-built system. It has thirteen
classes with 79-node talent trees, active abilities, companions, elemental and blood magic,
sieges and blood moons. Its code is the most carefully engineered of the twenty: it refuses to
overwrite a save it could not read, snapshots before migrating, and switches itself off rather
than run with a hook that no longer matches. It never cancels a death (its near-death talents
say "cannot save a lethal hit", and nothing sets health to 1), and vanilla skills still progress,
so the boss-key skill floor and the professions keep working.

## Decision

- **Oathbound is the class-level, talent and magic pillar.** WackyEpicMMOSystem and MagicPlugin
  leave the stack: two level systems would stack on the same stats, and Mage and Warlock are the
  magic schools.
- **SocialSystem supplies parties**: invite-only, capped at eight, across guilds, with positions
  on the map.
- **Overlap is allowed** where a mod is well built and its overlap can be tuned. ADR-0019's
  one-owner-per-axis rule becomes a preference, not a gate.
- **Four changes Oathbound has no settings for are made by our own plugin, `Lembitu.Oathbound`**,
  which patches Oathbound at runtime rather than editing its DLLs, so an upstream update
  replaces their files without losing ours:
  1. Respec resets the active class to level 1. Cheap early, expensive late.
  2. Switching class also starts over at level 1: one levelled class at a time.
  3. Kill XP goes to party members near the kill, split so the party's total is about 110-125% of
     a solo kill, using the party ID SocialSystem stores on each player. Oathbound's server-side
     kill routing is the one place this happens.
  4. A cap on talent points, if the Shakedown shows level 80 arrives too early in the month.
- **Kept as Oathbound ships them:** the death penalty (half the progress into the current level,
  never a level), companions, sieges, blood moons and the Oathstone. Walking from a guild's start
  to the Oathstone is itself early progression.

## Consequences

- ADR-0010's "no plugins of our own" is amended for one narrow plugin. It is not a fork in
  ADR-0003's sense: we own a patch layer, not Oathbound's source.
- Our patches hook Oathbound internals that change between releases, and Oathbound releases
  almost daily. Oathbound is pinned, and every bump means re-checking `Lembitu.Oathbound` first.
- The package carries no licence. This is a private server for personal use, so patching it at
  runtime needs nobody's permission.
- Oathbound's damage hook expects exactly two `HitData.GetTotalDamage` reads in
  `Character.ApplyDamage`. The game we run has two (`IL_0029`, `IL_0092`). A game update could move
  them, and then Oathbound switches itself off; ADR-0007's frozen game version is what keeps that
  from happening mid-Run.
- The Oathstone is a location written into the world at generation, so Oathbound must be installed
  before the Run world is created (ADR-0009).
- Every character's EpicMMO level, attributes, XP orbs and meads are gone, along with all
  MagicPlugin items. The Shakedown world absorbs that.
- Sieges and blood moons add to raids and creature levels. Their interaction with ZenRaids,
  personal raids, the Guilds monster ward and CreatureManager's tuning is a Shakedown question.
- `Lembitu.Oathbound` is decided but not yet written.
