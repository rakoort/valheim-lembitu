#!/usr/bin/env bash
# Install everything in dist/ into a BepInEx directory.
#
#   scripts/install-plugins.sh [--dist <dir>] <bepinex-dir>
#   scripts/install-plugins.sh prune-mirror <bepinex-dir> <docker-container>
#
# --dist overrides dist/ as the source tree; the tests use it to stage throwaway trees.
#
# dist/ mirrors the BepInEx directory it deploys into: plugins/ holds our plugin DLLs and whole
# staged mod trees (see scripts/stage-stack.sh), patchers/ holds BepInEx patcher DLLs, and config/
# holds config files a package ships as seeds, such as Clan's emblems. Everything in those three
# trees is deployed preserving relative paths, so a DLL at the top of dist/plugins/ lands in the
# plugins root and a directory lands there as one self-contained tree. See docs/build.md.
#
# Stale files are the whole reason this script exists. A server keeps loading a plugin DLL until the
# file is gone, and the lloesche/valheim-server container copies the plugins directory into the game
# directory on every start without ever pruning it (see docs/build.md). So this script records every
# file it installed in .lembitu-installed and removes anything it installed previously but no longer
# finds in dist/. Files it did not install are never touched: removal is driven by the manifest
# alone, and a directory is only removed by rmdir once it has become empty. A manifest left in
# plugins/ by the older, plugins-only version of this script is migrated to the BepInEx root on the
# next run, its entries prefixed with plugins/, so those files stay owned and prunable.
#
# The container's second copy needs separate help: its rsync has no --delete, so a tree pruned from
# /config keeps loading under /opt/valheim until prune-mirror removes it there. Install runs append
# what they pruned to .lembitu-removed; after the container has synced, prune-mirror replays the
# plugins/ portion of that list inside it and clears the ledger - the container only ever mirrors
# plugins/, so config/ and patchers/ entries are spent without a replay.
#
# dist/ is the source of truth, so run `dotnet clean` (or delete dist/) after renaming or removing
# a plugin, otherwise the old DLL is still there to install.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"

# The BepInEx trees dist/ may hold. plugins/ is required; the other two deploy when present.
TREES=(plugins patchers config)

# Where lloesche/valheim-server copies /config/bepinex/plugins into the game directory.
CONTAINER_PLUGINS_DIR="/opt/valheim/bepinex/BepInEx/plugins"

# shellcheck source=lib/ledger.sh
. "$REPO_ROOT/scripts/lib/ledger.sh"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Every regular file in dist/'s BepInEx trees, as paths relative to dist/, sorted. Anything that is
# neither a file nor a directory (a symlink, say) is an error: it would be skipped silently
# otherwise. Entries at the dist/ root outside the three trees are ignored - the staging ledger
# dist/.staged-dirs lives there.
dist_files() {
  local tree unexpected
  for tree in "${TREES[@]}"; do
    [[ -d "$DIST_DIR/$tree" ]] || continue
    unexpected="$(cd "$DIST_DIR/$tree" && find . -mindepth 1 ! -type f ! -type d -print)"
    [[ -z "$unexpected" ]] || die "unexpected entry in dist/$tree/: $(printf '%s' "$unexpected" | head -n 1)"
    (cd "$DIST_DIR/$tree" && find . -type f | sed "s|^\\./|$tree/|")
  done | LC_ALL=C sort
}

# One line per staged tree, so a 230-file bundle tree is summarized instead of scrolled:
#   installed plugins/MaxPlayerCount.dll
#   removed stale plugins/ValheimRAFT/ (40 files)
# Groups are the first two path components - tree and package - because with dist/ mirroring
# BepInEx/ the first component alone would collapse every package into "plugins/".
report() {  # report <verb> <relative-path>...
  local verb=$1; shift
  local path rest root="" count=0 nested=0
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    rest="${path#*/}"
    if [[ "${path%%/*}/${rest%%/*}" != "$root" ]]; then
      report_group "$verb" "$root" "$count" "$nested"
      root="${path%%/*}/${rest%%/*}"; count=0; nested=0
    fi
    count=$((count + 1))
    [[ "$path" == */*/* ]] && nested=1
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
  case "$(basename "$target")" in
    plugins|patchers|config)
      die "the target is the BepInEx directory itself, not its $(basename "$target") subdirectory" ;;
  esac
  [[ -d "$DIST_DIR/plugins" ]] || die "no dist/plugins/; run 'dotnet build' (and scripts/stage-stack.sh) first"

  local manifest="$target/.lembitu-installed"

  # Manifests from the plugins-only era of this script live in plugins/ with bare plugins-relative
  # paths; adopt them at the BepInEx root with the prefix they now need, or their files stop being
  # pruned the moment this version runs against an old server.
  #
  # That era predates the path policy, so the legacy entries are checked here, while the original is
  # still on disk to correct. They are not traversal-shaped in practice - a legacy entry that
  # reaches outside plugins/ would never have matched a file the old script installed - but the
  # character allowlist is newer than the file, and refusing after the rm -f below would leave the
  # operator nothing to edit and no way to recover the stale files it recorded.
  if [[ ! -f "$manifest" && -f "$target/plugins/.lembitu-installed" ]]; then
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      safe_ledger_entry "plugins/$name" \
        || die "unsafe entry in $target/plugins/.lembitu-installed: $name (remove that line, then rerun)"
    done < "$target/plugins/.lembitu-installed"
    sed 's|^|plugins/|' "$target/plugins/.lembitu-installed" > "$manifest"
    rm -f "$target/plugins/.lembitu-installed"
    if [[ -f "$target/plugins/.lembitu-removed" ]]; then
      sed 's|^|plugins/|' "$target/plugins/.lembitu-removed" > "$target/.lembitu-removed"
      rm -f "$target/plugins/.lembitu-removed"
    fi
    echo "migrated the installer manifest from plugins/ to the BepInEx root"
  fi

  local files=() name dir
  while IFS= read -r name; do
    # Same policy the ledger enforces: paths prune-mirror would refuse never get installed, so a
    # dotfile or traversal-shaped name in dist/ fails here instead of breaking cleanup later.
    safe_ledger_entry "$name" || die "refusing to deploy from dist/: $name"
    files+=("$name")
  done < <(dist_files)
  [[ ${#files[@]} -gt 0 ]] || die "dist/plugins/ is empty; run 'dotnet build' or stage a mod tree (docs/build.md)"

  # Remove what we installed last time and no longer build. A failure part-way cannot disown files:
  # the manifest is only rewritten after every copy has succeeded, so the next run prunes again.
  #
  # The manifest is our own record, but the file on disk is not guaranteed to still be ours: a hand
  # edit, a crash or an older version can leave a traversal-shaped entry, and `rm` would then delete
  # outside the target. Every entry is validated before the first removal, so a corrupt manifest
  # refuses the whole run instead of pruning part-way - the ledger append and the manifest rewrite
  # both come after this point. This is the policy dist/ and the prune-mirror ledger already use,
  # and no manifest this script writes can fail it: names are checked before they are copied.
  local owned=()
  if [[ -f "$manifest" ]]; then
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      safe_ledger_entry "$name" \
        || die "unsafe entry in $manifest: $name (remove that line, then rerun)"
      owned+=("$name")
    done < "$manifest"
  fi

  local removed=()
  if [[ ${#owned[@]} -gt 0 ]]; then
    for name in "${owned[@]}"; do
      [[ -f "$DIST_DIR/$name" ]] && continue
      if [[ -f "$target/$name" ]]; then
        rm -- "$target/$name"
        removed+=("$name")
      fi
    done
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

  # Ledger entries are BepInEx-root-relative; the container only mirrors plugins/, so only those
  # are replayed, stripped of the prefix. Validation still runs on the full path.
  local entries=() rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    safe_ledger_entry "$rel" || die "unsafe ledger entry: $rel"
    case "$rel" in
      plugins/*) entries+=("${rel#plugins/}") ;;
    esac
  done < "$ledger"
  if [[ ${#entries[@]} -eq 0 ]]; then
    : > "$ledger"
    echo "nothing to prune (ledger held no plugins/ entries for the container mirror)"
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
    [[ $# -eq 3 ]] || die "usage: scripts/install-plugins.sh prune-mirror <bepinex-dir> <docker-container>"
    do_prune_mirror "$2" "$3"
    ;;
  -*) die "unknown option: $1 (only --dist is understood before the target)" ;;
  *)
    [[ $# -eq 1 ]] || die "usage: scripts/install-plugins.sh [--dist <dir>] <bepinex-dir> | prune-mirror <bepinex-dir> <docker-container>"
    do_install "$1"
    ;;
esac
