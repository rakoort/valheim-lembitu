# ADR-0005: Personal keys are the fixed point, and a bridge adapts the mods that disagree

Date: 2026-09-10
Status: Accepted
Issues: #11, #12, #13, #27

## Context

The server's premise is that a rival clan gains nothing from your boss kill: progression is private
(#11), and the kill only credits players who fought it (#12). Valheim's own mechanism is the
opposite — a world-wide key set once, for everyone.

Several adopted mods read that world key, or the creature star levels that character level rewrites:

- **EpicLoot** gates biome progression, unidentified-item identification and bounty offers on world
  boss keys via `biomedata.json`, and rolls drop rarity off creature star level. It knows how to ask
  StarLevelSystem for the level, and has never heard of WackyEpicMMOSystem.
- **More World Locations AIO** gates trader stock on `requiredGlobalKey`/`notRequiredGlobalKey`.
- **ProgressivePowers** earns mastery levels from boss kills, by a mechanism we have not yet
  confirmed.
- **YouAreNotWorthy** gates gear on world progression, which is why it was not adopted.

Left alone, a server that never sets world keys presents EpicLoot and MWL AIO with a world where
nobody has killed anything: Meadows-tier identification and empty trader shelves for three months.
The cheap fix — dual-writing a world key when any clan first kills a boss — leaks the first clan's
progress to everyone, which is precisely what #11 exists to prevent.

## Decision

- **Personal keys are authoritative.** No world key is written to make another mod happy.
- **One plugin of ours, the progression bridge, answers other mods' questions** from per-character
  state: which biomes a player has unlocked, and what effective creature level a fight was worth.
- **EpicLoot is adapted, not configured around.** Its integration API is documented as stable — "no
  assembly reference and no Harmony patches on its internals" — so the bridge uses that seam rather
  than patching EpicLoot, and survives its updates.
- **Character level owns creature levels; the bridge feeds it into EpicLoot's rarity roll.** A
  dangerous creature therefore drops better loot, which is the link players expect and the reason
  StarLevelSystem was not adopted as a third scaling system.
- **MWL AIO's trader gates stay unset.** Trader stock is priced and curated instead of key-gated, so
  it needs no key at all.

## Consequences

- The bridge is the one piece of integration code the whole stack depends on, and it is ours. If it
  is wrong, loot tiers and trader stock are wrong; if it is absent, EpicLoot behaves as if the run
  never started.
- Whether ProgressivePowers needs the bridge is an open question for #10: per-character kill counts
  need nothing, world keys need adapting.
- Any future mod that reads world keys is an adoption cost, not a drop-in. That test belongs in the
  verification gate.
- Boss keys cannot be traded or gifted, so #16's Trade Post never carries progression — only goods.
