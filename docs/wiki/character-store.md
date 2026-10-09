# Character store — server-held characters and the five-minute save

On 2026-10-07 the owner decided the server holds the character of record (ADR-0034) and asked for
the server to run like a professional dedicated server. This page keeps the research behind that
decision: how vanilla saves characters, what Thunderstore offers, what each candidate was found to
do, what saving costs, and the open-source code a fallback plugin would learn from. The research was
static: decompiled packages and the 1.0.16 game assembly, Thunderstore and GitHub metadata, the live
server's log, and one throwaway benchmark. No candidate was run in game.

## Decisions

The decisions are ADR-0034's; the interview's other answers are in [Server
operations](operations.md#decisions-of-2026-10-07). In short:

- **ServerManager holds the characters**, after a trial on the test host with the full Pack (#101)
  and its adoption in Pack v17 (#102). If the trial fails, we build our own plugin to the same
  contract.
- **A player's crash loses at most five minutes, a server crash about ten.** ServerManager sends a
  full character every five minutes and inventory changes within about a second, but writes
  characters to disk only after a world save, so the world saves every five minutes
  (`-saveinterval 300`). The trial measured 385 s lost to a hard server kill, and the owner accepted
  about two save intervals for that rare case (ADR-0034, 2026-10-07 amendment).
- **Settings this implies** (README of `sighsorry/ServerManager` 1.1.7, "Server settings"):
  `maxPlayers: 10`, `maxCharactersPerAccount: 1`, `startItems: []`, `cheatDetection.action: log`,
  `statCaps.action: log`, an empty logo URL so it fetches nothing from outside, and the Pack copied
  into its `required` folder with the seven presentation mods in `optional`. Its Discord webhooks and
  bot replace DiscordConnector.
- **Enrollment of the Run's existing characters** uses `loadServerCharacterOnJoin: false` until
  every Run player has joined once; the owner then checks `sm:characterlist` and sets it to `true`.
  This covers the three players who joined `LembituRun` on 2026-10-06, so the owner coordinates
  their first join and no deadline is needed.

### How vanilla saves a character (Valheim 1.0.16, decompiled)

- Each client saves its own character on its own timer: `Game.m_saveInterval` is a static 1800 s,
  checked in `Game.UpdateSaving`. The server's `-saveinterval` sets only the server's timer.
- When the server's world save fires, `ZNet.Save(saveOtherPlayerProfiles: true)` calls
  `ZNet.SaveOtherPlayerProfiles`, which sends every client the `SavePlayerProfile` RPC. A shorter
  server interval therefore makes every client save more often, with no client mod.
- Clients also save on logout and after sleeping (`Game.SleepStop`, if more than 60 s since the last
  save). A death updates the profile in memory only.
- A server shutdown (`ZNet.Shutdown`, `Save(sync: true)`) does not ask clients to save; the console
  `save` command (`ZNet.RPC_Save`) does. A maintenance restart therefore saves before it stops.
- `Game.SavePlayerProfile` runs on the main thread: `PlayerProfile.SavePlayerData` (which calls
  `Player.Save`), `Minimap.SaveMapData`, then `PlayerProfile.Save`. `Player.Save` carries the
  inventory with item custom data, known texts, skills and `Player.m_customData`, so a store that
  keeps the game's own bytes keeps Oathbound, Callings, Guide, EpicLoot and personal keys.

### What saving costs (measured 2026-10-07)

| What | Measurement | Source |
| --- | --- | --- |
| World save on the live server, day one | 42–371 ms, 15 saves | `World save (5/5) done. Total time` lines in the `lembitu` container log |
| A character file after the first evening | about 30 KB | Steam Cloud character files on astral-tricep |
| The map buffer a character save rebuilds | 8,388,658 bytes, compressed to about 8.5 KB | `Minimap: compressed mapData` in a client `Player.log` |
| Rebuilding and compressing that buffer | 45 ms in a .NET 8 benchmark | Throwaway F# script copying `Minimap.GetMapData`; Unity's Mono is slower, so 0.1–0.3 s in game is an estimate, not a measurement |
| Host | 12 cores, 125 GB RAM, load 0.4–0.9; the game container at about 6% CPU and 1.8 GB after 16 h | `docker stats` and `uptime` on astral-bicep |

A save every five minutes therefore costs each player one short freeze per five minutes, and the
server one sub-second world save. Neither was judged a reason to save less often.

### Thunderstore, 2026-10-07

The full Valheim index (12,762 packages) was filtered for character storage and save frequency.
Server-side character storage that is live on 1.0:

| Package | Version, date | Verdict |
| --- | --- | --- |
| [sighsorry/ServerManager](https://thunderstore.io/c/valheim/p/sighsorry/ServerManager/) | 1.1.7, 2026-09-29 | Adopted, after a trial. All 81 game members it patches exist in 1.0.16. Uses the game's `Player.Save` bytes inside its own profile format (schema 46). Accepted updates live in server memory; the disk copy follows world saves, written to a temp file then `File.Replace`, 30 backups per character. No published source or licence. |
| [Chazman/RunicCharacterVault](https://thunderstore.io/c/valheim/p/Chazman/RunicCharacterVault/) | 1.0.4, 2026-10-06 | Not chosen. MIT, a fork of Landoria's; enrols existing characters. Uploads the written `.fch` on every save and writes each upload at once. Confirms a logout before the disk write, and drops a failed write without retrying. |
| [Landoria/CharacterVault](https://thunderstore.io/c/valheim/p/Landoria/CharacterVault/) | 1.0.30, 2026-09-25 | Not chosen. As Runic, but requires new characters. Its README says characters are not saved after a client crash or network loss. |
| [ReefTeam/ReefCharacters](https://thunderstore.io/c/valheim/p/ReefTeam/ReefCharacters/) | 0.1.0, 2026-09-11 | Rejected. Keeps the 30-minute window, replaces files non-atomically, sends no confirmation, saves nothing at shutdown, and has no limit on incoming data. |
| [Smoothbrain/ServerCharacters](https://thunderstore.io/c/valheim/p/Smoothbrain/ServerCharacters/) | 1.4.16, 2025-05-02, deprecated | Rejected. Breaks on 1.0.16 (`Inventory.Load` is now ambiguous by name). The fix exists only in unreleased source ([`bb7d3cd`](https://github.com/blaxxun-boop/ServerCharacters/commit/bb7d3cd), "fix for deep north"), which has no licence. Its emergency backup is rejected after any normal save in the same session. |

Not audited: BigAI/CharactersVault 2.6.1 (five-minute sync, its README warns old characters lose
their inventory), UpdatingOldPlugins/ServerSideSave 0.1.0, Creaton/Server_Manager 2.7.7 (needs its
own Docker agent), VerdantsAscent/FiresVAngarde 0.2.37 and Zomax/TheGreatHall 3.0.51 (a development
build).

Save frequency only: ComfyMods/OdinSaves 1.6.0 saves the character every 300 s through
`Game.SavePlayerProfile`, so any upload hook sees it (GPL-3.0). MidnightMods/AsyncSave 0.6.0 moves
the map rebuild and the file write off the main thread; how it interacts with a storage mod was not
checked.

### Code a fallback plugin would learn from

| Source | Licence | What it teaches |
| --- | --- | --- |
| [landoria-gaming/Landoria.CharacterVault](https://github.com/landoria-gaming/Landoria.CharacterVault) | MIT | Storage, chunked transfer with SHA-256, a commit queue, backup retention, admission policy, a graceful-shutdown coordinator |
| [ChazmanMods/ValheimMods, RunicCharacterVault](https://github.com/ChazmanMods/ValheimMods/tree/main/RunicCharacterVault) | MIT (folder `LICENSE`) | Fail-closed local backup before a character is replaced; a protected first enrollment |
| [Tenemo/EpicLoot_ProgressionFix](https://thunderstore.io/c/valheim/p/Tenemo/EpicLoot_ProgressionFix/) 0.1.183, the character-checkpoints and first-join-enrollment sources shipped in its package | MIT | Checkpoints carrying a request ID and checked byte for byte against the disk copy; a shutdown that waits for every verified checkpoint |
| ReefTeam/ReefCharacters 0.1.0 (package only) | MIT | The smallest upload-on-save, server-copy-wins loop |
| [ucwxcato/CatosAntiCheat-valheim](https://github.com/ucwxcato/CatosAntiCheat-valheim) | MIT | A mod-list handshake with an allowed-optional list and a retry; it checks GUID and version, not hashes |
| `blaxxun-boop/ServerCharacters`, ServerManager | none | Ideas only, never code |

The Pack's `.versions.txt` already lists a SHA-256 for every file, which is what a hash check needs.

### The trial, 2026-10-07 (#101)

ServerManager 1.1.7 ran with the full Pack on the test host, server and client both on Valheim
1.0.17, one Steam account. Run directories are under `~/lembitu-native-tests/` on astral-tricep;
the per-criterion disposition is the file ticket101-final-disposition.json in the planned-orders run.
Kill tests used the native processes, not `docker kill`.

| Criterion | Result | Run |
| --- | --- | --- |
| Pack client joins; missing optional AzuClock joins | Passed | `20261007T093543Z-ticket101-boot` |
| Altered Tally DLL refused (`validation.hash_not_allowed`); missing Tally refused (`validation.required_plugin_missing`) | Passed | `…093543Z-ticket101-boot`, `20261007T135216Z-ticket109-missing-tally` |
| Second character on one account refused | Passed | `…093543Z-ticket101-boot` |
| Enrollment: `false` stored a used character; `true` replaced an edited local file; deleting every local copy restored identical custom data, inventory with item metadata, skills and known texts | Passed | `20261007T123308Z-ticket101-resumed-contract` |
| Client killed: 83.6 s lost; coins picked up 2 s before the kill kept | Passed | `20261007T125851Z-ticket101-runtime-contract` |
| Server killed five minutes after a checkpoint: 384.7 s lost | Failed the original 300 s; passes the amended bound | `20261007T100836Z-ticket101-crash-bound` |
| Buffed fight with a real EpicLoot club, the Oathbound Huscarl record and a full backpack against Eikthyr: nobody kicked | Passed | `20261007T132207Z-ticket101-combat-maintenance` |
| Planned restart: progress made just before `save` survived the stop | Passed | `20261007T133035Z-ticket101-planned-orders` |

One client, five idle minutes: without ServerManager 41.1 CPU seconds, a 33.35 ms frame and
`ZNet.Update` at 0.73 ms mean, 3.9 ms worst; with it 38.5 s, 33.35 ms, and 0.65 ms mean, 11.4 ms
worst. The worst-case figure is one sample. Two-player load, the shared Tally meters and the
owner's admin client joining are the owner's two-account session.

Three differences in the first comparisons came from the game, not from ServerManager, and a plain
reload without ServerManager shows them too: Explorer gains skill in the first seconds after
spawn, AzuExtendedPlayerInventory rearranges equipped items in its hidden rows after load, and
Venture Logout Tweaks empties its own `VV_LogoutData` key on load. The comparisons now read the
character at native deserialization, before any of that runs; nothing was excluded.

### Cutover runbook

1. Take a full backup with `scripts/backup-world.sh` and keep its off-host copy.
2. Unpack the approved Pack v17 on astral-bicep and write `~/.config/lembitu/deploy.env` (0600):
   `LEMBITU_PACK_ROOT=<that directory>` and `LEMBITU_LOAD_SERVER_CHARACTER=false`.
3. Deploy the server install and the Discord webhook file, then recreate the container with
   `scripts/launch-server.sh run`, which applies and checks ServerManager's policy before it
   starts. Never edit `required/` or `optional/` by hand.
4. Announce the update. The three players who joined `LembituRun` on 2026-10-06 each join once.
5. Check `sm:characterlist` lists all three, set `LEMBITU_LOAD_SERVER_CHARACTER=true`, and run
   `scripts/launch-server.sh restart`. Confirm a rejoin plays the server's copy and the log shows
   `WorldCharacterCheckpointCompleted ... pending=0`.

## Exclusions

- **Client-owned characters with a shorter save interval.** This would cut the loss window with no
  mod, but leaves the restore gap and edited files. Excluded by the integrity goal.
- **Runic Character Vault plus separate parts.** Excluded for the integration it needs and its
  logout-before-disk confirmation. It stays the best MIT base if the fallback is built.
- **Building our own plugin first.** Excluded only on time: characters would stay unprotected for
  weeks of a live Run. It stays the fallback.
- **AsyncSave.** Not adopted: the five-minute freeze was accepted, and its fit with a storage mod is
  unverified.

## Lessons

- **Where a character is stored does not change how much a crash loses; how often it is saved
  does.** Every storage mod examined copies the character when the game saves it.
- **Memory is not disk.** ServerManager acknowledges an update once it is in memory. Only a written,
  replaced file survives a server crash; that is why the world save interval matters to it.
- **Deprecated is not proof of broken, but check.** ServerCharacters 1.4.16 really is broken on
  1.0.16, while its unreleased source is fixed.
- **The 2026-10-04 premium review was wrong** to say no maintained server-character mod existed
  (`local/premium-review-2026-10-04/README.md:88`): Landoria's (2026-08-01) and ServerManager
  (2026-09-09) were both live then.
