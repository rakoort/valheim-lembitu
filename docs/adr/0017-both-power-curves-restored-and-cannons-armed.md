# ADR-0017: Both power curves restored, ValheimRAFT back, cannons armed

On 2026-09-17 the owner removed character level, then gear, then ValheimRAFT, and then restored all
three within hours (#86). This ADR records the end state and supersedes ADR-0014 and ADR-0016. The
end state: **two power curves — character level and gear — and ValheimRAFT installed with cannons
enabled and player building open.**

## What is pinned again

- `WackyMole/WackyEpicMMOSystem` 1.9.67, with the XP and attribute configuration the repository had
  before removal. Its armour-gate companion, `WackyItemRequiresSkillLevel`, is **not** restored, so
  character level buys attributes and gates nothing. Gear remains gated by personal keys alone.
- `RandyKnapp/EpicLoot` 0.14.5, with every pinned value intact: `PlayerMustKnowRecipe` gating,
  Adventure Mode off, drop rate 0.6, shardstones 0.05, the thinned effect counts from #73 and the
  muted client palette. Nothing had to be re-derived; the configs came back from git.
- `team0/ValheimRAFT` 4.3.2, and with it `DynamicLocations` and `ZdoWatcher`. Twenty-seven pins.

## What changed rather than returned

**Cannons are on.** They were disabled at adoption (#64, #26) on the reasoning that the run did not
need a vehicle weapon system. The owner reversed that here. The consequence is bounded by the PvP
stance: a flagged crew can shell another flagged crew, and an unflagged player cannot be shelled. It
is still the first weapon system this run has added, and the first content decision made without a
measurement behind it.

**Player vehicle building is open again**, after being closed for part of the same day (#82).

## What did not come back, and cannot

- **Character levels and XP.** They lived in the character file, and removal stranded them. Every
  character starts at level 1 with the personal keys it already holds.
- **Magic item properties.** They lived on the item as a `MagicItemComponent` and were stripped when
  EpicLoot left. Old gear is plain vanilla; new drops roll normally.
- **Every vessel built before the removal**, with whatever was stored aboard. ValheimRAFT's ships
  are prefabs in the world save.

Re-adding a mod restores the *system*, never the player state it held. That is the load-bearing
lesson of the day and it applies to every mod in this stack that writes into a character file, an
item, or the world.

## The churn is the risk this ADR exists to name

The stack changed shape six times on 2026-09-17: modifiers retuned twice, character level removed,
a creature-mod swap attempted and reverted after it proved dead on this game, Karma and modifiers
switched off, EpicLoot and ValheimRAFT removed, and all three mods restored. ADR-0007 freezes the
game and Pack after an acceptance gate precisely to stop this; the run is pre-freeze, so nothing was
violated, but three player-visible reversals in one day is its own cost. Players lost levels, magic
gear and ships to decisions that were undone the same afternoon.

The practical guard, recorded here rather than as a rule nobody reads: **a removal that destroys
player state waits a day**. Disabling is reversible, removing is not, and every destructive step
today had a disable available.

## Consequences

- The join-time handshake regains `EpicMMOSystem` and `ValheimRAFT`, so a Pack reissue is mandatory
  rather than optional: v12.
- The BepInEx 5.4.2202 override and the Jotunn 2.29.2 override return to `scripts/stage-stack.sh`
  with the mods that declare them, and the pin-count tripwire goes back to 27.
- ADR-0009 is intact again for ValheimRAFT: the mod is world-permanent, it is installed, and the
  precedent its removal set — that a world-permanent mod may leave when the owner accepts losing its
  content — now has a second half, which is that the content does not come back.
