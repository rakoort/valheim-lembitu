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
| `lembitu-sns-probe` | `scripts/sns-probe.sh HOST PORT`, the game port probe that `lembitu-ready` and the monitor's outside check share (below). |
| `lembitu-logmark` | `nix/logmark.c`, the filter on the server's stdout that marks "Opened Steam server". |
| `lembitu-a2s` | `nix/a2s-info.c`, an A2S_INFO client. Under `-public 0` the server never answers it, so it is not the readiness probe (below). |
| The base | dumb-init as PID 1; `/lib64/ld-linux-x86-64.so.2`; glibc, libgcc, libstdc++ and zlib on the library path; the CA bundle; tzdata, with Europe/Oslo as local time; `passwd` and `group` entries for `lembitu`, uid and gid 10160. |

The game is not patched. Its interpreter is `/lib64/ld-linux-x86-64.so.2`, and it finds its
libraries through `LD_LIBRARY_PATH`, so its bytes stay the depot's.

Not in it: the enforced and dedicated config (a ConfigMap), the world, and the Secrets.

`plugins` is the one input that decides our own DLLs' bytes. Following ra's choice (b)
(`docs/live-vs-lock-20261027.md`, decision 3), `.#plugins` builds them from source with SDK
10.0.400, the live build's path and its commit stamp. They are IL-identical to the live DLLs.

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
| `/data` | The world volume, owned by uid 10160 (the Workload's `fsGroup`). | `save/` is the game's `-savedir`; `bepinex/` holds the plugins' stores; `dedicated/` is SeparateSpawns' own config root. |
| `/run/lembitu` | An emptyDir, mounted with exec. | The runtime tree, rebuilt at every start. |
| `/home/lembitu` | An emptyDir. | Unity's and Steam's per-user files. |
| `/tmp` | An emptyDir. | |
| `/etc/lembitu/bepinex` | `config/enforced`, from the ConfigMaps `lembitu-config` and `lembitu-config-nested`. | Read with `cp -RL`; its `..data` entries are skipped. |
| `/etc/lembitu/dedicated` | `config/dedicated`, from the ConfigMap `lembitu-dedicated`. | SeparateSpawns' `.cfg`, copied fresh at every start, and its roster seed, copied only when `/data/dedicated` has none. |
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
| `/data/bepinex/ValheimWebMap/` | The map fork's data, per world: the explored mask, history and base map cache. Its default directory is `BepInEx/config/ValheimWebMap`, linked here. | The volume. |
| `/data/bepinex/EpicLoot/BountySaves/` | EpicLoot's bounty ledgers, one per player. They are written under `BepInEx/config/EpicLoot`, and `BountySaves/` is linked here. | The volume. |
| `/data/bepinex/SeparateSpawns/reports/` | SeparateSpawns' layout report of each world. It writes beside its DLL; the runtime tree links `reports/` here. | The volume. |
| `/data/dedicated/SeparateSpawns/worlds/<world uid>.json` | SeparateSpawns: each world's layout, the start regions and the Eikthyr altars it placed. Written under `<game root>/config/bepinex`, which is a link here. | The volume. |
| `/data/dedicated/SeparateSpawns.groups.json` | SeparateSpawns: the roster, seeded from `config/dedicated` once, then written by the mod with who belongs to which region. | The volume. |
| `/data/dedicated/abortipus.separatespawns.cfg` | The entrypoint, from `config/dedicated`, at every start. | Each start. |
| `/run/lembitu/BepInEx/plugins/OdinOnDemand/assetbundles/`, `radio/` | OdinOnDemand creates both beside its DLL and reads radio stations from them. The Pack ships none, so they start empty. | Each start. |
| `/run/lembitu/BepInEx/config/` | The config copied at start; plugins add the files they create when missing, such as FineDining's `Icebox.yml`. | Each start. |
| `/run/lembitu/BepInEx/cache/`, `DumpedAssemblies/`, `patchers/`, `LogOutput.log` | BepInEx. | Each start. |
| `/run/lembitu/.steam-server-opened` | `lembitu-logmark`, the readiness marker. | Each start. |
| `/home/lembitu/.config/unity3d/IronGate/Valheim/prefs` | Unity. | The Pod. |
| `/home/lembitu/Steam/` | `steamclient.so`: `config/config.vdf`, `logs/`, `appcache/httpcache/`. | The Pod. |

Three plugins needed the runtime tree's help:

- OdinOnDemand finds its directory by its own `Assembly.Location`, and Mono resolves a link to its
  store path. A linked DLL would try to create `assetbundles/` in the read-only store and fail
  with `IOException: Read-only file system`. So `OdinOnDemand.dll` is a byte-identical copy, not a
  link.
- SeparateSpawns writes `reports/` under BepInEx's plugin path. A link to the volume keeps the
  reports, as the live server keeps them.
- SeparateSpawns 0.1.1 also has a root of its own on a headless server, `<game root>/config/bepinex`,
  which it reads before `BepInEx/config` (`ModPaths.GetConfigRoots`). It keeps each world's layout
  there, and, when the files are there, its `.cfg` and its roster. The layout is state: without it the
  mod generates the start regions again. #130's image left that root in the emptyDir, so a restart
  lost the layout, and the roster's assignments with it. The runtime tree now links the root to
  `/data/dedicated`, as the live server keeps it on disk in its game tree (its BepInEx log names the
  directory: `Dedicated config root: …`). config/dedicated lands there at every start: the `.cfg`
  whole, and the roster only when there is none. The roster is what `scripts/apply-dedicated-config.sh`
  does on the live server; the `.cfg` is not: the live applier merges the overlay's keys into the
  live file one by one, and the Pod copies the file whole. The two agree only while the live file
  holds no key outside the overlay at a value other than the default, which the cutover checks
  (its first step diffs the live `.cfg` against `config/dedicated/abortipus.separatespawns.cfg`).
  `scripts/backup-world.sh` archives the layout and the roster under `dedicated/`, and the reports,
  but not the `.cfg` (docs/wiki/operations.md, the backup).

The stores must not come from the ConfigMap. A config seed for `ValheimWebMap` or
`EpicLoot/BountySaves` stops every start with "the config carries …", on purpose: a copy there would
hide the volume's.

### Ready

`lembitu-ready` is the readiness probe's exec check. It passes when all three hold:

- the Unity log has said "Opened Steam server" since this start. The line is on stdout only, not in
  BepInEx's `LogOutput.log`;
- the game port, UDP 2456, is bound, in `/proc/net/udp` or `udp6`;
- that port answers a padded SteamNetworkingSockets ConnectionClosed, sent to `127.0.0.1:2456`
  by `lembitu-sns-probe`, with its fixed NoConnection reply, `25 15 4c 45 4d 42 1d 42 4d 45 4c`.
  The monitor sends the same probe from astral-tricep to the public game address
  (`docs/wiki/operations.md`, monitoring).

**Why "Opened Steam server".** Valheim logs it after the world loads, when it opens the listen
socket clients connect to. "Game server connected" is only the Steam registration (`docs/build.md`,
"Repeatable native acceptance"). In the image's runs it came 17 to 42 seconds earlier, and
2456 was not bound or answering until "Opened Steam server". A check on the earlier line went
green while nobody could join.

**Why 2456.** The game's socket is a SteamNetworkingSockets listen socket on the `-port` it is
given, 2456, bound on the IPv6 wildcard, so it shows in `/proc/net/udp6`. Clients connect there.
2457 is the Steam game server's query socket. Under `-public 0` it never sends a byte: not to
A2S_INFO, and not to SteamNetworkingSockets' own packets. Both were measured on 2026-10-27 with
tcpdump on the running image, over four starts.

**Why the probe.** A ConnectionClosed asks for no connection, no authentication and no Steam. The
server answers it from its own networking code with NoConnection, which echoes the two connection
IDs. The reply is the same 11 bytes every time, and ten checks added no line to the server's log.
A padded ChallengeRequest (`20 10 00 0d 4c 45 4d 42 …`, 512 bytes) also gets an answer, a
ChallengeReply that starts `21 0d 4c 45 4d 42 11`. Its 8 challenge bytes change every time, so the
check uses ConnectionClosed. Both requests must be padded to 512 bytes; the server ignores them
shorter. The datagram must leave as one write: bash's `printf` flushes at every 0x0a byte, so the
request's body carries a `reason_code` field (length 12, not 10), and `dd bs=512
iflag=fullblock` re-blocks it into a single 512-byte write in any case. The same probe gets the
same reply from a server running `-public 1`: today's container on astral-bicep answered it on
2456 on 2026-10-27.

**Why not A2S_INFO.** Under `-public 0` the server never answers it, on 2457 or on 2456. With
`-public 1` the same image answered on 2457 within about two minutes. `lembitu-a2s` stays in the
image for querying with `-public 1`.

In the image tier, readiness stays red through "Game server connected" and turns green on the first
check after "Opened Steam server".

### Stopping

`docker stop` or the kubelet sends SIGTERM, dumb-init sends the server SIGINT, and the server saves
and exits 0. In the image tier the save and exit took 21 to 24 seconds. The Workload's grace period
is 180 s.

## The config

The live server merges `config/enforced` into the files the mods generated on its disk, which keep
every other value they hold (`scripts/apply-enforced-config.sh`, before every start). The image
copies files whole: the ConfigMap's file, then the mod fills in every key it binds and the file
lacks, at its default. So a value the live server holds outside the overlay, and not at its
default, would change at the move.

The two ways to keep those values were weighed (A3):

- **(a) The ConfigMap holds the merged files.** The live server's merged files are too big for it:
  the 53 overlay files alone are 1.64 MB as live holds them (`local.warrior.rpg.cfg` is 811 KB),
  over a ConfigMap's 1 MiB. They would need splitting across several ConfigMaps, a committed
  copy of the generated files beside the overlay, and keeping the two in step.
- **(b) Apply the overlay at start.** The applier merges into files the mods have generated, and
  refuses a missing one. A fresh runtime tree has none, so the generated files would have to live
  on the volume, the applier and its tools would join the image, a first start would need its own
  path, and drift would outlive restarts again, as on the live server.

Chosen: (a)'s effect without its bulk. The live server's merged tree (its second read, 2026-10-27)
was compared key by key with the tree the image's mods write from the overlay alone. Exactly 21
keys the server's mods bind hold another value on the live server; they are now overlay entries,
each marked as live's value, in seven files:

| File | Keys |
| --- | --- |
| `BepInEx.cfg` | `[Logging.Disk] WriteUnityLog`, `[Logging.Console] Enabled`, `ForceBepInExTTYDriver`, `PreventClose`, all `true` |
| `adrian.valheim.guilds.cfg` | `[5 - Territory] BannerRecipe = Wood:1`, `TerritoryBaseSize = 50` |
| `sighsorry.CreatureManager.cfg` | `[3 - Karma] Dungeon Enforcer Spawn Delay (s) = 7` |
| `vapok.mods.adventurebackpacks.cfg` | six `Effective Quality Level` keys; `Enable Anonymous Telemetry` is pinned `false` instead of live's `true` (ra, 2026-10-27) |
| `MidnightsFX.ProgressivePowers.cfg` | `[Client config] Full Power Displays = 1` |
| `Raelaziel.OdinArchitect.cfg` (new) | the two elevators' `Crafting Costs` |
| `Searica.Valheim.ExtraSnapPointsMadeEasy.cfg` (new) | four manual-snapping key bindings |

The rest of the comparison was keys the mods no longer bind (a removed mod's, or an older
version's), and generated reference, cache and localization files, which the mods write again.
`scripts/verify-enforced-config.sh` passed on the live tree with these entries (`472 entries
match`), so on the live server they were already in effect. The one exception since: telemetry is
pinned off by ra's decision, so against today's live tree the check reports that one key until the
overlay is next applied there. On the image's own run it finds exactly these 21 different. The
ConfigMaps stay small (about 150 KB), the entrypoint is unchanged, and drift still can't outlive a
restart.

## The Workload

`./workloads/lembitu` is the kustomization astral-fleet's registration delivers into namespace
`project-valheim-lembitu`, from `main`, suspended until the cutover. It lists the StatefulSet and
`config/`, whose `kustomization.yaml` makes the three ConfigMaps (kustomize reads a generator's
files only from inside its own directory).

The StatefulSet `lembitu`:

- one replica, `OrderedReady`, on astral-bicep, at priority `fleet-games`;
- a 180 s grace period, no service-account token and no service links;
- the image by digest, `astral-bicep.tail032eca.ts.net:30500/project/valheim-lembitu/server@sha256:…`,
  the digest `.#serverImage` builds;
- Guaranteed QoS, 3 CPU and 6Gi for requests and limits alike;
- Pod Security `restricted`: uid, gid and `fsGroup` 10160, the RuntimeDefault seccomp profile, no
  privilege escalation, every capability dropped, and a read-only root;
- ports `game` 2456/UDP, `query` 2457/UDP and `map` 3000/TCP, and the labels
  `app.kubernetes.io/name: lembitu` (the fleet's Services) and `fleet.astral.ee/egress: lembitu` (its
  NetworkPolicy);
- the probes: readiness is an exec of `lembitu-ready` every 10 s; a startup probe of the same allows
  15 minutes; there is no liveness probe, which could kill the server mid-save;
- the Secret `lembitu-secrets`: its `password` as a file, `defaultMode` 0400, which the kubelet
  widens with the group's read because of `fsGroup`, so it is readable by the server's uid; and its
  `discord-bot-token` as `SERVERMANAGER_DISCORD_BOT_TOKEN`, which ServerManager's bot reads, as on
  the live container;
- the claim template `world`, so the claim is `world-lembitu-0`, which the fleet's volume
  `fleet-lembitu` is pre-bound to: `fleet-lembitu-local`, 20Gi, `backup.fleet/tier: none` (ra's
  decision of 2026-10-20, not #114's "off-site"), and a regeneration that names the archives and
  `scripts/restore-world.sh --root`.

### The volume

The fleet's volume is `/state/lembitu/world` on astral-bicep, mounted at `/data`. The move fills it
from the stopped live server:

| On the volume | From the live server |
| --- | --- |
| `save/` | `~/lembitu/config/save/`, the live `-savedir`: `worlds_local/`, `cache/`, the three lists, `ServerManager/` |
| `bepinex/Guilds/`, `Marketplace/`, `Lembitu.Guilds/`, `ValheimWebMap/`, `EpicLoot/BountySaves/` | the same directories in `~/lembitu/config/bepinex/` |
| `bepinex/SeparateSpawns/reports/` | `SeparateSpawns/reports/` in the live plugin tree (`~/lembitu/data/bepinex/BepInEx/plugins/`; regenerated if absent) |
| `dedicated/` | the live server's SeparateSpawns root, the directory its BepInEx log names as `Dedicated config root:` (the game tree's `config/bepinex`, `~/lembitu/data/bepinex/config/bepinex` on the host): the roster and `SeparateSpawns/worlds/` |

`scripts/backup-world.sh --root /state/lembitu/world --out …` captures the volume: `save/`,
`bepinex/`'s stores, SeparateSpawns' roster and `SeparateSpawns/worlds/` in `dedicated/`, and
`bepinex/SeparateSpawns/reports/`, the same archive as `--savedir`, `--bepinex`, `--dedicated` and
`--reports` name. `dedicated/`'s `.cfg` is configuration, from the ConfigMap, and not archived.
`scripts/restore-world.sh --root` restores into the same layout, and, run as root, gives what it
restored to the volume's owner.

### What the Pod does not do that `launch-server.sh` does

Before every start, `scripts/launch-server.sh` also applies ServerManager's policy from the
approved Pack and writes ServerManager's `discord.yml` from the host's Discord files, both into
`save/ServerManager/`, and after the start it verifies the overlay. In the Pod, `save/ServerManager/`
keeps what the move copied; a new Pack's policy or a changed webhook is written there by hand,
with the server stopped. The overlay's verification is the ConfigMap's copy, which can't drift.

### Sealing lembitu-secrets

`workloads/lembitu/lembitu-secrets.sops.yaml` is a placeholder with the two keys and no value, and
it stays out of the kustomization until it is sealed: listed as it is, it would apply an empty
password, which the entrypoint refuses. At the lift ("Lift valheim-lembitu" in astral-fleet's
runbook), ra's agent:

1. adds a `.sops.yaml` rule for `workloads/lembitu/.*\.sops\.yaml$` with the Project's age public
   half and `encrypted_regex: ^(data|stringData)$`;
2. fills `password` and `discord-bot-token` and encrypts the file in place with sops. Both keys must
   be there, the token empty if there is no bot: the container's environment names the token key,
   not optionally, so a Secret without it stops the Pod in `CreateContainerConfigError`, not a
   start without the bot;
3. adds `- lembitu-secrets.sops.yaml` to `workloads/lembitu/kustomization.yaml`'s `resources`.

`test/lembitu-workload.test.sh` fails while a sealed file is unlisted or a placeholder is listed.

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
- SeparateSpawns' root on the volume: its `.cfg` fresh at every start, its roster seeded only when
  absent, its layouts kept;
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

`test/lembitu-workload.test.sh` checks the Workload. Its render tier runs with every pass: it
renders the working tree's commit with astral-fleet's own `project-workload-delivery`
(`LEMBITU_FLEET_FLAKE`, default its `dev`), so the fleet's Project rules apply, then checks every
field above, rebuilds `config/enforced` and `config/dedicated` from the ConfigMaps byte for byte,
and holds the render to the fleet's side: its Services, NetworkPolicy, volume, registration and
priority class. Its image tier (`LEMBITU_IMAGE_TEST=1`) starts the pinned image as the render says,
on `test/fixtures/lembitu-world`, a world this image generated on 2026-10-27 (never a copy of
LembituRun's save), with its SeparateSpawns layout: the digest is the pin, readiness turns green,
the stored layout loads from the volume, every overlay entry is in effect in the running config,
the map answers, and SIGTERM saves a fresh generation.
