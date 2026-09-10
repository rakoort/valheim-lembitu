#!/usr/bin/env bash
# Install everything in dist/plugins/ into a BepInEx plugins directory.
#
#   scripts/install-plugins.sh [--dist <dir>] <bepinex-plugins-dir>
#   scripts/install-plugins.sh prune-mirror <bepinex-plugins-dir> <docker-container>
#
# --dist overrides dist/plugins/ as the source tree; the tests use it to stage throwaway trees.
#
# dist/plugins/ holds our plugin DLLs and whole mod trees: a DLL with the files it ships beside it,
# such as More World Locations AIO's asset-bundle manifest and Bundles/ directory. Everything in
# dist/plugins/ is deployed preserving relative paths, so a DLL at the top level lands in the
# plugins root and a directory lands there as one self-contained tree. See docs/build.md for how a
# Thunderstore package is staged into dist/plugins/.
#
# Stale files are the whole reason this script exists. A server keeps loading a plugin DLL until the
# file is gone, and the lloesche/valheim-server container copies the plugins directory into the game
# directory on every start without ever pruning it (see docs/build.md). So this script records every
# file it installed in .lembitu-installed and removes anything it installed previously but no
# longer finds in dist/plugins/. Files it did not install are never touched: removal is driven by
# the manifest alone, and a directory is only removed by rmdir once it has become empty.
#
# The container's second copy needs separate help: its rsync has no --delete, so a tree pruned from
# /config keeps loading under /opt/valheim until prune-mirror removes it there. Install runs append
# what they pruned to .lembitu-removed; after the container has synced, prune-mirror replays that
# list inside it and clears the ledger.
#
# dist/plugins/ is the source of truth, so run `dotnet clean` (or delete dist/) after renaming or
# removing a plugin, otherwise the old DLL is still there to install.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist/plugins"

# Where lloesche/valheim-server copies /config/bepinex/plugins into the game directory.
CONTAINER_PLUGINS_DIR="/opt/valheim/bepinex/BepInEx/plugins"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Ledger entries are relative paths with a boring charset, because prune-mirror embeds them in a
# shell script that runs inside the container. Traversal is refused on top of that: anything else
# is an error rather than something to escape.
safe_ledger_entry() {
  [[ "$1" =~ ^[A-Za-z0-9._+()@-]+(/[A-Za-z0-9._+()@-]+)*$ ]] || return 1
  case "$1" in .*|*/../*|*/..|*/.) return 1 ;; esac
  return 0
}

# Every regular file in dist/plugins/, as paths relative to it, sorted. Anything that is neither a
# file nor a directory (a symlink, say) is an error: it would be skipped silently otherwise.
dist_files() {
  local unexpected
  unexpected="$(cd "$DIST_DIR" && find . -mindepth 1 ! -type f ! -type d -print)"
  [[ -z "$unexpected" ]] || die "unexpected entry in dist/plugins/: $(printf '%s' "$unexpected" | head -n 1)"
  cd "$DIST_DIR" && find . -type f | sed 's|^\./||' | LC_ALL=C sort
}

# One line per top-level dist entry, so a 230-file bundle tree is summarized instead of scrolled:
#   installed Lembitu.Hello.dll
#   removed stale More_World_Locations_AIO/ (4 files)
report() {  # report <verb> <relative-path>...
  local verb=$1; shift
  local path root="" count=0 nested=0
  # Paths are sorted here, so a group is a run sharing the same first component. A group is a tree
  # if any of its paths has a slash - decided from the paths, not from dist/plugins/, because a
  # pruned tree's directory is by definition no longer there to ask.
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ "${path%%/*}" != "$root" ]]; then
      report_group "$verb" "$root" "$count" "$nested"
      root="${path%%/*}"; count=0; nested=0
    fi
    count=$((count + 1))
    [[ "$path" == */* ]] && nested=1
  done <<< "$(printf '%s\n' "$@" | sort)"
  report_group "$verb" "$root" "$count" "$nested"
}

report_group() {  # report_group <verb> <root> <count> <nested>
  local verb=$1 root=$2 count=$3 nested=$4
  [[ -n "$root" ]] || return 0
  if [[ "$nested" == 1 ]]; then
    echo "$verb $root/ ($count files)"
  else
    echo "$verb $root"
  fi
}

do_install() {
  local target_arg=$1 target
  mkdir -p "$target_arg"
  target="$(cd "$target_arg" && pwd)"
  [[ "$target" != "/" ]] || die "refusing to install into /"
  [[ -d "$DIST_DIR" ]] || die "no dist/plugins/; run 'dotnet build' first"

  local manifest="$target/.lembitu-installed"
  local files=() name dir
  while IFS= read -r name; do
    # Same policy the ledger enforces: paths prune-mirror would refuse never get installed, so a
    # dotfile or traversal-shaped name in dist/plugins/ fails here instead of breaking cleanup later.
    safe_ledger_entry "$name" || die "refusing to deploy from dist/plugins/: $name"
    files+=("$name")
  done < <(dist_files)
  [[ ${#files[@]} -gt 0 ]] || die "dist/plugins/ is empty; run 'dotnet build' or stage a mod tree (docs/build.md)"

  # Remove what we installed last time and no longer build. A failure part-way cannot disown files:
  # the manifest is only rewritten after every copy has succeeded, so the next run prunes again.
  local removed=()
  if [[ -f "$manifest" ]]; then
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      [[ -f "$DIST_DIR/$name" ]] && continue
      if [[ -f "$target/$name" ]]; then
        rm -- "$target/$name"
        removed+=("$name")
      fi
    done < "$manifest"
  fi
  if [[ ${#removed[@]} -gt 0 ]]; then
    printf '%s\n' "${removed[@]}" >> "$target/.lembitu-removed"
    report "removed stale" "${removed[@]}"
    # A tree is only gone when its directory is gone too. rmdir walks up from each removed file and
    # stops at the first non-empty directory, so a foreign file keeps its directory alive.
    for name in "${removed[@]}"; do
      dir="$(dirname -- "$target/$name")"
      while [[ "$dir" != "$target" ]] && rmdir "$dir" 2>/dev/null; do
        dir="$(dirname -- "$dir")"
      done
    done
  fi

  local installed=()
  for name in "${files[@]}"; do
    # A file we are about to own that the manifest does not know: it got here by other means, so
    # say so before the copy makes it ours - and prunable - from now on.
    if [[ -f "$target/$name" ]] && ! grep -Fxq -- "$name" "$manifest" 2>/dev/null; then
      echo "warning: overwriting foreign file $name" >&2
    fi
    dir="$(dirname -- "$name")"
    [[ "$dir" == "." ]] || mkdir -p -- "$target/$dir"
    cp "$DIST_DIR/$name" "$target/$name"
    installed+=("$name")
  done
  printf '%s\n' "${installed[@]}" > "$manifest"
  report "installed" "${installed[@]}"

  if [[ -s "$target/.lembitu-removed" ]]; then
    echo "note: removals pending in the container; run: scripts/install-plugins.sh prune-mirror $target_arg <container>" >&2
  fi
  echo "target: $target"
}

do_prune_mirror() {
  local target_arg=$1 container=$2 target
  mkdir -p "$target_arg"
  target="$(cd "$target_arg" && pwd)"
  local ledger="$target/.lembitu-removed"
  command -v docker >/dev/null 2>&1 || die "docker not found: prune-mirror reaches $container through it"

  if [[ ! -s "$ledger" ]]; then
    echo "nothing to prune (no pending entries in $ledger)"
    return 0
  fi

  local entries=() rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    safe_ledger_entry "$rel" || die "unsafe ledger entry: $rel"
    entries+=("$rel")
  done < "$ledger"
  if [[ ${#entries[@]} -eq 0 ]]; then
    : > "$ledger"
    echo "nothing to prune (ledger held no paths)"
    return 0
  fi

  # This script runs inside the container as `sh -s`: cd into the mirror, remove every ledgered
  # file, then the directories those removals emptied (deepest first) and the mirror's ledger copy.
  # Ledger entries are charset-validated above, so the quoting below is all they ever need. With
  # set -e, a removal that fails aborts the script with a nonzero status, docker exec reports it,
  # and the ledger below stays intact for a retry - it is only spent on a full replay.
  {
    printf 'cd "%s" || exit 1\n' "$CONTAINER_PLUGINS_DIR"
    printf 'set -e\n'
    printf 'rm -f -- "%s"\n' "${entries[@]}"
    printf '%s\n' "${entries[@]}" \
      | awk -F/ 'NF > 1 { d = $1; for (i = 2; i < NF; i++) d = d "/" $i; print d }' \
      | LC_ALL=C sort -r -u \
      | sed 's/.*/rmdir "&" 2>\/dev\/null || true/'
    printf 'rm -f -- ".lembitu-removed"\n'
  } | docker exec -i "$container" sh -s

  : > "$ledger"   # the container replayed the list, so the ledger is spent
  echo "pruned ${#entries[@]} path(s) from $container:$CONTAINER_PLUGINS_DIR; ledger cleared"
}

if [[ "${1:-}" == "--dist" ]]; then
  [[ $# -ge 3 ]] || die "--dist needs a directory and a target"
  DIST_DIR="$2"
  shift 2
fi

case "${1:-}" in
  prune-mirror)
    [[ $# -eq 3 ]] || die "usage: scripts/install-plugins.sh prune-mirror <bepinex-plugins-dir> <docker-container>"
    do_prune_mirror "$2" "$3"
    ;;
  -*) die "unknown option: $1 (only --dist is understood before the target)" ;;
  *)
    [[ $# -eq 1 ]] || die "usage: scripts/install-plugins.sh [--dist <dir>] <bepinex-plugins-dir> | prune-mirror <bepinex-plugins-dir> <docker-container>"
    do_install "$1"
    ;;
esac
