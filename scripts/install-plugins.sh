#!/usr/bin/env bash
# Install everything in dist/plugins/ into a BepInEx plugins directory.
#
#   scripts/install-plugins.sh ~/.cache/valheim-lembitu/server/BepInEx/plugins
#
# Stale DLLs are the whole reason this script exists. A server keeps loading a plugin DLL until the
# file is gone, and the lloesche/valheim-server container copies the plugins directory into the game
# directory on every start without ever pruning it (see docs/build.md). So this script records what
# it installed in .lembitu-installed and removes anything it installed previously but no longer
# builds. Files it did not install are never touched.
#
# dist/plugins/ is the source of truth, so run `dotnet clean` (or delete dist/) after renaming or
# removing a plugin, otherwise the old DLL is still there to install.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist/plugins"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

TARGET_DIR="${1:-}"
[[ -n "$TARGET_DIR" ]] || die "usage: scripts/install-plugins.sh <bepinex-plugins-dir>"
[[ -d "$DIST_DIR" ]] || die "no dist/plugins/; run 'dotnet build' first"

shopt -s nullglob
built=("$DIST_DIR"/*.dll)
shopt -u nullglob
[[ ${#built[@]} -gt 0 ]] || die "dist/plugins/ contains no DLLs; run 'dotnet build' first"

mkdir -p "$TARGET_DIR"
MANIFEST="$TARGET_DIR/.lembitu-installed"

# Remove what we installed last time and no longer build.
if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ -f "$DIST_DIR/$name" ]] && continue
    if [[ -f "$TARGET_DIR/$name" ]]; then
      rm "$TARGET_DIR/$name"
      echo "removed stale $name"
    fi
  done < "$MANIFEST"
fi

# The manifest is written after the copies, so a failure part-way cannot disown DLLs that are still
# sitting in the target directory.
installed=()
for dll in "${built[@]}"; do
  cp "$dll" "$TARGET_DIR/"
  installed+=("$(basename "$dll")")
  echo "installed $(basename "$dll")"
done
printf '%s\n' "${installed[@]}" > "$MANIFEST"

echo "target: $TARGET_DIR"
