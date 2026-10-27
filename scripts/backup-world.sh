#!/usr/bin/env bash
# Capture one consistent set of the server's live save stores (#20).
#
#   scripts/backup-world.sh --savedir <dir> --out <dir> [--dedicated <dir>] [--reports <dir>] [--world <name>]
#                           [--keep <n>] [--offhost <spec>]
#   scripts/backup-world.sh --root <dir> --out <dir> [...]
#
# --root names the Workload's volume (docs/server-image.md, "The volume"): <dir>/save is the game's
# -savedir, <dir>/bepinex holds the plugin stores, <dir>/dedicated is SeparateSpawns' root and
# <dir>/bepinex/SeparateSpawns/reports its reports, so on astral-bicep after the cutover it is
# /state/lembitu/world. It reads exactly what --savedir <dir>/save --bepinex <dir>/bepinex
# --dedicated <dir>/dedicated --reports <dir>/bepinex/SeparateSpawns/reports reads.
#
# On today's container SeparateSpawns' root is the game tree's config/bepinex and its reports sit in
# the plugin tree, neither under the save or BepInEx config directory, so --dedicated and --reports
# name them (docs/wiki/operations.md, the backup). Without them, and without --root, the two are not
# captured and the MANIFEST says so: a restore then leaves the target's copies as they are.
#
# The measured pack writes per-world directories, not flat files: a world is
# `worlds_local/<World>/_main.<n>.fwl2` with `.db2`, `.chunks`, `.chunk` siblings and an `.ok`
# marker written last. A `*.fwl`/`*.db` glob therefore captures nothing on Valheim 1.0 and is not
# used here. The stores below were enumerated from a real pack boot
# (`~/.cache/valheim-lembitu/ticket-66-20260915/*-saves/` on astral-tricep, removed 2026-10-04) and
# from the live server's save tree.
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
# ServerManager/ holds the authoritative account-global characters (ADR-0034).
# Guilds/, Marketplace/, Lembitu.Guilds/, ValheimWebMap/ and EpicLoot/BountySaves/ under the
# sibling bepinex directory hold per-world and per-player state, not deployed configuration
# (BEPINEX_STORES in lib/save-format.sh). Each is optional and recorded absent until a plugin
# writes it. Override the directory with --bepinex.
# SeparateSpawns' roster and world layouts (dedicated/) and its reports
# (bepinex-state/SeparateSpawns/reports) come from --dedicated and --reports, or --root
# (DEDICATED_STORES and REPORTS_STORE in lib/save-format.sh). Each is optional and recorded absent
# when its directory holds none; its configuration file is not archived.
# All these stores travel together; selecting one world is refused once installed.
# Consistency: world generation markers and state file hashes must remain unchanged
# across copying. This is a stable disk snapshot, not a requested checkpoint. World
# saves and character uploads may differ by the five-minute upload interval (or more
# for a stalled client); per-file disk timestamps in STATE-TIMES.txt record observed
# age, not gameplay freshness. No character/world atomicity is claimed.

set -euo pipefail
# ServerManager can include Discord configuration; archives are private operator data.
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/save-format.sh
. "$REPO_ROOT/scripts/lib/save-format.sh"

SAVEDIR=""
OUT=""
WORLD=""
KEEP=14
OFFHOST=""
ATTEMPTS=3
BEPINEX=""
ROOT=""
DEDICATED=""
REPORTS=""

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/backup-world.sh --savedir <dir> --out <dir> [options]
       scripts/backup-world.sh --root <dir> --out <dir> [options]

  --savedir <dir>   the server's save directory (the game's -savedir, e.g. /config/save)
  --root <dir>      the Workload's volume: <dir>/save, <dir>/bepinex, <dir>/dedicated and
                    <dir>/bepinex/SeparateSpawns/reports (instead of the four options they replace)
  --out <dir>       where backup archives are written
  --bepinex <dir>   state source (default: sibling bepinex beside savedir)
  --dedicated <dir> SeparateSpawns' root, holding its roster and SeparateSpawns/worlds/
                    (default: not captured)
  --reports <dir>   SeparateSpawns' reports directory (default: not captured)
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
    --root) ROOT=${2:?}; shift 2 ;;
    --out) OUT=${2:?}; shift 2 ;;
    --bepinex) BEPINEX=${2:?}; shift 2 ;;
    --dedicated) DEDICATED=${2:?}; shift 2 ;;
    --reports) REPORTS=${2:?}; shift 2 ;;
    --world) WORLD=${2:?}; shift 2 ;;
    --keep) KEEP=${2:?}; shift 2 ;;
    --offhost) OFFHOST=${2:?}; shift 2 ;;
    --attempts) ATTEMPTS=${2:?}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

if [[ -n "$ROOT" ]]; then
  [[ -z "$SAVEDIR" && -z "$BEPINEX" && -z "$DEDICATED" && -z "$REPORTS" ]] \
    || die "--root replaces --savedir, --bepinex, --dedicated and --reports; give one or the others"
  SAVEDIR="$ROOT/save" BEPINEX="$ROOT/bepinex" DEDICATED="$ROOT/dedicated" REPORTS="$ROOT/bepinex/SeparateSpawns/reports"
fi
[[ -n "$SAVEDIR" ]] || die "--savedir or --root is required"
[[ -n "$OUT" ]] || die "--out is required"
[[ -d "$SAVEDIR" ]] || die "no such save directory: $SAVEDIR"
[[ "$KEEP" =~ ^[0-9]+$ ]] || die "--keep must be a non-negative integer"
[[ "$ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || die "--attempts must be a positive integer"

WORLDS_DIR="$SAVEDIR/worlds_local"
[[ -d "$WORLDS_DIR" ]] || die "no worlds_local in $SAVEDIR; is this the server's -savedir?"
BEPINEX=${BEPINEX:-$(dirname "$SAVEDIR")/bepinex}

# SeparateSpawns' stores: archive path, then source, for each one this backup knows where to find.
extra_keys=() extra_sources=() not_captured=()
if [[ -n "$DEDICATED" ]]; then
  for f in "${DEDICATED_STORES[@]}"; do extra_keys+=("dedicated/$f"); extra_sources+=("$DEDICATED/$f"); done
else
  not_captured+=("dedicated (no --dedicated)")
fi
if [[ -n "$REPORTS" ]]; then
  extra_keys+=("$REPORTS_STORE"); extra_sources+=("$REPORTS")
else
  not_captured+=("$REPORTS_STORE (no --reports)")
fi
if [[ -d "$SAVEDIR/ServerManager" ]]; then
  [[ -d "$SAVEDIR/ServerManager/characters" ]] || die "ServerManager installed without character store"
  [[ -z "$WORLD" ]] || die "partial world capture refused with account-global character store"
fi

# world_dirs and generations come from scripts/lib/save-format.sh, which restore-world.sh uses too:
# the two scripts must agree on exactly which directories are worlds.

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
    state_before="$(state_fingerprint)"
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
    for f in "${ADMISSION_FILES[@]}"; do
      [[ -f "$SAVEDIR/$f" ]] && { cp -a "$SAVEDIR/$f" "$stage/$f" || rc=$?; }
    done
    [[ ! -d "$SAVEDIR/ServerManager" ]] || cp -a "$SAVEDIR/ServerManager" "$stage/ServerManager" || rc=$?
    mkdir -p "$stage/bepinex-state"
    for f in "${BEPINEX_STORES[@]}"; do
      # A store may be nested (EpicLoot/BountySaves) without the rest of its parent.
      [[ ! -d "$BEPINEX/$f" ]] || { mkdir -p "$(dirname "$stage/bepinex-state/$f")" && cp -a "$BEPINEX/$f" "$stage/bepinex-state/$f"; } || rc=$?
    done
    for i in "${!extra_keys[@]}"; do
      [[ ! -e "${extra_sources[$i]}" ]] \
        || { mkdir -p "$(dirname "$stage/${extra_keys[$i]}")" && cp -a "${extra_sources[$i]}" "$stage/${extra_keys[$i]}"; } || rc=$?
    done
    [[ ! -d "$SAVEDIR/ServerManager" || -d "$stage/ServerManager/characters" ]] || die "character store disappeared during capture"
    after=""
    for d in "$@"; do after+="$(generations "$d")|"; done
    if [[ "$before" == "$after" && "$state_before" == "$(state_fingerprint)" ]]; then
      (( rc == 0 )) || die "copy failed (exit $rc)"
      return 0
    fi
    note "a save committed during the copy (generations '$before' -> '$after'); retrying ($attempt/$ATTEMPTS)"
  done
  die "could not capture the world between saves after $ATTEMPTS attempts"
}

# Account-global characters and per-world mod stores can change independently of .ok.
state_fingerprint() {
  local p
  for p in "$SAVEDIR/ServerManager" "${BEPINEX_STORES[@]/#/$BEPINEX/}" "${extra_sources[@]}"; do
    path_fingerprint "$p"
  done
}

worlds=()
if [[ -n "$WORLD" ]]; then
  worlds=("$(require_world "$WORLD")")
else
  while IFS= read -r d; do worlds+=("$d"); done < <(world_dirs "$WORLDS_DIR")
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
  printf 'format=2\n'
  printf 'contents=worlds_local,cache,admission lists,ServerManager%s%s\n' "$(printf ',bepinex-state/%s' "${BEPINEX_STORES[@]}")" \
    "$( (( ${#extra_keys[@]} )) && printf ',%s' "${extra_keys[@]}")"
  printf 'excluded=BepInEx deployed configuration; SeparateSpawns configuration; local character exports\n'
  (( ${#not_captured[@]} == 0 )) || printf 'not_captured=%s\n' "$(IFS=,; printf '%s' "${not_captured[*]}")"
  printf 'consistency=stable disk files; no forced checkpoint; world and characters may differ by upload interval (300s), longer if stalled\n'
  for f in cache ServerManager "${ADMISSION_FILES[@]}" "${BEPINEX_STORES[@]/#/bepinex-state/}" "${extra_keys[@]}"; do
    if [[ -e "$stage/$f" ]]; then printf 'store_%s=present\n' "$f"; else printf 'store_%s=absent\n' "$f"; fi
  done
} > "$stage/MANIFEST.txt"
time_roots=("$stage/worlds_local" "$stage/bepinex-state")
[[ ! -d "$stage/ServerManager" ]] || time_roots+=("$stage/ServerManager")
[[ ! -d "$stage/dedicated" ]] || time_roots+=("$stage/dedicated")
while IFS= read -r f; do
  printf '%s %s\n' "$(file_mtime "$f")" "${f#"$stage/"}"
done < <(find "${time_roots[@]}" -type f) > "$stage/STATE-TIMES.txt"
store_inventory "$stage" > "$stage/INVENTORY.txt.part"
mv "$stage/INVENTORY.txt.part" "$stage/INVENTORY.txt"

# A capture with no world files is the failure this script exists to prevent: the container's own
# backup produced 23 byte-identical archives of a directory the live server never wrote to.
( cd "$stage" && find worlds_local -mindepth 2 -type f | grep -q . ) \
  || die "capture contains no world files; refusing to write $archive"

archive_tmp="$archive.part"
( cd "$stage" && tar czf "$archive_tmp" . ) || die "archiving failed"
mv -- "$archive_tmp" "$archive"

note "backup: $archive ($(du -h "$archive" | cut -f1))"

if [[ "$KEEP" -gt 0 ]]; then
  # Rotation is by the timestamp in the archive name, newest kept — not by the whole name, whose
  # leading component is the world label. Sorting the full name would compare labels first and
  # could delete the newest archive of one world while keeping an older one of another.
  archives=()
  for f in "$OUT"/lembitu-*.tar.gz; do
    [[ -e "$f" ]] || continue
    archives+=("$f")
  done
  if ((${#archives[@]} > KEEP)); then
    # `basename` after a sort keyed on the trailing stamp: the label may itself contain hyphens.
    mapfile -t old < <(for f in "${archives[@]}"; do
      base="$(basename "$f")"
      printf '%s\t%s\n' "${base##*-}" "$f"
    done | sort -r | tail -n +"$((KEEP + 1))" | cut -f2-)
    for f in "${old[@]}"; do
      rm -f -- "$f"
      note "rotated out: $(basename "$f")"
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
