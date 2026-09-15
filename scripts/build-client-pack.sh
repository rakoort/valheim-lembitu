#!/usr/bin/env bash
# Build the client Pack a player installs (#21).
#
#   scripts/build-client-pack.sh --list
#   scripts/build-client-pack.sh [--out <dir>] [--version <label>]
#                               [--pins <file>] [--cache <dir>] [--lock <file>]
#
# The client Pack is the adopted pin list, staged into a BepInEx-shaped tree and archived for
# distribution. It is NOT the server's dist/: two things differ, and both matter.
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
# BoneMod is adopted and client-side: players need it and the server does not.
#
# Staging is delegated to scripts/stage-stack.sh, which owns pin parsing, hash verification,
# dependency closure and the package-layout normalisation. This script adds what is specific to a
# player-facing distribution: the exclusions, the assertions that they hold, a manifest a player's
# install can be checked against, and the archive.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGER="$REPO_ROOT/scripts/stage-stack.sh"

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
( cd "$stage" && find plugins -mindepth 2 -type f | grep -q . ) \
  || die "client pack staged no package files"

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
# list the install checklist compares against. The staging ledger (`.staged-dirs`) is builder
# bookkeeping, not pack content, and is left out of both this list and the archive.
( cd "$stage" && find . -type f ! -name '.staged-dirs' | LC_ALL=C sort | while IFS= read -r f; do
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

mv -- "$archive_tmp" "$archive"
mv -- "$built/versions.txt" "$versions"
mv -- "$built/manifest.json" "$manifest"

printf '\nclient pack: %s (%s)\n' "$archive" "$(du -h "$archive" | cut -f1)"
printf 'manifest:    %s\n' "$manifest"
printf 'files:       %s\n' "$versions"
printf '\nplayers extract this over their Valheim install; see docs/wiki/pack.md for the checklist.\n'
