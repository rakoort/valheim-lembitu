#!/usr/bin/env bash
# Capture one consistent set of the server's live save stores (#20).
#
#   scripts/backup-world.sh --savedir <dir> --out <dir> [--world <name>] [--keep <n>] [--offhost <spec>]
#
# The measured pack writes per-world directories, not flat files: a world is
# `worlds_local/<World>/_main.<n>.fwl2` with `.db2`, `.chunks`, `.chunk` siblings and an `.ok`
# marker written last. A `*.fwl`/`*.db` glob therefore captures nothing on Valheim 1.0 and is not
# used here. The stores below were enumerated from a real pack boot
# (`~/.cache/valheim-lembitu/ticket-66-20260915/*-saves/`) and from the live server's save tree.
#
# What is captured, and who owns it (see docs/wiki/operations.md):
#
#   worlds_local/<World>/   world save, chunked 1.0 form - server
#   worlds_local/           any other world directory, so a promoted playtest world is not lost
#   cache/                  per-world biome data cache, regenerable but cheap - server
#   permittedlist.txt       the Roster whitelist - server
#   adminlist.txt           admins - server
#   bannedlist.txt          bans - server
#
# What is deliberately NOT captured, and why:
#
#   characters/*.fch        client-owned. A client's character file, and therefore character level
#                           and personal keys, lives on the player's machine (ADR-0010 accepts
#                           client-owned progression). A server-only archive must not be described
#                           as backing it up.
#   config/ServerManager/   contained a retired mod's state on the historical host; nothing in the
#                           current pack reads it.
#
# Consistency: the game writes `_main.<n>.ok` last and only then reaps generation n-1, so a
# generation whose `.ok` set is unchanged across the copy was not reaped underneath it. The script
# copies, compares marker sets, and retries; it never claims consistency it did not observe.
#
# A running server is copied live by default, using the marker comparison. `--stop-command` is
# intentionally not offered: pausing saves requires controlling the server, which is the operator's
# decision, not this script's.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SAVEDIR=""
OUT=""
WORLD=""
KEEP=14
OFFHOST=""
ATTEMPTS=3

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/backup-world.sh --savedir <dir> --out <dir> [options]

  --savedir <dir>   the server's save directory (the game's -savedir, e.g. /config/save)
  --out <dir>       where backup archives are written
  --world <name>    world to capture; default: every world directory found
  --keep <n>        how many archives to retain (default 14); 0 disables rotation
  --offhost <spec>  a destination for a second copy; one of:
                      user@host:/path        mirrored with rsync over ssh
                      /absolute/mount/path   copied locally (a mounted off-host filesystem)
  --attempts <n>    copy attempts when a save commits mid-read (default 3)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --savedir) SAVEDIR=${2:?}; shift 2 ;;
    --out) OUT=${2:?}; shift 2 ;;
    --world) WORLD=${2:?}; shift 2 ;;
    --keep) KEEP=${2:?}; shift 2 ;;
    --offhost) OFFHOST=${2:?}; shift 2 ;;
    --attempts) ATTEMPTS=${2:?}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$SAVEDIR" ]] || die "--savedir is required"
[[ -n "$OUT" ]] || die "--out is required"
[[ -d "$SAVEDIR" ]] || die "no such save directory: $SAVEDIR"
[[ "$KEEP" =~ ^[0-9]+$ ]] || die "--keep must be a non-negative integer"
[[ "$ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || die "--attempts must be a positive integer"

WORLDS_DIR="$SAVEDIR/worlds_local"
[[ -d "$WORLDS_DIR" ]] || die "no worlds_local in $SAVEDIR; is this the server's -savedir?"

# World directories the game owns. The game also writes derived snapshots of a world beside it —
# `<World>_backup_auto-<stamp>` automatically and `<World>_backup_<stamp>` for a manual copy — and
# scripts/restore-world.sh moves a world aside as `<World>.replaced-<stamp>`. None of those is a
# world a server loads by name: capturing them inflates the archive and, worse, a restore of "all
# worlds" would put a stale snapshot back beside the live one.
world_dirs() {
  local d base
  for d in "$WORLDS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    case "$base" in
      *_backup_auto-*|*_backup_*|*.replaced-*) continue ;;
    esac
    printf '%s\n' "$d"
  done
}

# The committed-generation marker set for a world directory. Empty when the world has no chunked
# save yet, which is a real state (a world created but never saved). Names are collected with a
# glob rather than `find -printf`, which BSD find does not have.
generations() {
  local names=() f out=""
  for f in "$1"/_main.*.ok; do
    [[ -e "$f" ]] || continue
    names+=("$(basename "$f")")
  done
  ((${#names[@]})) || { printf ''; return; }
  printf '%s' "$(printf '%s\n' "${names[@]}" | sort | tr '\n' ' ')"
}

require_world() {
  local path="$WORLDS_DIR/$1"
  [[ -d "$path" ]] || die "no world directory '$1' in $WORLDS_DIR"
  printf '%s\n' "$path"
}

# Copy the consistent set into a staging directory, retrying if a save commits mid-read.
# $1 destination staging dir, $2.. world directories
capture() {
  local stage=$1; shift
  local attempt before after rc
  for (( attempt = 1; attempt <= ATTEMPTS; attempt++ )); do
    before=""
    local d
    for d in "$@"; do before+="$(generations "$d")|"; done
    rm -rf -- "$stage"
    mkdir -p "$stage/worlds_local"
    rc=0
    for d in "$@"; do
      # No trailing slash: `cp -a src/ dest/` copies the *contents* on BSD and GNU alike, which
      # would put the world's files directly in worlds_local/ and lose the world name the game
      # loads by. The name is part of the save.
      cp -a "${d%/}" "$stage/worlds_local/" || rc=$?
    done
    [[ -d "$SAVEDIR/cache" ]] && { cp -a "$SAVEDIR/cache" "$stage/cache" || rc=$?; }
    local f
    for f in permittedlist.txt adminlist.txt bannedlist.txt; do
      [[ -f "$SAVEDIR/$f" ]] && { cp -a "$SAVEDIR/$f" "$stage/$f" || rc=$?; }
    done
    after=""
    for d in "$@"; do after+="$(generations "$d")|"; done
    if [[ "$before" == "$after" ]]; then
      (( rc == 0 )) || die "copy failed (exit $rc)"
      return 0
    fi
    note "a save committed during the copy (generations '$before' -> '$after'); retrying ($attempt/$ATTEMPTS)"
  done
  die "could not capture the world between saves after $ATTEMPTS attempts"
}

worlds=()
if [[ -n "$WORLD" ]]; then
  worlds=("$(require_world "$WORLD")")
else
  while IFS= read -r d; do worlds+=("$d"); done < <(world_dirs)
  (( ${#worlds[@]} )) || die "no world directories in $WORLDS_DIR"
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
label="${WORLD:-all-worlds}"
archive="$OUT/lembitu-$label-$stamp.tar.gz"

mkdir -p "$OUT"
stage="$(mktemp -d)"
trap 'rm -rf -- "$stage"' EXIT

capture "$stage" "${worlds[@]}"

# A manifest makes the archive self-describing: what was captured, from where, and what the
# generation markers were at capture time. The restore procedure reads it rather than guessing.
{
  printf 'captured_utc=%s\n' "$stamp"
  printf 'source_savedir=%s\n' "$SAVEDIR"
  printf 'world=%s\n' "${WORLD:-<all>}"
  printf 'generations_marker_set=%s\n' "$(for d in "${worlds[@]}"; do printf '%s=%s ' "$(basename "$d")" "$(generations "$d")"; done)"
  printf 'host=%s\n' "$(hostname)"
  printf 'contents=worlds_local,cache,permittedlist.txt,adminlist.txt,bannedlist.txt\n'
  printf 'excluded=characters (client-owned), BepInEx config (deployed from the repo)\n'
} > "$stage/MANIFEST.txt"

# A capture with no world files is the failure this script exists to prevent: the container's own
# backup produced 23 byte-identical archives of a directory the live server never wrote to.
( cd "$stage" && find worlds_local -mindepth 2 -type f | grep -q . ) \
  || die "capture contains no world files; refusing to write $archive"

archive_tmp="$archive.part"
( cd "$stage" && tar czf "$archive_tmp" . ) || die "archiving failed"
mv -- "$archive_tmp" "$archive"

note "backup: $archive ($(du -h "$archive" | cut -f1))"

if [[ "$KEEP" -gt 0 ]]; then
  # Rotation is by archive name (a UTC timestamp), newest kept. Only archives this script names are
  # considered, so an operator's manual copy is never deleted.
  archives=()
  for f in "$OUT"/lembitu-*.tar.gz; do
    [[ -e "$f" ]] || continue
    archives+=("$(basename "$f")")
  done
  if ((${#archives[@]} > KEEP)); then
    mapfile -t old < <(printf '%s\n' "${archives[@]}" | sort -r | tail -n +"$((KEEP + 1))")
    for f in "${old[@]}"; do
      rm -f -- "$OUT/$f"
      note "rotated out: $f"
    done
  fi
fi

if [[ -n "$OFFHOST" ]]; then
  case "$OFFHOST" in
    *:*) # user@host:/path
      command -v rsync >/dev/null 2>&1 || die "--offhost needs rsync for a remote destination"
      rsync -a --partial "$archive" "$OFFHOST/" || die "off-host copy to $OFFHOST failed"
      note "off-host copy: $OFFHOST/$(basename "$archive")"
      ;;
    /*) # a mounted off-host filesystem
      [[ -d "$OFFHOST" ]] || die "--offhost directory does not exist: $OFFHOST"
      cp -a "$archive" "$OFFHOST/" || die "off-host copy to $OFFHOST failed"
      note "off-host copy: $OFFHOST/$(basename "$archive")"
      ;;
    *) die "--offhost must be user@host:/path or an absolute directory path" ;;
  esac
fi

printf '%s\n' "$archive"
