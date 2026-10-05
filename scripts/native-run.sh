#!/usr/bin/env bash
# Run one native session on the Linux test host, holding the host-wide lock the whole time.
#
#   scripts/native-run.sh <scenario.py> [scenario args...]
#   nix shell nixpkgs#python3 nixpkgs#xorg.xdpyinfo --command bash \
#       scripts/native-run.sh scripts/native-demo.py
#
# The lock makes "only one native session at a time on this host" a property of the host, not of
# who remembers to coordinate. The Mac side pushes the tree to ~/lembitu-stage first (rsync does
# not need the lock: nothing native reads that directory), and this script pulls it into
# ~/lembitu-work under the lock, so a running session can never see a half-updated tree:
#
#   rsync -a --delete --exclude dist-client --exclude '**/bin/' --exclude '**/obj/' \
#         --exclude .git ./ astral-tricep:lembitu-stage/
#   ssh astral-tricep nix shell nixpkgs#python3 nixpkgs#xorg.xdpyinfo -c \
#       bash lembitu-work/scripts/native-run.sh lembitu-work/scripts/native-demo.py
#
# The display is the other shared resource. If the configured display has no X server, one
# Weston headless session is started (GPU renderer, fake seat, Xwayland) and left running; it is
# host infrastructure, not session-owned, so it is never killed here.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE_DIR="${LEMBITU_STAGE_DIR:-$HOME/lembitu-stage}"
WORK_DIR="${LEMBITU_WORK_DIR:-$HOME/lembitu-work}"
DISPLAY_ID="${LEMBITU_DISPLAY:-:0}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ $# -ge 1 ]] || die "usage: scripts/native-run.sh <scenario.py> [args...]"
SCENARIO="$1"
shift
case "$SCENARIO" in
  # A stage-prefixed scenario path names the same file inside the synced work tree.
  "$STAGE_DIR"/*) SCENARIO="$WORK_DIR${SCENARIO#"$STAGE_DIR"}" ;;
  lembitu-stage/*) SCENARIO="$WORK_DIR/${SCENARIO#lembitu-stage/}" ;;
esac

# Tools the session and the runner need on PATH: the runner checks the display, python3 runs the
# scenario, and the client env gets xdotool for real OS key input when this directory carries it.
# Provisioned before the lock: a first nix build must not hold the host-wide lock.
TOOLS_DIR="$HOME/.cache/valheim-lembitu/tools/bin"
mkdir -p "$TOOLS_DIR"
if ! command -v xdotool >/dev/null 2>&1 && [[ ! -e "$TOOLS_DIR/xdotool" ]]; then
  if store="$(nix build nixpkgs#xdotool --print-out-paths 2>/dev/null)" && [[ -x "$store/bin/xdotool" ]]; then
    ln -sfn "$store/bin/xdotool" "$TOOLS_DIR/xdotool"
  else
    printf 'warning: xdotool unavailable; the key action falls back to InputSystem events\n' >&2
  fi
fi
export PATH="$TOOLS_DIR:$PATH"
export LEMBITU_CLIENT_DIR="${LEMBITU_CLIENT_DIR:-/games/SteamLibrary/steamapps/common/Valheim}"

# --- the lock -----------------------------------------------------------------------------------
exec 9>"$HOME/lembitu-native.lock"
flock 9

# --- the tree -----------------------------------------------------------------------------------
# Running from the staged copy is the managed flow: sync stage -> work under the lock. Running
# from the work tree itself means that checkout owns its code; never overwrite it.
RUNNING_FROM_STAGE=1
case "$REPO_ROOT" in
  "$WORK_DIR"/*) RUNNING_FROM_STAGE=0 ;;
esac
if [[ "$RUNNING_FROM_STAGE" == 1 && -d "$STAGE_DIR" ]]; then
  rsync -a --delete --exclude dist-client --exclude '**/bin/' --exclude '**/obj/' \
        --exclude .git "$STAGE_DIR/" "$WORK_DIR/"
fi
cd "$WORK_DIR"

# --- the display --------------------------------------------------------------------------------
# A real desktop session's X server (or a leftover headless weston) may hold the display but
# require its own Xauthority file; sessions and the game both inherit whatever we export here.
if ! xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then
  for auth in /run/user/"$(id -u)"/xauth_*; do
    [[ -f "$auth" ]] || continue
    if XAUTHORITY="$auth" xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then
      export XAUTHORITY="$auth"
      break
    fi
  done
fi
if ! xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1; then
  RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/lembitu-client"
  mkdir -p "$RUN_DIR" "$HOME/lembitu-native-tests"
  # A dead X server leaves its socket behind, and Xwayland then takes the NEXT display number,
  # which no session would find. Remove the stale socket only when no X server process holds it.
  X_NUM="${DISPLAY_ID#:}"
  if ! pgrep -f "(Xwayland|Xorg).*(:${X_NUM})( |$)" >/dev/null 2>&1; then
    rm -f "/tmp/.X11-unix/X${X_NUM}" "/tmp/.X11-unix/X${X_NUM}-lock"
  fi
  command -v weston >/dev/null 2>&1 || weston_on_path="$(nix build nixpkgs#weston --print-out-paths 2>/dev/null)/bin"
  if [[ -n "${weston_on_path:-}" ]]; then
    PATH="$weston_on_path:$PATH"
  fi
  command -v weston >/dev/null 2>&1 || die "weston is not available; run: nix shell nixpkgs#weston --command weston --backend=headless --renderer=gl --fake-seat --xwayland"
  [[ -c /dev/dri/renderD128 ]] || die "no render node at /dev/dri/renderD128; this host has no usable GPU"
  echo "starting weston on $DISPLAY_ID" >&2
  # 9>&-: weston outlives this run by design, and an inherited lock descriptor would hold the
  # host lock for as long as weston lives (observed 2026-10-05: every queued session waited on it).
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    setsid weston --backend=headless --renderer=gl --fake-seat --xwayland \
           --width=1600 --height=900 --socket=lembitu \
           >"$HOME/lembitu-native-tests/weston.log" 2>&1 9>&- &
  for _ in $(seq 60); do
    xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1 && break
    sleep 1
  done
  xdpyinfo -display "$DISPLAY_ID" >/dev/null 2>&1 || die "no display on $DISPLAY_ID; see $HOME/lembitu-native-tests/weston.log"
fi

exec python3 "$SCENARIO" "$@"
