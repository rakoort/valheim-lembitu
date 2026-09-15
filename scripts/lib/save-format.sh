# Shared by scripts/backup-world.sh and scripts/restore-world.sh: one definition of what a Valheim
# 1.0 save looks like and which directories are worlds.
#
# This is the archive's format contract, so it lives in one place. The two scripts have to agree
# exactly: a world the backup captures and the restore does not enumerate is data loss, and a
# directory the restore treats as a world that the backup never captured is a phantom. Keeping the
# knowledge in two files is how they drift apart.

# World directories the game owns, one absolute path per line. The game writes derived snapshots of
# a world beside it - `<World>_backup_auto-<stamp>` automatically and `<World>_backup_<stamp>` for a
# manual copy - and restore-world.sh moves a world aside as `<World>.replaced-<stamp>`. None of those
# is a world a server loads by name, so they are never captured and never restored.
world_dirs() {  # world_dirs <worlds-dir>
  local worlds_dir=$1 d base
  for d in "$worlds_dir"/*/; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    case "$base" in
      *_backup_auto-*|*_backup_*|*.replaced-*) continue ;;
    esac
    printf '%s\n' "$d"
  done
}

# The committed-generation marker set for a world directory: the `_main.<n>.ok` files, which the game
# writes last and only then reaps generation <n-1> from. An unchanged set across a read means nothing
# was reaped underneath it. Empty is a real state - a world created but never saved. Names come from
# a glob rather than `find -printf`, which BSD find does not have.
generations() {  # generations <world-dir>
  local names=() f
  for f in "$1"/_main.*.ok; do
    [[ -e "$f" ]] || continue
    names+=("$(basename "$f")")
  done
  ((${#names[@]})) || { printf ''; return; }
  printf '%s' "$(printf '%s\n' "${names[@]}" | sort | tr '\n' ' ')"
}

# A world a server can load must carry at least one committed-generation marker.
has_generation() {  # has_generation <world-dir>
  local f
  for f in "$1"/_main.*.ok; do
    [[ -e "$f" ]] && return 0
  done
  return 1
}

# Admission files that live beside the worlds in the save directory. Valheim reads all three.
ADMISSION_FILES=(permittedlist.txt adminlist.txt bannedlist.txt)
