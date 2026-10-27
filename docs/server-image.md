# The server image

The live server as a Nix-built OCI archive (#113), built from the locked inputs alone
(`docs/server-inputs.lock.json`; `docs/build.md`, "The locked live server inputs"). It follows
astral-fleet's `cluster/omp-auth-broker/image.nix`: `dockerTools.buildLayeredImage`, then skopeo
into an OCI archive.

```sh
nix build .#serverImage                                      # the archive, valheim-lembitu-server-<build>.oci.tar
nix build '.#projectImages."project/valheim-lembitu/server"' # the same derivation, the output fleet-publish builds
```

`nix/server-image.nix` is the recipe. The archive's tag is the server build, `25909431`. The image is
about 2.3 GB in 28 layers, zstd-compressed. A warm build of the image alone takes about 20 seconds;
the first, which fetches the depots, takes several minutes. Two builds of every derivation the image
is made from give the same bytes, so the manifest digest is a function of the locked inputs and
this repository's recipe.

The bytes stay in the local Nix store until the image is published. Publishing is
`fleet-publish --project valheim-lembitu` from astral-fleet. It builds the `projectImages` output,
pushes it to the fleet registry and pins the digest the Workload runs.

To run it locally, copy it into the docker daemon. `docker load` refuses an OCI archive ("does not
contain a manifest.json"):

```sh
nix shell nixpkgs#skopeo -c skopeo --insecure-policy copy \
  ${DOCKER_HOST:+--dest-daemon-host "$DOCKER_HOST"} \
  oci-archive:"$(nix build --no-link --print-out-paths .#serverImage)" \
  docker-daemon:valheim-lembitu-server:local
```

## What is in it

| Part | Holds |
| --- | --- |
| The game root | The server depot 896661, the Steamworks redistributable depot 1006 and BepInExPack's loader (`BepInEx/core`, `doorstop_libs`), as one directory of links into their store paths. `valheim_server.x86_64` is the one real file: a byte-identical copy of the depot's, mode 0555, because the depot marks nothing executable. |
| The plugin tree | `BepInEx/plugins`, `patchers` and the packages' config seeds, made exactly as the live deploy path makes them: `scripts/stage-stack.sh` over the locked mod zips, our plugins added (`.#plugins`), then `scripts/install-plugins.sh`, which withholds the client-only packages. |
| `lembitu-server` | `scripts/server-entrypoint.sh`, the entrypoint. |
| `lembitu-ready` | `scripts/server-ready.sh`, the readiness check. |
| `lembitu-logmark` | `nix/logmark.c`, the filter on the server's stdout that marks "Game server connected". |
| `lembitu-a2s` | `nix/a2s-info.c`, an A2S_INFO client. Under `-public 0` the server never answers it, so it is not the readiness probe (below). |
| The base | dumb-init as PID 1; `/lib64/ld-linux-x86-64.so.2`; glibc, libgcc, libstdc++ and zlib on the library path; the CA bundle; tzdata, with Europe/Oslo as local time; `passwd` and `group` entries for `lembitu`, uid and gid 10160. |

The game is not patched. Its interpreter is `/lib64/ld-linux-x86-64.so.2`, and it finds its
libraries through `LD_LIBRARY_PATH`, so its bytes stay the depot's.

Not in it: the enforced and dedicated config (a ConfigMap), the world, and the Secrets.

`plugins` is the one input that decides our own DLLs' bytes. `docs/live-vs-lock-20261027.md`,
decision 3, chooses which bytes those are; whichever is chosen swaps that input and nothing else.

## How it starts

The image runs as `10160:10160`. Its entrypoint is
`dumb-init --rewrite 15:2 -- lembitu-server`: dumb-init turns the kubelet's SIGTERM into the
SIGINT the server saves on, and forwards it to the server's process group.

`lembitu-server` reads the join password from the Secret's file, refusing one shorter than
Valheim's 5 characters. It rebuilds the runtime tree, then execs the server, so the server is
dumb-init's child, with no shell, supervisor or sleep between them:

```sh
./valheim_server.x86_64 -nographics -batchmode -name Lembitu -port 2456 -world LembituRun \
  -public 0 -password <secret> -savedir /data/save -saveinterval 300 \
  -modifier Combat hard -modifier DeathPenalty easy -modifier Resources default \
  -modifier Raids less -modifier Portals hard
```

The world rules are the live launch's (`config/launch/launch.env.example`). `-public 0` is ra's
Round of 2026-10-27: the Steam server list is off, and players join by address. The library path
is the redistributable's `linux64/`, which holds the `steamclient.so` the server loads, then the
doorstop's libraries, then the base's. `LD_PRELOAD` loads BepInEx's doorstop, as the Pack's own
start script does.

The server's stdout goes through `lembitu-logmark`, which passes every byte to the container log in
order. It ignores SIGINT, SIGTERM and SIGHUP, so the stop signal dumb-init sends the process group
can't break the server's stdout mid-save, and it exits when the server closes its stdout.

### What the Workload mounts

| Path | What | Notes |
| --- | --- | --- |
| `/data` | The world volume, owned by uid 10160 (the Workload's `fsGroup`). | `save/` is the game's `-savedir`; `bepinex/` holds the plugins' stores. |
| `/run/lembitu` | An emptyDir, mounted with exec. | The runtime tree, rebuilt at every start. |
| `/home/lembitu` | An emptyDir. | Unity's and Steam's per-user files. |
| `/tmp` | An emptyDir. | |
| `/etc/lembitu/bepinex` | The ConfigMap: the enforced and dedicated BepInEx config. | Read with `cp -RL`; its `..data` entries are skipped. |
| `/run/secrets/lembitu/password` | The Secret's join password. | |

The root filesystem can be read-only: the image tier runs that way, and nothing writes outside
these mounts.

### What the server writes

Read from the running image: the image tier's `ls -lAR` of every writable mount, and the logs.

| Path | Written by | Lifetime |
| --- | --- | --- |
| `/data/save/worlds_local/LembituRun/` | The game: `_main.<n>.db2`, `.fwl2`, `.chunks`, `.ok` and the chunk files, one generation per save. | The volume. |
| `/data/save/adminlist.txt`, `bannedlist.txt`, `permittedlist.txt` | The game, empty when absent. | The volume. |
| `/data/save/ServerManager/` | ServerManager: its character store and per-player activity logs. | The volume. |
| `/data/bepinex/Guilds/`, `Marketplace/`, `Lembitu.Guilds/` | The guild and market plugins. On the live server these live in `BepInEx/config`; the runtime tree links them here. | The volume. |
| `/data/bepinex/SeparateSpawns/reports/` | SeparateSpawns' layout report of each world. It writes beside its DLL; the runtime tree links `reports/` here. | The volume. |
| `/run/lembitu/BepInEx/plugins/OdinOnDemand/assetbundles/`, `radio/` | OdinOnDemand creates both beside its DLL and reads radio stations from them. The Pack ships none, so they start empty. | Each start. |
| `/run/lembitu/BepInEx/config/` | The config copied at start; plugins add the files they create when missing, such as FineDining's `Icebox.yml`. | Each start. |
| `/run/lembitu/BepInEx/cache/`, `DumpedAssemblies/`, `patchers/`, `LogOutput.log` | BepInEx. | Each start. |
| `/run/lembitu/.game-server-connected` | `lembitu-logmark`, the readiness marker. | Each start. |
| `/home/lembitu/.config/unity3d/IronGate/Valheim/prefs` | Unity. | The Pod. |
| `/home/lembitu/Steam/` | `steamclient.so`: `config/config.vdf`, `logs/`, `appcache/httpcache/`. | The Pod. |

Two plugins needed the runtime tree's help:

- OdinOnDemand finds its directory by its own `Assembly.Location`, and Mono resolves a link to its
  store path. A linked DLL would try to create `assetbundles/` in the read-only store and fail
  with `IOException: Read-only file system`. So `OdinOnDemand.dll` is a byte-identical copy, not a
  link.
- SeparateSpawns writes `reports/` under BepInEx's plugin path. A link to the volume keeps the
  reports, as the live server keeps them.

### Ready

`lembitu-ready` is the readiness probe's exec check. It passes when both hold:

- the Unity log has said "Game server connected" since this start (the line is on stdout only, not
  in BepInEx's `LogOutput.log`);
- the server's UDP socket, 2457, is bound.

The server binds no socket on 2456, the `-port` it is given. Its Steam game server socket is 2457:
clients add one to the port they are given, and A2S queries land there too. Read from
`/proc/net/udp` in the running image, 2026-10-27.

Why not A2S_INFO: under `-public 0` the server never answers it. The running image was queried for
over ten minutes with `lembitu-a2s` and `scripts/query-server.py`, and neither got a reply, though
2457 was bound. The same image with only `-public 1` answered within about two minutes. So a
readiness probe built on A2S and ra's `-public 0` can't both stand. `lembitu-ready` keeps
`-public 0`, and `lembitu-a2s` stays in the image for querying with `-public 1`.

In the image tier, readiness was red right after the start and green 63 to 83 seconds later on a
new world.

### Stopping

`docker stop` or the kubelet sends SIGTERM, dumb-init sends the server SIGINT, and the server saves
and exits 0. In the image tier the save and exit took 21 to 24 seconds. The Workload's grace period
is 180 s.

## What the first boots showed

- BepInEx 5.4.23.5 reports `Chainloader startup complete (68 loaded, 1 skipped, 0 failed)`, as
  the live server does. The skip is Valheim Visual Enhanced 0.5.18
  (`dev.local.valheimvisualenhanced`): its own `[BepInProcess("valheim.exe")]` limits it to the
  client. The lock records it under `serverPlugins.skip`.
- `steamclient.so` reads the system CA bundle at `/etc/ssl/certs/ca-certificates.crt`, not
  `SSL_CERT_FILE`. Without one, its game-server logon never completes and the server never says
  "Game server connected". The image links the bundle at the Debian and Red Hat paths.
- `DllNotFoundException: libParty.so` from PlayFab Party at start. Crossplay is off, and the game
  carries on.
- `[Error :CreatureManager] Expected one final-damage checkpoint in Character.ApplyDamage, found 0;
  Deathward lethal prevention is disabled.` This comes from the adopted CreatureManager 1.3.5
  (`sighsorry.CreatureManager`), not from the image. It is not yet compared with the live server's
  log.

## The proofs

`test/server-image.test.sh` has two tiers.

The fast tier runs with every `for t in test/*.test.sh` pass, in about a second. It runs the real
entrypoint against a fake game, whose server records how it was started and saves on SIGINT. It
checks:

- the exec;
- the arguments and the password;
- the library path;
- the runtime tree, the stores on the volume and the copied DLL;
- the log filter, through the stop signal;
- the readiness check, red and green.

The image tier runs the real server, so it is opt-in:

```sh
LEMBITU_IMAGE_TEST=1 LEMBITU_BUILD_LOCK=<lock file> LEMBITU_IMAGE_REPORT=<dir> \
  bash test/server-image.test.sh
```

It needs nix, docker (rootless works) and about 4 GB of memory. The builds run under
`flock $LEMBITU_BUILD_LOCK` when it is set. It checks:

- a second build of every non-fetched derivation in the image gives the same bytes, and the digest
  is one;
- the image's server and redistributable trees pass `scripts/verify-server-inputs.sh`, and
  `valheim_server.x86_64` is the locked file at mode 0555;
- BepInEx's core and doorstop are the locked pack's, and the plugin tree is the deploy path's;
- there is no world, Secret or enforced config in the image;
- the image's plugin GUIDs, read from the assemblies by `scripts/list-plugin-guids.sh`, are the
  lock's `serverPlugins`;
- readiness is red at the start and green once the server is up;
- the chainloader loads exactly the lock's GUIDs, skips only its process-filter skips, and fails
  none;
- nothing writes to the read-only root;
- the only processes are dumb-init, the server and the log filter;
- SIGTERM saves a fresh `.db2` and `.fwl2` generation of a new world, and the server exits 0
  within 180 s.

`LEMBITU_IMAGE_REPORT` receives the digests, the logs, the image's file list and the list of
written paths.

`nix flake check` also runs `server-plugin-guids`: the image's plugin tree against
`serverPlugins`, without a game.
