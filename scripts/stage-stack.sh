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
# A pin downloads from Thunderstore unless docs/modstack.md's "### Download sources" table names
# another URL for it. The first such table carries Azumatt's six mods, which the author moved to
# Hexium while their Thunderstore lines stand deprecated (ADR-0026). A source URL must end in the
# pin's own `/<version>.zip`, so a version bump with a stale URL dies instead of quietly
# re-downloading the old release; the downloaded bytes are lock-verified exactly like a
# Thunderstore fetch, so per-pin sources change where a zip comes from, never what proves it.
#
# A Thunderstore package becomes one self-contained directory in dist/, because BepInEx loads DLLs
# from subdirectories and a mod's assets (Jotunn localization .yml, bundle manifests) resolve
# relative to the DLL. The shapes packages ship in all normalize to the same layout:
#
#   zip root files           -> dist/plugins/<Mod>/...     (Thunderstore metadata is dropped)
#   plugins/...              -> dist/plugins/<Mod>/...
#   BepInEx/plugins/...      -> dist/plugins/<Mod>/...
#   BepInEx/patchers/...     -> dist/patchers/<Mod>/...    (no pinned package ships one; ServersideQoL
#                                                           and EpicLoot_ProgressionFix did and were cut,
#                                                           and the container never mirrors this tree
#                                                           into the game, #86)
#   BepInEx/config/...       -> dist/config/...            (CreatureManager's seeds)
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
#   - denikson-BepInExPack_Valheim 5.4.2351 is what scripts/test-server.sh installs and what
#     scripts/extract-refs.sh compiles against; adopted packages name older ones — most at 5.4.2350,
#     EpicLoot, DiscordConnector and Jotunn at 5.4.2333, SearsCatalog at 5.4.2202. The 5.4.2202
#     line has left and returned more than once, with the mods that declare it (#80); the 5.4.1501
#     skew left with BetterArchery on 2026-10-04,
#   - Jotunn is pinned at 2.30.2, overriding the 2.29.0 Guilds and Marketplace declare, the 2.29.2
#     EpicLoot declares, the 2.30.0 that World Advancement Progression, ProgressivePowers, XPortal and
#     others declare, and PlanBuild's 2.30.1 (docs/modstack.md),
#   - Zen_ModLib is pinned at its latest release, overriding the older minimum ZenRaids declares
#     (2026-10-04),
#   - Oathbound is pinned at 0.21.14, overriding the 0.21.6 minimum Oathbound Addon declares
#     (2026-10-06); every Oathbound bump re-checks the addon as it does Lembitu.Oathbound.
KNOWN_OVERRIDES="denikson-BepInExPack_Valheim-5.4.2202
denikson-BepInExPack_Valheim-5.4.2333
denikson-BepInExPack_Valheim-5.4.2350
denikson-BepInExPack_Valheim-5.4.2351
ValheimModding-Jotunn-2.29.0
ValheimModding-Jotunn-2.29.2
ValheimModding-Jotunn-2.30.0
ValheimModding-Jotunn-2.30.1
ZenDragon-Zen_ModLib-1.14.14
LionAndOtter-Oathbound-0.21.6"

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

# Download-source overrides from the "### Download sources" table: "team/mod | URL" rows. The
# URL column is rejected unless it is an https URL ending in .zip, so prose and broken rows are
# ignored the same way parse_pins ignores non-pin rows. A source row cannot be mistaken for a
# pin: a URL never passes parse_pins' digit-first version check.
parse_sources() {  # parse_sources <modstack.md>; prints "team/mod<TAB>url" per row
  awk '
    /^## / { sources = 0; next }
    /^### / { sources = ($0 == "### Download sources"); next }
    !sources { next }
    {
      if (sub(/^\|/, "") == 0) next
      split($0, f, "|")
      if (length(f) < 3) next
      gsub(/^ +| +$/, "", f[1]); gsub(/^ +| +$/, "", f[2])
      split(f[1], id, "/")
      if (id[1] ~ /^[A-Za-z0-9_-]+$/ && id[2] ~ /^[A-Za-z0-9_.-]+$/ && f[2] ~ /^https:\/\// && f[2] ~ /\.zip$/)
        print id[1] "/" id[2] "\t" f[2]
    }
  ' "$1"
}

# The override URL for one pin, or nothing when the pin downloads from Thunderstore.
source_url() {  # source_url <team/mod> <sources-tsv>
  awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$2"
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
    config/*)           printf 'config/%s\n' "${entry#config/}" ;;  # root config/ is BepInEx/config, as mod managers place it
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
  # A tripwire, not a lock on growth: the pack is 70 pins today, and a smaller count means the table
  # changed shape unnoticed rather than that a mod was deliberately retired. Retiring a pin on
  # purpose means editing this number in the same commit — which the 2026-09-16 review did, taking
  # it from 23 to 21 by dropping AdminQoL and BoneMod (#70), #78 raised it with five Azumatt mods,
  # #80 lowered it by removing character level, #83 raised it with ServersideQoL and JustSleep, and
  # 2026-10-03 took it to 27 by dropping Max Dungeon Rooms, ValheimRAFT and PvPBiomeDominions, then
  # to 37 by adding ten building, ship, season, portal and content mods, then to 36 by dropping
  # PortalRules; 2026-10-04 took it to 35 by dropping Almanac, then to 49 by adding fourteen farming,
  # magic, storage, map, station and skill mods, then to 83 by adding thirty-five packages around
  # Guilds and dropping Clan, then to 78 by swapping EpicMMO, MagicPlugin and five rejected
  # progression packages for Oathbound and SocialSystem (ADR-0020), then to 75 by dropping
  # the three map-sharing mods, then to 74 by dropping STU_Ward for Guilds' wards, then to 70 by
  # dropping OCDheim and the client-side Infinity Hammer tools, then to 68 by dropping the two
  # chest sorters, then to 67 by dropping ComfyAutoRepair, then to 66 by dropping ZenBossStone,
  # then back to 67 by adding Item_Requirement as the master-recipe gate (ADR-0021), then to 66 by
  # scrapping Seasonality, then to 65 by dropping BetterStations, then to 64 by dropping
  # BetterArchery, then to 63 by dropping Njord so the Sailing profession owns ship speed (ADR-0024);
  # 2026-10-05 took it to 70 with the five Shakedown mods, CrewStats and ConditionalConfigSync
  # (#87, ADR-0026), then to 68 when the owner removed CrewStats and DamageMeter that evening;
  # 2026-10-06 took it back to 70 with LiveExperienceTracker and Oathbound Addon (owner), then to
  # 71 with FineDining's spoilage (ADR-0029).
  # The Hexium re-pins, Guilds 1.2.3 and Explorer replacement change versions, not the count.
  [[ "$(wc -l < "$PINS" | tr -d ' ')" -ge 71 ]] \
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
SOURCES="$WORK/sources"
parse_sources "$MODSTACK" > "$SOURCES"
while IFS=$'\t' read -r team mod version; do
  zip="$CACHE_DIR/$team-$mod-$version.zip"
  if [[ ! -f "$zip" || $REFRESH == 1 ]]; then
    url="$(source_url "$team/$mod" "$SOURCES")"
    if [[ -n "$url" ]]; then
      [[ "$url" == */"$version.zip" ]] \
        || die "download source for $team/$mod does not name $version: $url - update the Download sources row in $MODSTACK"
      echo "fetching $team/$mod $version from $url"
    else
      url="https://thunderstore.io/package/download/$team/$mod/$version/"
      echo "fetching $team/$mod $version"
    fi
    curl -fsSL --retry 3 -o "$zip.download" "$url" \
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
    # Windows-built zips (Jotunn 2.30.x, ExpertExplorer) store backslash separators, directory
    # entries included; mod managers treat them as /. Normalise before the directory check.
    [[ -n "$entry" && "${entry//\\//}" != */ ]] || continue
    entry="${entry#./}"   # some packers prefix entries with ./
    map_rc=0
    dest="$(map_stage_path "$mod" "${entry//\\//}")" || map_rc=$?
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
  # unzip reads the name as a wildcard pattern, where a backslash escapes; double it to match.
  unzip -p "$zip" "${entry//\\/\\\\}" > "$DIST_DIR/$dest"
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
