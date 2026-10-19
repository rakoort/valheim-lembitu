# ADR-0037: Balance for the group that plays

Date: 2026-10-19
Status: Accepted; ships with Pack v23 (#123), native acceptance still required
Amends: ADR-0019 (death costs, difficulty, pace), ADR-0020 and ADR-0031 (Oathbound's death penalty),
ADR-0021 and ADR-0030 (the focus rate and the steep curve), ADR-0022 (`ExperienceMultiplier`, the
Callings death message), ADR-0033 (tuning targets, creature and boss numbers, the pace model)

## Context

Thirteen days into the Run, the live server log since 2026-10-09 and the character store showed a
game tuned for a group that does not play. One guild of four plays; at sleep time two players were
online 18 times of 37, one 11 times, three 6 times and four twice. Players died 1.6 times per
play-hour, the most frequent 2.3 times. The Elder took the whole guild 55 minutes and 14 deaths. The
two easiest bosses took about 27 hours of play, against a model that put Kall at 65. The top class
levels were about 19, below the power cap of 30 that two boss keys allow, so XP rather than keys
held classes back.

Players also reported that the Calling changed nothing. The log showed it working as built: on the
Oct 11 boat trip all three players earned about 300 raw Sailing XP; the focus helmsman kept 297, the
non-focus players 158 and 197. But a focus never earned more than the normal rate, nothing differed
below level 10, and low levels cost so little XP that a non-focus player gained levels as fast. No
focus skill lost a level at any of 277 deaths, yet every death showed a generic "Skills lowered".
The Calling was a penalty nobody saw rather than a reward anyone felt.

## Decision

All of it from the owner's balance review of 2026-10-19.

**A focus earns double.** A profession in the Calling gains ×2 XP at every level (`[Calling]
FocusRate = 2` in `Lembitu.Callings`). Its shadow level keeps the steep curve, so dropping a focus
still costs exactly what it gave.

**The steep curve eases.** A non-focus profession gains at full speed to 20, half to 80 and a third
after (was full to 10, half to 60, a quarter to 80 and a tenth after). Against a focus, a non-focus
skill now needs 3.3× the work to reach 30, 3.9× to reach 80 and 4.8× to reach 100; the old curve
beside a doubled focus would have meant 3.9×, 6× and 12×.

**A death costs the corpse run and 2.5% of each skill above the floor, and no class XP.**
Oathbound's `DeathLossFraction` is 0 (was 0.5). The launch modifier `DeathPenalty easy` halves
vanilla's skill loss and keeps its item rules. The floor stays 10 levels per personal boss key; focus
skills stay protected. The death message names the drain, the floor and the focus skills kept,
replacing the generic one.

**Fights are tuned for the group that plays: ordinary creatures for two players, bosses for four.**
`Global.health` falls from 2 to 1.5, `Boss.health` from 5 to 4 and `Boss.damage` from 1.5 to 1.2,
which Combat hard makes 1.8× vanilla. Combat hard, the Hard star preset with +75% health per star,
about 20% creature modifiers, Karma, Enforcers and one to four boss modifiers stay. There is no
death-rate target: fights are judged in play, not against a number.

**The pace model aims for Kall near 100 hours of play,** Fader near 88. Oathbound's
`ExperienceMultiplier` is 2 (was 1). Profession XP rates stay; with a doubled focus the measured
focus rates already put mastery at 46-88 hours for the professions players practised. A week of
`Profession XP:` lines under the new rules decides any correction (#100).

**No catch-up.** Existing skills and class levels stay where they are.

## Consequences

- Expected effort against vanilla, counting Combat hard's 85% player damage and the Hard stars:
  Meadows 1.9×, Swamp 2.7×, Plains 3.5×, Ashlands and Deep North 4.7× for ordinary creatures; about
  4.7× for every boss. These are estimates, not observed fights.
- ADR-0032's mastery targets follow the new pace: Land a little before Fader (about 85 hours), Road
  at Fader (about 88), Craft at Kall (about 100).
- `Lembitu.Callings` 0.7.0 declares `VersionStrictness.Minor`, so a client without Pack v23 is refused
  at join; the Pack updater installs it at the next start.
- Unchanged: the guild kill-XP split (full bonus at four, a pair 58% each), the 10-levels-per-key
  power cap, the corpse run and boss key rules.
- Boss fights are still recorded after each session: party size, minutes, deaths and modifiers.
