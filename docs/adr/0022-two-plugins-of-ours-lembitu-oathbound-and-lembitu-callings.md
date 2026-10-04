# ADR-0022: Two plugins of ours — Lembitu.Oathbound and Lembitu.Callings

Date: 2026-10-04
Status: Accepted; the specification below grows as the 2026-10-04 grilling settles it
Amends: ADR-0020 (scope of `Lembitu.Oathbound`), ADR-0021 (owner of the Callings code)

## Context

ADR-0020 decided one patch plugin, `Lembitu.Oathbound`, for the four changes Oathbound has no
settings for. ADR-0021 then gave the Callings design to "a plugin of ours" and said it widened that
single plugin. The two halves patch different targets. The Oathbound half hooks Oathbound
internals, and Oathbound ships almost daily, so every bump means re-checking it. The Callings half
hooks vanilla skills, World Advancement Progression, BlacksmithingExpanded and Herbalist, which
change rarely, and needs from Oathbound only where the Oathstone stands.

## Decision

**Two plugins, split by what they patch.**

- **`Lembitu.Oathbound`** adapts Oathbound: respec and class switch reset to level 1, and party
  kill XP.
- **`Lembitu.Callings`** owns professions: the focus choice, the steep curve, shadow levels, the
  star in the skills window and the Oathstone check. It finds the Oathstone without linking
  Oathbound's assembly.

An Oathbound bump that breaks a hook disables only the class features; professions keep working.
Each plugin has its own enforced config and its own version check at join.

## Lembitu.Oathbound

**No talent-point cap, and Oathbound's stock XP pace.** Oathbound grants class level − 1 points
and no branch excludes another, so a level-80 character owns all 79 nodes. Level 80 costs
161,950 XP, roughly 2,500-3,000 kills at this server's creature health. The owner chose not to cap
points and not to change `ExperienceMultiplier` (1). If level 80 arrives too early in the Run, that
is revisited once observed. This drops item 4 of ADR-0020.

**A kill pays the killer's party, and nobody else.** Oathbound's `SharedExperience` stays off, so
the server attributes each kill to the owner of the killing blow (companions and burning count for
their owner). An unpartied killer earns the kill alone. A partied killer's party members near the
kill split it with the party bonus. Players who hit the creature but are outside the killer's party
earn nothing. This keeps partying the only way to share XP: if unpartied helpers kept full XP, two
strangers on one Troll would earn 200% and out-earn any party. Guilds that fight a boss together
party up first; boss keys stay presence-based and are unaffected. A party never waives proximity:
a member who is not near the kill earns nothing from it and does not count in the split.

**The party bonus rises from 100% for one to 150% for eight.** With n party members in range of the
kill (the killer included), the party shares the kill's XP × (1 + 0.5 × (n − 1) / 7), split equally:
one member alone earns 100%, two share about 107%, four about 121%, eight share 150%, which is
18.75% of the kill each. The curve is linear in n and its top is the party cap of eight. Shares are
rounded at random so each member's average is exact. This replaces the 110-125% band of ADR-0019
and ADR-0020 (owner's decision, 2026-10-04).

**"Near the kill" is 100 m**, measured on the server from the dead creature to each member's
reported position, among connected members. It is the same radius World Advancement Progression uses
for a boss key and ProgressivePowers for mastery credit (pinned to 100 m the same day), so "present
for the fight" means one distance across the server. The centres differ slightly: a boss key is
measured from the player whose game controls the boss. A member SocialSystem holds in the party while
disconnected is never in range.

**Every class may gather with every profession.** Oathbound's equipment rules (`Equipment.Allows`)
treat the fishing rod as a two-handed weapon, so Rogue, Monk, Berserker, Highlander and Breaker could
not fish, and a Monk holds no pickaxe or axe and mines and chops bare-handed, which raises Unarmed
rather than Mining or Wood Cutting. `Lembitu.Oathbound` lets every class equip the fishing rod, and
a Monk's bare-handed hit on a rock or tree raises Mining or Wood Cutting. Armour, weapon, shield and
bow restrictions stay as Oathbound ships them. A class therefore never narrows a Calling
(ADR-0021: anyone can practise any profession).

How it is built, decided from the code rather than asked:

- **Respec.** After `Warrior.Core.Progression.Respec` clears the active class's talents, its XP is
  set to zero, so the class is at level 1. The tree's "Reset for free" button says what it now costs.
- **Class switch.** After a successful `Progression.SwitchClass`, both the class left and the class
  taken have their XP and talents cleared. Their records are kept, because Oathbound keys the unlock
  of Berserker, Highlander, Breaker and Dragonsworn on the record existing.
- **Kill XP.** Oathbound's server-side `RouteDeath` keeps its validation and its per-creature XP
  (`KillRewards.Experience`); only the recipient list and amounts change. Party membership comes
  from SocialSystem's server-side party service by player ID, not from the party ID clients publish
  on their character, which a client writes and the server cannot vouch for.
- **Gathering tools.** A postfix on `Equipment.Allows` admits the fishing rod for every class; the
  Monk's bare-handed hits on rocks and trees raise Mining or Wood Cutting.
- **Enforced Oathbound config.** `SharedExperience = false` and `ExperienceMultiplier = 1` are pinned,
  because the design above depends on them.

## Lembitu.Callings

**The star is clickable only at the Oathstone.** Each profession row of the skills window carries a
star showing the Calling. Within about 10 m of the Oathstone (the `WarriorOathstone` object Oathbound
places beside the start temple) a click takes effect at once; elsewhere the star does nothing and its
tooltip says to change the Calling at the Oathstone. There is no pending state. Dropping a focus asks
for confirmation and names the level the skill falls to. The star has its own click target, because
DetailedLevels already uses a click on the row to show skill buffs.

**A focus keeps its XP on death; its shadow does not.** Dying leaves a focus skill's level and its
progress into the next level untouched. Its shadow, being what the skill would be without the focus,
drains as a non-focus skill would: World Advancement Progression's relative drain and boss-key floor,
applied to the shadow's own level. Dropping a focus therefore gives back both the faster gain and the
death protection the focus gave. Combat, body and non-focus profession skills drain as before. With
the ladder of ADR-0023, a specialist never drains below a rung of their own focus.

**Herbalist and Fishing get a bonus-output perk.** Neither mod gives its producer a level-scaled
perk: tonic strength reads the drinker's skill, and no pinned mod scales fishing. `Lembitu.Callings`
adds expected extra output that grows linearly with level: about 1.5 extra items per successful
tonic, elixir or mead-base craft and about 1.25 extra fish per landed catch at 100 (ADR-0024). Each
craft or catch rolls once: the whole part of the expectation is given and the fraction is a chance,
so the average is exact. It copies the item's identity and quality, consumes nothing more and grants
no extra skill XP.

**Every profession skill drains by one rule.** BlacksmithingExpanded and Herbalist bring bundled
skill managers that take their skill out of the list during death, apply their own loss and put it
back, so World Advancement Progression's drain and floor never see it (Blacksmithing lost 5% even
below the floor; Herbalist lost nothing). Both mods' own loss is set to 0, and `Lembitu.Callings`
drains a non-focus Blacksmithing or Herbalist by World Advancement Progression's settings and
boss-key floor in the same death step where it protects focuses and drains shadows.

How it is built, decided from the code rather than asked:

- **Gain.** A lowest-priority prefix on `Skills.RaiseSkill(SkillType, float)` scales `factor` for the
  eleven profession skills. Every one of them reaches that method: vanilla skills directly, the
  Jotunn skills of ImpactfulSkills and ExpertExplorer and the bundled-manager skills of
  BlacksmithingExpanded and Herbalist through `Player.RaiseSkill`. Running last means ImpactfulSkills'
  per-skill rates and any learning bonus are already in `factor`. World Advancement Progression's
  `Skill.Raise` replacement then applies its ceiling as before.
- **Shadow levels.** Only a focus skill stores one; a non-focus skill's shadow always equals its real
  level. When a skill becomes a focus its shadow starts at its current level, and every later gain
  also advances the shadow at the steep-curve rate against vanilla's level requirement. Dropping
  the focus sets the real level to the shadow and clears its accumulator.
- **Death.** A focus skill's level and accumulator are saved before `Skills.OnDeath` and restored
  after every other patch on it has run, the two bundled skill managers' own drain included; their
  drain therefore never reaches a focused Blacksmithing or Herbalist. ImpactfulSkills restores its
  hidden skills the same way (`ImpactfulSkills.cs:4710-4737`). The shadow is drained with World
  Advancement Progression's settings at the same moment.
- **Storage.** A versioned record in `Player.m_customData`, beside Oathbound's own, holding the four
  focuses and their shadows.
- **Settings.** The curve bands and rates are server-locked through Jotunn, which the Pack already
  requires.

## Consequences

- Adding a plugin is adding a directory (ADR-0001); the build cost of two is the same as one.
- An Oathbound pin bump re-checks `Lembitu.Oathbound` only.
