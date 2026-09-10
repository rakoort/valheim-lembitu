# Building and installing plugins

Every plugin in this repo is a BepInEx 5 plugin for **Valheim 1.0.7 (network version 39)**, built as
a .NET Framework 4.7.2 assembly because the game runs Unity's Mono runtime.

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
scripts/test-server.sh install   # game files, reference assemblies, BepInEx (a few GB, once)
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
`MissingFieldException` a pre-1.0 build would throw:

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
