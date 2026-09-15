#!/usr/bin/env bash
# Start (or re-create) the launch server from config/launch (#19).
#
#   scripts/launch-server.sh env          print the container environment, secret file merged in
#   scripts/launch-server.sh run          create the data directories and start the container
#   scripts/launch-server.sh world-rules  print the world-rule arguments alone
#
# The launch configuration lives in config/launch/launch.env.example (committed, non-secret) and
# config/launch/launch.secret.env (gitignored: SERVER_PASS, and later the Discord webhook).
#
# This script owns the *container invocation*, not the server's contents. The Pack is deployed from
# this repository with scripts/install-plugins.sh, and the enforced overlay with
# scripts/apply-enforced-config.sh; neither happens here. See docs/wiki/operations.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCH_ENV="$REPO_ROOT/config/launch/launch.env.example"
SECRET_ENV="$REPO_ROOT/config/launch/launch.secret.env"

CONTAINER_NAME=${CONTAINER_NAME:-lembitu}
IMAGE=${IMAGE:-ghcr.io/community-valheim-tools/valheim-server:latest}
DATA_ROOT=${DATA_ROOT:-$HOME/lembitu}
CONFIG_DIR="$DATA_ROOT/config"
DATA_DIR="$DATA_ROOT/data"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f "$LAUNCH_ENV" ]] || die "no launch configuration at $LAUNCH_ENV"

# Read `KEY=value` lines, ignoring comments and blanks. Values may contain spaces (SERVER_ARGS), so
# the split is on the first `=` only.
read_env() {  # read_env <file>
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true
}

load_env() {
  local line key value
  while IFS= read -r line; do
    key=${line%%=*}
    value=${line#*=}
    printf '%s\n' "$key=$value"
  done < <(read_env "$LAUNCH_ENV")
  [[ -f "$SECRET_ENV" ]] && read_env "$SECRET_ENV"
}

world_rules() {
  # The world-rule arguments as the game's own parser expects them. SERVER_ARGS carries them
  # alongside -savedir; they are printed separately so the rule set can be reviewed on its own.
  local args
  args="$(read_env "$LAUNCH_ENV" | sed -n 's/^SERVER_ARGS=//p')"
  [[ -n "$args" ]] || die "SERVER_ARGS is empty in $LAUNCH_ENV"
  printf '%s\n' "${args#-savedir /config/save }"
}

do_env() {
  [[ -f "$SECRET_ENV" ]] || printf 'warning: %s is absent; SERVER_PASS is unset and the server will refuse to start\n' "$SECRET_ENV" >&2
  load_env
}

do_run() {
  command -v docker >/dev/null 2>&1 || die "docker is not available"
  [[ -f "$SECRET_ENV" ]] || die "no $SECRET_ENV; copy the shape from the example and put SERVER_PASS in it"

  mkdir -p "$CONFIG_DIR" "$DATA_DIR"
  # The container writes as PUID:PGID; the bind mounts must be writable by that user.
  local puid pgid
  puid="$(read_env "$LAUNCH_ENV" | sed -n 's/^PUID=//p')"
  pgid="$(read_env "$LAUNCH_ENV" | sed -n 's/^PGID=//p')"

  local -a env_args=()
  local line
  while IFS= read -r line; do env_args+=(-e "$line"); done < <(load_env)

  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    printf 'error: container %s already exists. Stop and remove it first:\n  docker rm -f %s\n' \
      "$CONTAINER_NAME" "$CONTAINER_NAME" >&2
    exit 1
  fi

  docker run -d --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -v "$CONFIG_DIR:/config" \
    -v "$DATA_DIR:/opt/valheim" \
    -p "${SERVER_PORT:-2456}:2456/udp" \
    -p "$(( ${SERVER_PORT:-2456} + 1 )):2457/udp" \
    "${env_args[@]}" \
    "$IMAGE" >/dev/null

  printf 'started %s\n' "$CONTAINER_NAME"
  printf '  config: %s -> /config\n' "$CONFIG_DIR"
  printf '  data:   %s -> /opt/valheim\n' "$DATA_DIR"
  printf '  logs:   docker logs -f %s\n' "$CONTAINER_NAME"
  printf 'next: deploy the pack with scripts/install-plugins.sh %s/config/bepinex\n' "$CONFIG_DIR"
}

case "${1:-}" in
  env) do_env ;;
  run) do_run ;;
  world-rules) world_rules ;;
  *) die "usage: scripts/launch-server.sh env | run | world-rules" ;;
esac
