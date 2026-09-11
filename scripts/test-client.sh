#!/usr/bin/env bash
# Run a real Valheim 1.0.7 game client with our pack loaded, driven by the harness plugin, so the
# playtest criteria that need a client (#10) can be checked without a human at a keyboard.
#
#   scripts/test-client.sh install                  BepInEx and the built plugins into the client
#   scripts/test-client.sh run                       join 127.0.0.1:2466 as the harness character
#   scripts/test-client.sh run 10.0.0.5:2466 secret  join elsewhere, with a password
#   scripts/test-client.sh shot                      screenshot the virtual display
#   scripts/test-client.sh stop                      stop the client
#
# Requires an x86_64 Linux host with a GPU (astral-bicep, astral-tricep) and, unlike the dedicated
# server, a **Steam client logged into an account that owns Valheim**: the game is not free, so
# DepotDownloader cannot fetch it anonymously, and Steamworks refuses to initialise unless a logged
# in Steam client is running. Install the game once through that Steam client; this script only
# adds BepInEx and our plugins on top of it.
#
# The client runs against a virtual X display, so no monitor and no desktop session is needed.
# Xvfb alone is not enough: without a window manager the game cannot be focused and input never
# reaches it, so a minimal one is started too.
#
# Environment:
#   VALHEIM_CLIENT_DIR  game files (default: the Steam library copy under ~/.local/share/Steam)
#   LEMBITU_DISPLAY     X display to use (default :7)
#   LEMBITU_CHARACTER   character name the harness creates and plays (default harness)

set -euo pipefail

VALHEIM_CLIENT_APPID="892970"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_DIR="${VALHEIM_CLIENT_DIR:-$HOME/.local/share/Steam/steamapps/common/Valheim}"
PACK_DIR="$REPO_ROOT/lib/bepinex/pack/BepInExPack_Valheim"
DISPLAY_ID="${LEMBITU_DISPLAY:-:0}"
CHARACTER="${LEMBITU_CHARACTER:-harness}"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/lembitu-client"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

require_client() {
  [[ -x "$CLIENT_DIR/valheim.x86_64" ]] || die "no game client in $CLIENT_DIR
Install it once through the Steam client on this host (it owns the licence; DepotDownloader cannot
fetch a paid app anonymously):
  DISPLAY=$DISPLAY_ID steam steam://install/$VALHEIM_CLIENT_APPID"
}

# The game talks to a running Steam client over IPC; without one Steamworks fails to initialise and
# the client quits at the splash screen.
require_steam() {
  pgrep -f 'ubuntu12_32/steam' >/dev/null \
    || die "no Steam client running on this host; start one on $DISPLAY_ID first:
  DISPLAY=$DISPLAY_ID steam -silent"
}

do_install() {
  require_client
  [[ -d "$PACK_DIR" ]] || die "no BepInEx pack in $PACK_DIR; run scripts/extract-refs.sh"

  # The same pack the server runs, but its client half: the doorstop launcher for the game binary.
  cp -R "$PACK_DIR/BepInEx" "$CLIENT_DIR/"
  cp -R "$PACK_DIR/doorstop_libs" "$CLIENT_DIR/"
  cp "$PACK_DIR/doorstop_config.ini" "$PACK_DIR/.doorstop_version" "$CLIENT_DIR/"
  cp "$PACK_DIR/start_game_bepinex.sh" "$CLIENT_DIR/"
  chmod +x "$CLIENT_DIR/start_game_bepinex.sh"

  # A plain glob, not compgen: nix develop's bash refuses the builtin.
  set -- "$REPO_ROOT"/dist/plugins/*
  [[ -e "$1" ]] || die "nothing in dist/plugins; run 'dotnet build' and 'scripts/stage-stack.sh' first"
  "$REPO_ROOT/scripts/install-plugins.sh" "$CLIENT_DIR/BepInEx"
  echo "client ready in $CLIENT_DIR"
}

# A GPU-backed display, because a software-rendered client is not merely slow: it stalls its main
# thread for minutes loading this pack, the server sees "ZRpc timeout detected" thirty seconds
# after the handshake, and the peer is dropped before it ever spawns. Xvfb cannot help — it has no
# DRI3, so Vulkan cannot present on it, and OpenGL renders nothing because Valheim's Linux build
# ships Vulkan shaders only. Weston's headless backend with the GL renderer drives the real
# Radeon through /dev/dri/renderD128 and hands the game an Xwayland display.
ensure_display() {
  mkdir -p "$RUN_DIR"
  if xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then
    return
  fi

  command -v weston >/dev/null || die "weston is not installed; it provides the GPU-backed display:
  nix shell nixpkgs#weston --command weston --backend=headless --renderer=gl --xwayland"
  [[ -c /dev/dri/renderD128 ]] || die "no render node at /dev/dri/renderD128; this host has no usable GPU"

  echo "starting weston on $DISPLAY_ID" >&2
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    weston --backend=headless --renderer=gl --xwayland \
           --width=1600 --height=900 --socket=lembitu >"$RUN_DIR/weston.log" 2>&1 &
  for _ in $(seq 30); do
    xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1 && return
    sleep 1
  done
  die "no display on $DISPLAY_ID; see $RUN_DIR/weston.log"
}

do_run() {
  require_client
  require_steam
  ensure_display

  local server="${1:-127.0.0.1:2466}" password="${2:-lembitutest}"

  cd "$CLIENT_DIR"
  export DISPLAY="$DISPLAY_ID"
  export SteamAppId="$VALHEIM_CLIENT_APPID"

  # Two wrappers, both load-bearing. The pack's launcher exports the doorstop variables and
  # preloads the injector, so BepInEx's interface stays its own business. steam-run supplies the
  # FHS library tree the Unity player expects: launched bare on NixOS it finds no libX11 at all,
  # reports "the selected window backend is (null)" and dies with "no available video device".
  local runtime=()
  command -v steam-run >/dev/null && runtime=(steam-run)

  echo "joining $server as '$CHARACTER' on $DISPLAY_ID" >&2
  exec "${runtime[@]}" ./start_game_bepinex.sh \
    -screen-width 1600 -screen-height 900 -screen-fullscreen 0 \
    -lembitu-harness \
    -lembitu-server "$server" \
    -lembitu-password "$password" \
    -lembitu-character "$CHARACTER"
}

do_shot() {
  local out="${1:-$RUN_DIR/client-$(date +%H%M%S).png}"
  mkdir -p "$(dirname "$out")"
  DISPLAY="$DISPLAY_ID" import -window root "$out"
  printf '%s\n' "$out"
}

do_stop() {
  pkill -f 'valheim\.x86_64' || true
  echo "client stopped"
}

case "${1:-}" in
  install) [[ $# -eq 1 ]] || die "install takes no arguments"; do_install ;;
  run)     shift; do_run "$@" ;;
  shot)    shift; do_shot "$@" ;;
  stop)    do_stop ;;
  *) die "usage: scripts/test-client.sh install | run [host:port [password]] | shot [file] | stop" ;;
esac
