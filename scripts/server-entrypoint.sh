#!/usr/bin/env bash
# The server image's entrypoint (#113; nix/server-image.nix bakes it in). It assembles the
# writable runtime tree, then execs valheim_server.x86_64 under BepInEx's doorstop. There is no
# updater, no supervisor and no sleep: the server is the only long-running process, and the
# image's PID 1 (dumb-init) only forwards signals to it. Its stdout goes through lembitu-logmark,
# which marks "Opened Steam server" for the readiness check (scripts/server-ready.sh).
#
# The image's store paths are read-only, and BepInEx and the mods write beside their own files. So
# at every start the runtime tree is rebuilt from nothing on an emptyDir:
#
#   $RUNTIME/<every game file>     links into the store (the server, the redistributable's
#                                  linux64/, the loader's doorstop_libs/ and BepInEx/core)
#   $RUNTIME/BepInEx/plugins/      links to each installed package; SeparateSpawns/ is a real
#                                  directory whose reports/ links to $DATA/bepinex; OdinOnDemand/
#                                  is a real directory with a copy of its DLL and empty
#                                  assetbundles/ and radio/
#   $RUNTIME/BepInEx/config/       real files, copied fresh at every start: the packages' seeds,
#                                  then the ConfigMap; the plugins' stores in it link to
#                                  $DATA/bepinex
#   $RUNTIME/BepInEx/cache/, DumpedAssemblies/, patchers/, LogOutput.log
#                                  written by BepInEx, gone at the next start
#   $RUNTIME/.steam-server-opened  lembitu-logmark's readiness marker
#
# and the state that must outlive the Pod is on the volume: the world and ServerManager's store
# under $DATA/save (the game's -savedir), and the plugins' stores under $DATA/bepinex.
#
# Environment (the image sets the first three; the rest default to the Workload's mounts):
#   LEMBITU_GAME, LEMBITU_BEPINEX, LEMBITU_LIBRARY_PATH   store paths
#   LEMBITU_RUNTIME         the runtime tree, an emptyDir       (default /run/lembitu)
#   LEMBITU_DATA            the world volume                    (default /data)
#   LEMBITU_CONFIG          the ConfigMap's BepInEx config      (default /etc/lembitu/bepinex)
#   LEMBITU_PASSWORD_FILE   the Secret's join password          (default /run/secrets/lembitu/password)

set -euo pipefail

: "${LEMBITU_GAME:?the image sets LEMBITU_GAME}"
: "${LEMBITU_BEPINEX:?the image sets LEMBITU_BEPINEX}"
: "${LEMBITU_LIBRARY_PATH:?the image sets LEMBITU_LIBRARY_PATH}"
RUNTIME=${LEMBITU_RUNTIME:-/run/lembitu}
DATA=${LEMBITU_DATA:-/data}
CONFIG=${LEMBITU_CONFIG:-/etc/lembitu/bepinex}
PASSWORD_FILE=${LEMBITU_PASSWORD_FILE:-/run/secrets/lembitu/password}

# Plugin stores that live in BepInEx/config on the live server. scripts/backup-world.sh captures the
# first three as bepinex-state/. The live config read of 2026-10-27 (docs/live-vs-lock-20261027.md,
# section 7) found two more: ValheimWebMap's per-world explored map and history, and EpicLoot's
# per-player bounty ledgers.
CONFIG_STORES=(Guilds Marketplace Lembitu.Guilds ValheimWebMap EpicLoot/BountySaves)
# Directories plugins create inside their own plugin directory at run time, found by running the
# image (docs/server-image.md, "What the server writes"). PLUGIN_STATE persists on the volume:
# SeparateSpawns' reports of each world's spawn regions. PLUGIN_SCRATCH starts empty at every
# start, as it is on the live server: OdinOnDemand creates assetbundles/ and radio/ for radio
# stations, and the Pack ships none.
PLUGIN_STATE=(SeparateSpawns/reports)
PLUGIN_SCRATCH=(OdinOnDemand/assetbundles OdinOnDemand/radio)
# Assemblies that find their own directory by Assembly.Location. Mono resolves a link to its store
# path, so these are byte-identical copies, not links: OdinOnDemand builds the two paths above from
# its own Location, and through a link it would try to create them in the read-only store.
PLUGIN_LOCATED=(OdinOnDemand/OdinOnDemand.dll)

die() { printf 'lembitu-server: %s\n' "$*" >&2; exit 1; }

# --- the password ------------------------------------------------------------------------------
# Valheim takes it only on its command line. The Secret's file is the one place it is read from.
[[ -r "$PASSWORD_FILE" ]] || die "no readable password file at $PASSWORD_FILE"
password="$(head -n 1 "$PASSWORD_FILE")"
password="${password%$'\r'}"
(( ${#password} >= 5 )) || die "the password in $PASSWORD_FILE is shorter than the 5 characters Valheim requires"

# --- the volume --------------------------------------------------------------------------------
[[ -d "$DATA" && -w "$DATA" ]] || die "$DATA is not a writable directory"
mkdir -p "$DATA/save" "$DATA/bepinex"
for store in "${CONFIG_STORES[@]}" "${PLUGIN_STATE[@]}"; do mkdir -p "$DATA/bepinex/$store"; done

# --- the runtime tree --------------------------------------------------------------------------
[[ -d "$RUNTIME" && -w "$RUNTIME" ]] || die "$RUNTIME is not a writable directory"
find "$RUNTIME" -mindepth 1 -delete
for entry in "$LEMBITU_GAME"/* "$LEMBITU_GAME"/.doorstop_version; do
  [[ "$(basename "$entry")" == BepInEx ]] || ln -s "$entry" "$RUNTIME/$(basename "$entry")"
done
mkdir -p "$RUNTIME/BepInEx/plugins" "$RUNTIME/BepInEx/config" "$RUNTIME/BepInEx/cache"
ln -s "$LEMBITU_GAME/BepInEx/core" "$RUNTIME/BepInEx/core"
[[ ! -d "$LEMBITU_BEPINEX/patchers" ]] || ln -s "$LEMBITU_BEPINEX/patchers" "$RUNTIME/BepInEx/patchers"

for entry in "$LEMBITU_BEPINEX"/plugins/*; do
  ln -s "$entry" "$RUNTIME/BepInEx/plugins/$(basename "$entry")"
done
# A package that a plugin writes into becomes a real directory of links, so the write can land.
unfold_package() {  # unfold_package <package>
  local target="$RUNTIME/BepInEx/plugins/$1" entry
  [[ -d "$target" && ! -L "$target" ]] && return 0
  [[ -L "$target" ]] || die "$1 is not an installed package"
  rm "$target"
  mkdir "$target"
  for entry in "$LEMBITU_BEPINEX/plugins/$1"/*; do ln -s "$entry" "$target/$(basename "$entry")"; done
}
for state in "${PLUGIN_STATE[@]}" "${PLUGIN_SCRATCH[@]}" "${PLUGIN_LOCATED[@]}"; do
  unfold_package "${state%%/*}"
done
for state in "${PLUGIN_STATE[@]}" "${PLUGIN_SCRATCH[@]}"; do
  [[ ! -e "$RUNTIME/BepInEx/plugins/$state" ]] || die "${state%%/*} ships its own ${state#*/}"
done
for state in "${PLUGIN_STATE[@]}"; do ln -s "$DATA/bepinex/$state" "$RUNTIME/BepInEx/plugins/$state"; done
for scratch in "${PLUGIN_SCRATCH[@]}"; do mkdir "$RUNTIME/BepInEx/plugins/$scratch"; done
for located in "${PLUGIN_LOCATED[@]}"; do
  [[ -f "$LEMBITU_BEPINEX/plugins/$located" ]] || die "${located%%/*} no longer ships ${located#*/}"
  rm "$RUNTIME/BepInEx/plugins/$located"
  cp --no-preserve=mode,ownership "$LEMBITU_BEPINEX/plugins/$located" "$RUNTIME/BepInEx/plugins/$located"
done

# The config is real, writable files, fresh at every start: a plugin's Config.Bind of a missing
# key can save, and no drift survives a restart.
cp -R --no-preserve=mode,ownership "$LEMBITU_BEPINEX/config/." "$RUNTIME/BepInEx/config/"
if [[ -d "$CONFIG" ]]; then
  # A ConfigMap's files are links into its ..data directory; copy what they point at.
  cp -RL --no-preserve=mode,ownership "$CONFIG/." "$RUNTIME/BepInEx/config/"
  find "$RUNTIME/BepInEx/config" -name '..*' -prune -exec rm -rf {} +
else
  printf 'lembitu-server: no config at %s; starting with the packages'"'"' seeds only\n' "$CONFIG" >&2
fi
for store in "${CONFIG_STORES[@]}"; do
  [[ ! -e "$RUNTIME/BepInEx/config/$store" ]] || die "the config carries $store, which is a plugin store on $DATA"
  mkdir -p "$(dirname "$RUNTIME/BepInEx/config/$store")"
  ln -s "$DATA/bepinex/$store" "$RUNTIME/BepInEx/config/$store"
done

# --- the server --------------------------------------------------------------------------------
cd "$RUNTIME"
# The readiness marker belongs to this start only; the wipe above already removed any older one.
# stdout goes through lembitu-logmark, which passes every byte on to the container log. It runs
# beside the server, not between it and its signals: this shell execs the server below, so the
# server is dumb-init's child, and lembitu-logmark ignores the stop signal dumb-init sends the
# process group and exits when the server closes its stdout. stderr is left as it is.
# The trap ignores the signals before the exec too, so there is no instant in which they kill it.
exec > >(trap '' INT TERM HUP; exec lembitu-logmark "$RUNTIME/.steam-server-opened" "Opened Steam server")
export DOORSTOP_ENABLED=1
export DOORSTOP_TARGET_ASSEMBLY=./BepInEx/core/BepInEx.Preloader.dll
export LD_LIBRARY_PATH="$RUNTIME/linux64:$RUNTIME/doorstop_libs:$LEMBITU_LIBRARY_PATH"
export LD_PRELOAD=libdoorstop_x64.so
export SteamAppId=892970

# The live launch, docs: config/launch/launch.env.example (the world rules) and ra's 2026-10-27
# Round (-public 0: players join by address, the Steam list is off).
exec ./valheim_server.x86_64 -nographics -batchmode \
  -name Lembitu -port 2456 -world LembituRun -public 0 -password "$password" \
  -savedir "$DATA/save" -saveinterval 300 \
  -modifier Combat hard -modifier DeathPenalty easy -modifier Resources default \
  -modifier Raids less -modifier Portals hard
