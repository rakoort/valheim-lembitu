# MaxPlayerCount

Raises the ten-player limit Valheim embeds in the peer-admission path, and the capacities it
advertises to Steam and asks PlayFab for, to a configured value. Our cap is **20**, against a
fifteen-player roster (ADR-0007, `CONTEXT.md`).

| | |
| --- | --- |
| Upstream | <https://github.com/AzumattDev/MaxPlayerCount> |
| Forked at | `4482e27acc105385700c81bd74b08980201a3857` (2025-07-04, "Fix refs"), which declares `ModVersion = "1.2.4"` |
| Pinned release | `Azumatt/MaxPlayerCount 1.2.5` (2026-09-06), whose design change we carry — see below |
| Licence | MIT-0, `LICENSE.md` in this directory (copied verbatim from upstream) |
| Built for | Valheim 1.0.7 (network version 39), BepInEx 5.4.23.5 |

## Why this fork exists

Upstream has no 1.0-era release: 1.2.5 declares BepInEx `5.4.2333` and has not moved since
2026-09-06 (ADR-0003 makes it one of the four mods nobody upstream is porting). The limit itself is
still a literal in the 1.0.7 admission path, so the mod's approach is sound and only its build is
stale.

The public source is **1.2.4**; the pin is **1.2.5**, which is binary-only. Its changelog reads
"Fix crossplay once more. Now holds off on patching anything until the game knows it is the host
for better timing." Decompiling the pinned DLL shows what that means in practice, and it is a
better design than 1.2.4's:

- 1.2.4 rewrote the IL operand at patch time (`codes[j].operand = ReplacePlayerLimit()`), baking
  the configured number into the method, and patched the Steam and PlayFab sites lazily from a
  `FejdStartup.Start` postfix that branched on `ZNet.m_onlineBackend`.
- 1.2.5 patches everything from `Awake` and **inserts a `call` after the literal the method loads**,
  so the limit is resolved on every admission and every lobby creation. The backend branching
  disappears, and a config edit takes effect without a restart.

We took 1.2.5's shape. That is the pinned behaviour, and the version number in our `.csproj` names
the upstream release this port matches rather than a version of our own.

## What the 1.0.7 assemblies actually contain

Verified against `lib/valheim/` before writing the port, because a transpiler that silently fails
to match leaves the cap at ten:

- `ZNet.RPC_PeerInfo` still holds `call instance int32 ZNet::GetNrOfPlayers()` immediately followed
  by `ldc.i4.s 10` and `blt.s`. The admission limit is a literal in the peer-admission path, as
  issue #9 assumed.
- `ZPlayFabMatchmaking` declares `public const uint MaxPlayers = 10u` and loads the offset literal
  **11** at two sites: `CreateLobby` (`ldc.i4.s 11` then
  `stfld PlayFab.MultiplayerModels.CreateLobbyRequest::MaxPlayers`) and `CreateAndJoinNetwork`
  (`ldc.i4.s 11` then `callvirt PlayFab.Party.PlayFabNetworkConfiguration::set_MaxPlayerCount`).
  The 11 is ten players plus the server's own relay leg, which is why the arithmetic is
  `configured + (vanillaLiteral - 10)` rather than a bare assignment. `CreateAndJoinNetwork` loads
  a second literal (`ldc.i4.s 15`) two instructions later, so only the first match is rewritten.
- `SteamGameServer.SetMaxPlayerCount` still takes the count as an argument, so that site stays a
  prefix.

## Our changes

1. **Ported to our toolchain.** Upstream's project is a legacy non-SDK `net4.8` file with HintPaths
   into a Windows Steam install and Windows-only post-build steps (ILRepack, PowerShell, Thunderstore
   zip). Replaced with an SDK-style `net472` project per `docs/build.md`. Plugin identity comes from
   the generated `PluginInfo`, so the GUID, name and version are declared once — the GUID is
   unchanged (`Azumatt.MaxPlayerCount`), because BepInEx derives the config file name from it.
2. **1.2.5's runtime-resolved limit, as described above**, instead of 1.2.4's patch-time operand
   rewrite and `FejdStartup.Start` lazy patching.
3. **Game members are `nameof`.** `ZNet.RPC_PeerInfo`, `ZNet.GetNrOfPlayers` (upstream compared the
   method name against a string), `ZPlayFabMatchmaking.CreateLobby`,
   `ZPlayFabMatchmaking.CreateAndJoinNetwork`, `SteamGameServer.SetMaxPlayerCount`. A game update
   that renames or removes one is now a build error here rather than a server that quietly admits
   ten players (ADR-0002 has the general form of this argument). Two names stay strings:
   `MaxPlayers` and `set_MaxPlayerCount` belong to the PlayFab SDK, which nothing in this repo
   references; a transpiler that fails to match them logs an error, which is the fallback.
4. **Evidence logging at Info, not `#if DEBUG`.** Upstream logs its patch results only in debug
   builds, so the shipped binary is silent and its failure mode — pattern not found, cap still ten —
   is invisible. We log one Info line per patched site naming the vanilla literal and the value it
   now resolves to, an Error naming the method when a pattern is not found, and one Info line the
   first time each rewritten site actually calls back into us. Issue #9's acceptance criteria are
   evidenced from `BepInEx/LogOutput.log` alone; without a real eleventh client, that is the
   available proof.
5. **Config default is 20** (upstream also defaults to 20; stated here because the value is a
   project decision, not an inherited one). Section `1 - General`, key `MaxPlayerCount`, in
   `Azumatt.MaxPlayerCount.cfg`. Kept upstream's `FileSystemWatcher` reload, which is what makes
   the runtime-resolved limit useful, and it now logs the old and new value instead of nothing.
6. **Dead scaffolding removed**: upstream's `ConfigurationManagerAttributes`, `AcceptableShortcuts`
   and the `config<T>` overload whose `synchronizedSetting` parameter was accepted and ignored.
   Nothing referenced them.
7. **No ServerSync.** This mod has none upstream and needs none: the limit is enforced by the
   server on its own admission path, and a client cannot opt out of it. ADR-0002 does not apply.

## Do clients need it? No — server only

Issue #9 asks this explicitly, and all three patched surfaces answer it. `ZNet.RPC_PeerInfo` runs
on the machine **receiving** a peer's info, which is the host; `SteamGameServer.SetMaxPlayerCount`
exists only on a game server; `ZPlayFabMatchmaking.CreateLobby` and `CreateAndJoinNetwork` run on
whoever creates the session, again the host. A client without the mod is told the server's capacity
by the server, so it stays out of the pack: nothing about it is synchronised, and installing it on
a client changes nothing. It is not in the client pack list in `docs/modstack.md` for that reason.

What the test server proves and what it does not: the log lines show each of the three literals
found and rewritten, and the Steam prefix actually executing with the configured value. The
admission hook's own "rewritten limit in use" line needs a peer to connect, so the *rewrite* of
the admission path is evidenced and its *execution* is not — that, and the eleventh simultaneous
player, are #10's.

## Re-forking

Upstream is one file. Pull its `Plugin.cs`, re-apply changes 1–6 (the `nameof` conversion is
compiler-guided: build, fix errors), and re-check the IL facts above against the new game build —
`ilspycmd -r lib/valheim --ilcode lib/valheim/assembly_valheim.dll` and grep for `GetNrOfPlayers`
and `set_MaxPlayerCount`. If upstream ever publishes 1.2.5's source, diff change 2 away.
