# ADR-0007: The game version and the pack are frozen for the run

Date: 2026-09-10
Status: Accepted
Issues: #19, #21, #23

## Context

The run is three months long, with an announced start and end date. Over that window Valheim will
very likely patch, and every mod in the stack is published by someone who ships on their own
schedule — the whole catalogue moved in a single evening on 2026-09-09.

Most of what the server runs cannot be withdrawn once players have used it. EpicLoot writes data
onto items; the world-permanent mods write content into the world save (ADR-0009); our own plugins
persist keys, XP pools and contracts. A mid-run break therefore has no clean rollback: disabling the
mod destroys what players built with it.

Nothing on the server refuses a mismatched client either. A player whose game or mods moved ahead
either desyncs, crashes on missing prefabs, or silently loses the rules that mod carried.

## Decision

- **Freeze the game at 1.0.7 for the whole run.** Automatic update on restart is disabled on the
  server, and the install checklist tells players to disable Steam auto-update for Valheim.
- **Freeze the pack.** Pins in `docs/modstack.md` are re-checked once, immediately before the launch
  world is created, and then fixed. A newer upstream release is not adopted mid-run unless it fixes
  something that is actually broken for us.
- **Everything ships at launch.** No planned content injections, so there is no mid-run pack update
  to coordinate across fifteen non-technical players.
- **Player cap 20**, above a fifteen-player roster, so a full evening never refuses anyone.
- **Recovery is rollback, not adaptation**: if something does break, restore from the proven backup
  in #20 and stay on the frozen version.

## Consequences

- Upstream bug fixes published during the run are declined by default. That is the cost of the
  freeze, and it is cheaper than a mid-run cutover on an irreversible stack.
- The pinned pack becomes a hard requirement rather than a nicety: #21's distribution and
  verification steps are what make the freeze real on the client side.
- Vanilla 1.0.7 embeds the ten-player limit as a literal, so a cap of 20 depends on the
  MaxPlayerCount fork in #9 working — or on us patching the admission path ourselves.
- The end of the run is the natural moment to re-pin everything, which makes an extension a
  deliberate re-verification rather than a drift.
