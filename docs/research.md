# Research provenance

Where the project's external claims come from, and where its own measurements live (#22).

There is no separate "research reports" directory. The research that informed this pack is recorded
in the places that use it: upstream source and commits cited inline in the ADRs and wiki, the
Thunderstore package APIs the pin list was taken from, the game's own shipped documentation, and the
dated first-party measurements retained on the hosts that produced them. This page is the index,
with each item marked **in repo** or **external**.

## External primary sources

These are the sources a claim in this repository can be traced back to. Each is a specific,
version-qualified location rather than a project home page, because a moving target is not a source.

| Source | What it settles | Referenced by |
| --- | --- | --- |
| Valheim dedicated server manual, shipped as `Valheim Dedicated Server Manual.pdf` inside the dedicated server install | The command-line surface: `-name`, `-port`, `-world`, `-password`, `-savedir`, `-public`, `-logFile`, `-saveinterval`, `-backups`, `-crossplay`, `-instanceid`, `-preset`, `-modifier`, `-setkey`; the valid preset names and modifier values; the `permittedlist.txt` / `adminlist.txt` / `bannedlist.txt` whitelist model and the `[Platform]_[User ID]` identity format | `config/launch/launch.env.example`, `docs/wiki/operations.md`, `docs/rules.md` |
| The dedicated server binary itself (`valheim_server_Data/Managed/assembly_valheim.dll`, 1.0.12) | The argument strings actually parsed at runtime, and the modifier enum values (`$menu_modifier_*` keys and `$menu_combat` / `$menu_deathpenalty` / `$menu_resources` / `$menu_raids` / `$menu_portals`) | `config/launch/launch.env.example` |
| [AzumattDev/MaxPlayerCount](https://github.com/AzumattDev/MaxPlayerCount) at `4482e27`, and the pinned 1.2.5 release | The admission limit is a literal in `ZNet.RPC_PeerInfo`; `ZPlayFabMatchmaking.MaxPlayers` and its two literal sites; `SteamGameServer.SetMaxPlayerCount` stays a prefix. Recorded in `src/forks/MaxPlayerCount/UPSTREAM.md` | `src/forks/MaxPlayerCount/`, `docs/modstack.md:60` |
| [sighsorry1029/BossRules](https://github.com/sighsorry1029/BossRules) source at `3d4e693` and commit [`e3d6d38`](https://github.com/sighsorry1029/BossRules/commit/e3d6d38563dcfd90353a568320f47f110d1253ca) | The altar-scan guard that caused the synchronous asset-preparation stall, and official 1.0.10's native-authority predicate that replaced our local plugin | `docs/build.md:671-683`, `docs/wiki/pack.md` |
| [Wacky-Mole/ItemRequiresSkillLevel](https://github.com/Wacky-Mole/ItemRequiresSkillLevel) commit [`141e5746`](https://github.com/Wacky-Mole/ItemRequiresSkillLevel/commit/141e5746aea2107cc281b45e359a7e82a0eee504) | 1.4.7 replaces its bundled `ServerSync.dll`; the package declares BepInEx 5.4.2350 | `docs/wiki/pack.md:130-132` |
| [JNDEV0/ValheimRAFT-zolantrisFork-1.0.12](https://github.com/JNDEV0/ValheimRAFT-zolantrisFork-1.0.12/tree/d899bc5c9cb182cc5f2da416c8047c7fcffc9493) at `d899bc5c` | `ValheimRaftPlugin.ModConfigSync.IsLocked` is set true; `CannonPrefabConfig.EnableCannons` is a public field registered through `ServerSyncConfigSyncUtil.RegisterAllConfigEntries`; `CannonPrefabs.OnRegister` returns before registering cannon items when disabled | `docs/wiki/pack.md:142-147` |
| [Valheim-Modding/Jotunn](https://github.com/Valheim-Modding/Jotunn/blob/v2.30.0/JotunnLib/Managers/MockSystem/MockManager.cs#L308-L353) v2.30.0 `MockManager` | The unsupported-dictionary warning is emitted before the field value is read, so the warning does not establish that any entry needs replacement | `docs/wiki/native-testing.md:90-93` |
| [blaxxun-boop/ServerSync](https://github.com/blaxxun-boop/ServerSync) | The pre-1.0 `ZRoutedRpc.Everybody` `MissingFieldException` and the shared-source remedy | `docs/adr/0002-serversync-vendored-as-shared-source.md` |
| Thunderstore package APIs for each pinned `owner/mod@version` | The pin versions themselves, their declared dependencies, and the package bytes the lock records | `docs/modstack.md`, `docs/modstack.lock.json`, `scripts/stage-stack.sh` |

The Thunderstore pins were re-checked against the live package APIs on 2026-09-15
(`docs/modstack.md:6-8`). That check is not archived as a report; its lasting output is the pinned
table and the hash lock, which is what the build consumes.

## First-party measurements

These are this project's own evidence. They are **external to the repository** by design — logs,
saves and binaries are large, machine-specific and sometimes contain private identities — and they
live on the hosts that produced them. Dates are the measurement dates, not the commit dates.

| Location | Host | Date | What it proves |
| --- | --- | --- | --- |
| `~/.cache/valheim-lembitu/ticket-66-20260915/` | astral-tricep | 2026-09-15 | The reduced 23-package pack stages with verified hashes and declared closure, builds only MaxPlayerCount and Lembitu.Harness with zero errors and zero warnings, and boots to `Chainloader startup complete` and the native Steam listener with twenty-nine plugins and no `MissingFieldException`/`MissingMethodException`. Also the generated-config surface the enforced overlays were written against. |
| `~/.cache/valheim-lembitu/ticket-64-20260914/` | astral-tricep | 2026-09-14 | Server-synced cannon disablement: baseline logs `Registered HandCannon`; after the overlay, zero registrations. Assembly coexistence for ValheimRAFT's bundled ServerSync and two Newtonsoft.Json copies. |
| `~/.cache/valheim-lembitu/ticket-62-20260914/` | astral-tricep | 2026-09-14 | EpicMMO panel drag ownership, with rendered screenshots and before/after state. |
| `~/.cache/valheim-lembitu/ticket-36-20260915/` | astral-tricep | 2026-09-15 | EpicLoot dictionary-warning safety: baseline vs. fixed logs, `verification.json`, `installed-files.json`. |
| `~/.cache/valheim-lembitu/ticket-35-20260915/` | astral-tricep | 2026-09-15 | Configuration generation and the boot that followed it. |
| `~/.cache/valheim-lembitu/ticket-32-20260914/` | astral-tricep | 2026-09-14 | Generated StoneOutlook content and the restoration blocker. |
| `~/.cache/valheim-lembitu/ticket-61-20260914/` | astral-tricep | 2026-09-14 | Committed-binary identity and the diagnostic instrumentation hashes. |
| `~/.local/state/lembitu/native-tests/` | astral-bicep / astral-tricep | 2026-09-13 | The full-pack native acceptance repetitions: `proof.json`, `events.jsonl`, IPC replies, installed-file hashes, screenshots and logs. Two repetitions passed; simultaneous two-client acceptance did not run. |

`docs/build.md` and the wiki pages carry the quoted excerpts from these runs, dated and scoped, so a
reader without host access can still see what was observed. The rule applied throughout: a
measurement is evidence for the thing it measured and nothing else — a clean boot is not gameplay,
a screenshot's existence is not rendering proof, and a declared capacity is not an admitted peer.

## What is not researched

- **No independent review of upstream mod source for correctness or security.** Adoption means
  running someone else's verified build; `scripts/screen-bundled-libs.sh` screens bundled libraries
  for game members that moved, which is a compatibility check, not an audit.
- **No load testing.** The twenty-player cap has a configured value, a rewritten admission literal
  and an advertised capacity; no eleventh simultaneous connection has been admitted, and #9 records
  that gap rather than closing it.
- **No client-side compatibility testing of every package.** The pack's own mismatch behaviour is
  the adopted packages' business; `docs/wiki/pack.md` states which mismatches are rejected
  automatically and which are not checked at all.
