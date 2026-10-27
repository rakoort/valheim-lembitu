#!/usr/bin/env bash
# Restore a backup produced by scripts/backup-world.sh into a server's save directory (#20).
#
#   scripts/restore-world.sh --archive <file> --savedir <dir> [--dedicated <dir>] [--reports <dir>] [--world <name>]
#                            [--dry-run] [--force]
#   scripts/restore-world.sh --archive <file> --root <dir> [...]
#
# --root names the Workload's volume, as for scripts/backup-world.sh: <dir>/save, <dir>/bepinex,
# <dir>/dedicated and <dir>/bepinex/SeparateSpawns/reports. Run as root (the volume belongs to the
# server's uid, 10160), it then gives every restored store to <dir>'s owner, as the server needs to
# write them: tar and cp -a keep the archive's owner, which is whoever ran the backup.
#
# Restores the world, cache, admission lists, authoritative ServerManager store and the
# BEPINEX_STORES (Guilds, Marketplace, region claims, web map data, bounty ledgers) together, and
# SeparateSpawns' roster, world layouts and reports where --dedicated and --reports (or --root) say.
# An archive's SeparateSpawns stores with no destination given are left out, and the target's copies
# stay. BepInEx deployed configuration is excluded. Use an isolated destination and stop the target
# server before restoring.
# Existing stores are moved aside unless --force is given. Account-global character
# archives cannot select a single world. Integrity is checked before any target write.
#
# Restore with the generation settings used by that world, including Expand_World_Size.
# Removing world content is not a tested recovery path (ADR-0009, ADR-0018).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/save-format.sh
. "$REPO_ROOT/scripts/lib/save-format.sh"

ARCHIVE=""
SAVEDIR=""
WORLD=""
BEPINEX=""
ROOT=""
DEDICATED=""
REPORTS=""
DRY_RUN=false
FORCE=false

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/restore-world.sh --archive <file> --savedir <dir> [options]
       scripts/restore-world.sh --archive <file> --root <dir> [options]

  --archive <file>  a lembitu-*.tar.gz produced by scripts/backup-world.sh
  --savedir <dir>   the save directory to restore into (the game's -savedir)
  --root <dir>      the Workload's volume: <dir>/save, <dir>/bepinex, <dir>/dedicated and
                    <dir>/bepinex/SeparateSpawns/reports (instead of the four options they replace);
                    as root, the restored stores are given to <dir>'s owner
  --bepinex <dir>   state destination (default: sibling bepinex beside savedir)
  --dedicated <dir> SeparateSpawns' root, for its roster and SeparateSpawns/worlds/ (default: left out)
  --reports <dir>   SeparateSpawns' reports directory (default: left out)
  --world <name>    restore only this world from a multi-world archive
  --dry-run         print what would change, change nothing
  --force           replace an existing world directory outright instead of moving it aside
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive) ARCHIVE=${2:?}; shift 2 ;;
    --savedir) SAVEDIR=${2:?}; shift 2 ;;
    --root) ROOT=${2:?}; shift 2 ;;
    --bepinex) BEPINEX=${2:?}; shift 2 ;;
    --dedicated) DEDICATED=${2:?}; shift 2 ;;
    --reports) REPORTS=${2:?}; shift 2 ;;
    --world) WORLD=${2:?}; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$ARCHIVE" ]] || die "--archive is required"
if [[ -n "$ROOT" ]]; then
  [[ -z "$SAVEDIR" && -z "$BEPINEX" && -z "$DEDICATED" && -z "$REPORTS" ]] \
    || die "--root replaces --savedir, --bepinex, --dedicated and --reports; give one or the others"
  SAVEDIR="$ROOT/save" BEPINEX="$ROOT/bepinex" DEDICATED="$ROOT/dedicated" REPORTS="$ROOT/bepinex/SeparateSpawns/reports"
fi
[[ -n "$SAVEDIR" ]] || die "--savedir or --root is required"
[[ -f "$ARCHIVE" ]] || die "no such archive: $ARCHIVE"
BEPINEX=${BEPINEX:-$(dirname "$SAVEDIR")/bepinex}

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

tar xzf "$ARCHIVE" -C "$work" || die "could not extract $ARCHIVE"

[[ -d "$work/worlds_local" ]] || die "archive has no worlds_local/; not a lembitu backup"
[[ -f "$work/MANIFEST.txt" ]] || note "warning: archive has no MANIFEST.txt"

declare -a worlds=()
while IFS= read -r d; do
  worlds+=("$(basename "$d")")
done < <(world_dirs "$work/worlds_local")
(( ${#worlds[@]} )) || die "archive contains no world directories"

if [[ -n "$WORLD" ]]; then
  found=false
  for w in "${worlds[@]}"; do [[ "$w" == "$WORLD" ]] && found=true; done
  $found || die "archive does not contain world '$WORLD' (has: ${worlds[*]})"
  worlds=("$WORLD")
fi

# A chunked world must carry its committed-generation markers, or the game will not load it. This is
# the check a pre-1.0 flat-file backup fails.
for w in "${worlds[@]}"; do
  has_generation "$work/worlds_local/$w" \
    || die "world '$w' has no _main.*.ok generation marker; the archive is not a usable 1.0 save"
done
if [[ -f "$work/INVENTORY.txt" ]]; then
  [[ "$(store_inventory "$work")" == "$(cat "$work/INVENTORY.txt")" ]] || die "partial or damaged archive: inventory mismatch"
else
  die "partial archive: missing inventory; legacy world-only backups require a separate manual recovery"
fi
if [[ -d "$SAVEDIR/ServerManager" || -d "$work/ServerManager" ]]; then
  [[ -d "$work/ServerManager/characters" ]] || die "partial archive: missing character store"
  [[ -z "$WORLD" ]] || die "partial restore refused with account-global character store"
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
note "archive: $ARCHIVE"
note "target:  $SAVEDIR"
note "worlds:  ${worlds[*]}"
if [[ -f "$work/MANIFEST.txt" ]]; then
  note "manifest:"
  sed 's/^/  /' "$work/MANIFEST.txt" >&2
fi

# MANIFEST.txt names every store the backup looked for, as `store_<path>=present|absent`. A store with
# no line is newer than the archive (ValheimWebMap and EpicLoot/BountySaves before #131, SeparateSpawns'
# stores before #133) or one the backup wasn't told where to find: the backup never looked, so its
# absence says nothing about the target's copy, which stays, even with --force. Only a recorded
# `=absent` replaces a target with nothing.
unrecorded() {  # unrecorded <archive-relative store path>
  [[ ! -e "$work/$1" && -f "$work/MANIFEST.txt" ]] \
    && ! grep -Fxq -e "store_$1=present" -e "store_$1=absent" "$work/MANIFEST.txt"
}

# Every store and where it goes. SeparateSpawns' have a destination only when one was given.
store_keys=() store_targets=() left_out=()
for f in cache ServerManager "${ADMISSION_FILES[@]}"; do store_keys+=("$f"); store_targets+=("$SAVEDIR/$f"); done
for f in "${BEPINEX_STORES[@]}"; do store_keys+=("bepinex-state/$f"); store_targets+=("$BEPINEX/$f"); done
for f in "${DEDICATED_STORES[@]}"; do
  if [[ -n "$DEDICATED" ]]; then store_keys+=("dedicated/$f"); store_targets+=("$DEDICATED/$f"); else left_out+=("dedicated/$f"); fi
done
if [[ -n "$REPORTS" ]]; then store_keys+=("$REPORTS_STORE"); store_targets+=("$REPORTS"); else left_out+=("$REPORTS_STORE"); fi
note_left_out() {  # note_left_out <verb>: the archive's SeparateSpawns stores with nowhere to go
  local f
  for f in "${left_out[@]}"; do
    unrecorded "$f" && continue
    note "$1: $f (the archive records it; the target's copy stays): give --$([[ $f == dedicated/* ]] && echo dedicated || echo reports) to restore it"
  done
}
# As root on the Workload's volume, the restored stores go to the volume's owner.
owner_fix=false
[[ -n "$ROOT" && "$(id -u)" == 0 ]] && owner_fix=true

if $DRY_RUN; then
  for w in "${worlds[@]}"; do
    if [[ -d "$SAVEDIR/worlds_local/$w" ]]; then
      $FORCE && note "would replace: $SAVEDIR/worlds_local/$w" \
              || note "would move aside: $SAVEDIR/worlds_local/$w -> $w.replaced-$stamp"
    else
      note "would create: $SAVEDIR/worlds_local/$w"
    fi
  done
  for i in "${!store_keys[@]}"; do
    f=${store_keys[$i]} target=${store_targets[$i]}
    if unrecorded "$f"; then note "not in this archive (older format): would leave as is: $target"; continue; fi
    if [[ -e "$target" ]]; then
      if $FORCE; then note "would replace: $target"; else note "would move aside: $target -> $target.replaced-$stamp"; fi
    elif [[ -e "$work/$f" ]]; then note "would create: $target"; fi
    [[ -e "$work/$f" ]] || note "would leave absent: $target"
  done
  note_left_out "would leave out"
  [[ ! -d "$work/ServerManager" ]] || note "would reset: $SAVEDIR/ServerManager/cron.yml to idle seed (keep cron_last.yml)"
  ! $owner_fix || note "would give: $SAVEDIR, $BEPINEX and $DEDICATED to $(stat -c %u:%g "$ROOT"), $ROOT's owner"
  note "dry run: nothing changed"
  exit 0
fi

mkdir -p "$SAVEDIR/worlds_local"

for w in "${worlds[@]}"; do
  target="$SAVEDIR/worlds_local/$w"
  if [[ -e "$target" ]]; then
    if $FORCE; then
      rm -rf -- "$target"
      note "replaced: $target"
    else
      mv -- "$target" "$SAVEDIR/worlds_local/$w.replaced-$stamp"
      note "moved aside: $target -> $w.replaced-$stamp"
    fi
  fi
  cp -a "$work/worlds_local/$w" "$target"
  note "restored: $target"
done

# Replace every archived store, including admission and cache; never merge later state.
restore_store() {  # restore_store <archive-relative store path> <target>
  local key=$1 source="$work/$1" target=$2
  if unrecorded "$key"; then
    note "not in this archive (older format): left as is: $target"
    return 0
  fi
  if [[ -e "$target" ]]; then
    if $FORCE; then rm -rf -- "$target"; else mv -- "$target" "$target.replaced-$stamp"; fi
  fi
  if [[ -e "$source" ]]; then
    mkdir -p "$(dirname "$target")"
    cp -a "$source" "$target"
    note "restored: $target"
  else
    note "restored absence: $target"
  fi
}
for i in "${!store_keys[@]}"; do
  restore_store "${store_keys[$i]}" "${store_targets[$i]}"
done
note_left_out "left out"
if [[ -d "$SAVEDIR/ServerManager" ]]; then
  cp "$REPO_ROOT/config/launch/servermanager-cron.yml" "$SAVEDIR/ServerManager/cron.yml"
  note "reset ServerManager cron.yml to idle seed; kept cron_last.yml"
fi
if $owner_fix; then
  owners=()
  for d in "$SAVEDIR" "$BEPINEX" "$DEDICATED"; do [[ ! -e "$d" ]] || owners+=("$d"); done
  chown -R --reference="$ROOT" -- "${owners[@]}"
  note "gave: ${owners[*]} to $(stat -c %u:%g "$ROOT"), $ROOT's owner"
fi

note "restore complete; start the server with -savedir $SAVEDIR and confirm the world loads"
