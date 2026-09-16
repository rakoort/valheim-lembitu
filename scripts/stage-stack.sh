#!/usr/bin/env bash
# Fetch every adopted mod at its pin and stage it into dist/, so install-plugins.sh can deploy the
# whole stack in one run (#25). docs/modstack.md is the only place a version is written by hand;
# this script reads it, so the pin list cannot drift between the docs and what we install.
#
#   scripts/stage-stack.sh [--refresh] [--pins <modstack.md>] [--cache <dir>] [--dist <dir>]
#                          [--lock <modstack.lock.json>]
#   scripts/stage-stack.sh --list [same flags]   print the parsed pins, no downloads
#
# The flags exist for the tests; day to day the defaults below are what you want.
#
# A Thunderstore package becomes one self-contained directory in dist/, because BepInEx loads DLLs
# from subdirectories and a mod's assets (Jotunn localization .yml, bundle manifests) resolve
# relative to the DLL. The shapes packages ship in all normalize to the same layout:
#
#   zip root files           -> dist/plugins/<Mod>/...     (Thunderstore metadata is dropped)
#   plugins/...              -> dist/plugins/<Mod>/...
#   BepInEx/plugins/...      -> dist/plugins/<Mod>/...
#   BepInEx/patchers/...     -> dist/patchers/<Mod>/...    (no pinned package ships one today)
#   BepInEx/config/...       -> dist/config/...            (Clan's emblems and emoji)
#
# dist/ mirrors the target BepInEx/ directory, and install-plugins.sh owns the copy into a server.
# Every directory this script stages is recorded in dist/.staged-dirs and wiped before restaging,
# so a version bump cannot leave files from the older package behind, and retiring a pin removes
# its tree on the next run. Top-level files in dist/plugins/ (our own build output) are never
# touched.
#
# Each package zip is hash-verified against docs/modstack.lock.json: a re-published zip under the
# same version number is the silent-upgrade path this repo exists to close (ADR-0007). A pin the
# lock does not know yet is recorded on first fetch - there is nothing to verify against yet - and
# the run says so, because the lock only protects anyone once it is committed.
#
# Declared dependencies are checked against the pin list before anything is staged: a manifest
# asking for a package we do not pin (at a version we do not run) is a broken closure, not a
# warning. The BepInEx pack and the Jotunn override are the two deliberate exceptions, both
# recorded in docs/modstack.md.
#
# Environment:
#   VALHEIM_TEST_CACHE   download cache root (default ~/.cache/valheim-lembitu)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/ledger.sh
. "$REPO_ROOT/scripts/lib/ledger.sh"

MODSTACK="$REPO_ROOT/docs/modstack.md"
LOCK_FILE="$REPO_ROOT/docs/modstack.lock.json"
DIST_DIR="$REPO_ROOT/dist"
CACHE_DIR="${VALHEIM_TEST_CACHE:-$HOME/.cache/valheim-lembitu}/thunderstore"

# Dependencies satisfied by something other than an exact pin:
#   - denikson-BepInExPack_Valheim 5.4.2350 is what scripts/test-server.sh installs and what
#     scripts/extract-refs.sh compiles against; three adopted packages name an older pack
#     (EpicLoot and DiscordConnector 5.4.2333, WackyEpicMMOSystem 5.4.2202),
#   - Jotunn is pinned at 2.30.0, overriding the 2.29.2 EpicLoot declares (docs/modstack.md).
KNOWN_OVERRIDES="denikson-BepInExPack_Valheim-5.4.2202
denikson-BepInExPack_Valheim-5.4.2333
denikson-BepInExPack_Valheim-5.4.2350
ValheimModding-Jotunn-2.29.2"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Pins from the "Adopted upstream" table: "team/mod | version" rows only. The header and separator
# rows are rejected by requiring a digit-first version; other lines are ignored, so prose can grow
# around the table without breaking the parser - and a row in any other section (the fork table,
# "Considered and cut") is ignored because only the Adopted upstream section is read.
parse_pins() {  # parse_pins <modstack.md>; prints "team<TAB>mod<TAB>version" per pin
  awk '
    /^## / { adopted = ($0 == "## Adopted upstream"); next }
    !adopted { next }
    {
      if (sub(/^\|/, "") == 0) next
      split($0, f, "|")
      if (length(f) < 3) next
      gsub(/^ +| +$/, "", f[1]); gsub(/^ +| +$/, "", f[2])
      split(f[1], id, "/")
      if (id[1] ~ /^[A-Za-z0-9_-]+$/ && id[2] ~ /^[A-Za-z0-9_.-]+$/ && f[2] ~ /^[0-9][A-Za-z0-9.+-]*$/)
        print id[1] "\t" id[2] "\t" f[2]
    }
  ' "$1"
}

# Dependency strings out of a package manifest.json, one per line. Hand-rolled rather than jq
# because the dev shell has no jq, and tolerant of the UTF-8 BOM Thunderstore writes in front of
# some manifests (Jotunn): the BOM only ever precedes the opening brace, so it never touches the
# strings being extracted.
manifest_deps() {  # manifest_deps <zip>
  unzip -p "$1" manifest.json 2>/dev/null | awk '
    {
      line = $0
      if (!in_deps && line ~ /"dependencies"[ \t]*:/) {
        sub(/^.*"dependencies"[ \t]*:/, "", line)
        in_deps = 1
      }
      if (!in_deps) next
      while (match(line, /"[^"]*"/)) {
        dep = substr(line, RSTART + 1, RLENGTH - 2)
        if (dep != "") print dep
        line = substr(line, RSTART + RLENGTH)
      }
      if (line ~ /]/) in_deps = 0
    }
  '
}

# A dependency is satisfied when it names an exact pin, or is one of the documented overrides.
dependency_satisfied() {  # dependency_satisfied <team-Mod-version> <pins-tsv>
  local dep=$1 pins=$2 team mod version
  team="${dep%%-*}"
  version="${dep##*-}"
  mod="${dep#*-}"; mod="${mod%-*}"
  # -x anchors the match: an unanchored -F grep would let a prefix version ("2.3") satisfy pin
  # 2.30.0, and the closure check exists to refuse versions we do not run.
  grep -qxF "$(printf '%s\t%s\t%s' "$team" "$mod" "$version")" "$pins" && return 0
  grep -qFx -e "$dep" <<<"$KNOWN_OVERRIDES"
}

# Where one zip entry lands in dist/. Prints the dist-relative path; returns 1 for Thunderstore
# metadata to drop and 2 for a shape this script cannot place - a status rather than die(),
# because callers run it in a command substitution, where die would only kill the subshell and
# the caller's || would swallow the abort. Root-level files and directories both land beside the
# DLL (Jotunn localization, bundle manifests, asset directories): BepInEx loads recursively from
# plugins/, and a package's assets resolve relative to its DLL.
map_stage_path() {  # map_stage_path <mod> <zip-entry>
  local mod=$1 entry=$2
  case "$entry" in
    plugins/*)          printf 'plugins/%s/%s\n' "$mod" "${entry#plugins/}" ;;
    patchers/*)         printf 'patchers/%s/%s\n' "$mod" "${entry#patchers/}" ;;
    BepInEx/plugins/*)  printf 'plugins/%s/%s\n' "$mod" "${entry#BepInEx/plugins/}" ;;
    BepInEx/patchers/*) printf 'patchers/%s/%s\n' "$mod" "${entry#BepInEx/patchers/}" ;;
    BepInEx/config/*)   printf 'config/%s\n' "${entry#BepInEx/config/}" ;;
    BepInEx/*)          return 2 ;;
    README.md|CHANGELOG.md|icon.png|manifest.json) return 1 ;;
    *)                  printf 'plugins/%s/%s\n' "$mod" "$entry" ;;
  esac
}

lock_hash() {  # lock_hash <team/mod@version>; prints the hash, nothing when unknown
  [[ -f "$LOCK_FILE" ]] || return 0
  sed -n "s,^ *\"$1\": \"\([0-9a-f]\{64\}\)\".*$,\1,p" "$LOCK_FILE"
}

write_lock() {  # write_lock <sorted-tsv of "team/mod@version<TAB>hash">
  local key hash first=1
  {
    printf '{\n'
    while IFS=$'\t' read -r key hash; do
      [[ -n "$key" ]] || continue
      [[ $first == 1 ]] && first=0 || printf ',\n'
      printf '  "%s": "%s"' "$key" "$hash"
    done < "$1"
    printf '\n}\n'
  } > "$LOCK_FILE.tmp"
  mv "$LOCK_FILE.tmp" "$LOCK_FILE"
}

# --- arguments -------------------------------------------------------------------------------

REFRESH=0 LIST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh) REFRESH=1 ;;
    --list) LIST=1 ;;
    --pins)  [[ $# -ge 2 ]] || die "--pins needs a file"; MODSTACK="$2"; shift ;;
    --cache) [[ $# -ge 2 ]] || die "--cache needs a directory"; CACHE_DIR="$2"; shift ;;
    --dist)  [[ $# -ge 2 ]] || die "--dist needs a directory"; DIST_DIR="$2"; shift ;;
    --lock)  [[ $# -ge 2 ]] || die "--lock needs a file"; LOCK_FILE="$2"; shift ;;
    -*) die "unknown option: $1 (understood: --refresh --list --pins --cache --dist --lock)" ;;
    *) die "unexpected argument: $1" ;;
  esac
  shift
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PINS="$WORK/pins"

# --- pins ------------------------------------------------------------------------------------

parse_pins "$MODSTACK" > "$PINS" || die "cannot read pins from $MODSTACK"
[[ -s "$PINS" ]] || die "no pins parsed from $MODSTACK - broken parser or broken file"
if [[ "$MODSTACK" == "$REPO_ROOT/docs/modstack.md" ]]; then
  # A tripwire, not a lock on growth: the pack is 21 pins today, and a smaller count means the table
  # changed shape unnoticed rather than that a mod was deliberately retired. Retiring a pin on
  # purpose means editing this number in the same commit — which the 2026-09-16 review did, taking
  # it from 23 by dropping AdminQoL and BoneMod (#70).
  [[ "$(wc -l < "$PINS" | tr -d ' ')" -ge 21 ]] \
    || die "only $(wc -l < "$PINS" | tr -d ' ') pins parsed from $MODSTACK - expected the whole stack"
fi
if [[ $LIST == 1 ]]; then
  cat "$PINS"
  exit 0
fi

# --- fetch, verify, closure-check -------------------------------------------------------------

mkdir -p "$CACHE_DIR" "$DIST_DIR"
HASHES="$WORK/hashes"
: > "$HASHES"
VERIFIED=0 RECORDED=0
while IFS=$'\t' read -r team mod version; do
  zip="$CACHE_DIR/$team-$mod-$version.zip"
  if [[ ! -f "$zip" || $REFRESH == 1 ]]; then
    echo "fetching $team/$mod $version"
    curl -fsSL --retry 3 -o "$zip.download" "https://thunderstore.io/package/download/$team/$mod/$version/" \
      || die "download failed: $team/$mod $version"
    mv "$zip.download" "$zip"
  fi

  key="$team/$mod@$version"
  hash="$(sha256 "$zip")"
  locked="$(lock_hash "$key")"
  if [[ -n "$locked" ]]; then
    [[ "$locked" == "$hash" ]] \
      || die "hash mismatch for $key: lock says $locked, download is $hash - the pin's bytes moved; re-record deliberately"
    VERIFIED=$((VERIFIED + 1))
  else
    RECORDED=$((RECORDED + 1))
  fi
  printf '%s\t%s\n' "$key" "$hash" >> "$HASHES"

  while IFS= read -r dep; do
    dependency_satisfied "$dep" "$PINS" \
      || die "$team/$mod $version declares $dep, which is neither pinned nor a documented override"
  done < <(manifest_deps "$zip")
done < "$PINS"

# --- plan the staging ------------------------------------------------------------------------

# One dist-relative destination per zip entry, decided before any file is touched, so an unexpected
# package shape aborts with dist/ untouched and wipe lists exist before copies begin.
PLAN="$WORK/plan"
while IFS=$'\t' read -r team mod version; do
  zip="$CACHE_DIR/$team-$mod-$version.zip"
  while IFS= read -r entry; do
    [[ -n "$entry" && "$entry" != */ ]] || continue
    entry="${entry#./}"   # some packers prefix entries with ./
    map_rc=0
    dest="$(map_stage_path "$mod" "$entry")" || map_rc=$?
    case $map_rc in
      1) continue ;;
      2) die "unexpected package shape in $mod $version: $entry" ;;
    esac
    safe_ledger_entry "$dest" \
      || die "refusing to stage $mod $version: $entry would leave dist/ as $dest, which the installer refuses"
    printf '%s\t%s\t%s\t%s\n' "$zip" "$entry" "$team/$mod $version" "$dest" >> "$PLAN"
  done < <(LC_ALL=C unzip -Z1 "$zip")
done < "$PINS"

# --- wipe restaged and retired trees ----------------------------------------------------------

# A staged directory is owned outright: the first two components of every destination path. Wiping
# before restaging is what makes a version bump clean - a bundle dropped from the newer package
# would otherwise survive inside the old directory - and dropping a pin retires its tree here.
NEW_DIRS="$WORK/new-dirs"
cut -f4 "$PLAN" | awk -F/ '{print $1 "/" $2}' | LC_ALL=C sort -u > "$NEW_DIRS"
if [[ -f "$DIST_DIR/.staged-dirs" ]]; then
  while IFS= read -r old; do
    [[ -n "$old" ]] || continue
    grep -qxF "$old" "$NEW_DIRS" && continue
    [[ "$old" =~ ^(plugins|patchers|config)/[A-Za-z0-9._+()@-]+$ ]] || die "refusing to retire: $old"
    rm -rf "${DIST_DIR:?}/$old"
    echo "retired $old (no longer in the pin list)"
  done < "$DIST_DIR/.staged-dirs"
fi
while IFS= read -r dir; do
  [[ -d "$DIST_DIR/$dir" ]] && rm -rf "${DIST_DIR:?}/$dir"
done < "$NEW_DIRS"

# --- copy ------------------------------------------------------------------------------------

while IFS=$'\t' read -r zip entry pkg dest; do
  [[ -n "$pkg" ]] || continue
  mkdir -p "$DIST_DIR/$(dirname "$dest")"
  unzip -p "$zip" "$entry" > "$DIST_DIR/$dest"
done < "$PLAN"
cp "$NEW_DIRS" "$DIST_DIR/.staged-dirs"

# --- report ----------------------------------------------------------------------------------

echo
cut -f4 "$PLAN" | awk -F/ '
  { counts[$1 "/" $2]++ }
  END { for (d in counts) printf "staged %s (%d files)\n", d, counts[d] }
' | LC_ALL=C sort
echo
echo "staged $(wc -l < "$PINS" | tr -d ' ') packages from $MODSTACK into $DIST_DIR"

# The lock mirrors the current pin set exactly - hashes for the pins that ran, nothing else - so a
# retired pin's hash leaves with it and the file is byte-identical while nothing changes.
LC_ALL=C sort -o "$HASHES" "$HASHES"
write_lock "$HASHES"
if [[ $RECORDED -gt 0 ]]; then
  echo "recorded $RECORDED new hash(es) into $LOCK_FILE - verified $VERIFIED existing; commit the lock file"
else
  echo "verified $VERIFIED package hashes against $LOCK_FILE"
fi
