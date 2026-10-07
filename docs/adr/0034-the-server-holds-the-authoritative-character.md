# ADR-0034: The server holds the authoritative character

Date: 2026-10-07
Status: Accepted; ships with Pack v17 after a test-host trial
Supersedes: ADR-0010's "accept character saves as authoritative" and "progression is client-owned";
ADR-0005's 2026-09-15 line on character-save storage
Amends: ADR-0007 (player cap, moderation), ADR-0003 (no fork remains)

## Context

ADR-0010 accepted that each player's own character file is the truth, with no tamper resistance.
The owner now wants the server run like a professional dedicated server, not a game room. Three
gaps follow from client-owned characters. A restore returns the world but no character
(`docs/wiki/operations.md`, Backups). A player can edit, copy or restore their own file to gain
items, keys or levels. And a crash can cost up to thirty minutes of play: vanilla saves a character
only on the client's own thirty-minute timer, when the server's world save asks, after sleeping and
on logout, and a server shutdown does not ask at all.

The Run began on `LembituRun` on 2026-10-06, so live characters exist only on players' PCs.

## Decision

- **The character store is the character of record.** The server keeps every character; a joining
  player plays the server's copy, and their local file is overwritten by it.
- **The mechanism is sighsorry ServerManager**, after a trial on the test host with the full Pack.
  If the trial fails, we build our own plugin to the same contract from MIT-licensed sources
  (`docs/wiki/character-store.md`).
- **A crash costs at most five minutes.** Full characters reach the server every five minutes and
  inventory changes within about a second; the world saves every five minutes (`-saveinterval
  300`) because ServerManager writes characters to disk at world saves.
- **The integrity goal is explicit.** One character per Steam account, the owner exempt. The server
  refuses a client whose mods differ from the Pack by DLL hash, except for leaving out its optional
  presentation mods. Cheat and stat detections are logged for review, never acted on
  automatically, because client reports can be wrong or forged.
- **Existing Run characters enrol once, from their players' own files.** The server accepts each
  player's local character at join until every Run player has joined, then the store wins.
- **Player logs are disclosed and used.** ServerManager always records positions, inventories,
  skills, damage and deaths; the rules say so, admins use them to settle loss and duplication
  cases, and they are deleted after the Run.

## Considered options

- **Shorter saves only, characters stay client-owned.** Cheapest, but leaves the restore gap and
  edits. Rejected by the integrity goal.
- **Runic Character Vault, a separate mod check and our own restart tooling.** MIT and lean, but
  more parts to integrate, and it confirms a logout before the file reaches disk.
- **Our own plugin.** Exactly the contract and fully ours, but weeks before characters are
  protected while the Run is live. Kept as the fallback.

## Consequences

- Restores can now return characters: the hourly backup captures the character store with the
  world, Guilds, Marketplace and region claims, as one set.
- ServerManager replaces the MaxPlayerCount fork, DiscordConnector and the admission cap. The
  player cap becomes vanilla's ten (ADR-0003 and ADR-0007, 2026-10-07 amendments).
- ServerManager has no published source or licence. We configure it and cannot patch it; a defect
  waits for its author or triggers the fallback.
- A character can no longer be repaired by editing its file on a PC. Repairs are admin restores
  from the store's backups.
- Every Pack change is a reinstall the server enforces: a client one DLL off is refused.
- A player who edited a file before their enrollment keeps the edit. The window is short and
  accepted.
