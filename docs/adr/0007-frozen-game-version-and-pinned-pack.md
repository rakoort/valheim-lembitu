# ADR-0007: The game version and the pack are frozen for the run

Date: 2026-09-10
Revised: 2026-09-12 — freeze only after acceptance, not during development
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

- **Develop on the latest stable/public game and latest mod releases.** Update both the test
  client and dedicated server, refresh references, and rebuild maintained forks while preserving
  their custom behavior. Do not hold development on an archived client to fit an older server.
- **Freeze the proven game and pack together only after everything works.** Full-pack acceptance
  and simultaneous two-client acceptance must pass on the same candidate before freezing it and
  creating the launch world. Re-check public releases before that gate; changes require a new gate.
  Exact versions, build IDs, manifests and hashes recorded during development identify test inputs,
  not an approved freeze. No game version is selected for the run yet.
- **Keep the accepted versions for the whole run.** Only after acceptance, arrange controlled
  client/server installations and disable automatic server updates so the tested combination does
  not drift. A newer upstream release is not adopted mid-run unless it fixes something actually
  broken for us and the replacement passes acceptance.
- **Everything ships at launch.** No planned content injections, so there is no mid-run pack update
  to coordinate across fifteen non-technical players.
- **Player cap 20**, above a fifteen-player roster, so a full evening never refuses anyone.
- **Recovery is rollback, not adaptation**: if something does break, restore from the proven backup
  in #20 and stay on the frozen version.

## Consequences

- The original 1.0.7 selection was premature and is superseded by this revision. Existing 1.0.7
  logs, manifests and failed candidate results remain historical evidence, not current acceptance.

- Upstream bug fixes published during the run are declined by default. That is the cost of the
  freeze, and it is cheaper than a mid-run cutover on an irreversible stack.
- The pinned pack becomes a hard requirement rather than a nicety: #21's distribution and
  verification steps are what make the freeze real on the client side.
- Vanilla 1.0.7 embeds the ten-player limit as a literal, so a cap of 20 depends on the
  MaxPlayerCount fork in #9 working — or on us patching the admission path ourselves.
- The end of the run is the natural moment to re-pin everything, which makes an extension a
  deliberate re-verification rather than a drift.
