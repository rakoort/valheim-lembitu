#!/usr/bin/env bash
# Replace the client Pack in a Valheim game folder, cleanly, with a published Pack or a local one.
# Written for astral-tricep's Steam install (owner, 2026-10-07); any Linux client works.
#
#   scripts/install-client-pack.sh [--release <tag> | --zip <archive>] [--game-dir <dir>]
#                                  [--without <plugin>]... [--keep-backups <n>]
#
# From the Mac, without a checkout on the client:
#
#   ssh astral-tricep bash -s -- [options] < scripts/install-client-pack.sh
#
# Source. By default the newest release tagged client-pack-* of rakoort/valheim-lembitu that is not
# a draft or a pre-release, downloaded with its inventory into ~/.cache/valheim-lembitu/client-packs/
# <tag>/ and checked against the SHA-256 digests GitHub publishes for release assets; a cached copy
# with the right digest is reused. --release picks a tag. --zip installs a local archive instead (an
# unpublished candidate, the tests); scripts/build-client-pack.sh writes its <name>.versions.txt
# inventory beside it, and that file must be there.
#
# Game folder. --game-dir, else $LEMBITU_CLIENT_DIR, else tricep's
# /games/SteamLibrary/steamapps/common/Valheim (the default scripts/native-run.sh uses too).
#
# Clean means everything a Pack puts into the game folder leaves it: BepInEx/ whole (plugins, their
# configs, caches and logs), the doorstop loader files and both launchers. They are moved, not
# deleted, to ~/lembitu-pack-backups/game-<UTC stamp>.<random>/, so a player setting or a saved server
# password can be fetched back; only the newest --keep-backups (default 3) such backups are kept.
# Game files are never touched.
#
# The new Pack is extracted and checked against its inventory before the old one moves, and checked
# again in place afterwards; a failure after the old Pack moved puts it back. --without <plugin>
# leaves BepInEx/plugins/<plugin>/ out, for a client-only presentation mod one machine cannot run
# (tricep's GPU hangs and ValheimVisualEnhanced, 2026-10-06). Leaving out a mod the server requires
# gets the client refused at join.
#
# It refuses while Valheim runs from the folder, and while a native test session holds
# ~/lembitu-native.lock (scripts/native-run.sh), because those sessions copy this folder. A machine
# without flock(1) runs no native sessions, so there the lock is not taken.
#
# Steam's launch option is not touched: on Linux the Pack needs `./start_game_bepinex.sh %command%`.
#
# The environment overrides LEMBITU_PACK_CACHE, LEMBITU_PACK_BACKUPS and LEMBITU_NATIVE_LOCK exist for
# the tests.

set -euo pipefail

REPO="rakoort/valheim-lembitu"
GAME_DIR="${LEMBITU_CLIENT_DIR:-/games/SteamLibrary/steamapps/common/Valheim}"
CACHE_DIR="${LEMBITU_PACK_CACHE:-$HOME/.cache/valheim-lembitu/client-packs}"
BACKUP_ROOT="${LEMBITU_PACK_BACKUPS:-$HOME/lembitu-pack-backups}"
LOCK_FILE="${LEMBITU_NATIVE_LOCK:-$HOME/lembitu-native.lock}"
KEEP=3
RELEASE=""
ZIP=""
WITHOUT=()

# Everything scripts/build-client-pack.sh can put into a game folder. The clean moves exactly these,
# and a Pack whose inventory names anything else is refused, so a later clean can never miss a file.
PACK_ROOTS=(BepInEx doorstop_libs)
PACK_FILES=(doorstop_config.ini .doorstop_version winhttp.dll start_game_bepinex.sh
  valheim_Data/start_game_bepinex.sh)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

usage() {
  cat <<'EOF'
usage: install-client-pack.sh [--release <tag> | --zip <archive>] [--game-dir <dir>]
                              [--without <plugin>]... [--keep-backups <n>]
EOF
}

while (($#)); do
  case "$1" in
    --release) RELEASE="${2:?--release needs a tag}"; shift 2 ;;
    --zip) ZIP="${2:?--zip needs an archive}"; shift 2 ;;
    --game-dir) GAME_DIR="${2:?--game-dir needs a directory}"; shift 2 ;;
    --without) WITHOUT+=("${2:?--without needs a plugin directory name}"); shift 2 ;;
    --keep-backups) KEEP="${2:?--keep-backups needs a number}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done
[[ -z "$RELEASE" || -z "$ZIP" ]] || die "--release and --zip are alternatives; give one"
[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || die "--keep-backups needs a positive whole number"
for tool in unzip curl; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done

# sha256sum on Linux, shasum on macOS: both read the inventory's `<hash>  <path>` lines.
sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}
sha_check() {  # sha_check <inventory>, run inside the tree it describes; prints only failures
  local out status=0
  if command -v sha256sum >/dev/null 2>&1; then out="$(sha256sum -c "$1" 2>&1)" || status=$?
  else out="$(shasum -a 256 -c "$1" 2>&1)" || status=$?
  fi
  if ((status)); then
    printf '%s\n' "$out" | grep -v ': OK$' | head -n 20 >&2
    return 1
  fi
}

# --- the game folder ------------------------------------------------------------------------------

[[ -d "$GAME_DIR/valheim_Data" && ( -e "$GAME_DIR/valheim.x86_64" || -e "$GAME_DIR/valheim.exe" ) ]] \
  || die "not a Valheim game folder: $GAME_DIR"
GAME_DIR="$(cd "$GAME_DIR" && pwd -P)"
if pgrep -f -- "$GAME_DIR/valheim" >/dev/null 2>&1; then
  die "Valheim is running from $GAME_DIR; quit it first"
fi
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "a native test session holds $LOCK_FILE; run this after it finishes"
fi

# --- the Pack -------------------------------------------------------------------------------------

mkdir -p "$CACHE_DIR"

download() {  # download <url> <file> <sha256 or empty>
  local url=$1 file=$2 want=$3
  if [[ -n "$want" && -f "$file" && "$(sha_of "$file")" == "$want" ]]; then
    note "cached: ${file##*/}"
    return
  fi
  note "downloading ${file##*/}"
  curl -fL --retry 3 --silent --show-error -o "$file.part" "$url" || die "download failed: $url"
  if [[ -n "$want" && "$(sha_of "$file.part")" != "$want" ]]; then
    rm -f -- "$file.part"
    die "${file##*/} does not match the SHA-256 digest GitHub publishes for it"
  fi
  mv -- "$file.part" "$file"
}

LABEL=""
if [[ -n "$ZIP" ]]; then
  [[ -f "$ZIP" ]] || die "no such archive: $ZIP"
  INVENTORY="${ZIP%.zip}.versions.txt"
  [[ -f "$INVENTORY" ]] || die "the archive's inventory is missing: $INVENTORY"
  LABEL="${ZIP##*/}"
else
  command -v jq >/dev/null 2>&1 || die "jq is required to read the GitHub release"
  api="https://api.github.com/repos/$REPO/releases"
  if [[ -n "$RELEASE" ]]; then
    release="$(curl -fsSL "$api/tags/$RELEASE")" || die "no release tagged $RELEASE"
  else
    release="$(curl -fsSL "$api?per_page=50" | jq '[.[] | select((.draft or .prerelease) | not)
      | select(.tag_name | startswith("client-pack-"))] | first')" || die "could not list releases"
  fi
  LABEL="$(jq -r '.tag_name // empty' <<<"$release")"
  [[ -n "$LABEL" ]] || die "found no client Pack release"
  asset() {  # asset <suffix> <field>
    jq -r --arg s "$1" --arg f "$2" \
      '[.assets[] | select(.name | endswith($s))] | if length == 1 then .[0][$f] // "" else error("assets") end' \
      <<<"$release" 2>/dev/null || die "release $LABEL does not carry exactly one *$1"
  }
  dir="$CACHE_DIR/$LABEL"
  mkdir -p "$dir"
  for suffix in .zip .versions.txt; do
    name="$(asset "$suffix" name)"
    digest="$(asset "$suffix" digest)"
    download "$(asset "$suffix" browser_download_url)" "$dir/$name" "${digest#sha256:}"
    if [[ "$suffix" == .zip ]]; then ZIP="$dir/$name"; else INVENTORY="$dir/$name"; fi
  done
fi

unzip -tq "$ZIP" >/dev/null 2>&1 || die "the archive is damaged: $ZIP"

# The archive and its inventory must name the same files (the builder's own parity rule), and every
# one of them must be something the clean above would move next time.
inv_paths="$(cut -c67- "$INVENTORY" | LC_ALL=C sort)"
zip_paths="$(unzip -Z1 "$ZIP" | grep -v '/$' | LC_ALL=C sort)"
[[ -n "$inv_paths" ]] || die "the inventory is empty: $INVENTORY"
if [[ "$inv_paths" != "$zip_paths" ]]; then
  diff <(printf '%s\n' "$inv_paths") <(printf '%s\n' "$zip_paths") | head -n 20 >&2 || true
  die "the archive and its inventory disagree; nothing was changed"
fi
while IFS= read -r path; do
  owned=0
  for root in "${PACK_ROOTS[@]}"; do [[ "$path" == "$root/"* ]] && owned=1; done
  for file in "${PACK_FILES[@]}"; do [[ "$path" == "$file" ]] && owned=1; done
  ((owned)) || die "the Pack installs $path, outside what this script cleans; update PACK_ROOTS/PACK_FILES"
done <<<"$inv_paths"

# --without: each name must be a plugin directory this Pack ships, so a typo cannot pass silently.
excludes=()
for name in ${WITHOUT[@]+"${WITHOUT[@]}"}; do
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "--without takes a plugin directory name: $name"
  grep -q -- "^BepInEx/plugins/${name//./\\.}/" <<<"$inv_paths" || die "the Pack has no BepInEx/plugins/$name/"
  excludes+=("BepInEx/plugins/$name/*")
done

# The trimmed inventory sits beside the stage, not in it: everything in the stage is copied into the
# game folder.
stage="$(mktemp -d "$CACHE_DIR/stage.XXXXXX")"
inventory="$stage.versions.txt"
trap 'rm -rf -- "$stage" "$inventory"' EXIT
awk -v list="${WITHOUT[*]+${WITHOUT[*]}}" '
  BEGIN { n = split(list, skip, " ") }
  { path = substr($0, 67); keep = 1
    for (i = 1; i <= n; i++) if (index(path, "BepInEx/plugins/" skip[i] "/") == 1) keep = 0
    if (keep) print }' "$INVENTORY" > "$inventory"

note "extracting $LABEL"
unzip -q "$ZIP" ${excludes[@]+-x "${excludes[@]}"} -d "$stage" || die "extraction failed"
(cd "$stage" && sha_check "$inventory") || die "the extracted Pack fails its inventory; nothing was changed"
files="$(wc -l < "$inventory" | tr -d ' ')"

# --- swap -----------------------------------------------------------------------------------------

mkdir -p "$BACKUP_ROOT"
backup="$(mktemp -d "$BACKUP_ROOT/game-$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")"
mkdir -p "$backup/valheim_Data"
moved=()

restore() {
  for path in "${PACK_ROOTS[@]}" "${PACK_FILES[@]}"; do rm -rf -- "${GAME_DIR:?}/$path"; done
  for path in ${moved[@]+"${moved[@]}"}; do mv -- "$backup/$path" "$GAME_DIR/$path"; done
  rm -rf -- "$backup"
}

for path in "${PACK_ROOTS[@]}" "${PACK_FILES[@]}"; do
  if [[ -e "$GAME_DIR/$path" || -L "$GAME_DIR/$path" ]]; then
    if ! mv -- "$GAME_DIR/$path" "$backup/$path"; then
      restore
      die "could not move $path out of the game folder; the previous Pack is back in place"
    fi
    moved+=("$path")
  fi
done

# Entry by entry rather than `cp -a stage/. game/`, which would also stamp the stage directory's
# mode and times onto the game folder itself. Each root and file is absent from the game folder now,
# so cp creates it; valheim_Data stays the game's own directory and only gains the shim.
install_new() {
  local path
  for path in "${PACK_ROOTS[@]}" "${PACK_FILES[@]}"; do
    if [[ -e "$stage/$path" ]]; then cp -a -- "$stage/$path" "$GAME_DIR/$path" || return 1; fi
  done
  (cd "$GAME_DIR" && sha_check "$inventory") || return 1
}
if ! install_new; then
  restore
  die "the installed Pack failed its inventory; the previous Pack is back in place"
fi
((${#moved[@]})) || rm -rf -- "$backup"

# Prune this script's own backups, newest kept.
backups=()
while IFS= read -r old; do backups+=("$old"); done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'game-*' | LC_ALL=C sort)
pruned=0
while ((${#backups[@]} - pruned > KEEP)); do
  rm -rf -- "${backups[$pruned]}"
  pruned=$((pruned + 1))
done

note ""
note "installed $LABEL into $GAME_DIR"
note "  $files files match the Pack's inventory${WITHOUT[*]+ (left out: ${WITHOUT[*]})}"
if ((${#moved[@]})); then
  note "  previous Pack moved to $backup"
else
  note "  the folder held no previous Pack"
fi
((pruned == 0)) || note "  $pruned older backup(s) removed, $KEEP kept"
note "Linux: Steam's launch option for Valheim must be ./start_game_bepinex.sh %command%"
