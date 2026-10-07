#!/usr/bin/env bash
# Restore a backup produced by scripts/backup-world.sh into a server's save directory (#20).
#
#   scripts/restore-world.sh --archive <file> --savedir <dir> [--world <name>] [--dry-run] [--force]
#
# Restores the world, cache, admission lists, authoritative ServerManager store and
# Guilds/Marketplace/region-claim state together. BepInEx deployed configuration is
# excluded. Use an isolated destination and stop the target server before restoring.
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
DRY_RUN=false
FORCE=false

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/restore-world.sh --archive <file> --savedir <dir> [options]

  --archive <file>  a lembitu-*.tar.gz produced by scripts/backup-world.sh
  --savedir <dir>   the save directory to restore into (the game's -savedir)
  --bepinex <dir>   state destination (default: sibling bepinex beside savedir)
  --world <name>    restore only this world from a multi-world archive
  --dry-run         print what would change, change nothing
  --force           replace an existing world directory outright instead of moving it aside
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive) ARCHIVE=${2:?}; shift 2 ;;
    --savedir) SAVEDIR=${2:?}; shift 2 ;;
    --bepinex) BEPINEX=${2:?}; shift 2 ;;
    --world) WORLD=${2:?}; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$ARCHIVE" ]] || die "--archive is required"
[[ -n "$SAVEDIR" ]] || die "--savedir is required"
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

if $DRY_RUN; then
  for w in "${worlds[@]}"; do
    if [[ -d "$SAVEDIR/worlds_local/$w" ]]; then
      $FORCE && note "would replace: $SAVEDIR/worlds_local/$w" \
              || note "would move aside: $SAVEDIR/worlds_local/$w -> $w.replaced-$stamp"
    else
      note "would create: $SAVEDIR/worlds_local/$w"
    fi
  done
  for f in cache ServerManager "${ADMISSION_FILES[@]}" "${BEPINEX_STORES[@]/#/bepinex-state/}"; do
    case "$f" in bepinex-state/*) target="$BEPINEX/${f#bepinex-state/}" ;; *) target="$SAVEDIR/$f" ;; esac
    if [[ -e "$target" ]]; then
      if $FORCE; then note "would replace: $target"; else note "would move aside: $target -> $target.replaced-$stamp"; fi
    elif [[ -e "$work/$f" ]]; then note "would create: $target"; fi
    [[ -e "$work/$f" ]] || note "would leave absent: $target"
  done
  [[ ! -d "$work/ServerManager" ]] || note "would reset: $SAVEDIR/ServerManager/cron.yml to idle seed (keep cron_last.yml)"
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
restore_store() {
  local source=$1 target=$2
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
for f in cache ServerManager "${ADMISSION_FILES[@]}"; do
  restore_store "$work/$f" "$SAVEDIR/$f"
done
for f in "${BEPINEX_STORES[@]}"; do
  restore_store "$work/bepinex-state/$f" "$BEPINEX/$f"
done
if [[ -d "$SAVEDIR/ServerManager" ]]; then
  cp "$REPO_ROOT/config/launch/servermanager-cron.yml" "$SAVEDIR/ServerManager/cron.yml"
  note "reset ServerManager cron.yml to idle seed; kept cron_last.yml"
fi

note "restore complete; start the server with -savedir $SAVEDIR and confirm the world loads"
