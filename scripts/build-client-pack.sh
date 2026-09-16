#!/usr/bin/env bash
# Build the client Pack a player installs (#21).
#
#   scripts/build-client-pack.sh --list
#   scripts/build-client-pack.sh [--out <dir>] [--version <label>]
#                               [--pins <file>] [--cache <dir>] [--lock <file>]
#
# The archive is a COMPLETE client install, shaped like the game's own folder. A player extracts it
# into their Valheim game folder, sets one Steam launch parameter - empty on Windows, the BepInEx
# launcher on Linux - and presses Play. Nothing else: no BepInEx install step, no mod manager, no
# per-mod download.
#
# That means the archive carries three things, and all three are required:
#
#   BepInEx loader   BepInEx/, doorstop_libs/, doorstop_config.ini, winhttp.dll and the launcher
#                    scripts, from the same pinned BepInExPack_Valheim the server deploys. Without
#                    these the plugins are inert files in a folder and the game refuses to load
#                    them: a player who extracts only mods gets a vanilla client, which this
#                    server rejects outright at the handshake.
#   plugins/         the adopted pin list, plus every package's assets and config seeds.
#   config/          the package-supplied config seeds, and the client-relevant locked settings.
#
# It is NOT the server's dist/: two things differ, and both matter.
#
#   MaxPlayerCount   server-only. Every surface it patches - the admission literal in
#                    ZNet.RPC_PeerInfo, the Steam capacity prefix, the PlayFab lobby request - runs
#                    on the host. A client is told the server's capacity by the server, so shipping
#                    it to players changes nothing and would only add a mismatched plugin.
#                    It is a fork, so it is not in the adopted pin table and never staged here;
#                    the assertion below is what keeps that true if it ever moves.
#   Lembitu.Harness  our test harness. Inert without -lembitu-harness, and it belongs to the
#                    disposable test client, not to players.
#
# Client-only mods were dropped by the 2026-09-16 review: a mod the server cannot enforce behaves
# differently for every player. AdminQoL proved it, and BoneMod fell to the same argument. #70
# removes both and repoints the REQUIRED assertion below, which BoneMod currently satisfies alone.
#
# Staging is delegated to scripts/stage-stack.sh, which owns pin parsing, hash verification,
# dependency closure and the package-layout normalisation. This script adds what is specific to a
# player-facing distribution: the loader, the exclusions, the assertions that they hold, a manifest
# a player's install can be checked against, and the archive.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGER="$REPO_ROOT/scripts/stage-stack.sh"
# The loader, from the same pinned pack scripts/extract-refs.sh downloads and the server deploys.
# Overridable so the test suite can supply a fixture: lib/ is gitignored, so a clean checkout has no
# pack and a test that needed the real one could never run.
BEPINEX_PACK="${BEPINEX_PACK:-$REPO_ROOT/lib/bepinex/pack/BepInExPack_Valheim}"

OUT="dist-client"
VERSION=""
PINS_ARGS=()
LIST=0

# Plugins that must NOT reach a player. Matched as path components anywhere in the staged tree, so a
# rename of the containing directory does not quietly reintroduce one.
EXCLUDED=(MaxPlayerCount Lembitu.Harness)
# Adopted packages a client needs. BoneMod is cosmetic and client-side; if it ever stops being
# staged, the pack silently loses a feature rather than failing loudly.
REQUIRED=(BoneMod)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

usage() {
  cat >&2 <<'EOF'
usage: scripts/build-client-pack.sh --list
       scripts/build-client-pack.sh [--out <dir>] [--version <label>]

  --out <dir>       where the client pack is built (default: dist-client)
  --version <label> a label for the archive and manifest (default: the UTC date)
  --pins <file>     pin table to read (default: docs/modstack.md)
  --cache <dir>     package cache (default: ~/.cache/valheim-lembitu/thunderstore)
  --lock <file>     hash lock (default: docs/modstack.lock.json)
  --list            print the client pin list and exit; downloads and writes nothing
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT=${2:?}; shift 2 ;;
    --version) VERSION=${2:?}; shift 2 ;;
    --pins) PINS_ARGS+=(--pins "$2"); shift 2 ;;
    --cache) PINS_ARGS+=(--cache "$2"); shift 2 ;;
    --lock) LOCK=${2:?}; PINS_ARGS+=(--lock "$2"); shift 2 ;;
    --list) LIST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done

[[ -x "$STAGER" ]] || die "no stager at $STAGER"

if [[ $LIST == 1 ]]; then
  # The stager owns the pin list; asking it is what keeps the client list from drifting from the
  # adopted table.
  exec "$STAGER" --list "${PINS_ARGS[@]}"
fi

OUT_ABS="$OUT"
[[ "$OUT_ABS" = /* ]] || OUT_ABS="$REPO_ROOT/$OUT"
[[ -n "$VERSION" ]] || VERSION="$(date -u +%Y-%m-%d)"

archive="$OUT_ABS/lembitu-client-pack-$VERSION.zip"
manifest="$OUT_ABS/lembitu-client-pack-$VERSION.manifest.json"
versions="$OUT_ABS/lembitu-client-pack-$VERSION.versions.txt"

mkdir -p "$OUT_ABS"
# Two private trees: `stage` is what goes INTO the archive, `built` is where the three published
# artifacts are assembled. Keeping them apart is what stops a builder artifact from being zipped
# into the pack it describes — the manifest is written to `built`, not into the tree being archived.
stage="$(mktemp -d)"
built="$(mktemp -d)"
trap 'rm -rf -- "$stage" "$built"' EXIT

if ! "$STAGER" --dist "$stage" "${PINS_ARGS[@]}" > "$stage/stage.log" 2>&1; then
  # On failure the log is what the operator needs, so it is kept beside the (absent) pack rather
  # than only printed.
  cp "$stage/stage.log" "$OUT_ABS/stage-failed.log" 2>/dev/null || true
  cat "$stage/stage.log" >&2
  die "staging failed (log kept at $OUT_ABS/stage-failed.log)"
fi
tail -3 "$stage/stage.log" >&2

# --- the loader, and the install shape ---------------------------------------------------------
#
# The mods are dormant files until a BepInEx loader is present to load them, so the archive ships
# the loader too. Copying the pinned pack wholesale is deliberate: picking files out of it would be
# a second, silently-drifting definition of "a working BepInEx install". The server-only launcher is
# dropped, because a player runs the game, not a dedicated server.
[[ -d "$BEPINEX_PACK" ]] || die "no BepInEx pack at $BEPINEX_PACK; run scripts/extract-refs.sh first"
cp -a "$BEPINEX_PACK/BepInEx" "$stage/"
cp -a "$BEPINEX_PACK/doorstop_libs" "$stage/"
cp -a "$BEPINEX_PACK/doorstop_config.ini" "$stage/"
[[ -f "$BEPINEX_PACK/.doorstop_version" ]] && cp -a "$BEPINEX_PACK/.doorstop_version" "$stage/"
cp -a "$BEPINEX_PACK/winhttp.dll" "$stage/"
cp -a "$BEPINEX_PACK/start_game_bepinex.sh" "$stage/"
chmod +x "$stage/start_game_bepinex.sh"

# Linux, Steam: pressing Play runs the game binary directly, so the launcher has to be in the
# command. The project's launch option is `./start_game_bepinex.sh %command%`, and Steam resolves
# that relative path against `valheim_Data`, not the game root. Measured on astral-tricep,
# 2026-09-15: Steam ran `<game>/valheim_Data/start_game_bepinex.sh`, which no install contains, so
# Play opened a terminal on a missing file and the game never started - a silent vanilla-or-nothing
# failure a player cannot diagnose.
#
# Ship a shim at that path which hands off to the real launcher. `exec` replaces `$0`, so the
# launcher still derives BASEDIR - and with it `BepInEx/`, `doorstop_libs/` and every plugin path -
# from the game root. A symlink would not: BASEDIR comes from `$0` without resolving links, so each
# derived path would point inside `valheim_Data`. The file is inert on Windows, where `winhttp.dll`
# injects the loader, and on macOS, where injection needs the game's x86_64 slice under Rosetta:
# the shipped `libdoorstop_x64.dylib` cannot load into Valheim 1.0's native arm64 client.
mkdir -p "$stage/valheim_Data"
cat > "$stage/valheim_Data/start_game_bepinex.sh" <<'SHIM'
#!/bin/sh
# Steam resolves the launch option "./start_game_bepinex.sh %command%" against valheim_Data.
# Hand off to the real BepInEx launcher in the game root, keeping every argument Steam passed.
exec "$(cd "$(dirname "$0")/.." && pwd)/start_game_bepinex.sh" "$@"
SHIM
chmod +x "$stage/valheim_Data/start_game_bepinex.sh"

# Upstream's launcher works out the game's architecture by shelling out to `file(1)`. On a machine
# without it - NixOS, and minimal images generally - the command fails, `file_out` is empty, and the
# launcher aborts with "is not compiled for x86 or x64 (might be ARM?)" and a blank `Got:`. That is
# a misleading error: the game binary is fine and only the probe is missing.
#
# Patch that one probe rather than replacing the launcher, so everything else upstream does - the
# Steam re-exec handshake in particular - is preserved exactly. awk, because this is a single-line
# substitution and the repo's scripts stay bash-only.
launcher="$stage/start_game_bepinex.sh"
grep -qF 'file -b "${executable_path}"' "$launcher" \
  || die "the launcher no longer contains the \`file\` probe this build patches; upstream changed"
awk '
  /file -b "\$\{executable_path\}"/ {
    print "if command -v file >/dev/null 2>&1; then"
    print "    file_out=\"$(LD_PRELOAD=\"\" file -b \"${executable_path}\")\""
    print "else"
    print "    # No `file`: read the ELF header class byte directly (1 = 32-bit, 2 = 64-bit)."
    print "    case \"$(od -An -tu1 -j4 -N1 \"${executable_path}\" 2>/dev/null | tr -d \" \\t\")\" in"
    print "        2) file_out=\"ELF 64-bit\" ;;"
    print "        1) file_out=\"ELF 32-bit\" ;;"
    print "        *) file_out=\"\" ;;"
    print "    esac"
    print "fi"
    next
  }
  { print }
' "$launcher" > "$launcher.new"
mv -- "$launcher.new" "$launcher"
chmod +x "$stage/start_game_bepinex.sh"

# The stager writes a `dist/`-shaped tree, which mirrors the *BepInEx directory*: `dist/plugins`,
# `dist/patchers`, `dist/config`. That is what scripts/install-plugins.sh expects, and it is one
# level too shallow for a game folder. Nesting them under BepInEx/ is what turns two layouts that
# both look plausible into the one BepInEx actually loads from: at the game root, `plugins/` next to
# the game binary is an inert folder, while `BepInEx/plugins/` is where the loader looks.
for tree in plugins patchers config; do
  [[ -e "$stage/$tree" ]] || continue
  mkdir -p "$stage/BepInEx"
  if [[ -d "$stage/BepInEx/$tree" ]]; then
    # A package's file may collide with the loader's own. The package's copy is the one the mod
    # reads, so it wins — but the collision is reported, because a silent overwrite of a loader file
    # is the kind of change that only shows up as a broken install later.
    while IFS= read -r f; do
      [[ -e "$stage/BepInEx/$tree/$f" ]] && printf 'note: BepInEx/%s/%s overrides a loader file\n' "$tree" "$f" >&2
      # `find -printf` is GNU-only and this pack is built on macOS as well, where it fails and the
      # loop reads nothing - so the collision would go unreported on exactly one of the two build
      # hosts. Strip the `./` prefix here instead.
    done < <(cd "$stage/$tree" && find . -type f | sed 's|^\./||')
    cp -a "$stage/$tree/." "$stage/BepInEx/$tree/"
    rm -rf "$stage/$tree"
  else
    mv "$stage/$tree" "$stage/BepInEx/$tree"
  fi
done

# --- assertions --------------------------------------------------------------------------------

# Absence: our server-only plugin and our test harness must not be in a player's pack. The search
# is by stem so both a directory and a bare DLL are caught.
for name in "${EXCLUDED[@]}"; do
  found="$(find "$stage" \( -name "$name" -o -name "$name.dll" \) -print -quit)"
  [[ -z "$found" ]] || die "client pack contains '$name' ($found); it must not ship to players"
done

# Presence: a client-side adopted package must be staged, or the pack is silently missing content.
for name in "${REQUIRED[@]}"; do
  found="$(find "$stage" -type d -name "$name" | head -1)"
  [[ -n "$found" ]] || die "client pack is missing required client-side package '$name'"
done

# The pack must not be empty: an empty distribution installs nothing and looks successful.
( cd "$stage" && find BepInEx/plugins -mindepth 2 -type f | grep -q . ) \
  || die "client pack staged no package files under BepInEx/plugins"

# Nothing may sit at the game root except the loader's own files. A `plugins/` or `config/` at the
# root extracts cleanly, contains every mod, and loads nothing: the loader only reads BepInEx/.
for stray in plugins patchers config; do
  [[ -e "$stage/$stray" ]] && die "client pack has $stray/ at the game root; it must live under BepInEx/"
done

# The install must be complete enough to run. These are the checks whose absence produced a release
# that looked fine and could not work: a zip of mods with no loader. Launching such an install gives
# a vanilla client, which this server refuses at the handshake, and nothing in the player's folder
# explains why.
for required in \
  "BepInEx/core/BepInEx.Preloader.dll" \
  "BepInEx/core/BepInEx.dll" \
  "BepInEx/core/0Harmony.dll" \
  "doorstop_config.ini" \
  "winhttp.dll" \
  "valheim_Data/start_game_bepinex.sh" \
  "BepInEx/plugins/BoneMod"; do
  [[ -e "$stage/$required" ]] || die "client pack is missing $required; a player could not run it"
done
# At least one doorstop library per supported platform: a Windows player needs the DLL, a Linux
# player the .so, and a Mac player the .dylib - which only injects under Rosetta, since it is
# x86_64 only. Shipping one platform's library silently breaks the others.
for lib in libdoorstop_x64.so libdoorstop_x64.dylib; do
  [[ -e "$stage/doorstop_libs/$lib" ]] \
    || die "client pack is missing doorstop_libs/$lib; that platform could not load any plugin"
done
[[ -e "$stage/winhttp.dll" ]] \
  || die "client pack is missing winhttp.dll; a Windows player could not load any plugin"

# The loader must not be the only thing that is version-consistent: the plugins the server enforces
# are checked above by name, and the loader is pinned by scripts/extract-refs.sh. Record which
# loader this pack carries so a mismatch is visible rather than inferred.
loader_version="$(sed -n 's/^BEPINEX_PACK_VERSION="\([^"]*\)".*$/\1/p' "$REPO_ROOT/scripts/extract-refs.sh" | head -1)"
[[ -n "$loader_version" ]] || die "cannot read BEPINEX_PACK_VERSION from scripts/extract-refs.sh"

# --- manifest ----------------------------------------------------------------------------------

# Pin -> package hash, taken from the lock the stager verified against. This is what a player's
# installed tree is compared to; the version labels alone would not catch a re-published package.
lock="${REPO_ROOT}/docs/modstack.lock.json"

for ((i = 0; i < ${#PINS_ARGS[@]}; i += 2)); do
  [[ "${PINS_ARGS[i]}" == --lock ]] && lock="${PINS_ARGS[i + 1]}"
done

# Only the pins this run actually staged. The lock is the stager's output for its own pin set, so
# reading it wholesale would over-report if someone built from a different table, and a pin with no
# locked hash cannot be verified against a player's install at all.
pins_lines=""
[[ -f "$lock" ]] || die "no hash lock at $lock; the pack cannot be byte-verified against a player's install"
while IFS=$'\t' read -r team mod version; do
  hash="$(sed -n "s,^ *\"$team/$mod@$version\": \"\([0-9a-f]\{64\}\)\".*$,\1,p" "$lock")"
  [[ -n "$hash" ]] || die "no locked hash for $team/$mod@$version; the pack is not byte-verifiable"
  [[ -z "$pins_lines" ]] || pins_lines+=$'\n'
  pins_lines+="  \"$team/$mod@$version\": \"$hash\""
done < <("$STAGER" --list "${PINS_ARGS[@]}")

{
  printf '{\n'
  printf '  "pack": "valheim-lembitu client",\n'
  printf '  "version": "%s",\n' "$VERSION"
  printf '  "built_utc": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "complete_install": true,\n'
  printf '  "bepinex_pack": "%s",\n' "$loader_version"
  printf '  "install_shape": "extract into a copy of the Valheim game folder",\n'
  printf '  "excluded_server_only": ['
  sep=""
  for name in "${EXCLUDED[@]}"; do printf '%s"%s"' "$sep" "$name"; sep=", "; done
  printf '],\n'
  printf '  "required_client_side": ['
  sep=""
  for name in "${REQUIRED[@]}"; do printf '%s"%s"' "$sep" "$name"; sep=", "; done
  printf '],\n'
  printf '  "pins": {\n'
  # The comma goes between entries, never after the last: a trailing comma would make this file
  # invalid JSON, which is the one thing a manifest must not be.
  first=true
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    $first || printf ',\n'
    first=false
    printf '%s' "$line"
  done <<< "$pins_lines"
  printf '\n  }\n'
  printf '}\n'
} > "$built/manifest.json"

# Human-readable inventory: every file the player should end up with, with its hash. This is the
# list the install checklist compares against. The staging ledger (`.staged-dirs`) and the staging
# log are builder bookkeeping, not pack content, and are left out of both this list and the
# archive; the parity check after archiving is what keeps the two exclusion lists in step.
( cd "$stage" && find . -type f ! -name '.staged-dirs' ! -name 'stage.log' | LC_ALL=C sort \
  | while IFS= read -r f; do
    printf '%s  %s\n' "$(sha256_of "$f")" "${f#./}"
  done ) > "$built/versions.txt"

# --- archive, then publish ---------------------------------------------------------------------
#
# Everything is built in the private tree and moved into place only once every artifact exists. The
# three artifacts are one unit: a manifest without the zip it describes, or a zip without the
# inventory a player checks it against, is a partial pack that looks complete — the failure this
# builder exists to prevent. An earlier version wrote the manifest and inventory first and published
# them even when the archive step failed.

archive_tmp="$built/pack.zip"
# Only the staged tree is archived. Everything the builder writes for the operator lives in
# `built`, so no builder artifact can end up inside the pack.
( cd "$stage" && zip -qr "$archive_tmp" . -x './.staged-dirs' '.staged-dirs' './stage.log' ) \
  || die "archiving failed; nothing was published"

[[ -s "$archive_tmp" ]] || die "the archive is empty; nothing was published"

# The inventory and the archive must name the same files. They come from two separate exclusion
# lists, and when those drifted the published inventory listed a builder log no player could have:
# `sha256sum -c` then reported a failure on a byte-correct install, the false alarm the inventory
# exists to rule out. A hash is 64 characters plus two spaces, so the path starts at column 67.
inv_paths="$(cut -c67- "$built/versions.txt" | LC_ALL=C sort)"
zip_paths="$(unzip -Z1 "$archive_tmp" | grep -v '/$' | LC_ALL=C sort)"
if [[ "$inv_paths" != "$zip_paths" ]]; then
  diff <(printf '%s\n' "$inv_paths") <(printf '%s\n' "$zip_paths") >&2 || true
  die "the inventory and the archive disagree; nothing was published"
fi

mv -- "$archive_tmp" "$archive"
mv -- "$built/versions.txt" "$versions"
mv -- "$built/manifest.json" "$manifest"

printf '\nclient pack: %s (%s)\n' "$archive" "$(du -h "$archive" | cut -f1)"
printf 'manifest:    %s\n' "$manifest"
printf 'files:       %s\n' "$versions"
printf '\nThis is a complete client install. A player extracts it into their Valheim game folder,\nsets the Steam launch parameter for their platform, and presses Play. See docs/wiki/pack.md.\n'
