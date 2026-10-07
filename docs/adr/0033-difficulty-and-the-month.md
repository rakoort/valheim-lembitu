# ADR-0033: Difficulty and the month

Date: 2026-10-06
Status: Accepted; ships with Pack v17, native acceptance still required (#97, #99)
Amends: ADR-0019 (tuning targets and the month), ADR-0025 (the last boss, not the class cap)

## Context

On the first evening three players died eleven times in about two and a half hours in the Meadows.
The owner reported that ordinary creatures felt about right, but Eikthyr, though killed, took too
long (`docs/wiki/shakedown.md`, first-evening basis). Eight-player bosses forced every guild to
borrow fighters; a five-player target lets a full guild win alone while smaller guilds still have
reason to party across guilds. The Market already rewards cooperation without making it compulsory.

Valheim 1.0 has eight bosses. Kall Fimbulbringer in the Deep North (internal `FrozenKing`), not
Fader, is the last. The month's model had omitted that last biome.

## Decision

**Bosses are fixed for five players.** CreatureManager's Bosses Follow Biome Level Preset is Off:
every boss is level 1. `Boss.health` falls from 8 to 5; `Boss.damage` stays 1.5, or 2.25× vanilla
with Combat hard. No health, damage or raid odds scale with players online or nearby. At the target,
average players with the biome's gear win with margin; a smaller skilled group can win too.

**Bosses roll one to four modifiers.** The offence group always rolls one, its entries summing to
at least 100%; defence, on-hit and utility each roll about 33%. Vortex, adaptive and chameleon stay
banned for bosses and Enforcers; deathward, regenerating, omen and blamer stay banned everywhere.

**Ordinary creatures keep their base health, with gentler stars and more traits.** `Global.health`
stays 2, `Global.healthPerLevel` falls from 1 to 0.75 (+75% per star), damage stays unchanged. Each
of four modifier groups rises from a 2.64% total to about 5.43%, giving about 20 in 100 creatures
at least one trait rather than about 10. This is a three-player target in practice, based on the
Meadows evening, not a promise that all biomes have been played. Creature biome levels stay.
Karma, Enforcers and Combat hard stay; Kall's phase 2 keeps CreatureManager's built-in exemption.

Expected effective health after dividing by Combat hard's 0.85 player damage is about 2.5× vanilla
in Meadows, 3.0× Black Forest, 3.7× Swamp, 4.2× Mountains, 4.7× Plains, 5.2× Mistlands and 6.3×
Ashlands/Deep North; every boss is about 5.9×. These are estimates, not observed fight results.

**The month ends at Kall.** An actively playing group should kill Kall Fimbulbringer in about one
month; the Run remains open-ended afterwards. The pace model adds about ten hours after Fader
(around 55 hours) to Kall (around 65). ADR-0025's power cap stays 80 after Fader, Oathbound's class
cap: Kall adds no class power. ADR-0032 sets profession mastery targets against these milestones.

## Consequences

- A full guild can win a boss alone. Inter-guild cooperation now rests on the Market, parties and
  smaller guilds, not a numeric requirement for every boss fight.
- Five-player boss fights must be measured with biome gear: party size, minutes, deaths and
  rolled modifiers. The first evening cannot establish the balance of later biomes.
- Native acceptance verifies boss level 1 across biomes, fixed health despite headcount, 75% star
  growth on ordinary creatures and modifier-group roll semantics. Kall's phase exemption must
  survive; defeating him must not raise the class power cap.
