#!/usr/bin/env bash
# Behaviour tests for the server image (#113): nix/server-image.nix, scripts/server-entrypoint.sh,
# scripts/server-ready.sh and nix/logmark.c.
#
# Two tiers.
#
# The fast tier runs on every `for t in test/*.test.sh` pass. It runs the real entrypoint against a
# fake game, whose "server" is a script that records how it was started and behaves like the real
# one on a stop signal. It checks:
#   - the entrypoint execs the server (same PID), so no shell sits between it and its signals;
#   - the launch arguments, the password from the Secret's file, and the library path;
#   - the writable runtime tree, rebuilt at every start;
#   - lembitu-logmark: the server's stdout reaches the log byte for byte, it marks "Opened Steam
#     server", and it outlives the stop signal sent to the whole process group;
#   - the readiness check: red before "Opened Steam server" (after "Game server connected" too),
#     red with it but the game port unbound or silent, and green with the line, the port bound and
#     a NoConnection answer from a fake server that answers as SteamNetworkingSockets does.
# It needs lembitu-logmark (from LEMBITU_TOOLS, else built through nix, else compiled with cc) and
# python3 for the fake server (on PATH, else from nix). Without them it says "skip" and passes
# nothing.
#
# The image tier runs the real server, so it is opt-in: LEMBITU_IMAGE_TEST=1. It needs nix, rootless
# docker and about 4 GB of memory, and takes about fifteen minutes on a warm store. Set
# LEMBITU_BUILD_LOCK to a lock file and the nix builds run under flock on it. It checks:
#   - two builds of every derivation the image is made from give the same bytes, so the digest is one;
#   - the image's files are the locked inputs: the server and redistributable depots by the
#     verifier, BepInEx's core by the pack, the plugin tree by the deploy path, and no config, world
#     or Secret;
#   - the readiness check is red at the start, stays red until the log says "Opened Steam server",
#     and turns green after it;
#   - the chainloader loads every plugin GUID the lock lists, skips only the lock's process-filter
#     skips, and fails none;
#   - SIGTERM saves the world (a fresh .db2 and .fwl2 generation) and the server exits 0 within
#     180 s.
# LEMBITU_IMAGE_REPORT, if set, names a directory that receives the digest, the logs and the list of
# every path the server wrote.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTRYPOINT="$REPO_ROOT/scripts/server-entrypoint.sh"
READY="$REPO_ROOT/scripts/server-ready.sh"

WORK="$(mktemp -d)"
cleanup() {
  local status=$?
  # Stop anything this test started: fake servers by their process group, the fake game socket by
  # its PID, containers by name.
  [[ -f "$WORK/pgids" ]] && while read -r pgid; do kill -KILL -- "-$pgid" 2>/dev/null || true; done < "$WORK/pgids"
  [[ -f "$WORK/pids" ]] && while read -r pid; do kill -KILL "$pid" 2>/dev/null || true; done < "$WORK/pids"
  if [[ -f "$WORK/containers" ]]; then
    while read -r name; do docker rm -f "$name" >/dev/null 2>&1 || true; done < "$WORK/containers"
  fi
  if [[ -f "$WORK/volumes" ]]; then
    while read -r name; do docker volume rm "$name" >/dev/null 2>&1 || true; done < "$WORK/volumes"
  fi
  # The image tag goes last: docker refuses to remove it while a container still uses it.
  if [[ -f "$WORK/images" ]]; then
    while read -r name; do docker rmi "$name" >/dev/null 2>&1 || true; done < "$WORK/images"
  fi
  chmod -R u+w "$WORK" 2>/dev/null || true
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT INT TERM

pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@"; then report ok "$what"; else report fail "$what"; fi
}
finish() { printf '\n%d passed, %d failed\n' "$pass" "$fail"; [[ $fail -eq 0 ]]; }

# --- lembitu-logmark ----------------------------------------------------------------------------

TOOLS="${LEMBITU_TOOLS:-}"
if [[ -z "$TOOLS" ]] && command -v nix >/dev/null 2>&1; then
  TOOLS="$(nix build --no-link --print-out-paths "$REPO_ROOT#serverImage.passthru.tools" 2>/dev/null || true)"
fi
if [[ -z "$TOOLS" ]] && command -v cc >/dev/null 2>&1; then
  mkdir -p "$WORK/tools/bin"
  cc -O2 -D_GNU_SOURCE -o "$WORK/tools/bin/lembitu-logmark" "$REPO_ROOT/nix/logmark.c" && TOOLS="$WORK/tools"
fi
if [[ -z "$TOOLS" || ! -x "$TOOLS/bin/lembitu-logmark" ]]; then
  echo "skip: the image tests need lembitu-logmark (LEMBITU_TOOLS, nix or cc)"
  finish; exit
fi
LOGMARK="$TOOLS/bin/lembitu-logmark"

# Byte for byte, binary included, and no marker without the text.
head -c 300000 /dev/urandom > "$WORK/noise"
LC_ALL=C sed -i 's/Opened Steam server/Opened Steam xerver/g' "$WORK/noise"
"$LOGMARK" "$WORK/m1" < "$WORK/noise" > "$WORK/noise.out"
check "lembitu-logmark passes 300 kB of binary through unchanged" cmp -s "$WORK/noise" "$WORK/noise.out"
check "lembitu-logmark makes no marker when the text never appears" test ! -e "$WORK/m1"

# The text split across two reads still counts.
{ printf 'boot\n10/27 12:06:52: Opened Steam ser'; sleep 0.3; printf 'ver\nmore\n'; } \
  | "$LOGMARK" "$WORK/m2" > "$WORK/split.out"
check "lembitu-logmark marks a line whose text arrives in two reads" test -e "$WORK/m2"
check "lembitu-logmark keeps that line whole in the log" grep -qx '10/27 12:06:52: Opened Steam server' "$WORK/split.out"
printf '10/27 12:06:12: Game server connected\n' | "$LOGMARK" "$WORK/m3" > /dev/null
check "lembitu-logmark's default text is \"Opened Steam server\", not \"Game server connected\"" test ! -e "$WORK/m3"

# The stop signal reaches the filter too (dumb-init signals the whole process group). It must keep
# passing the server's last lines and exit only at end of input. Its own signal handling is tested
# here, without the entrypoint's trap, which only closes the instant before the filter starts.
mkfifo "$WORK/feed"
"$LOGMARK" "$WORK/m3" < "$WORK/feed" > "$WORK/signals.out" &
filter_pid=$!
exec 7> "$WORK/feed"
printf 'before\n' >&7
sleep 0.2
kill -INT "$filter_pid" 2>/dev/null || true
kill -TERM "$filter_pid" 2>/dev/null || true
kill -HUP "$filter_pid" 2>/dev/null || true
sleep 0.2
printf 'after the signals\n' >&7
exec 7>&-
filter_status=0
wait "$filter_pid" || filter_status=$?
check "lembitu-logmark ignores SIGINT, SIGTERM and SIGHUP, and exits 0 at end of input" \
  bash -c "[[ $filter_status -eq 0 ]] && diff <(printf 'before\nafter the signals\n') '$WORK/signals.out'"

# --- the plugins' compiler -----------------------------------------------------------------------

# nix/plugins.nix builds with the SDK the lock's `plugins` names, and refuses another: the build IDs
# follow the compiler's exact version (docs/live-vs-lock-20261027.md, section 4).
plugins_drv() {  # plugins_drv <sdk>: evaluate nix/plugins.nix with that SDK in the stamp
  nix eval --impure --raw --expr "let r = \"$REPO_ROOT\";
    pkgs = (builtins.getFlake \"path:\${r}\").inputs.nixpkgs.legacyPackages.x86_64-linux;
    in (pkgs.callPackage (r + \"/nix/plugins.nix\") { server = \"/s\"; bepinexPack = \"/p\";
      bepinexVersion = \"5\"; mods = \"/m\";
      stamp = { sdk = \"$1\"; pathMap = \"/x/\"; sourceRevisionId = \"0\"; }; }).drvPath" > "$WORK/eval.out" 2>&1
}
if command -v nix >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  locked_sdk="$(jq -r '.plugins.sdk' "$REPO_ROOT/docs/server-inputs.lock.json")"
  check "the plugins evaluate with the lock's SDK, $locked_sdk" plugins_drv "$locked_sdk"
  wrong_sdk() { ! plugins_drv 10.0.999 && grep -q "the lock's plugins.sdk is 10.0.999" "$WORK/eval.out"; }
  check "the plugins refuse an SDK the lock doesn't name" wrong_sdk
else
  echo "skip: the plugins' SDK guard needs nix and jq"
fi

# --- a fake game for the entrypoint -------------------------------------------------------------

GAME="$WORK/game"
BEPINEX="$WORK/bepinex"
mkdir -p "$GAME/linux64" "$GAME/doorstop_libs" "$GAME/BepInEx/core" "$GAME/valheim_server_Data"
printf '4.2.1\n' > "$GAME/.doorstop_version"
printf 'core\n' > "$GAME/BepInEx/core/BepInEx.Preloader.dll"
cat > "$GAME/valheim_server.x86_64" <<'FAKE'
#!/usr/bin/env bash
# The fake server: records how it was started, logs like Unity, and saves on SIGINT.
printf '%s\n' "$$" > "$FAKE_OUT/pid"
printf '%s\n' "$@" > "$FAKE_OUT/args"
env > "$FAKE_OUT/env"
pwd > "$FAKE_OUT/cwd"
trap 'echo "World save (5/5) done after SIGINT"; echo saved > "$FAKE_OUT/saved"; exit 0' INT
echo "Loading world"
echo "10/27/2026 12:06:12: Game server connected"
[[ -n "${FAKE_NO_OPEN:-}" ]] || echo "10/27/2026 12:06:52: Opened Steam server"
: > "$FAKE_OUT/running"
while :; do sleep 0.1; done
FAKE
chmod +x "$GAME/valheim_server.x86_64"

mkdir -p "$BEPINEX/plugins/SeparateSpawns" "$BEPINEX/plugins/OdinOnDemand" "$BEPINEX/plugins/Jotunn" \
  "$BEPINEX/config/CreatureManager"
printf 'dll\n' > "$BEPINEX/plugins/SeparateSpawns/SeparateSpawns.dll"
printf 'dll\n' > "$BEPINEX/plugins/OdinOnDemand/OdinOnDemand.dll"
printf 'dll\n' > "$BEPINEX/plugins/Jotunn/Jotunn.dll"
printf 'dll\n' > "$BEPINEX/plugins/Lembitu.Guilds.dll"
printf '[Seed]\nKey = seed\n' > "$BEPINEX/config/BepInEx.cfg"
printf 'seed\n' > "$BEPINEX/config/CreatureManager/seed.yml"
chmod -R a-w "$GAME" "$BEPINEX"

# The ConfigMap's shape: files that are links into a ..data directory.
CONFIG="$WORK/configmap"
mkdir -p "$CONFIG/..2026_10_27/CreatureManager" "$CONFIG/..2026_10_27/EpicLoot/patches"
printf '[Seed]\nKey = enforced\n' > "$CONFIG/..2026_10_27/BepInEx.cfg"
printf 'enforced\n' > "$CONFIG/..2026_10_27/lembitu.guilds.cfg"
printf '{}\n' > "$CONFIG/..2026_10_27/EpicLoot/patches/lembitu.json"
ln -s ..2026_10_27 "$CONFIG/..data"
ln -s ..data/BepInEx.cfg "$CONFIG/BepInEx.cfg"
ln -s ..data/lembitu.guilds.cfg "$CONFIG/lembitu.guilds.cfg"
ln -s ..data/EpicLoot "$CONFIG/EpicLoot"

PROC_NET="$WORK/proc-net"
mkdir -p "$PROC_NET"
printf '  sl  local_address rem_address   st\n' > "$PROC_NET/udp"
printf '  sl  local_address rem_address   st\n' > "$PROC_NET/udp6"

# A fake game socket: a UDP server on 127.0.0.1 that answers as SteamNetworkingSockets does
# (GameNetworkingSockets, steamnetworkingsockets_udp.cpp). It answers a ConnectionClosed (36) padded
# to at least 512 bytes with NoConnection (37), the IDs echoed, and ignores anything else. Its mode
# file decides: "sns" answers, "silent" ignores everything, "wrong" answers with a NoConnection of
# the same length whose IDs are not the ones sent.
cat > "$WORK/fake-sns.py" <<'PY'
import socket, struct, sys
mode_file, port_file = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("127.0.0.1", 0))
open(port_file, "w").write(str(s.getsockname()[1]))
def fixed32(body, tag):
    i = 0
    while i < len(body):
        key = body[i]; i += 1
        if key & 7 == 5:
            if key == tag: return body[i:i + 4]
            i += 4
        else:
            return None
    return None
while True:
    pkt, peer = s.recvfrom(65536)
    mode = open(mode_file).read().strip()
    if mode == "silent" or len(pkt) < 512 or pkt[0] != 36:
        continue
    body = pkt[3:3 + struct.unpack_from("<H", pkt, 1)[0]]
    to, frm = fixed32(body, 0x25), fixed32(body, 0x2d)
    if mode == "wrong":
        s.sendto(b"\x25\x15" + b"XXXX" + b"\x1d" + b"YYYY", peer)
    elif to and frm:
        s.sendto(b"\x25\x15" + to + b"\x1d" + frm, peer)
PY
FAKE_PY="$(command -v python3 || true)"
if [[ -z "$FAKE_PY" ]] && command -v nix >/dev/null 2>&1; then
  FAKE_PY="$(nix build --no-link --print-out-paths nixpkgs#python3 2>/dev/null || true)"
  [[ -z "$FAKE_PY" ]] || FAKE_PY="$FAKE_PY/bin/python3"
fi
if [[ -z "$FAKE_PY" ]]; then
  echo "skip: the readiness tests need python3 (on PATH, or through nix) for the fake game socket"
  finish; exit
fi
printf 'sns\n' > "$WORK/fake-sns.mode"
"$FAKE_PY" "$WORK/fake-sns.py" "$WORK/fake-sns.mode" "$WORK/fake-sns.port" &
echo "$!" >> "$WORK/pids"
for _ in $(seq 50); do [[ -s "$WORK/fake-sns.port" ]] && break; sleep 0.1; done
GAME_PORT="$(cat "$WORK/fake-sns.port")"

ready() {  # ready: run the readiness check against this test's runtime, fake /proc/net and socket
  LEMBITU_RUNTIME="$RUNTIME" LEMBITU_PROC_NET="$PROC_NET" LEMBITU_GAME_PORT="$GAME_PORT" \
    "$READY" > "$WORK/ready.out" 2>&1
}
bind_game_port() {  # bind_game_port <udp|udp6>: the fake socket's port, in /proc/net's hex
  printf '14266: 00000000:%04X 00000000:0000 07 00000000:00000000\n' "$GAME_PORT" >> "$PROC_NET/$1"
}
unbind_game_port() {
  printf '  sl  local_address rem_address   st\n' | tee "$PROC_NET/udp" > "$PROC_NET/udp6"
}

# start_entrypoint [VAR=value...]: run the entrypoint in its own process group, as dumb-init does,
# with stdout and stderr captured. Sets EP_PID.
start_entrypoint() {
  RUNTIME="$WORK/run"; DATA="$WORK/data"; FAKE_OUT="$WORK/fake"
  mkdir -p "$RUNTIME" "$DATA" "$FAKE_OUT"
  rm -f "$FAKE_OUT"/*
  set -m
  env LEMBITU_GAME="$GAME" LEMBITU_BEPINEX="$BEPINEX" LEMBITU_LIBRARY_PATH=/store/lib \
    LEMBITU_RUNTIME="$RUNTIME" LEMBITU_DATA="$DATA" LEMBITU_CONFIG="$CONFIG" \
    LEMBITU_PASSWORD_FILE="$WORK/password" FAKE_OUT="$FAKE_OUT" PATH="$TOOLS/bin:$PATH" "$@" \
    bash "$ENTRYPOINT" > "$WORK/stdout" 2> "$WORK/stderr" &
  EP_PID=$!
  set +m
  echo "$EP_PID" >> "$WORK/pgids"
}
wait_for() {  # wait_for <file> <seconds>
  local i
  for ((i = 0; i < $2 * 10; i++)); do [[ -e "$1" ]] && return 0; sleep 0.1; done
  return 1
}
# finish_entrypoint <seconds>: the entrypoint's exit status in EP_STATUS. A run still going after
# that long has its process group killed and counts as status 124, so a wrong start never hangs.
finish_entrypoint() {
  local i hung=0
  for ((i = 0; i < $1 * 10; i++)); do kill -0 "$EP_PID" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$EP_PID" 2>/dev/null; then hung=1; kill -KILL -- "-$EP_PID" 2>/dev/null || true; fi
  EP_STATUS=0
  wait "$EP_PID" || EP_STATUS=$?
  [[ $hung -eq 0 ]] || EP_STATUS=124
}
stop_entrypoint() {  # stop_entrypoint: SIGINT to the process group, as dumb-init's rewrite sends it
  kill -INT -- "-$EP_PID" 2>/dev/null || true
  finish_entrypoint 10
}

# --- the password ------------------------------------------------------------------------------

rm -f "$WORK/password"
start_entrypoint; finish_entrypoint 5
check "no password file: the entrypoint refuses to start" \
  bash -c "[[ $EP_STATUS -ne 0 && $EP_STATUS -ne 124 ]] && grep -q 'no readable password file' '$WORK/stderr' && [[ ! -e '$WORK/fake/pid' ]]"

printf 'abcd\n' > "$WORK/password"
start_entrypoint; finish_entrypoint 5
check "a password shorter than Valheim's 5 characters is refused" \
  bash -c "[[ $EP_STATUS -ne 0 && $EP_STATUS -ne 124 ]] && grep -q 'shorter than the 5 characters' '$WORK/stderr' && [[ ! -e '$WORK/fake/pid' ]]"

# A ConfigMap that carries a plugin store would hide the volume's copy under its own.
mkdir -p "$WORK/configmap-store/ValheimWebMap"
printf 'map\n' > "$WORK/configmap-store/ValheimWebMap/history.json"
printf 'fixture pass\n' > "$WORK/password"
start_entrypoint LEMBITU_CONFIG="$WORK/configmap-store"; finish_entrypoint 5
check "a ConfigMap carrying a plugin store is refused" \
  bash -c "[[ $EP_STATUS -ne 0 && $EP_STATUS -ne 124 ]] && grep -q 'the config carries ValheimWebMap' '$WORK/stderr' && [[ ! -e '$WORK/fake/pid' ]]"

# With no EpicLoot directory in the ConfigMap, the bounty saves' parent is made for the link.
mkdir -p "$WORK/configmap-empty"
start_entrypoint LEMBITU_CONFIG="$WORK/configmap-empty"
wait_for "$WORK/fake/running" 10 || true
check "EpicLoot's bounty saves link to the volume when the ConfigMap has no EpicLoot directory" \
  bash -c "[[ \"\$(readlink '$RUNTIME/BepInEx/config/EpicLoot/BountySaves')\" == '$DATA/bepinex/EpicLoot/BountySaves' ]]"
stop_entrypoint

# --- one start, end to end ---------------------------------------------------------------------

# Leftovers of an earlier start, which the wipe must remove: a stale marker and a stale file.
mkdir -p "$WORK/run/BepInEx"
: > "$WORK/run/.steam-server-opened"
: > "$WORK/run/BepInEx/stale.txt"
bind_game_port udp6

# The port is bound and answers, but the log has said only "Game server connected".
start_entrypoint FAKE_NO_OPEN=1
wait_for "$WORK/fake/running" 10 || true
check "a stale marker from an earlier start is wiped" test ! -e "$RUNTIME/.steam-server-opened"
not_ready() { ! ready; }
check "readiness is red after \"Game server connected\" but before \"Opened Steam server\"" not_ready
check "the red check says why" grep -q 'no "Opened Steam server"' "$WORK/ready.out"
stop_entrypoint
unbind_game_port

start_entrypoint
wait_for "$WORK/fake/running" 10 || true
wait_for "$RUNTIME/.steam-server-opened" 5 || true
check "the entrypoint execs the server: one PID, no shell left between it and its signals" \
  bash -c "[[ \"\$(cat '$WORK/fake/pid')\" == $EP_PID ]]"
check "the server runs in the runtime tree" grep -qx "$RUNTIME" "$WORK/fake/cwd"

args="$(tr '\n' ' ' < "$WORK/fake/args")"
want="-nographics -batchmode -name Lembitu -port 2456 -world LembituRun -public 0 -password fixture pass -savedir $DATA/save -saveinterval 300 -modifier Combat hard -modifier DeathPenalty easy -modifier Resources default -modifier Raids less -modifier Portals hard "
check "the launch arguments are the live ones, with -public 0 and the Secret's password" \
  test "$args" == "$want"
check "the password is one argument, spaces and all" grep -qx 'fixture pass' "$WORK/fake/args"
check "the library path puts the redistributable's linux64 first, then the doorstop's libraries" \
  grep -qx "LD_LIBRARY_PATH=$RUNTIME/linux64:$RUNTIME/doorstop_libs:/store/lib" "$WORK/fake/env"
check "BepInEx's doorstop is preloaded" bash -c "grep -qx 'LD_PRELOAD=libdoorstop_x64.so' '$WORK/fake/env' \
  && grep -qx 'DOORSTOP_TARGET_ASSEMBLY=./BepInEx/core/BepInEx.Preloader.dll' '$WORK/fake/env'"

check "the stale runtime file is gone" test ! -e "$RUNTIME/BepInEx/stale.txt"
check "the game's files are links into the store" \
  bash -c "[[ -L '$RUNTIME/valheim_server.x86_64' && -L '$RUNTIME/linux64' && -L '$RUNTIME/BepInEx/core' ]]"
check "a plugin package nobody writes into stays one link" test -L "$RUNTIME/BepInEx/plugins/Jotunn"
check "SeparateSpawns' reports/ is on the volume" \
  bash -c "[[ \"\$(readlink '$RUNTIME/BepInEx/plugins/SeparateSpawns/reports')\" == '$DATA/bepinex/SeparateSpawns/reports' \
    && -d '$DATA/bepinex/SeparateSpawns/reports' && -L '$RUNTIME/BepInEx/plugins/SeparateSpawns/SeparateSpawns.dll' ]]"
check "OdinOnDemand's assetbundles/ and radio/ are real, empty, writable directories" \
  bash -c "for d in assetbundles radio; do p='$RUNTIME/BepInEx/plugins/OdinOnDemand/'\$d; \
    [[ -d \$p && ! -L \$p && -w \$p && -z \$(ls -A \$p) ]] || exit 1; done"
check "OdinOnDemand.dll is a real copy, so its Assembly.Location is in the writable tree" \
  bash -c "p='$RUNTIME/BepInEx/plugins/OdinOnDemand/OdinOnDemand.dll'; [[ -f \$p && ! -L \$p ]] \
    && cmp -s \$p '$BEPINEX/plugins/OdinOnDemand/OdinOnDemand.dll'"
check "the plugin stores in config/ link to the volume" \
  bash -c "for s in Guilds Marketplace Lembitu.Guilds ValheimWebMap EpicLoot/BountySaves; do \
    [[ \"\$(readlink '$RUNTIME/BepInEx/config/'\$s)\" == '$DATA/bepinex/'\$s && -d '$DATA/bepinex/'\$s ]] || exit 1; done"
check "EpicLoot's bounty saves link to the volume beside the ConfigMap's EpicLoot/patches" \
  bash -c "[[ -d '$RUNTIME/BepInEx/config/EpicLoot' && ! -L '$RUNTIME/BepInEx/config/EpicLoot' \
    && -f '$RUNTIME/BepInEx/config/EpicLoot/patches/lembitu.json' ]]"
check "config/ is real writable files: the seeds, then the ConfigMap over them" \
  bash -c "[[ ! -L '$RUNTIME/BepInEx/config/BepInEx.cfg' && -w '$RUNTIME/BepInEx/config/BepInEx.cfg' ]] \
    && grep -q 'Key = enforced' '$RUNTIME/BepInEx/config/BepInEx.cfg' \
    && grep -q enforced '$RUNTIME/BepInEx/config/lembitu.guilds.cfg' \
    && grep -q seed '$RUNTIME/BepInEx/config/CreatureManager/seed.yml'"
check "none of the ConfigMap's ..data plumbing is copied" \
  bash -c "[[ -z \$(find '$RUNTIME/BepInEx/config' -name '..*') ]]"

check "the stdout filter marked \"Opened Steam server\"" test -e "$RUNTIME/.steam-server-opened"
check "readiness is red with the line logged but the game port unbound" not_ready
check "the red check names the port" grep -q "UDP $GAME_PORT is not bound" "$WORK/ready.out"
bind_game_port udp6
check "readiness is green with the line, the game port bound (udp6), and a NoConnection answer" ready
check "the green check says what it saw" grep -q '^ready: "Opened Steam server", UDP' "$WORK/ready.out"
unbind_game_port; bind_game_port udp
check "readiness reads /proc/net/udp too" ready
printf 'silent\n' > "$WORK/fake-sns.mode"
check "readiness is red when the bound port doesn't answer" not_ready
check "the red check says the port didn't answer" grep -q "UDP $GAME_PORT did not answer" "$WORK/ready.out"
printf 'wrong\n' > "$WORK/fake-sns.mode"
check "readiness is red when the port answers with anything but NoConnection" not_ready
printf 'sns\n' > "$WORK/fake-sns.mode"
check "readiness is green again once the port answers" ready

stop_entrypoint
check "SIGINT to the process group reaches the server, which saves and exits 0" \
  bash -c "[[ $EP_STATUS -eq 0 && -e '$WORK/fake/saved' ]]"
check "the log keeps the lines the server wrote after the signal: the filter outlived it" \
  grep -q 'World save (5/5) done after SIGINT' "$WORK/stdout"
check "the log has the server's stdout, in order" \
  bash -c "diff <(printf 'Loading world\n10/27/2026 12:06:12: Game server connected\n10/27/2026 12:06:52: Opened Steam server\nWorld save (5/5) done after SIGINT\n') '$WORK/stdout'"
sleep 0.3
# The bracket keeps pgrep from matching its own command line.
filter_gone() { ! pgrep -f "lembitu-logmar[k] $RUNTIME/.steam-server-opened" > /dev/null; }
check "the filter exits when the server's stdout closes" filter_gone

# --- the image tier ----------------------------------------------------------------------------

if [[ "${LEMBITU_IMAGE_TEST:-}" != 1 ]]; then
  echo "skip: the image tier runs the real server; set LEMBITU_IMAGE_TEST=1 (docs/server-image.md)"
  finish; exit
fi
for tool in nix docker jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: the image tier needs $tool" >&2; exit 2; }
done
REPORT="${LEMBITU_IMAGE_REPORT:-$WORK/report}"
mkdir -p "$REPORT"
LOCK="$REPO_ROOT/docs/server-inputs.lock.json"

locked() {  # locked <command...>: under LEMBITU_BUILD_LOCK when it is set
  if [[ -n "${LEMBITU_BUILD_LOCK:-}" ]]; then flock "$LEMBITU_BUILD_LOCK" "$@"; else "$@"; fi
}
nix_out() { nix build --no-link --print-out-paths "$REPO_ROOT#$1"; }
in_nix() { nix shell --inputs-from "$REPO_ROOT" "$@"; }

# Two builds. The first realises the image; the second rebuilds every derivation the image is made
# from that is not a fixed-output fetch, and Nix refuses any whose bytes differ.
ARCHIVE="$(locked nix build --no-link --print-out-paths "$REPO_ROOT#serverImage")"
image_drv="$(nix eval --raw "$REPO_ROOT#serverImage.drvPath")"
nix derivation show -r "$image_drv" > "$WORK/drvs.json"
# Newer nix nests the map under .derivations and drops the /nix/store/ prefix; a fixed-output
# derivation's outputs carry a hash or a method.
jq -r '(.derivations // .) | to_entries[]
  | select(.value.outputs | to_entries | map(.value | has("hash") or has("method")) | any | not)
  | select(.value.name | test("^(valheim-lembitu|lembitu-|bepinexpack-valheim|stream-valheim-lembitu)"))
  | .key + "^*"' "$WORK/drvs.json" | LC_ALL=C sort > "$WORK/ours"
sed -i 's|^\([^/]\)|/nix/store/\1|' "$WORK/ours"
cp "$WORK/ours" "$REPORT/rebuilt-derivations.txt"
mapfile -t ours < "$WORK/ours"
rebuild_ok=0
if locked nix build --rebuild --no-link "${ours[@]}" > "$REPORT/rebuild.log" 2>&1; then rebuild_ok=1; fi
digest="$(in_nix nixpkgs#skopeo -c skopeo inspect --format '{{.Digest}}' "oci-archive:$ARCHIVE")"
printf '%s\n' "$digest" > "$REPORT/digest.txt"
# Nix compares each rebuilt output with the first byte for byte, so identical archives are one
# manifest digest, the one fleet-publish reads with this same skopeo inspect.
check "a second build of all ${#ours[@]} of the image's own derivations gives the same bytes, so one digest ($digest)" \
  test "$rebuild_ok" = 1
check "projectImages.\"project/valheim-lembitu/server\" is the same archive" \
  test "$(nix_out 'projectImages."project/valheim-lembitu/server"')" == "$ARCHIVE"

# Into the engine, under a tag of this run.
TAG="valheim-lembitu-server:test-$$"
echo "$TAG" >> "$WORK/images"
host_args=()
[[ -n "${DOCKER_HOST:-}" ]] && host_args=(--dest-daemon-host "$DOCKER_HOST")
in_nix nixpkgs#skopeo -c skopeo --insecure-policy copy --quiet "${host_args[@]}" \
  "oci-archive:$ARCHIVE" "docker-daemon:$TAG"

# --- the image's files ---
NAME="lembitu-image-test-$$"
echo "$NAME-files" >> "$WORK/containers"
docker create --name "$NAME-files" "$TAG" > /dev/null
ROOTFS="$WORK/rootfs"
mkdir -p "$ROOTFS"
docker export "$NAME-files" | tar -x -C "$ROOTFS" --exclude='dev/*'
game="$(nix eval --raw "$REPO_ROOT#serverImage.passthru.gameRoot")"
server_dir="$(readlink "$ROOTFS$game/valheim_server_Data")"; server_dir="${server_dir%/valheim_server_Data}"
redist_dir="$(readlink "$ROOTFS$game/linux64")"; redist_dir="${redist_dir%/linux64}"
check "the image's server and redistributable trees are the locked bytes, by the verifier" \
  bash -c "'$REPO_ROOT/scripts/verify-server-inputs.sh' --server '$ROOTFS$server_dir' --redist '$ROOTFS$redist_dir' > '$REPORT/verify.txt' 2>&1"
want_exe="$(awk '$2 == "valheim_server.x86_64" {print $1}' "$REPO_ROOT/docs/server-files.sha256")"
check "valheim_server.x86_64 is the locked file, executable (mode 0555)" \
  bash -c "[[ \$(sha256sum < '$ROOTFS$game/valheim_server.x86_64' | cut -c1-64) == $want_exe \
    && \$(stat -c %a '$ROOTFS$game/valheim_server.x86_64') == 555 ]]"
mkdir -p "$WORK/pack"
in_nix nixpkgs#unzip -c unzip -q "$(nix_out bepinexPack)" 'BepInExPack_Valheim/*' -d "$WORK/pack"
check "BepInEx's core and doorstop are the locked pack's" \
  bash -c "diff -r '$WORK/pack/BepInExPack_Valheim/BepInEx/core' '$ROOTFS$(readlink "$ROOTFS$game/BepInEx/core")' \
    && diff -r '$WORK/pack/BepInExPack_Valheim/doorstop_libs' '$ROOTFS$(readlink "$ROOTFS$game/doorstop_libs")'"
bepinex="$(nix eval --raw "$REPO_ROOT#serverImage.passthru.bepinex")"
check "the plugin tree is the deploy path's from the locked mods and our plugins" \
  bash -c "diff -r '$bepinex' '$ROOTFS$bepinex' > /dev/null"
(cd "$ROOTFS" && find . \( -type f -o -type l \) -printf '%P\t%m\t%l\n' | LC_ALL=C sort) > "$REPORT/image-files.tsv"
no_state() {
  ! awk -F'\t' '$1 ~ /\.(db|db2|fwl|fwl2)$/ || $1 ~ /(^|\/)password$/ || $1 ~ /lembitu\.guilds\.cfg$/ { found = 1 }
    END { exit !found }' "$REPORT/image-files.tsv" && [[ ! -e "$ROOTFS/data" ]]
}
check "no world, no Secret and no enforced config in the image" no_state
in_nix nixpkgs#ilspycmd -c "$REPO_ROOT/scripts/list-plugin-guids.sh" "$ROOTFS$bepinex/plugins" > "$WORK/guids.tsv"
check "the image's plugin GUIDs are the lock's serverPlugins" \
  bash -c "diff <(jq -r '.serverPlugins | (.load[] | . + \"\tload\"), (.skip | to_entries[] | .key + \"\t\" + .value)' '$LOCK' | LC_ALL=C sort) '$WORK/guids.tsv'"
# Our DLLs carry the live build's PDB path and commit stamp (the lock's `plugins`).
stamped() {
  local dll path stamp
  path="$(jq -r '.plugins.pathMap' "$LOCK")"; stamp="$(jq -r '.plugins.sourceRevisionId' "$LOCK")"
  for dll in Lembitu.Callings Lembitu.Guide Lembitu.Guilds Lembitu.Harness Lembitu.Oathbound ValheimWebMap; do
    grep -qaF "$path" "$ROOTFS$bepinex/plugins/$dll.dll" && grep -qaF "+$stamp" "$ROOTFS$bepinex/plugins/$dll.dll" || return 1
  done
}
check "our six server DLLs carry the lock's PathMap and commit stamp" stamped

# --- the server ---
VOLUME="$NAME-data"
echo "$VOLUME" >> "$WORK/volumes"
docker volume create "$VOLUME" > /dev/null
# The volume belongs to the server's uid, as the Workload's fsGroup makes it. The image has no
# chown, so a throwaway busybox does it.
docker run --rm -v "$VOLUME:/data" busybox:1.37 chown 10160:10160 /data
mkdir -p "$WORK/config"
cp -R "$REPO_ROOT/config/enforced/." "$REPO_ROOT/config/dedicated/." "$WORK/config/"
printf 'fixture pass\n' > "$WORK/secret"
chmod 0444 "$WORK/secret"; chmod -R a+rX "$WORK/config"
echo "$NAME" >> "$WORK/containers"
docker run -d --name "$NAME" --read-only \
  --tmpfs /run/lembitu:rw,exec,size=1g,mode=1777 --tmpfs /home/lembitu:rw,size=512m,mode=1777 \
  --tmpfs /tmp:rw,size=512m,mode=1777 \
  -v "$VOLUME:/data:nocopy" -v "$WORK/config:/etc/lembitu/bepinex:ro" \
  -v "$WORK/secret:/run/secrets/lembitu/password:ro" \
  "$TAG" > /dev/null

# Readiness, every 2 s from the start. Before each check the server's log is read, so a green check
# can be put after or before "Opened Steam server". The timeline goes to the report.
started=$SECONDS
first_ready="" connected_at="" opened_at="" ready_at="" early=0 gap_red=0
for ((i = 0; i < 300; i++)); do
  t=$((SECONDS - started))
  log_now="$(docker logs "$NAME" 2>/dev/null || true)"
  connected=0; opened=0
  grep -q 'Game server connected' <<< "$log_now" && connected=1
  grep -q 'Opened Steam server' <<< "$log_now" && opened=1
  [[ -z $connected_at && $connected == 1 ]] && connected_at=$t
  [[ -z $opened_at && $opened == 1 ]] && opened_at=$t
  if docker exec "$NAME" lembitu-ready > "$REPORT/ready-last.txt" 2>&1; then
    [[ -n $first_ready ]] || first_ready=green
    (( opened )) || early=$((early + 1))
    ready_at=$t
    break
  fi
  [[ -n $first_ready ]] || { first_ready=red; cp "$REPORT/ready-last.txt" "$REPORT/ready-first.txt"; }
  (( connected && ! opened )) && gap_red=$((gap_red + 1))
  [[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" == true ]] || break
  sleep 2
done
printf 'Game server connected: ~%ss\nOpened Steam server: ~%ss\nlembitu-ready green: ~%ss\nred checks between the two lines: %s\n' \
  "${connected_at:-never}" "${opened_at:-never}" "${ready_at:-never}" "$gap_red" > "$REPORT/ready-timeline.txt"
check "readiness is red right after the start" test "$first_ready" = red
check "readiness turns green (log: \"Game server connected\" ~${connected_at:-never} s, \"Opened Steam server\" ~${opened_at:-never} s; green ~${ready_at:-never} s)" \
  test -n "$ready_at"
check "readiness never turned green before the log said \"Opened Steam server\"" test "$early" = 0
check "readiness stayed red between \"Game server connected\" and \"Opened Steam server\" ($gap_red checks)" \
  test "$gap_red" -gt 0
lines_before="$(docker logs "$NAME" 2>&1 | wc -l)"
for ((i = 0; i < 10; i++)); do docker exec "$NAME" lembitu-ready > /dev/null 2>&1 || true; done
printf 'server log lines added by ten more readiness checks: %s\n' \
  "$(( $(docker logs "$NAME" 2>&1 | wc -l) - lines_before ))" >> "$REPORT/ready-timeline.txt"
docker exec "$NAME" lembitu-a2s > "$REPORT/a2s.txt" 2>&1 || true

docker exec "$NAME" cat /run/lembitu/BepInEx/LogOutput.log > "$REPORT/LogOutput.log"
loaded="$(grep -oP '^\[Info   :   BepInEx\] Loading \[.*\] \(\K[^)]+(?=\)$)' "$REPORT/LogOutput.log" | LC_ALL=C sort)"
skipped="$(grep -oP '^\[Warning:   BepInEx\] Skipping \[.*\] \(\K[^)]+(?=\))' "$REPORT/LogOutput.log" | LC_ALL=C sort)"
check "the chainloader loads exactly the lock's plugin GUIDs" \
  test "$loaded" == "$(jq -r '.serverPlugins.load[]' "$LOCK" | LC_ALL=C sort)"
check "it skips only the lock's process-filter skips" \
  test "$skipped" == "$(jq -r '.serverPlugins.skip | keys[]' "$LOCK" | LC_ALL=C sort)"
counts="$(jq -r '"(\(.serverPlugins.load | length) loaded, \(.serverPlugins.skip | length) skipped, 0 failed)"' "$LOCK")"
check "Chainloader startup complete $counts" grep -qF "Chainloader startup complete $counts" "$REPORT/LogOutput.log"
check "nothing tried to write the read-only image" \
  bash -c "! docker logs '$NAME' 2>&1 | grep -q 'Read-only file system'"
docker top "$NAME" -o pid,ppid,args > "$REPORT/processes.txt"
check "the processes are dumb-init, the server and the log filter, nothing else" \
  bash -c "[[ \$(tail -n +2 '$REPORT/processes.txt' | grep -cvE 'dumb-init|valheim_server.x86_64|lembitu-logmark') -eq 0 ]]"

# Every path the server wrote, for docs/server-image.md's list.
docker exec "$NAME" ls -lAR /run/lembitu /home/lembitu /tmp /data > "$REPORT/written.txt" 2>&1 || true

# --- SIGTERM ---
world=/data/save/worlds_local/LembituRun
before="$(docker exec "$NAME" ls "$world" 2>/dev/null | grep -oP '^_main\.\K[0-9]+(?=\.fwl2$)' | sort -n | tail -1 || true)"
stop_started=$(date +%s)
docker stop -t 180 "$NAME" > /dev/null
stop_took=$(( $(date +%s) - stop_started ))
exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$NAME")"
docker logs "$NAME" > "$REPORT/server.log" 2>&1
check "SIGTERM: the server exits 0 within 180 s (took ${stop_took} s)" \
  bash -c "[[ $exit_code -eq 0 && $stop_took -le 180 ]]"
check "SIGTERM: the log shows a complete world save" grep -q 'World save (5/5) done' "$REPORT/server.log"
docker run --rm -v "$VOLUME:/data:ro" busybox:1.37 ls "$world" > "$REPORT/world-after.txt" 2>&1 || true
after="$(grep -oP '_main\.\K[0-9]+(?=\.fwl2$)' "$REPORT/world-after.txt" | sort -n | tail -1 || true)"
check "SIGTERM: a fresh .db2 and .fwl2 generation (${before:-none} -> ${after:-none})" \
  bash -c "[[ -n '$after' && ( -z '$before' || $after -gt ${before:-0} ) ]] \
    && grep -q '_main\.$after\.db2$' '$REPORT/world-after.txt' && grep -q '_main\.$after\.fwl2$' '$REPORT/world-after.txt'"

finish
