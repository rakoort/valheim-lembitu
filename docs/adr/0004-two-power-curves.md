# ADR-0004: Two power curves, character level and gear

Date: 2026-09-10
Status: Accepted
Issues: #5, #12, #14, #15, #24

## Context

The server is meant to feel MMO-lite: clans matter, and so does personal progress. Four candidate
systems each offered a way to grow a character, and all four were available and 1.0.7-capable:

- **Character level** (WackyEpicMMOSystem): an XP ladder with attribute points, already the old
  server's progression and the curve #12, #14 and #15 are written against.
- **Gear** (EpicLoot): magic drops, six rarities, enchanting, bounties.
- **Skill perks** (ImpactfulSkills): milestones and bonuses on every vanilla skill.
- **Enchant levels** (Valheim Enchantment System): flat stat gains per enchant level on an item.

They are not features that overlap; they are four multipliers landing on the same damage and
survivability numbers, each tuned by a different author against vanilla. AdditiveDamageModifier then
rewrites how resistances combine and imposes a player minimum-damage floor on top. ValheimArmory
sits alongside as a fifth axis of breadth, and its own FAQ concedes its weapons need
community-supplied EpicLoot and Enchantment System configs before they can be enchanted at all.

## Decision

- **Run exactly two power curves**: character level, and gear.
- **Cut ImpactfulSkills.** Vanilla skills stay vanilla, so skill gain remains a thing our XP
  tickets can reason about.
- **Cut Valheim Enchantment System.** EpicLoot owns enchanting, so an item carries one enchant
  state and one tooltip authority. This also answers #24: it stays dropped.
- **Cut ValheimArmory.** EpicLoot already turns every vanilla weapon into six tiers of progression;
  new base weapons that need vetted third-party config files to participate are breadth we would
  maintain and players would ignore.
- **Keep AdditiveDamageModifier.** With two curves it stops being a balance risk and starts being
  the thing that prevents stacked resistance rolls from becoming immunity, and its
  minimum-damage floor keeps a fully-geared player killable — which #14 depends on.
- **Keep DataForge for tuning only.** One YAML place to adjust weights, stacks and costs; no cloned
  or custom items, so item identities stay vanilla for #16's ledger.

## Consequences

- Balance has two inputs to tune, not four, and #12/#14/#15 modify one curve rather than competing
  with three.
- Harmony patch order still matters: character level attributes, EpicLoot effects and
  AdditiveDamageModifier's floor all land on one number. #10 measures the stacked result with
  Legendary resistance rolls.
- Players who wanted skill perks or a second enchanting UI do not get them. The compensating depth
  is world content and clan politics, not more multipliers.
- Adding a third curve mid-run is possible but one-way: EpicLoot-style item data cannot be removed
  without destroying gear.
