#!/usr/bin/env bash
# Check the live server's locked inputs (#112), offline: docs/server-inputs.lock.json and the bytes
# it names.
#
#   scripts/verify-server-inputs.sh [--server <dir>] [--bepinex <zip>] [--mods <dir>]
#                                   [--lock <json>] [--files <sha256-list>]
#                                   [--modstack-lock <json>] [--modstack <md>] [--extract-refs <sh>]
#
# Always, the lock against the files it must agree with:
#   - every mod in it is a pin of docs/modstack.lock.json, at the same sha256, and no pin is missing;
#   - each mod's URL is the one scripts/stage-stack.sh downloads (docs/modstack.md's Download
#     sources, else Thunderstore);
#   - BepInExPack's version and sha256 are the ones scripts/extract-refs.sh compiles against;
#   - the server's per-file list (docs/server-files.sha256) is well formed.
# Then whichever inputs are given, byte for byte:
#   --server   a dedicated server tree, e.g. the Nix fixed-output derivation or a copy of a live
#              install: every file in the list, with its sha256, and no file the list lacks;
#   --bepinex  the BepInExPack zip;
#   --mods     a directory of mod zips named <team>-<mod>-<version>.zip, stage-stack.sh's cache
#              names: every pin, at its sha256, and nothing else.
#
# Nothing here touches the network. Every refusal is printed, each naming its component (server,
# loader or mod) and the file, not just the first. Exit 0 when everything agrees, 1 when anything
# was refused, 2 for a missing prerequisite or bad usage, which is never a pass.
#
# The flags other than --server, --bepinex and --mods exist for the tests.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/mod-sources.sh
. "$REPO_ROOT/scripts/lib/mod-sources.sh"

LOCK="$REPO_ROOT/docs/server-inputs.lock.json"
FILES=""
MODSTACK_LOCK="$REPO_ROOT/docs/modstack.lock.json"
MODSTACK="$REPO_ROOT/docs/modstack.md"
EXTRACT_REFS="$REPO_ROOT/scripts/extract-refs.sh"
SERVER="" BEPINEX="" MODS=""

die() { printf 'error: %s\n' "$*" >&2; exit 2; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

refused=0
refuse() {  # refuse <component> <what>
  printf 'refused: %s: %s\n' "$1" "$2"
  refused=$((refused + 1))
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server|--bepinex|--mods|--lock|--files|--modstack-lock|--modstack|--extract-refs)
      [[ $# -ge 2 ]] || die "$1 needs a value" ;;
    *) die "unknown argument: $1 (understood: --server --bepinex --mods --lock --files --modstack-lock --modstack --extract-refs)" ;;
  esac
  case "$1" in
    --server) SERVER="$2" ;;
    --bepinex) BEPINEX="$2" ;;
    --mods) MODS="$2" ;;
    --lock) LOCK="$2" ;;
    --files) FILES="$2" ;;
    --modstack-lock) MODSTACK_LOCK="$2" ;;
    --modstack) MODSTACK="$2" ;;
    --extract-refs) EXTRACT_REFS="$2" ;;
  esac
  shift 2
done

command -v jq >/dev/null 2>&1 || die "jq is required (it is in the dev shell)"
for f in "$LOCK" "$MODSTACK_LOCK" "$MODSTACK" "$EXTRACT_REFS"; do
  [[ -f "$f" ]] || die "missing $f"
done
jq -e 'type == "object"' "$LOCK" >/dev/null 2>&1 || die "$LOCK is not a JSON object"
jq -e 'type == "object"' "$MODSTACK_LOCK" >/dev/null 2>&1 || die "$MODSTACK_LOCK is not a JSON object"
[[ -n "$FILES" ]] || FILES="$REPO_ROOT/$(jq -r '.server.files' "$LOCK")"
[[ -f "$FILES" ]] || die "missing the server's file list $FILES"
[[ -z "$SERVER" || -d "$SERVER" ]] || die "--server $SERVER is not a directory"
[[ -z "$BEPINEX" || -f "$BEPINEX" ]] || die "--bepinex $BEPINEX is not a file"
[[ -z "$MODS" || -d "$MODS" ]] || die "--mods $MODS is not a directory"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- the lock against the files it must agree with --------------------------------------------

jq -r '.mods | to_entries[] | [.key, .value.sha256, .value.url] | @tsv' "$LOCK" > "$WORK/mods"
jq -r 'to_entries[] | [.key, .value] | @tsv' "$MODSTACK_LOCK" > "$WORK/pins"
parse_sources "$MODSTACK" > "$WORK/sources"

while IFS=$'\t' read -r key _; do
  awk -F'\t' -v k="$key" '$1 == k { found = 1; exit } END { exit !found }' "$WORK/mods" \
    || refuse lock "$key is pinned in $(basename "$MODSTACK_LOCK") but missing from the lock"
done < "$WORK/pins"

while IFS=$'\t' read -r key hash url; do
  pinned="$(awk -F'\t' -v k="$key" '$1 == k { print $2; exit }' "$WORK/pins")"
  if [[ -z "$pinned" ]]; then
    refuse lock "$key is not a pin in $(basename "$MODSTACK_LOCK")"
    continue
  fi
  [[ "$hash" == "$pinned" ]] \
    || refuse lock "$key: sha256 $hash, but $(basename "$MODSTACK_LOCK") pins $pinned"
  team="${key%%/*}"; rest="${key#*/}"; mod="${rest%@*}"; version="${key##*@}"
  want="$(source_url "$team/$mod" "$WORK/sources")"
  [[ -n "$want" ]] || want="$(thunderstore_url "$team" "$mod" "$version")"
  [[ "$url" == "$want" ]] || refuse lock "$key: URL $url, but scripts/stage-stack.sh downloads $want"
done < "$WORK/mods"

script_value() {  # script_value <NAME>: a NAME="value" assignment in extract-refs.sh
  sed -n "s/^$1=\"\([^\"]*\)\"$/\1/p" "$EXTRACT_REFS"
}
pack_version="$(jq -r '.bepinexPack.version' "$LOCK")"
pack_sha="$(jq -r '.bepinexPack.sha256' "$LOCK")"
[[ "$pack_version" == "$(script_value BEPINEX_PACK_VERSION)" ]] \
  || refuse lock "BepInExPack $pack_version, but $(basename "$EXTRACT_REFS") compiles against $(script_value BEPINEX_PACK_VERSION)"
[[ "$pack_sha" == "$(script_value BEPINEX_PACK_SHA256)" ]] \
  || refuse lock "BepInExPack sha256 $pack_sha, but $(basename "$EXTRACT_REFS") pins $(script_value BEPINEX_PACK_SHA256)"

# sha256sum's own format, "<hash>  <path>", so a copy of the server checks with `sha256sum -c` too.
# A backslash-led line is sha256sum escaping an awkward name; the depot has none, so it is refused.
: > "$WORK/files"
line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  if [[ "$line" =~ ^([0-9a-f]{64})\ \ ([^/].*)$ ]]; then
    printf '%s\t%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}" >> "$WORK/files"
  else
    refuse lock "$(basename "$FILES") line $line_no is not \"<sha256>  <relative path>\""
  fi
done < "$FILES"

mod_count="$(wc -l < "$WORK/mods" | tr -d ' ')"
file_count="$(wc -l < "$WORK/files" | tr -d ' ')"

# --- the server's bytes ----------------------------------------------------------------------

if [[ -n "$SERVER" ]]; then
  while IFS=$'\t' read -r rel hash; do
    if [[ ! -f "$SERVER/$rel" ]]; then
      refuse server "$rel is missing"
    elif [[ "$(sha256 "$SERVER/$rel")" != "$hash" ]]; then
      refuse server "$rel changed"
    fi
  done < "$WORK/files"
  cut -f1 "$WORK/files" | LC_ALL=C sort > "$WORK/listed"
  (cd "$SERVER" && find . \( -type f -o -type l \) | sed 's,^\./,,' | LC_ALL=C sort) > "$WORK/present"
  while IFS= read -r rel; do
    refuse server "$rel is not in $(basename "$FILES")"
  done < <(LC_ALL=C comm -13 "$WORK/listed" "$WORK/present")
fi

# --- the loader's bytes ----------------------------------------------------------------------

if [[ -n "$BEPINEX" ]]; then
  [[ "$(sha256 "$BEPINEX")" == "$pack_sha" ]] \
    || refuse loader "BepInExPack $pack_version ($BEPINEX) changed"
fi

# --- the mods' bytes -------------------------------------------------------------------------

if [[ -n "$MODS" ]]; then
  : > "$WORK/mod-files"
  while IFS=$'\t' read -r key hash _; do
    team="${key%%/*}"; rest="${key#*/}"; mod="${rest%@*}"; version="${key##*@}"
    name="$team-$mod-$version.zip"
    printf '%s\n' "$name" >> "$WORK/mod-files"
    if [[ ! -f "$MODS/$name" ]]; then
      refuse mod "$key ($name) is missing"
    elif [[ "$(sha256 "$MODS/$name")" != "$hash" ]]; then
      refuse mod "$key ($name) changed"
    fi
  done < "$WORK/mods"
  LC_ALL=C sort -o "$WORK/mod-files" "$WORK/mod-files"
  (cd "$MODS" && find . -mindepth 1 -maxdepth 1 | sed 's,^\./,,' | LC_ALL=C sort) > "$WORK/mod-present"
  while IFS= read -r name; do
    refuse mod "$name is not a locked mod"
  done < <(LC_ALL=C comm -13 "$WORK/mod-files" "$WORK/mod-present")
fi

# --- report ----------------------------------------------------------------------------------

if [[ $refused -gt 0 ]]; then
  printf '%d refused\n' "$refused"
  exit 1
fi
printf 'lock agrees: %d mods with %s, BepInExPack %s with %s, %d server files listed\n' \
  "$mod_count" "$(basename "$MODSTACK_LOCK")" "$pack_version" "$(basename "$EXTRACT_REFS")" "$file_count"
[[ -n "$SERVER" ]] && printf 'server verified: %d files in %s\n' "$file_count" "$SERVER"
[[ -n "$BEPINEX" ]] && printf 'loader verified: %s\n' "$BEPINEX"
[[ -n "$MODS" ]] && printf 'mods verified: %d zips in %s\n' "$mod_count" "$MODS"
exit 0
