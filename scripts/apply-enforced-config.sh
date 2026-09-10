#!/usr/bin/env bash
# Apply the enforced server config onto a BepInEx config directory (#25).
#
#   scripts/apply-enforced-config.sh <bepinex-config-dir>
#
# config/enforced/ mirrors the target: a .cfg file there holds only the entries we deliberately
# set - section header plus `Key = value` lines - and each entry is merged into the same file in
# the target directory, wherever the mod generated it. Mods regenerate missing keys and add new
# ones on every boot, so a whole-file copy would go stale the moment a mod grows a setting; a
# merge keeps our values pinned and everything else exactly as the mod wrote it.
#
# Keys are matched by section and exact key text, because BepInEx config files reuse key names
# across sections: PvPBiomeDominions has `Biome 1 - Meadows Rule` in [2 - PvP Settings] and again
# in [3 - Map Position], and only the PvP one is ours to touch. An entry whose section+key is not
# in the target is appended under its section at the end of the file, so a mod renaming a key
# fails loudly at review time (a duplicate appears) rather than silently reverting to default.
# A target .cfg that does not exist at all is an error: writing one the mod never reads would be
# a silent no-op.
#
# Any non-.cfg file in the overlay replaces its target wholesale - those are data files with no
# merge semantics, such as BossRules.forsakenPowers.yml, which must hold no entries because
# ProgressivePowers owns all power effects.
#
# The run is idempotent and says exactly what it did; a second run changes nothing.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY_DIR="$REPO_ROOT/config/enforced"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }


changed=0

# merge_cfg <overlay-file> <target-file> — one merged copy per overlay entry, then appends.
merge_cfg() {
  local overlay=$1 target=$2
  [[ -f "$target" ]] || die "overlay targets $target, which the mods never generated - name drift?"

  local section="" key value line lhs
  local -a pend_sec=() pend_key=() pend_val=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '#'*|'') continue ;;
      \[*\]) section="${line%\]}"; section="${section#\[}" ;;
      *=*)
        key="${line%%=*}"; value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        [[ -n "$section" && -n "$key" ]] || die "entry outside a section in $overlay: $line"
        if ! apply_entry "$target" "$section" "$key" "$value"; then
          pend_sec+=("$section"); pend_key+=("$key"); pend_val+=("$value")
        fi
        ;;
      *) die "not a section, comment or entry in $overlay: $line" ;;
    esac
  done < "$overlay"

  local i
  for i in "${!pend_key[@]}"; do
    printf '[%s]\n%s = %s\n' "${pend_sec[$i]}" "${pend_key[$i]}" "${pend_val[$i]}" >> "$target"
    echo "appended ${target##*/} [${pend_sec[$i]}] ${pend_key[$i]} = ${pend_val[$i]}"
    changed=1
  done
}
# apply_entry <file> <section> <key> <value> — replace the entry in place; rc 1 when absent.
# Key text is compared exactly (no pattern), so keys with spaces, parens and dashes are just
# strings; only the section decides which same-named key is ours. Whether the value actually
# changed is decided by comparing bytes, not by trusting a rewrite: an enforced value that is
# already in effect must not be reported as set, or idempotence is invisible.
apply_entry() {
  local file=$1 section=$2 key=$3 value=$4 tmp
  tmp="$file.lembitu-merge"
  if awk -v sec="[$section]" -v key="$key" -v val="$value" '
    BEGIN { insec = 0; done = 0 }
    /^\[/ { insec = ($0 == sec) ? 1 : 0; print; next }
    !done && insec && index($0, "=") > 0 {
      lhs = substr($0, 1, index($0, "=") - 1)
      gsub(/^[ \t]+|[ \t]+$/, "", lhs)
      if (lhs == key) { print key " = " val; done = 1; next }
    }
    { print }
    END { exit done ? 0 : 3 }
  ' "$file" > "$tmp"; then
    if cmp -s "$file" "$tmp"; then
      rm -f "$tmp"
    else
      mv "$tmp" "$file"
      echo "set $(basename "$file") [$section] $key = $value"
      changed=1
    fi
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# --- walk the overlay -------------------------------------------------------------------------

if [[ "${1:-}" == "--overlay" ]]; then
  [[ $# -ge 3 ]] || die "--overlay needs a directory and a target"
  OVERLAY_DIR="$2"
  shift 2
fi
[[ $# -eq 1 ]] || die "usage: scripts/apply-enforced-config.sh [--overlay <dir>] <bepinex-config-dir>"
CONFIG_DIR=$1
[[ -d "$CONFIG_DIR" ]] || die "no such directory: $CONFIG_DIR"
[[ -d "$OVERLAY_DIR" ]] || die "no overlay at $OVERLAY_DIR"
found=0
while IFS= read -r rel; do
  found=1
  target="$CONFIG_DIR/$rel"
  case "$rel" in
    *.cfg) merge_cfg "$OVERLAY_DIR/$rel" "$target" ;;
    *)
      mkdir -p "$(dirname "$target")"
      if [[ ! -f "$target" ]] || ! cmp -s "$OVERLAY_DIR/$rel" "$target"; then
        cp "$OVERLAY_DIR/$rel" "$target"
        echo "replaced $rel"
        changed=1
      fi
      ;;
  esac
done < <(cd "$OVERLAY_DIR" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
[[ $found == 1 ]] || die "overlay at $OVERLAY_DIR is empty"

if [[ $changed -eq 0 ]]; then
  echo "enforced config already in effect: nothing to do"
fi
