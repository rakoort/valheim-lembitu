# ADR-0015: Creature difficulty is a fixed number, and CreatureLevelAndLootControl owns it

`Smoothbrain/CreatureLevelAndLootControl` 4.6.4 replaces `sighsorry/CreatureManager` 1.1.14 as the
authority on creature and boss levels, health, damage and loot (#84, decided 2026-09-17). The rule
the swap exists to protect is unchanged and was restated by the owner twice: **a creature is the
same creature whether two players or twelve are standing near it.**

## Why the swap

CreatureManager was adopted for Karma, and the run kept it for the flat health multipliers it could
express. Two things then happened. The 2026-09-16 review removed headcount scaling through its
`[4 - Multiplayer Difficulty]` keys, so the mod's load-bearing job became suppressing a vanilla
behaviour rather than adding one. And on 2026-09-17 twelve players found ordinary creatures
unkillable, which turned out to be its modifier table rolling one modifier per group of eight — a
config shape that reads as a per-creature rate and is not one. Two retunes later the owner asked for
the mod to go.

CLLC expresses the same decisions more directly and is the better-travelled mod: base health and
damage as plain percentages, gains per star, separate boss figures, star chances, and its own affix
and infusion tables in place of modifiers.

## The scaling requirement, and how CLLC satisfies it

CreatureManager wrote vanilla's own fields — `Game.m_healthScalePerPlayer`,
`m_damageScalePerPlayer`, `m_difficultyScaleMaxPlayers` — from a `Game.Awake` postfix. CLLC does not
touch those fields at all; it postfixes the functions that read them. Read from
`CreatureLevelControl.dll` 4.6.4:

- `Game.GetPlayerDifficulty` is clamped between the configured minimum and maximum player count,
  with an optional addition. A maximum of 1 makes the nearby-player count always 1.
- `Game.GetDifficultyDamageScaleEnemy` recomputes the effective-health factor from
  `HP increase per player in multiplayer (percentage)`. At 0 it returns exactly 1.
- `Game.GetDifficultyDamageScalePlayer` does the same for creature damage. At 0 it returns exactly 1.

The overlay therefore pins all three, plus the additional-player key, because any one of them alone
would leave a live lever. The suppression is redundant on purpose: a package update that changes one
default cannot quietly restore scaling.

## What this costs, accepted

**Karma and Enforcers leave the run.** CLLC has no counterpart for regional pressure that rises with
kills, and none for the named modifier-carrying creature it summoned. `CONTEXT.md` called the
Enforcer this project's stand-in for a scheduled event, since there is no game master, so the run now
has no such substitute. That is a real loss, recorded rather than replaced, and it is the reason this
ADR exists rather than a config commit.

**Boss health changes shape.** The retired table set `Boss.health: 8` directly. CLLC has no boss
base-health key: boss health is carried by `Health gained per star for bosses (percentage)` together
with the boss star chances, so 8× has to be expressed as pinned stars. The values are written from
the generated config file, because the star-chance keys take comma-separated strings whose format is
not guessable.

**The handshake loosens.** CreatureManager was mandatory for clients through a hand-rolled version
check. CLLC's `ConfigSync("CL&LC")` leaves `ModRequired` false and it carries no such check, so a
client without it joins and simply sees no star, infusion or affix indicators. Creature stats are
server-authoritative, which is why the mod works against vanilla and console clients at all.

## What is deliberately unchanged

The fixed difficulty itself: ordinary creatures at twice vanilla health, carried across as
`Base health for creatures (percentage) = 200`, and damage growth per star at 25%. Affixes stay rare
at four creatures in a hundred, the figure the owner chose on 2026-09-17. Personal keys, EpicLoot,
the portal rules, clans and wards are untouched.

## Consequences

- One mod fewer in the join-time handshake, and one fewer overlay: the retired `levels.yml` and its
  four sibling data files go with CreatureManager.
- The run's difficulty is now three plain percentages and a star table, which is easier to retune
  and easier to get wrong quietly — so the two-versus-eight comparison in #84 is the acceptance
  check, not the config diff.
- Re-adding Karma later means re-adopting CreatureManager, which would also re-introduce the
  mandatory version check and a second creature-level authority. It is not a config change.
