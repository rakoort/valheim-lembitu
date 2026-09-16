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
# This script owns the *container invocation* and the enforced overlay around it: the overlay is
# applied before the container starts and verified once the chainloader reports it is done, so a
# drifted server is never left running (ADR-0011, #69). The Pack itself is deployed separately,
# with scripts/install-plugins.sh. See docs/wiki/operations.md.

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

usage() {
  cat >&2 <<'EOF'
usage: scripts/launch-server.sh env | run | world-rules

  env          print the container environment, secret file merged in
  run          create the data directories and start the container
  world-rules  print the world-rule arguments alone

Reads config/launch/launch.env.example (committed, non-secret) and, for the password,
config/launch/launch.secret.env (gitignored). See docs/wiki/operations.md.
EOF
}

[[ -f "$LAUNCH_ENV" ]] || die "no launch configuration at $LAUNCH_ENV"

# Read `KEY=value` lines, ignoring comments and blanks. Values may contain spaces (SERVER_ARGS).
read_env() {  # read_env <file>
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null || true
}

# One value out of the launch configuration. Anything a container variable must have - the port,
# the user ids - is read from the file, never from the caller's shell, or the file stops being the
# description of the server that docs/wiki/operations.md says it is.
env_value() {  # env_value <key>
  local line
  line="$(read_env "$LAUNCH_ENV" | sed -n "s/^$1=//p" | head -1)"
  [[ -n "$line" ]] || die "$1 is not set in $LAUNCH_ENV"
  printf '%s\n' "$line"
}

load_env() {
  read_env "$LAUNCH_ENV"
  [[ -f "$SECRET_ENV" ]] && read_env "$SECRET_ENV"
  return 0
}

world_rules() {
  # The world-rule arguments as the game's own parser expects them. SERVER_ARGS carries them
  # alongside -savedir; they are printed separately so the rule set can be reviewed on its own.
  local args
  args="$(env_value SERVER_ARGS)"
  printf '%s\n' "${args#-savedir /config/save }"
}

do_env() {
  [[ -f "$SECRET_ENV" ]] || printf 'warning: %s is absent; SERVER_PASS is unset and the server will refuse to start\n' "$SECRET_ENV" >&2
  load_env
}

do_run() {
  command -v docker >/dev/null 2>&1 || die "docker is not available"
  [[ -f "$SECRET_ENV" ]] || die "no $SECRET_ENV; copy the shape from the example and put SERVER_PASS in it"

  local port; port="$(env_value SERVER_PORT)"
  local puid; puid="$(env_value PUID)"
  local pgid; pgid="$(env_value PGID)"

  mkdir -p "$CONFIG_DIR" "$DATA_DIR"
  # The container writes as PUID:PGID; the bind mounts must be writable by that user.
  chown -R "$puid:$pgid" "$DATA_ROOT" 2>/dev/null || true

  local -a env_args=()
  local line
  while IFS= read -r line; do env_args+=(-e "$line"); done < <(load_env)

  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    printf 'error: container %s already exists. Stop and remove it first:\n  docker rm -f %s\n' \
      "$CONTAINER_NAME" "$CONTAINER_NAME" >&2
    exit 1
  fi

  enforce_config "$CONFIG_DIR/bepinex"

  docker run -d --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -v "$CONFIG_DIR:/config" \
    -v "$DATA_DIR:/opt/valheim" \
    -p "$port:$port/udp" \
    -p "$((port + 1)):$((port + 1))/udp" \
    "${env_args[@]}" \
    "$IMAGE" >/dev/null

  printf 'started %s on UDP %s-%s\n' "$CONTAINER_NAME" "$port" "$((port + 1))"
  printf '  config: %s -> /config\n' "$CONFIG_DIR"
  printf '  data:   %s -> /opt/valheim\n' "$DATA_DIR"
  printf '  logs:   docker logs -f %s\n' "$CONTAINER_NAME"

  # A drifted server that is up and accepting players is the failure this refuses to leave
  # behind, so the exit status carries it even though the container is already running.
  if compgen -G "$CONFIG_DIR/bepinex/*.cfg" > /dev/null; then
    wait_for_chainloader "${CHAINLOADER_TIMEOUT:-300}" \
      || die "no 'Chainloader startup complete' within ${CHAINLOADER_TIMEOUT:-300}s; read docker logs $CONTAINER_NAME"
    "$REPO_ROOT/scripts/verify-enforced-config.sh" "$CONFIG_DIR/bepinex" \
      || die "the server booted with a drifted config; the keys above are not in effect"
  fi

  printf 'next: deploy the pack with scripts/install-plugins.sh %s/bepinex\n' "$CONFIG_DIR"
}

# The enforced overlay is re-applied on every start and proved afterwards (ADR-0011, #69).
#
# Both halves have to be here rather than in the operator's hands, because the thing that went
# wrong on 2026-09-16 was a human step that happened once: the overlay was applied at deploy
# time, ten keys were back at mod defaults by the next evening, and nothing had ever compared the
# two. Applying without verifying would repeat exactly that.
#
# The verify waits for the chainloader, because the boot is when the mods rewrite their own
# configuration files. Checking before that races the very rewrite the check exists to catch.
enforce_config() {  # enforce_config <bepinex-config-dir>
  local bepinex=$1

  # A world that has never booted has no generated configuration to merge into, and the applier
  # rightly refuses to write files no mod reads. That is a first boot, not a drifted server.
  if ! compgen -G "$bepinex/*.cfg" > /dev/null; then
    printf 'no generated config in %s yet; this is a first boot\n' "$bepinex"
    printf '  after it settles: scripts/apply-enforced-config.sh %s\n' "$bepinex"
    return 0
  fi

  "$REPO_ROOT/scripts/apply-enforced-config.sh" "$bepinex"
}

# Block until the chainloader reports it has finished, so the mods have written whatever they were
# going to write. A boot that never gets there is its own failure and is named as one.
#
# `grep -q` stops reading at the first match, which sends SIGPIPE to `docker logs`; under
# `pipefail` that exit status 141 would make a *successful* match read as a failure, and a real
# boot writes far more than a pipe buffer after the banner. The subshell turns pipefail off for
# this one pipeline so the match is what decides.
wait_for_chainloader() {  # wait_for_chainloader <seconds>
  local deadline=$(( SECONDS + $1 ))
  while (( SECONDS < deadline )); do
    if ( set +o pipefail; docker logs "$CONTAINER_NAME" 2>&1 | grep -qa 'Chainloader startup complete' ); then
      return 0
    fi
    sleep 5
  done
  return 1
}

case "${1:-}" in
  env) do_env ;;
  run) do_run ;;
  world-rules) world_rules ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 1 ;;
esac
