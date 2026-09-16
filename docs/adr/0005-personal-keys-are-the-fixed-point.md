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

## Amendment — 2026-09-15

The fixed point stands: progression is per character, and a rival clan gains nothing from your boss
kill. The mechanism is no longer ours.

- **Personal keys are World Advancement Progression 1.0.0**, configured with `UsePrivateKeys` and
  `BlockAllGlobalKeys`. Keys live in the character save, raids are evaluated per player, and the key
  is awarded to everyone within a hundred metres of the chunk host when the boss dies.
- **The progression bridge is cancelled.** EpicLoot needs no adapter: its own `Item Drop Limits`
  setting has a `PlayerMustKnowRecipe` mode that reads the requesting player, so gating follows the
  character rather than the world.
- **Contribution credit is cancelled.** Presence at the fight earns the key. A damage threshold
  would have punished the cooperation between clans that the boss scaling is designed to force.
- **Gear keeps two gates, deliberately.** Character level gates crafting, equipping and consuming
  through WackyItemRequiresSkillLevel's curated rules; personal keys gate equipment and crafting
  through World Advancement Progression's `LockEquipment` and `LockCrafting`. Nothing else is
  key-locked: building, cooking, eating, repairs, portals and boats stay open.
- **Character-save storage is accepted as authoritative**, with no tamper resistance (ADR-0010).

## Amendment — 2026-09-16

The 2026-09-16 configuration review went through every lock the mod offers and changed the scope
the 2026-09-15 amendment set above. The list of key-locked actions is now: equipment, crafting,
**cooking**, **eating**, guardian powers and boss summons. Building, building repair, equipment
repair, taming, boats and portals stay open.

Cooking and eating were added for the reason equipment was locked in the first place. Without them
a veteran feeds a keyless player endgame food, which is the same handout in a different slot. The
decision rests on a fact the earlier amendment did not record: every one of these locks is
**material-scoped**, not blanket. The mod gates an action by the biome of the materials involved,
so a character with no keys still cooks and eats Meadows food and builds in wood. Locking food
does not stop a newcomer feeding themselves.

One asymmetry is accepted knowingly: equipment is locked while equipment repair is open, so a
keyless player may repair above-tier gear they cannot wear.

The gear gates in `config/enforced/WackyMole.ItemRequiresSkillLevel.yml` also changed shape in the
same review: `BlockCraft` is now false and `BlockEquip` true, so character level gates wearing
rather than making. Crafting is still gated by material through `LockCrafting`, so the two gates
remain distinct rather than redundant.
