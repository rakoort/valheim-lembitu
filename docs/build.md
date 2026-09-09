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
| `dist/plugins/` | Build output: every plugin DLL, in one place. Not committed. |
| `scripts/` | Reference extraction, plugin install, test server. |

Game and BepInEx binaries are never committed. `scripts/extract-refs.sh` reproduces them.

## Where work happens

Development and testing happen on **astral-bicep** (x86_64 Linux). The Valheim dedicated server only
ships for linux/amd64 and its Mono runtime cannot be emulated on Apple Silicon:

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
nix develop                      # dotnet SDK 8, curl, unzip, rsync
scripts/test-server.sh install   # game files, reference assemblies, BepInEx (a few GB, once)
dotnet build                     # every plugin -> dist/plugins/
scripts/install-plugins.sh ~/.cache/valheim-lembitu/server/BepInEx/plugins
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

## Install loop

```sh
dotnet build                                        # -> dist/plugins/
scripts/install-plugins.sh <bepinex-plugins-dir>    # sync into a server
```

`scripts/install-plugins.sh` records what it installed in `.lembitu-installed` in the target
directory, and on the next run deletes DLLs it installed before but no longer builds. Files it did
not install are never touched.

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

So: remove plugins with `scripts/install-plugins.sh` (it prunes what it owns), and after removing or
renaming anything, check the server's own plugin directory, not just `/config`.

## Test server

On astral-bicep:

```sh
scripts/test-server.sh install   # game files (app 896660), reference assemblies, BepInEx, plugins
scripts/test-server.sh run       # foreground; Ctrl-C to stop
```

Game files land in `~/.cache/valheim-lembitu/server` (override with `VALHEIM_TEST_DIR`) and server
arguments can be replaced with `VALHEIM_TEST_ARGS`. DepotDownloader is used instead of SteamCMD:
anonymous login, no 32-bit dependencies, one self-contained binary.

Chainload is proven by the BepInEx banner and the plugin's own lines in the server log:

```
[Message:   BepInEx] BepInEx 5.4.23.5 - valheim_server
[Info   :   BepInEx] Loading [Lembitu.Hello 0.1.0]
[Info   :Lembitu.Hello] Lembitu.Hello 0.1.0 loaded on 1.0.7 (built against network version 39)
```

`BepInEx/LogOutput.log` in the server directory keeps the same output.
