#!/usr/bin/env bash
# Apply config/dedicated/ onto a mod's own config root inside the game tree (#86).
#
#   scripts/apply-dedicated-config.sh <game-root-config-dir>
#
# This exists for one mod and should stay that small. SeparateSpawns 0.1.0 ignores BepInEx's config
# directory when it detects a headless server: `ModPaths.UseDedicatedConfigLayout()` returns true and
# `GetDedicatedConfigRoot()` points at `<game root>/config/bepinex`. So its file lives inside the
# container's game tree, where two things are true that are not true of `/config`:
#
#   - scripts/apply-enforced-config.sh cannot reach it. A file placed in config/enforced/ would be
#     merged into a path the mod never reads, and verify-enforced-config.sh would report success.
#     That is the exact silence ADR-0011 was written against, so those keys live here instead.
#   - the container re-extracts BepInEx into that tree on an update, which wipes anything in it.
#     On 2026-09-17 that cost one boot with zero plugins. This script is therefore re-run on every
#     deploy rather than once.
#
# The merge is the same one the enforced overlay uses, through the same parser
# (scripts/lib/enforced-config.sh), so the two cannot disagree about what "applied" means: a `.cfg`
# entry is matched by section and exact key text, and a key the mod has not generated is appended
# under its section rather than silently dropped.
#
# A target file that does not exist yet is not an error here, unlike the enforced overlay: the mod
# writes its config on first boot, and a fresh container has not booted yet. The run says so and
# exits non-zero, so a deploy script can decide whether to boot first and retry.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/enforced-config.sh
. "$REPO_ROOT/scripts/lib/enforced-config.sh"
OVERLAY_DIR="$REPO_ROOT/config/dedicated"

changed=0
missing=0

apply_entry_to() {  # apply_entry_to <section> <key> <value> <target-file>
  local section=$1 key=$2 value=$3 target=$4 current rc=0
  current="$(enforced_cfg_value "$target" "$section" "$key")" || rc=$?
  case $rc in
    2) enforced_die "cannot read $target while applying [$section] $key" ;;
    3)
      printf '[%s]\n%s = %s\n' "$section" "$key" "$value" >> "$target"
      echo "appended ${target##*/} [$section] $key = $value"
      changed=1
      ;;
    *)
      if [[ "$current" != "$value" ]]; then
        awk -v sec="[$section]" -v key="$key" -v val="$value" '
          /^\[/ { insec = ($0 == sec) ? 1 : 0 }
          insec && index($0, "=") > 0 {
            lhs = substr($0, 1, index($0, "=") - 1)
            gsub(/^[ \t]+|[ \t]+$/, "", lhs)
            if (lhs == key) { print key " = " val; next }
          }
          { print }
        ' "$target" > "$target.new"
        mv "$target.new" "$target"
        echo "set ${target##*/} [$section] $key = $value"
        changed=1
      fi
      ;;
  esac
}

[[ $# -eq 1 ]] || enforced_die "usage: scripts/apply-dedicated-config.sh <game-root-config-dir>"
CONFIG_DIR=$1
[[ -d "$CONFIG_DIR" ]] || enforced_die "no such directory: $CONFIG_DIR"
[[ -d "$OVERLAY_DIR" ]] || enforced_die "no overlay at $OVERLAY_DIR"

while IFS= read -r rel; do
  target="$CONFIG_DIR/$rel"
  if [[ ! -f "$target" ]]; then
    printf 'absent: %s - the mod has not written it yet; boot once and re-run\n' "$rel"
    missing=$((missing + 1))
    continue
  fi
  enforced_cfg_each "$OVERLAY_DIR/$rel" apply_entry_to "$target"
done < <(enforced_overlay_files "$OVERLAY_DIR")

if [[ $missing -gt 0 ]]; then
  exit 1
fi
if [[ $changed -eq 0 ]]; then
  echo "dedicated config already in effect: nothing to do"
fi
