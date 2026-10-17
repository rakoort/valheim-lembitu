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

## Amendment — 2026-09-15: admission is a password, not a whitelist

The decision above assumes an invited Roster of fifteen, whitelisted on the server, with a cap of
twenty above it. The owner replaced that on 2026-09-15: the server is **public and
password-protected**. Friends find it in the server browser and join with the password.

What changes:

- **`permittedlist.txt` is deliberately not created.** Valheim treats that file as a whitelist —
  listing anyone in it bans everyone else — so its absence is what keeps the server open to anyone
  who holds the password. There is no roster list, and no per-person admission control.
- **The cap of twenty stays.** It is no longer sized against fifteen invited players; it is now the
  bound on how many may be connected at once.
- **The player cap's role changes meaning.** `MaxPlayerCount` still raises the admission literal
  above vanilla's ten, and #9's unproven eleventh connection is unchanged.

What the change costs, stated rather than discovered:

- **A password is not a person filter.** Anyone who sees the server can attempt it, and this pack
  ships no moderation mod. Admission cannot be restricted beyond the password, and undoing this
  means restoring the whitelist model or adopting a moderation mod that is not currently in the
  Pack.
- **The "fifteen non-technical players" premise of #21 softens.** Distribution still has to work for
  people who have never installed a mod, but the audience is no longer a fixed list this project can
  enumerate and check off.
- **#23's roster-onboarding criterion changes shape.** "Every player in the roster has installed the
  pack and connected once" becomes an expectation about a group, not a checklist over a known set.

The rest of ADR-0007 stands unchanged: the game and Pack are still frozen together after acceptance,
recovery is still rollback from the proven backup, and the Run still has an announced end.

## Amendment — 2026-10-07: cap ten, enforced Pack, password in the Discord server

- **The player cap is vanilla's ten.** The owner judged twenty unnecessary for a Run balanced
  around eight active players (ADR-0019). The MaxPlayerCount fork leaves with Pack v17; #9's
  unproven eleventh connection is moot.
- **The Pack is enforced, not just pinned.** ServerManager (ADR-0034) refuses a client whose mods
  differ from the Pack by DLL hash, except for leaving out its optional presentation mods. The cost
  recorded above, "this pack ships no moderation mod", no longer holds: ServerManager carries bans,
  kicks and access lists.
- **Admission stays public with a password**, now shared in a members-only channel of the Discord
  server. The owner is the only admin.
- **Every planned restart is a maintenance restart**, daily at 06:00 Europe/Oslo with warnings at
  ten, five and one minutes. A restart never runs the container's updater: the freeze above still
  requires that the accepted game version does not drift.

## Amendment — 2026-10-17: the game follows Steam's public build

The freeze above cannot hold on the client side. Steam updates every player's game, and no Steam
setting keeps a client on an older build: the `default_old` branch keeps the previous build only
until the next patch. Valheim 1.0.20 raised the network version from 40 to 41 on 2026-10-15, so the
server, still frozen at 1.0.17, refused every player for two days.

- **A network-version change on Steam's public branch is breakage, by definition.** It meets the
  bar above: a newer release that fixes something actually broken, adopted after renewed acceptance
  on the test host.
- **The owner moved the Run to 1.0.20 and every mod's latest release on 2026-10-17** (Pack v22).
  ServerManager 1.1.7 could not run on 1.0.20 at all, so the game and the Pack had to move together.
- **What stays frozen** is everything this project controls between patches: the server does not
  update itself on a restart, and the Pack does not move without acceptance. The update is still a
  deliberate act; only its trigger now comes from Steam rather than from us.
- **Going back is a restore, not a downgrade.** 1.0.20 rewrites the world in its own format at the
  first save and ServerManager rewrites each character at its next save, so returning to 1.0.17
  means restoring the pre-update backup and losing play since then.
