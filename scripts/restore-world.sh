#!/usr/bin/env bash
# Restore a backup produced by scripts/backup-world.sh into a server's save directory (#20).
#
#   scripts/restore-world.sh --archive <file> --savedir <dir> [--world <name>] [--dry-run] [--force]
#
# The archive holds `worlds_local/<World>/...` plus the admission lists and the biome cache, exactly
# the set scripts/backup-world.sh captured. Restoring means replacing the world directory in the
# target save directory with the archived one; the game then loads it as an ordinary save.
#
# Safety: the target world directory, if it exists, is moved aside to `<World>.replaced-<stamp>`
# rather than deleted, so a mistaken restore is itself reversible. `--force` is required to
# overwrite an existing world without that move-aside, and `--dry-run` prints the plan and exits.
#
# What a restore does NOT do:
#
#   characters    client-owned (ADR-0010). A player's character file, and with it character level,
#                 XP and personal keys, stays on the player's machine; the server cannot restore it
#                 and this script does not pretend to.
#   BepInEx config The enforced overlay is applied from the repository
#                 (scripts/apply-enforced-config.sh), not carried in the archive.
#
# The world-permanent mods (Max Dungeon Rooms, ValheimRAFT) must be installed in the server before it
# loads a restored world. A restore into a server missing them is not a valid recovery (ADR-0009).

set -euo pipefail

ARCHIVE=""
SAVEDIR=""
WORLD=""
DRY_RUN=false
FORCE=false

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat >&2 <<'EOF'
usage: scripts/restore-world.sh --archive <file> --savedir <dir> [options]

  --archive <file>  a lembitu-*.tar.gz produced by scripts/backup-world.sh
  --savedir <dir>   the save directory to restore into (the game's -savedir)
  --world <name>    restore only this world from a multi-world archive
  --dry-run         print what would change, change nothing
  --force           replace an existing world directory outright instead of moving it aside
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive) ARCHIVE=${2:?}; shift 2 ;;
    --savedir) SAVEDIR=${2:?}; shift 2 ;;
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

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

tar xzf "$ARCHIVE" -C "$work" || die "could not extract $ARCHIVE"

[[ -d "$work/worlds_local" ]] || die "archive has no worlds_local/; not a lembitu backup"
[[ -f "$work/MANIFEST.txt" ]] || note "warning: archive has no MANIFEST.txt"

declare -a worlds=()
for d in "$work/worlds_local"/*/; do
  [[ -d "$d" ]] || continue
  worlds+=("$(basename "$d")")
done
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
  marker_found=false
  for f in "$work/worlds_local/$w"/_main.*.ok; do
    [[ -e "$f" ]] && marker_found=true
  done
  $marker_found || die "world '$w' has no _main.*.ok generation marker; the archive is not a usable 1.0 save"
done

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

# The admission lists are restored only when the archive has them and the target is missing one, so
# a restore never silently discards a roster change made after the backup was taken.
for f in permittedlist.txt adminlist.txt bannedlist.txt; do
  if [[ -f "$work/$f" ]]; then
    if [[ -e "$SAVEDIR/$f" ]]; then
      note "kept existing $f (archive copy: $work/$f)"
    else
      cp -a "$work/$f" "$SAVEDIR/$f"
      note "restored: $SAVEDIR/$f"
    fi
  fi
done

# The biome cache is regenerable and world-specific; a stale one for a restored world is discarded
# rather than restored, because the game rewrites it on first load.
if [[ -d "$work/cache" ]]; then
  note "note: cache/ was captured but is not restored; the game regenerates it"
fi

note "restore complete; start the server with -savedir $SAVEDIR and confirm the world loads"
