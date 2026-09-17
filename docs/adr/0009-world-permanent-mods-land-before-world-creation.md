# ADR-0009: World-permanent mods land before the launch world is created

Date: 2026-09-10
Status: Accepted
Issues: #19, #20, #26, #28

## Context

Three adopted or forked mods write content into the world save rather than into config:

- **More World Locations AIO** stamps locations into a zone the first time that zone generates.
- **Max Dungeon Rooms** changes generated dungeon layouts; its own FAQ says that if the mod is
  removed, the dungeons "stay, they are part of the world save file".
- **ValheimRAFT** creates vehicles and building pieces that persist as ZDOs.

Installed after launch, each only affects ground nobody has walked yet, which produces a world where
half the map has content and half does not. Removed after launch, each leaves saved objects
referencing prefabs that no longer exist.

This is a different kind of irreversibility from EpicLoot or our own plugins. Those are one-way
because removing them destroys player *gear or progress*; these are one-way because removing them
corrupts the *world*.

## Decision

- **Install the world-permanent mods before the launch world is created**, as part of #19, and
  never remove them during the run.
- **Freeze their proven pins after full-pack and two-client acceptance** (ADR-0007), before launch
  world creation, since a later version cannot be swapped in casually either. Development uses the
  latest releases in disposable test worlds; world-permanence does not freeze development versions.
- **Make the deployment work a prerequisite** (#28): MWL AIO ships an asset-bundle manifest and a
  `Bundles/` tree, and `scripts/install-plugins.sh` currently syncs DLLs only. The container's
  `rsync` has no `--delete`, so stale bundles persist in the server's own plugin directory — the
  pruning trap already documented in `docs/build.md`, now applying to directories rather than single
  files.
- **Treat world-permanence as a documented property**, listed in `docs/modstack.md`, so a future
  addition is checked against it rather than discovered by a broken save.

## Consequences

- The launch world cannot be created until these three are verified, which puts ValheimRAFT — the
  fork with no upstream 1.0 release — on the critical path to #19. If it is not ready, the choice is
  to delay world creation or to launch without it forever.
- The playtest world in #10 and the launch world must run the same three mods, or the playtest
  proves nothing about generation.
- Backups in #20 must capture the world in its 1.0 chunked form together with the clan registry and
  character store, because a restore into a server missing any of these three cannot load the save.
- Anything else world-permanent is now a launch-window decision by definition, not a mid-run option.

## Amendment — 2026-09-15

More World Locations AIO is cut, so the world-permanent set is **Max Dungeon Rooms** and
**ValheimRAFT**. Its asset-bundle deployment consequence goes with it: `scripts/install-plugins.sh`
already deploys whole staged trees, and no remaining package ships a `Bundles/` tree of that size.

World Advancement Progression is not world-permanent — its keys live in character saves — but it
clears the world's global keys on startup, so it belongs in the pack before the launch world is
created rather than after.
