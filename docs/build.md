# Building and installing plugins

Every plugin in this repo is a BepInEx 5 plugin for the **latest stable/public Valheim** client
and dedicated server, built as a .NET Framework 4.7.2 assembly because the game runs Unity's Mono runtime.
During development, refresh both game installations and all mod candidates; extract fresh references
and rebuild before testing. Exact versions and hashes record test inputs, not a freeze. Freeze only
after full-pack and simultaneous two-client acceptance (ADR-0007).

The September 13 public-game check confirmed server 1.0.12 / network 40 and client build
25253764 remain current. The updated full pack passed two native gameplay repetitions; see
[the acceptance record](#full-pack-native-acceptance--2026-09-13). Simultaneous two-client acceptance remains open.
These identities are dated test records, not a permanent selection or a claim about future latest releases.

## Where things live

| Path | Contents |
| --- | --- |
| `src/plugins/<Name>/` | Plugins we wrote. One project per plugin. |
| `src/forks/<Name>/` | Forks of third-party mods, one directory each, each with an `UPSTREAM.md` recording origin, version, licence and our changes. See `src/forks/README.md`. |
| `lib/valheim/` | Game reference assemblies, extracted from a local install. Not committed. |
| `lib/bepinex/` | BepInEx assemblies to compile against, plus the full pack in `lib/bepinex/pack/`. Not committed. |
| `dist/` | Installer source, mirroring the target BepInEx directory: `plugins/` with our DLLs and staged mod trees, `patchers/`, `config/` seeds. Not committed. |
| `config/enforced/` | The enforced server config, applied onto mod-generated configs. Committed. |
| `scripts/` | Reference extraction, stack staging, plugin install, enforced config, test server, plus `lib/` helpers shared between them. |
| `test/` | Behaviour tests for the scripts; each `test/*.test.sh` runs standalone. |

Game and BepInEx binaries are never committed. `scripts/extract-refs.sh` reproduces them.

## Where work happens

Development and testing happen on **astral-bicep** (x86_64 Linux), where the checkout lives at
`~/code/valheim-lembitu`. The Valheim dedicated server only ships for linux/amd64 and its Mono
runtime cannot be emulated on Apple Silicon:

- Docker Desktop with Rosetta: `Assertion: should not be reached at tramp-amd64.c:641`.
- Docker Desktop with QEMU (`tonistiigi/binfmt --install amd64`): BepInEx 5.4.23.5 preloads, then
  `Assertion at x86-codegen.h:410, condition 'offset == (gint32)offset' not met`.
- `lloesche/valheim-server` cannot even install the game there: its SteamCMD is a 32-bit x86 binary
  and segfaults.

The macOS client is no help either: Valheim 1.0 ships it as a native arm64 app, and BepInEx's
`libdoorstop_x64.dylib` is x86_64 only, so `dyld` refuses to inject.

**astral-tricep** (x86_64 Linux) is the second host, for the two-client network tests in the
playtest tickets.

## Build from a clean checkout

```sh
git clone https://github.com/rakoort/valheim-lembitu.git
cd valheim-lembitu
nix develop                      # dotnet SDK 8, curl, unzip, zip
scripts/test-server.sh install   # latest public server, fresh references, BepInEx (also updates)
dotnet build                     # every plugin -> dist/plugins/
scripts/stage-stack.sh           # every adopted mod at its pin -> dist/{plugins,patchers,config}/
scripts/install-plugins.sh ~/.cache/valheim-lembitu/server/BepInEx
scripts/test-server.sh run       # foreground; Ctrl-C to stop
```

`scripts/test-server.sh install` runs `scripts/extract-refs.sh` for you, since the server it just
downloaded is the best source of reference assemblies. Run `scripts/extract-refs.sh` on its own when
you build against a different install (`VALHEIM_MANAGED=…`) or after a game update.

Without Nix, any .NET SDK 8 or newer works; `Microsoft.NETFramework.ReferenceAssemblies` supplies
the net472 reference assemblies, so no Windows or Mono install is needed.

## Reference assemblies

`scripts/extract-refs.sh` populates `lib/`:

- **Game assemblies** are copied from a local Valheim install. It prefers the test server in
  `~/.cache/valheim-lembitu/server`, then SteamCMD server installs, then a Steam client install;
  override with `VALHEIM_MANAGED=/path/to/*_Data/Managed`. `mscorlib`, `netstandard` and `System.*`
  are deliberately skipped — the net472 reference assemblies from NuGet provide those, and Unity's
  copies collide with them.
- **BepInEx assemblies** come from `denikson-BepInExPack_Valheim` on Thunderstore, pinned to version
  `5.4.2350` (BepInEx 5.4.23.5) and verified against a SHA-256 in the script. The same pack is what
  `scripts/test-server.sh` installs, so we compile against the loader we deploy.

The script records a SHA-256 per file in `lib/valheim/refs.lock.json`.
`scripts/extract-refs.sh --check` re-verifies them, which is how you catch "the game updated under
me" before a plugin misbehaves at runtime.

Valheim's version numbers are `const`, so the compiler **inlines** them. A plugin built against
stale references keeps the old value forever — this is exactly how pre-1.0 ServerSync builds break
on 1.0.7 (issue #2). `Lembitu.Hello` reports the skew: it logs the network version it was compiled
against and errors if the running server reports a different one.

## Adding a plugin

Create `src/plugins/<Name>/<Name>.csproj` with a GUID and a version; `dotnet build` at the root
globs `src/**/*.csproj`, so there is nothing else to register:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <PluginGuid>lembitu.example</PluginGuid>
    <Version>0.1.0</Version>
  </PropertyGroup>
</Project>
```

The build generates an internal `PluginInfo` class from those properties, so the identity is
declared once: `[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]`. `PluginGuid`
is required and the build fails without it. `PluginDisplayName` overrides the name, which otherwise
follows the assembly.

## Referencing more of the game

`Directory.Build.props` gives every plugin `assembly_valheim`, `assembly_utils`,
`assembly_guiutils`, `UnityEngine`, `UnityEngine.CoreModule`, `BepInEx` and `0Harmony`. For anything
else, add it to the plugin's own `.csproj`:

```xml
<ItemGroup>
  <Reference Include="UnityEngine.PhysicsModule" Private="false">
    <HintPath>$(ValheimRefDir)UnityEngine.PhysicsModule.dll</HintPath>
    <Publicize>true</Publicize>
  </Reference>
</ItemGroup>
```

`Publicize` (from `BepInEx.AssemblyPublicizer.MSBuild`) makes private members visible to patches.
`Private="false"` keeps game assemblies out of `dist/`. Set `Publicize` as metadata on the
`Reference`, not as a separate `<Publicize Include="…" />` item: the package declares empty default
metadata for that item type, and its task then rejects the empty value.

A port that reaches into most of the engine — `src/forks/EpicMMOSystem` references about fifty
Unity modules upstream — takes everything `scripts/extract-refs.sh` extracted instead of a list
that rots:

```xml
<Reference Include="$(ValheimRefDir)*.dll" Private="false"
           Exclude="$(ValheimRefDir)assembly_valheim.dll;…" />
```

Exclude the assemblies `Directory.Build.props` and `ServerSync.props` already declare, or they are
referenced twice. One module cannot be referenced at all: `UnityEngine.ImageConversionModule`
targets netstandard 2.1, which a net472 assembly cannot consume (CS1705).

## Depending on a library another mod ships

Several pinned packages are plain libraries — `ValheimModding/JsonDotNET` (Newtonsoft.Json),
`ValheimModding/YamlDotNet`, `Jotunn`. BepInEx resolves them from the plugins directory at runtime,
so compile against them and ship nothing:

```xml
<PackageReference Include="Newtonsoft.Json" Version="[13.0.4]" ExcludeAssets="runtime" PrivateAssets="all" />
```

The version is exact for a reason. A floating reference resolves to whatever NuGet has newest, and
.NET Framework binds strong-named assemblies by exact version: compiling against 17.x while the
server has 16.x loaded fails at runtime, not at build. Check what the pinned package actually
contains — `ValheimModding/YamlDotNet 16.3.1` ships YamlDotNet **16.3.0**, and 16.3.1 was never
released on NuGet.

## Screening a prebuilt DLL against the game

A mod that bundles prebuilt libraries hides the ADR-0002 failure mode in each one: a member the
game removed, or a field it turned into a `const`, fails when the code runs rather than when it
builds. Before trusting such a DLL, compare what it reaches for against `lib/valheim/`. Its member
references are readable with a decompiler:

```sh
nix run nixpkgs#ilspycmd -- -r lib/valheim --ilcode <mod>.dll | grep 'ldsfld\|call'
nix run nixpkgs#ilspycmd -- -r lib/valheim -t ZRoutedRpc lib/valheim/assembly_valheim.dll
```

`ZRoutedRpc.Everybody` is the known one: a `const` on 1.0.7, so any assembly compiled when it was a
field carries an `ldsfld` to storage that no longer exists. That check is how
`src/forks/EpicMMOSystem` learned its bundled PieceManager was as broken as its bundled ServerSync,
and why every library it needs is vendored as source and recompiled.

## Server-synced config

A plugin whose settings must come from the server imports our ServerSync fork:

```xml
<Import Project="$(RepoRoot)src/forks/ServerSync/ServerSync.props" />
```

That compiles `src/forks/ServerSync/ConfigSync.cs` into the plugin, along with the three extra
references it needs. ServerSync is shared source rather than a shared DLL, and our copy names game
members with `nameof`, so a game update that renames or removes one is a build error here rather
than a silent failure on the server; ADR-0002 has the reasoning and
`src/forks/ServerSync/UPSTREAM.md` the detail. `src/plugins/Lembitu.Hello/HelloPlugin.cs` is a
worked example.

Never bundle a mod's own copy of ServerSync when porting it — delete it and import ours. Every
pre-1.0 build of it throws `MissingFieldException` on 1.0.7 the moment a mod broadcasts, and one
vendored copy is one place to fix that.

## Install loop

```sh
dotnet build                                  # -> dist/plugins/
scripts/stage-stack.sh                        # -> dist/plugins/, dist/patchers/, dist/config/
scripts/install-plugins.sh <bepinex-dir>      # sync into a server's BepInEx directory
```

`dist/` mirrors the BepInEx directory it deploys into: `plugins/` holds our built DLLs and one
self-contained tree per adopted mod, `patchers/` holds BepInEx patcher DLLs (Fast_AssetBundle_Loader
ships as a patcher), and `config/` holds config files a package ships as seeds, such as Clan's
emblems. The installer deploys all three trees preserving relative paths, records every file it
installed in `.lembitu-installed` at the BepInEx root, and on the next run deletes what it
installed before but no longer finds in `dist/` — a stale DLL, or a whole stale tree, empty
directories included. Files it did not install are never touched, and a directory that still holds
a foreign file survives pruning. `test/install-plugins.test.sh` pins all of this down.

Pruning is driven by the manifest alone, so the manifest is the one input that can delete outside
the target. Every entry is checked before the first removal against the same path policy `dist/`
names and the prune ledger already use: a name outside the allowed characters, or a traversal-shaped
one (`.`, `..`, a leading-dot component, or an absolute path), aborts the run and names the offending
line. Because the check happens before any removal, a corrupt manifest refuses the whole run rather
than pruning part-way and leaving the manifest describing files that are already gone.

Only two places write that manifest, and both are checked: the install itself validates each name
before copying it, and the plugins/-era migration validates the legacy entries before it rewrites
them — while the legacy file is still on disk to correct, since refusing after removing it would
leave nothing to edit. So a reported entry means the manifest was edited by hand or left by another
tool; delete the reported line and rerun.

`dist/` is the installer's source of truth and the build only ever adds to it, so run `dotnet clean`
(which empties `dist/`) after renaming or deleting a plugin. Otherwise the old DLL is still there to
install, which is how you end up with two plugins claiming one GUID. An empty `dist/plugins/` is an
error, not "prune everything" — the build may simply not have run.

## Enforced server config

The deliberate deviations from each mod's defaults - the "Enforced config" column of
`docs/modstack.md` - live in `config/enforced/`, applied onto the configs the mods generate on
their first boot:

```sh
scripts/apply-enforced-config.sh <bepinex-config-dir>
```

A `.cfg` overlay holds only the entries we pin and merges them into the generated file by section
and exact key, so a mod adding or renaming settings keeps working and a renamed key shows up as a
duplicate instead of silently reverting. Data files with no merge semantics (BossRules' power
table) replace wholesale. The run is idempotent; `test/apply-enforced-config.test.sh` pins the
merge down. Run it once after the first boot of a server, and again whenever the overlay or a pin
changes.

**The pruning trap.** A server keeps loading a plugin DLL until the file is gone, and
`lloesche/valheim-server` — the container used for the real server — copies plugins into a *second*
location without ever pruning it. In `/usr/local/etc/valheim/common` it runs

```sh
rsync -a --itemize-changes "$config_path/plugins/" "$plugins_path"
```

where `$config_path` is `/config/bepinex` (the bind mount you edit) and `$plugins_path` is
`/opt/valheim/bepinex/BepInEx/plugins` (inside the merged game directory). There is no `--delete`.
Consequences:

- Deleting a DLL from `/config/bepinex/plugins` does **not** unload it; the copy under
  `/opt/valheim/bepinex` keeps loading until you delete it there too, or wipe that directory and let
  the updater rebuild it.
- Renaming a plugin DLL leaves the old name behind, so two copies of the same plugin load and
  BepInEx reports a duplicate GUID.

So: remove plugins with `scripts/install-plugins.sh` (it prunes what it owns in the target), then
clear the container's second copy with `prune-mirror`:

```sh
scripts/install-plugins.sh prune-mirror <bepinex-dir> <docker-container>
```

Install runs append whatever they pruned to `.lembitu-removed` beside the manifest, and remind you
to do this. `prune-mirror` replays that list inside the container at the lloesche mirror path
above, removes the directories those removals emptied, and clears the ledger. Run it after the
container has synced (any restart after the install), or before; both orders end clean. The ledger
is only spent on a full replay — a removal that fails inside the container aborts the run and
leaves it pending. An emptied directory can survive in the mirror when the container user may not
write the plugins root itself; it loads nothing and is harmless. The two trees are visible on the
existing barebones server on bicep:

```sh
docker exec valheim-barebones ls /config/bepinex/plugins
docker exec valheim-barebones ls /opt/valheim/bepinex/BepInEx/plugins
```

**Adopted mods are not built here.** Most of what the server runs is upstream, installed at a pinned
version straight from Thunderstore; `docs/modstack.md` is the pin list, and ADR-0003 says why we
adopt rather than fork. `scripts/stage-stack.sh` turns that list into `dist/` trees:

```sh
scripts/stage-stack.sh            # fetch if missing, verify hashes, stage every pin
scripts/stage-stack.sh --refresh  # re-download every package, still hash-verified
scripts/stage-stack.sh --list     # print the parsed pin list, no downloads
```

It reads the "Adopted upstream" table in `docs/modstack.md`, so the pin list has one home. Each
package becomes one self-contained directory — a mod that is just DLLs still gets its own, so two
mods can never argue about a file they both ship — with the package's three possible shapes
normalized: root files and `plugins/` trees into `dist/plugins/<Mod>/`, `BepInEx/patchers/` into
`dist/patchers/<Mod>/`, and shipped config seeds like Clan's emblems into `dist/config/`. Thunderstore
metadata (README, CHANGELOG, icon, manifest) is dropped; licences and Jotunn `.yml` localization
stay beside the DLL, where the game loads them.

Every download is hash-checked against `docs/modstack.lock.json`, which the script writes on first
fetch of a pin and verifies thereafter — a re-published zip under the same version number is
refused, which is the silent-upgrade path ADR-0007 exists to close. Commit the lock file when the
script says it recorded new hashes. Declared dependencies are checked against the pin list before
anything is staged; the BepInEx pack and the Jotunn 2.30.0-over-2.29.2 override are the two
documented exceptions. Staged trees are recorded in `dist/.staged-dirs`, wiped before restaging (a
version bump leaves nothing from the older package) and retired when a pin leaves the list;
`dotnet clean` does not remove them, and it does not need to.

`test/stage-stack.test.sh` pins the parser, the layouts, the lock and the closure check down.

## Test server

On astral-bicep:

```sh
scripts/test-server.sh install   # game files (app 896660), reference assemblies, BepInEx, plugins
scripts/test-server.sh run       # foreground; Ctrl-C to stop
```

Game files land in `~/.cache/valheim-lembitu/server` (override with `VALHEIM_TEST_DIR`). It listens
on port 2466, because bicep already runs the barebones server on 2456; anything after `run` replaces
the whole argument list, e.g. `scripts/test-server.sh run -world "My World" -port 2466 -public 0`.
DepotDownloader is used instead of SteamCMD: anonymous login, no 32-bit dependencies, one
self-contained binary pinned by hash.

Chainload is proven by the BepInEx banner and the plugin's own lines in the server log. The last two
are ServerSync: its RPC registered on `ZNet.Awake`, and a synced config value broadcast without the
`MissingFieldException` a pre-1.0 build would throw. This September 9 log is historical 1.0.7 proof,
not acceptance of the latest public game:

```
[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server
[Info   :   BepInEx] Loading [Lembitu.Hello 0.2.0]
[Info   :Lembitu.Hello] Lembitu.Hello 0.2.0 loaded on l-1.0.7 (built against network version 39)
[Message:   BepInEx] Chainloader startup complete
09/09/2026 20:39:47: Valheim version: l-1.0.7 (network version 39)
Registered 'lembitu.hello ConfigSync' RPC - waiting for incoming connections
[Info   :Lembitu.Hello] ServerSync broadcast ok (probe = 1788975592)
```

`BepInEx/LogOutput.log` in the server directory keeps the same output.

Vanilla noise to ignore: `DllNotFoundException: libParty.so` and
`[S_API FAIL] Tried to access Steam interface SteamNetworkingUtils004 before SteamAPI_Init
succeeded` appear on an unmodded dedicated server too. `GameServer.Init() failed` followed by
`Steam is not initialized` means the UDP ports are taken — usually by the barebones server.

## Headless test client

Under [#38’s September 14 scope amendment](https://github.com/rakoort/valheim-lembitu/issues/38),
the per-family rendered-client log-level separation is the accepted required comparison for #38.
The per-scenario rendered-view comparison transfers to
[#49](https://github.com/rakoort/valheim-lembitu/issues/49) and
[#52](https://github.com/rakoort/valheim-lembitu/issues/52), not unfinished #38 acceptance.
No #49/#52 view is claimed to have been produced or compared.

`scripts/test-client.sh run` requires a logged-in Steam client, the latest stable/public game
installation matching the test server, and a GPU-backed X display. Its Weston headless launcher
uses `--renderer=gl --fake-seat --xwayland`.
The virtual input seat is required: without it, Xwayland 24.1.12 aborts in `xwl_cursor_warped_to`
when a client warps the pointer. Valheim then aborts after losing its display; its Bumblelion
thread stack alone does not identify the original display failure.

On astral-bicep, `DISPLAY=:0 xdotool mousemove 400 300` reproduced the display crash without
Valheim. Adding only `--fake-seat` allowed 20 consecutive pointer warps to finish successfully.
Use this probe only on a disposable test display: the failing configuration kills its X clients.

The launcher uses `-force-glcore`: default Vulkan stayed in the `loading` scene on astral-bicep
even with BepInEx disabled, while OpenGL reached the menu and rendered native gameplay. This
does not establish compatibility of every mod’s bundled shaders; the full-pack attempt below
reported unavailable shader platforms.

Update the licensed Steam installation on the public branch, then copy that current installation
into `~/.cache/valheim-lembitu/client` for disposable testing. On astral-bicep its source is
`/home/ra/.local/share/Steam/steamapps/common/Valheim`. Both the launcher and native runner default
to the version-neutral cache path; `VALHEIM_CLIENT_DIR` can select another current test copy.
Refresh that copy after Steam updates, update the dedicated server with `scripts/test-server.sh install`,
and rebuild against fresh references. Keep the live server and historical evidence untouched.

Before loading mods on a fresh Linux profile, complete the native first-run settings setup:
launch the current client without gameplay mods, open **Settings**, choose the language, press
**OK**, then quit normally. Merely reaching the menu does not persist the language preference.
Do not force `SteamAPI.Init` earlier or patch out the exception. See the diagnosis below.

Use a dedicated initialized test preference profile, separate from the Steam desktop profile:
`export XDG_CONFIG_HOME="$HOME/.cache/valheim-lembitu/client-preferences"`. Use this same environment
for first-run setup and later tests. The initialized profile on astral-bicep was created through
Valheim's native Settings handlers, not by injecting a language key. It is not a game-version freeze.

**Historical restoration, not current installation instructions:** the earlier licensed 1.0.7
client at `/home/ra/.cache/valheim-lembitu/client-1.0.7` came from Linux depot 892971, manifest
8489898024822656053, network 39. Steam had already advanced to 1.0.12/network 40. The old instruction
to stay on that archived client rather than rebuild against the newer game is superseded by ADR-0007.

### Native gameplay control

`Lembitu.Harness` calls native Unity/Valheim methods on the main thread. Python only exchanges
JSON and checks observations; it does not emulate mouse or keyboard input. Control requires
both `-lembitu-harness` and an explicit absolute control directory. Dedicated servers stay inert.
The harness uses the stack’s existing JsonDotNET 13.0.4 (`Newtonsoft.Json.dll`); an isolated
harness-only installation must include that library too. Unity’s runtime `JsonUtility` omitted
nested response state in the first real-client run, so it is not used for this protocol.

```sh
export XDG_CONFIG_HOME="$HOME/.cache/valheim-lembitu/client-preferences"
export VALHEIM_CLIENT_DIR="$HOME/.cache/valheim-lembitu/client"
export LEMBITU_CHARACTER=harness
scripts/test-client.sh run --control-dir "$HOME/.local/state/lembitu/control-a" 127.0.0.1:2466

# From another shell; timeout includes waiting for the player to spawn.
python3 scripts/harness.py --dir "$HOME/.local/state/lembitu/control-a" \
  --timeout 1200 --command '{"action":"snapshot"}'
```

Use a fresh control directory for each launch: retained `status.json` is not process-liveness
proof and may describe a previous run. Use separate characters and installations for concurrent
clients. A scenario routes sequential commands with
`--scenario steps.json --client a=/absolute/control-a --client b=/absolute/control-b`.
An example `steps.json` that observes movement rather than assigning a position:

```json
[
  {"client":"a","command":{"action":"snapshot"},"save":"before"},
  {"client":"a","command":{"action":"move","x":1,"seconds":1},
   "expect":[{"path":"state.player.x","op":"gt",
              "from":{"saved":"before","path":"state.player.x"}}]}
]
```

Commands use observed IDs, not guessed object names:

| Action | Fields / behavior |
| --- | --- |
| `snapshot` | Player, inventory, nearby entities, progression texts, UI and connection state |
| `move` | World `x`/`z` direction in [-1,1], `seconds` in (0,10]; native player controls |
| `attack` | Entity `target`, optional `secondary`, `seconds` in (0,10]; native attacks, never direct damage/XP |
| `interact` | Nearby entity `target`; native interaction/pickup |
| `equip` | Inventory `item` ID; native equipment requirements apply |
| `craft` | `recipe` asset name from `state.ui.recipes`; native crafting UI/timer and requirements apply |
| `pvp` | Boolean `value` |
| `ui` | `target` = `inventory`/`map`, boolean `value`; or observed button ID with `value:true` |
| `screenshot` | `target` = new absolute image path; native screen capture |
| `fixture.spawn` | Prefab `target` and absolute `x`/`y`/`z` within 20 m; requires launcher `--fixtures` |
| `quit` | Exit this client; `state` is null; available before readiness and after startup failure, without a local player |

Fixtures arrange disposable-world objects; they do not prove gameplay. Assert movement, pickup,
equipment, material consumption or attack results separately. Entity/button IDs belong to one
client session, and inventory IDs are session-local; do not reuse IDs on another client.

Each step may `save` its response, reference a saved dot-path in command values, and `expect`
`eq`/`ne`/`gt`/`gte`/`lt`/`lte` comparisons against `value` or `from`. `expect_ok:false` requires an
explicit native refusal; errors are never silently treated as successful actions.

Protocol: `status.json` holds `{ready,error}`. Atomic `inbox/<UUID>.json` requests are limited to
16 KiB; `outbox/<UUID>.json` responses contain `{id,ok,error,state}`. Use one coordinator per
directory. Responses remain as evidence. A timeout does **not** cancel a published command;
inspect that UUID’s response before retrying. Exit codes: 0 success, 2 input, 3 native/startup
rejection, 4 IPC failure, 5 timeout, 6 assertion failure, 130 interruption.

### Repeatable native acceptance

Run the permanent coordinator on the Linux test host after building and staging `dist/`:

```sh
export XDG_CONFIG_HOME="$HOME/.cache/valheim-lembitu/client-preferences"
nix shell nixpkgs#python3 --command python3 scripts/test-native.py \
  --mode full-pack --port 2486 --repeat 2

# Explicit isolation for diagnosis; never counts as full-pack acceptance.
nix shell nixpkgs#python3 --command python3 scripts/test-native.py \
  --mode minimal --port 2496 --repeat 2
```

Steam must already be logged in, the native preference profile initialized as above, and a
GPU-backed X display available (`--display :0`). The coordinator copies the current game installations
into private working directories. Each
repetition gets fresh worlds, characters, save directories and IPC. It uses the existing launchers;
`test-client.sh run --save-dir DIR --log-file FILE` forwards absolute native storage paths.
Full-pack mode first generates configuration in a disposable world, applies the existing enforced
configuration merger, then starts a separate measured world. Minimal mode installs only the
harness and JsonDotNET. No source installation or live server is modified.

Server readiness means `Opened Steam server`, after world generation and native listener creation.
`Game server connected` only means Steam registration; joining then races world generation.
The process-level regression in `test/test-native.test.sh` distinguishes those two signals.

Proof is retained under `~/.local/state/lembitu/native-tests/<timestamp>-<mode>-<id>/`: compact
`proof.json`, append-only `events.jsonl`, IPC commands/responses, installed-file hashes, screenshots,
logs and generated configuration. Native quit waits for process exit before another client starts;
an acknowledgement alone does not mean Unity finished saving and unmounting Steam storage.
The script returns nonzero on failure and stops only process groups it launched. Disposable game
copies and saves are removed unless `--keep-work` is set. Inspect `skills.png` and `combat.png`
visually; screenshot creation alone is not rendering proof. Full-pack mode does not silently
fall back to minimal, and neither mode proves simultaneous two-client behavior.

### Historical verification status — 1.0.7

The following September 12 results used a real isolated 1.0.7 client, its dedicated server,
BepInEx, the harness and pinned JsonDotNET. They remain evidence of that build only, not current
public-game acceptance. No direct damage, XP grants or player teleportation were used.

- Movement advanced 5.47 metres through native controls.
- Inventory/map toggles and an observed Skills button worked; the resulting Skills panel was
  captured and inspected. Inactive button, invalid equipment ID and zero-duration move requests
  were refused.
- Six fixture wood objects were picked up through native interaction. Crafting refused one wood,
  then consumed six to produce a club; native equipment selected it.
- A normal club attack reduced a Greyling’s health by 19.65. The native screenshot showed the
  hit and a Clubs skill increase. World and UI rendering were visible.
- A fixture Skeleton caused normal death (25 → 0 health); the endpoint remained available
  through respawn, observed a new player object at 25 health, and accepted movement afterward.
- An incorrect server password surfaced `ErrorPassword`, controller exit 3, in 29 seconds.
- A fresh character completed its native first-spawn flight before readiness. The controller’s
  real five-step scenario passed saved-response comparisons and required fixture refusal when
  `--fixtures` was absent. Native quit also completed successfully, including a real respawn
  interval with no local player; its response contained `ok:true` and `state:null`.

Proof JSON and screenshots are under `/home/ra/.local/state/lembitu/`: `native-gameplay-smoke.*`,
`native-lifecycle-smoke.*`, `native-refused-result.json`, `native-scenario-result.json` and
`native-quit-respawn-smoke.json`.

**Full-pack and two-client acceptance remain open in #10.** The unchanged full pack reached a
join attempt but returned `ErrorConnectFailed`; the running test server logged a `ZRpc` timeout.
Its client also logged Fast_AssetBundle_Loader `DriveInfo` failures, STU_Ward accessing Steamworks
before initialization, unresolved MWL mock references, unavailable shader platforms, and BoneMod
logout exceptions. These observations are not a demonstrated causal diagnosis of the timeout.

### Historical updated candidate: 1.0.7 repeatable verification — 2026-09-12

Baseline work was committed as `cd0d00f` before updates. All ten adopted updates were staged and
EpicMMOSystem 1.9.66 was integrated while retaining custom behavior. The complete build passed
with 13 fork warnings; the changed harness subsequently built with zero warnings or errors.
The staging, installer and configuration suites passed 35 checks. The old test that pinned Clan
1.0.5 and the current package count was removed, not repinned.

The permanent runner completed **two fresh minimal-mode repetitions**, exit 0, in 13m28s:
`native-tests/20260912T155719Z-minimal-27512e6b/` under `/home/ra/.local/state/lembitu/`.
The invocation used `--mode minimal --port 2496 --repeat 2 --startup-timeout 360`. Both passed
fixture opt-in refusal, wrong-password rejection, native quit after failed startup, movement, PvP
toggles, inventory/map/Skills UI, rejection boundaries, six wood pickups, club crafting/equipment,
observed Greydwarf damage, natural death/respawn, movement afterward, and native shutdown.
Skills and combat screenshots from both repetitions were inspected; world/UI and combat feedback
were visible. This does not validate the full pack's shaders or simultaneous two-client behavior.

The runner exposed a shutdown bug: signalling a client immediately after quit acknowledgement
interrupted Unity shutdown; later launches reported an already-open Steam storage batch. The
runner now waits for native process exit and uses native quit even after failed startup. The
test Steam client was restarted once, retaining its cached login, to clear the earlier stuck
batch. Both final repetitions then created fresh characters and exited cleanly without a restart.
No timing-sensitive requirement to catch a player-less respawn frame remains; failed-startup quit
covers the no-local-player boundary deterministically.

The final **full-pack** invocation used `--mode full-pack --port 2486 --repeat 2
--startup-timeout 360`. Session `native-tests/20260912T161105Z-full-pack-03bc47f8/` exited 1
at configuration generation: the client never created `sighsorry.Clan.cfg` or
`sighsorry.InventorySlots.cfg`. STU_Ward logged a Steamworks-before-initialization startup
exception. No measured full-pack gameplay ran. Cleanup sent native quit, observed client exit 0,
stopped its server with exit 0, and removed the disposable game/world copies. Evidence remains.

Groundwork 1.1.9 also had a confirmed static field/property mismatch against the then-selected 1.0.7;
Hoe/Cultivator placement was not exercised. That candidate was not cleared, and #10 remained open.
Final process inspection for that run found only the existing live server, PID 576639;
the authenticated test Steam session and display services were left running.

### Latest public candidate verification — 2026-09-12

The premature development freeze was removed. Client and server now use **1.0.12 / network 40**.
Steam client build `25253764` matched the live public branch; depot `892971` manifest was
`6181039652481492267`. The server updater downloaded public depot `896661` manifest
`9055200629726788899`. These are test identities, not frozen launch versions.

All 28 adopted packages were rechecked and staged; Groundwork advanced again to **1.1.10**.
Maintained fork upstream heads remained current. Game references were refreshed and verified
against the server installation. All projects rebuilt successfully: 13 warnings, zero errors.
The staging/installer/configuration suites passed all 35 checks.

The full-pack command used `--mode full-pack --port 2486 --repeat 2 --startup-timeout 360`.
Evidence: `/home/ra/.local/state/lembitu/native-tests/20260912T165242Z-full-pack-b6193d36/`.
Client logs confirm runtime 1.0.12 and compiled network version 40. The run exited 1 during
configuration generation: Clan and InventorySlots still failed before creating their configs;
their stacks and STU_Ward report Steamworks access before initialization. Steam initialized
later in the same client log. Updating the game did not resolve these startup failures.

No measured full-pack gameplay ran, and prior minimal-mode passes remain 1.0.7 evidence only.
The owned client exited 0 via native quit; its server exited 0; disposable work was removed.
Logs and proof remain. Continue latest-version development; do not freeze this failing candidate.

### Steamworks startup diagnosis — 2026-09-12

The failure was reproduced before any server join in about 15 seconds. Removing the harness
did not help. A minimized client with only Clan and no third-party patchers still failed.
The trigger was an absent native `language` preference: `Localization.SetStartupLanguage` calls
`PlatformPrefs.GetString`; its missing-key migration calls `SteamUtils.IsSteamRunningOnSteamDeck`.
BepInEx loads plugins during `GameObject` initialization, before Valheim initializes Steamworks.
An already-saved language bypasses that migration. This is not failed Steam authentication.

Controlled isolated profiles, identical game and mod binaries:

| Probe | Result | Evidence directory under `~/.local/state/lembitu/startup-probes/` |
| --- | --- | --- |
| Clan only, no harness/patchers, missing language | Missing Clan config; one Steamworks exception | `20260912T171951Z-3af18fca` |
| Same setup, only saved language changed | Clan config created; zero Steamworks exceptions | `20260912T171956Z-6591c261` |
| Full pack with saved language | All three configs created; zero Steamworks exceptions | `20260912T172026Z-88fe83be` |

The language-only intervention was diagnostic, not the installed correction. Native first-run
setup then called `FejdStartup.OnButtonSettings` and `Settings.OnOk`, saved the actual settings,
and exited cleanly: `20260912T172704Z-e70c35ae`. Its `native-settings.png` was inspected.
That initialized profile was copied to `~/.cache/valheim-lembitu/client-preferences`. No upstream
mod binary or Steamworks initialization order was changed. The normal runner still rejects
missing generated configs, so a return of the original failure remains visible.

File-open tracing found this Linux player reading `unity3d/unknown/unknown/prefs`, not the
`IronGate/Valheim/prefs` save-directory copy. Do not guess the preference filename or hand-edit it;
native Settings writes the effective store. The user's existing desktop preferences were untouched.

The original full-pack runner was repeated using the natively initialized preference profile:
`native-tests/20260912T172840Z-full-pack-a88012d4/`. It passed config generation and enforced
configuration application. Neither the config-generation nor measured client boot logged the
original Steamworks-before-initialization or STU_Ward startup errors. It then failed at joining
with `ErrorConnectFailed`; this does not establish the cause of that separate connection failure.
No full-pack gameplay or simultaneous two-client clearance is claimed.

The temporary settings plugin and startup probe were removed from executable/staging locations;
their sources and diagnostic results remain under `startup-probes/diagnostic-source/`. The
permanent runner continues to reject missing generated configs.

### Native connection diagnosis — 2026-09-12

Checkpoint commit: `3293025`. Subsequent diagnosis separated two failures:

1. The coordinator launched clients on Steam registration, before the server opened its listener.
   `Run.start_server` now waits for `Opened Steam server`. A real child-process regression failed
   before the correction and passed afterward.
2. After that correction, transport connected, but the client stalled during location asset loads.
   The server closed its peer after the normal 30-second RPC timeout.

Controlled comparisons used isolated 1.0.12 installations, initialized native preferences, and
previously generated/enforced full-pack configs. Evidence directories below are under
`/home/ra/.local/state/lembitu/join-probes/`:

| Case | Result | Evidence |
| --- | --- | --- |
| Full pack, corrected listener readiness | 68-second client callback gap; disconnect | `20260912T181352Z-0ad3b1a8` |
| Only client FastAssetBundleLoader removed | 75-second gap; disconnect | `20260912T182334Z-67260b2d` |
| Only client SkadiNet stutter guard disabled | 69-second gap; disconnect | `20260912T183349Z-1d957f57` |
| MWL removed from both diagnostic peers | Living player, control-ready, native quit | `20260912T183802Z-6d047589` |
| BossRules removed, MWL retained | Living player, control-ready, native quit | `20260912T184522Z-7b456ca6` |
| Official BossRules 1.0.9, no authority guard | Disconnect still reproduces | `20260912T185300Z-56e52e57` |
| Full pack plus authority guard, fresh world | Join and reference-output checks pass; native quit | `20260912T190318Z-3d4e6d45` |

BossRules calls `AltarReferenceGenerator.TryAutoRefreshReferenceConfigurationFile` from its
`Update`. Its `IsSourceOfTruth` guard reads ServerSync state, which remains local before initial
configuration sync. A connecting client therefore enters the authority-only reference scan.
`TryCaptureReferenceEntry` synchronously loads each location prefab, including MWL content, and
blocks the main thread long enough to lose the connection. Removing either package isolated the
interaction. Official 1.0.9 and its [upstream source](https://github.com/sighsorry1029/BossRules/blob/3d4e693751fa81171bf1ffea203294366387e790/AltarReferenceGenerator.cs)
still contain this guard. The ordinary native join path does not perform an additional asset-preparation step.

The temporary `Lembitu.BossRules` plugin added one Harmony prefix requiring
`ZNet.instance != null && ZNet.instance.IsServer()` for this scan. The original ServerSync guard
still ran on the host. This kept reference discovery on native world authority without
changing timeouts, skipping content, or changing altar/gameplay behavior.

**2026-09-13:** official BossRules 1.0.10 adds the identical native-authority predicate in
[`e3d6d38`](https://github.com/sighsorry1029/BossRules/commit/e3d6d38563dcfd90353a568320f47f110d1253ca).
The redundant local plugin was removed. Build into clean `dist/` so its old DLL cannot survive;
the normal installer removes the previously managed DLL when installing the new pack.
Container mirrors still require the existing `prune-mirror` procedure.

The fresh-world proof kept all 28 adopted packages, maintained forks, FastAssetBundleLoader and
SkadiNet defaults enabled. Client `ZNet Start` and the connected callback both logged at 22:08:08
host time, rather than a minute apart. The player reached control-ready alive at 25/25 health.
Both reference files were removed from the private copies before startup: the server regenerated
real altar entries, while the client created only its normal empty template. Native quit exited
successfully. `joined.png` was visually inspected; `summary.json` records `ok: true`.

An earlier guarded run (`20260912T185719Z-a0b146e9`) also joined but failed an incorrect diagnostic
assertion that expected no client reference file. BossRules creates an empty template at startup.
The final proof checks its empty data instead; no production code changed for that correction.

Verification: complete build succeeds with 13 existing fork warnings and zero errors. The
readiness regression and 35 staging/installer/configuration checks pass. The native join scenario
is the regression seam for the authority race; a mocked ServerSync boolean would not reproduce
the real pre-handshake asset-loading stall. This proves joining, not full gameplay acceptance or
simultaneous two-client behavior. FastAssetBundleLoader DriveInfo errors and PvPBiomeDominions
missing-sprite messages remain separate findings, not cleared by a successful join.

The join probe is archived under `join-probes/diagnostic-source/`, outside the isolated checkout.
Logs, configs, installed-file hashes, screenshots and summaries remain in the evidence directories.
Private game copies were removed; the successful fresh world remains in that run’s `saved-world/`
directory for another controlled comparison. The live server was not changed.

### Full-pack native acceptance — 2026-09-13

Client and server remain public **1.0.12 / network 40**, client build **25253764**. Fourteen adopted
updates are recorded in `modstack.md`; official BossRules **1.0.10** replaces the local guard.
The clean isolated build passed with 13 existing fork warnings and zero errors. Packaging, installer
and config suites passed 35 checks; the native listener-readiness regression also passed.

On astral-bicep, the exact tested source/build copy is
`/home/ra/.cache/valheim-lembitu/update-20260913`; the existing working checkout was left untouched.

```sh
cd ~/.cache/valheim-lembitu/update-20260913
export XDG_CONFIG_HOME="$HOME/.cache/valheim-lembitu/client-preferences"
nix shell nixpkgs#python3 --command python3 scripts/test-native.py \
  --mode full-pack --port 2486 --repeat 2
```

Exit **0** after two fresh-world repetitions. Each passed generated/enforced configuration,
fixture permission refusal, wrong-password rejection, native quit without a local player, movement,
PvP toggles, Skills UI and rejected actions, pickup, insufficient-resource refusal, crafting,
equipment, observed club damage, natural death, respawn and movement afterward, then native quit.

Evidence: `/home/ra/.local/state/lembitu/native-tests/20260913T154603Z-full-pack-497266e6/`.
`summary.json` records `completed_runs: [true, true]`, `ok: true`, `full_pack_pass: true`.
Both repetitions’ `skills.png` and `combat.png` were visually inspected: world, Skills panel,
HUD and combat hit feedback render. The runner deliberately leaves `visual_review_required: true`;
this paragraph records the separate visual review. IPC, logs, config and installed hashes remain.
Disposable game copies and saves were removed by the runner; the live server was not changed.

Residual FastAssetBundleLoader Linux `DriveInfo` exceptions remain in the successful gameplay log.
This is full-pack coverage of the existing scenario, not exhaustive mod-feature acceptance or
simultaneous two-client verification. Those limits still prevent a launch freeze.

