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
DEPLOY_ENV=${DEPLOY_ENV:-$HOME/.config/lembitu/deploy.env}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/launch-server.sh env | run | start | restart | stop | tunnel | world-rules

  env          print the container environment, secret file merged in
  run          create the data directories and start the container
  start        apply the overlay, start an existing stopped container and verify
  restart      warn, save, confirm, stop, apply the overlay, start and verify
  stop         warn at 10/5/1 minutes, save and confirm before stopping
  tunnel       (re)create the Cloudflare Tunnel container that publishes the web map
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
  enforce_servermanager

  docker run -d --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --cpu-shares 4096 --memory-reservation 4g --stop-timeout 120 \
    -v "$REPO_ROOT/scripts/frozen-valheim-start.sh:/usr/local/bin/valheim-updater:ro" \
    -v "$CONFIG_DIR:/config" \
    -v "$DATA_DIR:/opt/valheim" \
    -p "$port:$port/udp" \
    -p "$((port + 1)):$((port + 1))/udp" \
    -p "127.0.0.1:3000:3000/tcp" \
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

# Stop, apply, start, verify — in that order, because the order is the whole point.
#
# Applying the overlay to a *running* server is what produced the 2026-09-16 revert. The mods
# watch their own files: EpicLoot logged `Config file ... changed on disk, reloading it` the
# moment the applier touched it, and the ServerSync-locked mods answered a mid-session edit by
# writing their in-memory values back over it. The disk then held the mod's defaults and the
# operator's apply had been undone within seconds, silently. A stopped container has nothing
# holding those files, so the values the applier writes are the values the mods read at boot.
do_restart() {
  command -v docker >/dev/null 2>&1 || die "docker is not available"
  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 \
    || die "no container named $CONTAINER_NAME; create it with: scripts/launch-server.sh run"

  if [[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME")" == true ]]; then
    do_stop
  fi
  do_start
}

do_start() {
  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || die "no container named $CONTAINER_NAME"
  [[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER_NAME")" != true ]] \
    || die "container is running; use restart for a maintenance restart"
  local state="$HOME/.local/state/lembitu"
  mkdir -p "$state"
  printf '%s\n' "$(( $(date +%s) + 1800 ))" > "$state/maintenance-until"

  enforce_config "$CONFIG_DIR/bepinex"
  enforce_servermanager

  # Everything after this second is this boot. The log carries every previous boot, and with
  # `AppendLog = true` so does the file, so an unscoped search would match a banner from last week.
  # The stamp spells its zone out: `docker logs --since` reads one without a zone as local time,
  # so a bare UTC stamp on a UTC+3 host looks three hours old and matches an earlier boot.
  local since; since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  docker start "$CONTAINER_NAME" >/dev/null
  printf 'started %s; waiting for the chainloader\n' "$CONTAINER_NAME"

  wait_for_chainloader "${CHAINLOADER_TIMEOUT:-300}" "$since" \
    || die "no 'Chainloader startup complete' within ${CHAINLOADER_TIMEOUT:-300}s; read docker logs $CONTAINER_NAME"
  "$REPO_ROOT/scripts/verify-enforced-config.sh" "$CONFIG_DIR/bepinex" \
    || die "the server booted with a drifted config; the keys above are not in effect"
  rm -f "$state/maintenance-until"
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

# ServerManager's policy (ADR-0034, #102) is generated from the approved Pack and checked before
# every start, for the same reason as the overlay above. Its YAML and reference DLLs live in the
# save directory, where verify-enforced-config.sh never looks, so the check happens here instead.
# The Pack, not the server's plugin tree, is the source: client-only mods such as Tally must be
# required of players without being installed on the server.
#
# Two host settings drive it, from the environment or from DEPLOY_ENV (plain KEY=value lines,
# never sourced): LEMBITU_PACK_ROOT, the unpacked approved Pack; and
# LEMBITU_LOAD_SERVER_CHARACTER, false while existing characters enrol, true after.
enforce_servermanager() {
  if [[ -z "$(find "$CONFIG_DIR/bepinex/plugins" -name ServerManager.dll -print -quit 2>/dev/null)" ]]; then
    printf 'ServerManager is not installed; no character-store policy to apply\n'
    return 0
  fi
  local pack=${LEMBITU_PACK_ROOT:-$(deploy_value LEMBITU_PACK_ROOT)}
  local load=${LEMBITU_LOAD_SERVER_CHARACTER:-$(deploy_value LEMBITU_LOAD_SERVER_CHARACTER)}
  [[ -n "$pack" ]] || die "LEMBITU_PACK_ROOT is unset; set it in $DEPLOY_ENV to the unpacked approved Pack"
  [[ "$load" == true || "$load" == false ]] \
    || die "LEMBITU_LOAD_SERVER_CHARACTER must be true or false in $DEPLOY_ENV (false while characters enrol)"
  local -a args=(--pack "$pack" --store "$CONFIG_DIR/save/ServerManager" --load-server-character "$load")
  "$REPO_ROOT/scripts/servermanager-policy.sh" apply "${args[@]}"
  "$REPO_ROOT/scripts/servermanager-policy.sh" check "${args[@]}" \
    || die "ServerManager's policy does not match the Pack; the server was not started"
}

deploy_value() {  # deploy_value <key>
  [[ -f "$DEPLOY_ENV" ]] || return 0
  grep -E "^$1=" "$DEPLOY_ENV" | tail -n 1 | cut -d= -f2-
}

# Block until the chainloader reports it has finished, so the mods have written whatever they were
# going to write. A boot that never gets there is its own failure and is named as one.
#
# `grep -q` stops reading at the first match, which sends SIGPIPE to `docker logs`; under
# `pipefail` that exit status 141 would make a *successful* match read as a failure, and a real
# boot writes far more than a pipe buffer after the banner. The subshell turns pipefail off for
# this one pipeline so the match is what decides.
wait_for_chainloader() {  # wait_for_chainloader <seconds> [since]
  local deadline=$(( SECONDS + $1 ))
  # `scope` stays empty for a freshly created container, whose log holds one boot anyway. The
  # guarded expansion is for bash 3.2, where `set -u` rejects an empty array under `"${a[@]}"`.
  local -a scope=()
  if [[ $# -ge 2 && -n "${2:-}" ]]; then scope=(--since "$2"); fi
  while (( SECONDS < deadline )); do
    if ( set +o pipefail; docker logs ${scope[@]+"${scope[@]}"} "$CONTAINER_NAME" 2>&1 | grep -qa 'Chainloader startup complete' ); then
      return 0
    fi
    sleep 5
  done
  return 1
}

do_stop() {
  # shellcheck source=lib/python.sh
  . "$REPO_ROOT/scripts/lib/python.sh"
  run_python "$REPO_ROOT/scripts/maintenance-restart.py" "$CONTAINER_NAME" "$CONFIG_DIR"
}

# The web map reaches the internet only through a Cloudflare Tunnel (docs/wiki/operations.md): this
# container dials out to Cloudflare and forwards lembitu-map.astral.ee to the map on 127.0.0.1:3000,
# so no router port opens. Host networking is what lets it reach that loopback-only port. The
# tunnel's routes live in Cloudflare (scripts/wizard-cloudflare.sh); its token stays in a private
# file on the host and enters the container as an environment file, never an argument.
TUNNEL_CONTAINER=${TUNNEL_CONTAINER:-lembitu-tunnel}
TUNNEL_IMAGE=${TUNNEL_IMAGE:-cloudflare/cloudflared:2026.10.0}
TUNNEL_ENV=${TUNNEL_ENV:-$HOME/.config/lembitu/cloudflared.env}
do_tunnel() {
  command -v docker >/dev/null 2>&1 || die "docker is not available"
  [[ -f "$TUNNEL_ENV" ]] || die "no $TUNNEL_ENV; run scripts/wizard-cloudflare.sh on the Mac first"
  grep -q '^TUNNEL_TOKEN=.' "$TUNNEL_ENV" || die "$TUNNEL_ENV has no TUNNEL_TOKEN"
  if docker inspect "$TUNNEL_CONTAINER" >/dev/null 2>&1; then
    docker rm -f "$TUNNEL_CONTAINER" >/dev/null
  fi
  docker run -d --name "$TUNNEL_CONTAINER" --restart unless-stopped --network host \
    --env-file "$TUNNEL_ENV" "$TUNNEL_IMAGE" tunnel --no-autoupdate run >/dev/null
  printf 'started %s (%s)\n' "$TUNNEL_CONTAINER" "$TUNNEL_IMAGE"
}

case "${1:-}" in
  env) do_env ;;
  run) do_run ;;
  restart) do_restart ;;
  start) do_start ;;
  stop) do_stop ;;
  tunnel) do_tunnel ;;
  world-rules) world_rules ;;
  -h|--help) usage; exit 0 ;;
  *) usage; exit 1 ;;
esac
