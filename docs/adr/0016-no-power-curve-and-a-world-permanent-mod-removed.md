# ADR-0016: The run keeps no power curve, and a world-permanent mod is removed anyway

Two removals on 2026-09-17, both the owner's decision, both destructive by design (#85).
`RandyKnapp/EpicLoot` 0.14.5 and `team0/ValheimRAFT` 4.3.2 leave the Pack and the server. This
supersedes ADR-0014's "one power curve, gear" and takes the deliberate exception to ADR-0009 that
that ADR said would never be taken.

## No power curve

ADR-0014 removed character level and left gear as the single curve. Removing EpicLoot leaves none. A
character now grows exactly as in vanilla — better materials, better gear — and what it may wear is
gated per character by World Advancement Progression's material-biome locks. That gate is not a
multiplier: it decides *when* a tier becomes available, not how strong it is.

This is coherent rather than a subtraction of everything. The run's distinguishing systems are now
clans, wards, personal keys, portal rules and fixed creature difficulty. What it no longer has is a
number that grows.

## What the EpicLoot removal destroys

- **Magic properties are lost.** They live in a `MagicItemComponent` on each item's custom data, so
  every enchanted weapon and armour piece becomes the plain vanilla item it was based on.
- **Its prefabs vanish from the world.** The enchanting and augmenting stations, shardstones and its
  other created items came from its own `PrefabCreator`; anything built or stored disappears on the
  first load without the mod.
- **A client can still roll loot.** Drops are rolled where the player is, so a player who keeps
  EpicLoot installed keeps generating magic items. Removal is therefore a player action as much as a
  server one, which is why Pack v11 exists and why the group is told to delete rather than update.

Three configuration files leave with it: the enforced `.cfg`, the `loottables.json` patch that
thinned effect counts (#73), and the client seed that muted the rarity palette. `config/client/`
is now empty of seeds entirely, the first time since it was introduced.

## What the ValheimRAFT removal destroys, and the rule it breaks

ADR-0009 says a world-permanent mod is installed before the launch world and never removed during
the run, because its content is written into the save. ValheimRAFT is world-permanent: its vessels
are prefabs in the world data. Removing it deletes every ship, its cargo, and the footing of anyone
aboard.

The owner accepted that knowingly, having first closed vehicle building to players that morning
(#82) and then judged a disabled mod not worth its weight. `DynamicLocations` and `ZdoWatcher` ship
inside the same package and leave with it, as do both their overlays.

The precedent this sets is narrow and worth stating: **a world-permanent mod may be removed when the
owner accepts the loss of its content**, and only then. It is not evidence that removal is safe, and
ADR-0009's rule stands for every other case, Max Dungeon Rooms included.

## Consequences

- Twenty-four pins. The Jotunn 2.29.2 override leaves `scripts/stage-stack.sh`, because EpicLoot was
  the only package declaring it, and the pin-count tripwire drops to 24.
- The join-time handshake loses two announced mods, so the server refuses fewer clients than before.
  A Pack reissue is still required, because a client that keeps either mod behaves differently from
  everyone else.
- Re-adding either mod mid-run is possible for the world but not for the players: existing gear
  would not become magical again, and no removed ship comes back.
- The run now has no answer to "what do I chase at level cap", because there is no cap and no
  chase. If that turns out to be the wrong shape for a three-month run, the cheapest reversal is
  EpicLoot with drops at a low rate, not character level.
