# ADR-0001: Plugin build toolchain for Valheim 1.0.7

Date: 2026-09-09
Status: Accepted
Issue: #1

## Context

We need to build BepInEx plugins for a modded Valheim 1.0.7 server (network version 39), from a
clean checkout, without committing game binaries, and prove they load on a real 1.0.7 server.

Constraints found while setting this up:

- The dedicated server is linux/amd64 only. Its Mono runtime crashes on Apple Silicon under Rosetta
  (`tramp-amd64.c:641`) and under QEMU (`x86-codegen.h:410`), and the usual
  `lloesche/valheim-server` container cannot install the game there because its SteamCMD is a 32-bit
  x86 binary. The macOS client is arm64 in 1.0, so BepInEx's x86_64 doorstop dylib cannot inject.
- Valheim's version numbers and several members are `const`, so the compiler inlines them. Building
  against the wrong game build produces plugins that fail at runtime, not at build time — the exact
  failure mode behind the broken pre-1.0 ServerSync builds (issue #2).
- Game assemblies cannot be redistributed, so they cannot live in the repo.

## Decision

- **Target net472 with the .NET SDK**, using `Microsoft.NETFramework.ReferenceAssemblies`. No
  Windows, Visual Studio or Mono install is needed.
- **No solution file.** `Valheim.Lembitu.proj` at the root globs `src/**/*.csproj` and forwards
  Restore, Build and Clean, so `dotnet build` builds every plugin and adding one is adding a
  directory. A `.sln` would have to be edited, with a fresh GUID, for every project, and a project
  missing from it would silently never build.
- **Shared build configuration in `Directory.Build.props`/`.targets`**: net472, nullable enabled,
  the baseline game/loader references, publicization, a generated `PluginInfo` class, and a copy of
  every plugin DLL into `dist/plugins/`. A plugin `.csproj` is then a GUID, a version and any extra
  references. Forks that do not want nullable analysis on upstream code set `<Nullable>disable</…>`.
- **Plugin identity lives in the project file.** `BepInPlugin` needs compile-time constants, so the
  build generates `PluginInfo` from `PluginGuid`/`Version` rather than restating them in code, where
  a bump applied to one of the two would make the server log lie.
- **Publicize with `BepInEx.AssemblyPublicizer.MSBuild`** at build time rather than committing
  publicized DLLs.
- **`scripts/extract-refs.sh` reproduces `lib/`**: game assemblies copied from a local install
  (preferring the test server, which is the build we deploy on), BepInEx from Thunderstore's
  `denikson-BepInExPack_Valheim` pinned to `5.4.2350` (BepInEx 5.4.23.5) with a SHA-256 check. It
  writes `lib/valheim/refs.lock.json`, and `--check` re-hashes both the extracted copies and the
  install they came from, so a game update is reported rather than inferred.
- **Compile against the loader we deploy**: the same downloaded pack provides both the reference
  assemblies and the server install, so plugin and loader versions cannot drift.
- **Develop and test on astral-bicep** (x86_64 Linux), with `scripts/test-server.sh` installing the
  server with DepotDownloader (anonymous, 64-bit, self-contained) and running it natively.
  astral-tricep is the second host for later two-client network tests.
- **`Lembitu.Hello` stays in the repo** as the smoke test and plugin template. It logs one line at
  startup and compares the network version it was compiled against with the one the running server
  reports, turning silent const-inlining skew into a log error.

## Consequences

- A Mac can build and review plugins but cannot run them; every runtime check happens on bicep.
- `lib/` is disposable and gitignored; a game update means re-running `extract-refs.sh` and
  rebuilding, and `--check` tells you when that is overdue.
- Plugins are pinned to one BepInEx version by construction. Moving to a new pack is a one-line
  change to `scripts/extract-refs.sh` (version plus hash).
- Nix users get the toolchain from `flake.nix`; everyone else needs a .NET SDK ≥ 8 on `PATH`.
