#!/usr/bin/env bash
# Assert that the enforced overlay is actually in effect on a BepInEx config directory (#69).
#
#   scripts/verify-enforced-config.sh [--overlay <dir>] <bepinex-config-dir>
#
# This exists because applying by hand once was not enough. On 2026-09-16 a key-by-key comparison
# found ten of forty-six pinned keys sitting at mod defaults, and an evening of play - including
# the run's first boss kill - had happened under them. Nothing had compared the applied result to
# the overlay afterwards, so the revert was silent. ADR-0011 answers that: the overlay is
# re-applied on every container start, and this command proves it took.
#
# It reads the same overlay the applier writes, through the same parser
# (scripts/lib/enforced-config.sh), so the two cannot drift into disagreeing about what is
# enforced. A `.cfg` overlay is compared key by key inside its own section; anything else is a
# data file and is compared byte for byte. A target file the overlay names and the mods never
# generated is a failure, never a pass: enforcing into a filename nobody reads is the exact shape
# of silence this command exists to break.
#
# Every difference is printed, not just the first, because an operator reading a restart wants the
# whole list rather than one key per run. The exit status is what callers branch on: 0 when the
# live tree matches the overlay entry for entry, non-zero otherwise.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/enforced-config.sh
. "$REPO_ROOT/scripts/lib/enforced-config.sh"
OVERLAY_DIR="$REPO_ROOT/config/enforced"

die() { enforced_die "$@"; }

drift=0
checked=0
verify_target=""
verify_rel=""

# The callback enforced_cfg_each hands every overlay entry to; the file under test travels in
# verify_target, and verify_rel is what an operator sees, so the message names the overlay path
# rather than a temporary absolute one.
verify_entry() {  # verify_entry <section> <key> <value>
  local section=$1 key=$2 want=$3 got rc=0
  checked=$((checked + 1))
  got="$(enforced_cfg_value "$verify_target" "$section" "$key")" || rc=$?
  if [[ $rc == 3 ]]; then
    printf 'absent: %s :: [%s] :: %s - expected "%s", the mod generated no such key\n' \
      "$verify_rel" "$section" "$key" "$want"
    drift=$((drift + 1))
  elif [[ "$got" != "$want" ]]; then
    printf 'drift:  %s :: [%s] :: %s - expected "%s", live "%s"\n' \
      "$verify_rel" "$section" "$key" "$want" "$got"
    drift=$((drift + 1))
  fi
}

if [[ "${1:-}" == "--overlay" ]]; then
  [[ $# -ge 3 ]] || die "--overlay needs a directory and a target"
  OVERLAY_DIR="$2"
  shift 2
fi
[[ $# -eq 1 ]] || die "usage: scripts/verify-enforced-config.sh [--overlay <dir>] <bepinex-config-dir>"
CONFIG_DIR=$1
[[ -d "$CONFIG_DIR" ]] || die "no such directory: $CONFIG_DIR"
[[ -d "$OVERLAY_DIR" ]] || die "no overlay at $OVERLAY_DIR"

found=0
while IFS= read -r rel; do
  found=1
  verify_rel="$rel"
  verify_target="$CONFIG_DIR/$rel"
  if [[ ! -f "$verify_target" ]]; then
    printf 'missing: %s - the overlay names it, the mods never generated it\n' "$rel"
    drift=$((drift + 1))
    continue
  fi
  case "$rel" in
    *.cfg) enforced_cfg_each "$OVERLAY_DIR/$rel" verify_entry ;;
    *)
      checked=$((checked + 1))
      if ! cmp -s "$OVERLAY_DIR/$rel" "$verify_target"; then
        printf 'drift:  %s - live file content differs from the overlay\n' "$rel"
        drift=$((drift + 1))
      fi
      ;;
  esac
done < <(enforced_overlay_files "$OVERLAY_DIR")
[[ $found == 1 ]] || die "overlay at $OVERLAY_DIR is empty"

if [[ $drift -eq 0 ]]; then
  printf 'enforced config verified: %d entries match\n' "$checked"
  exit 0
fi
printf 'enforced config NOT in effect: %d of %d entries differ\n' "$drift" "$checked" >&2
exit 1
