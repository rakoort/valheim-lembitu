#!/usr/bin/env bash
# Populate lib/valheim/ and lib/bepinex/ with the assemblies plugins compile against.
#
# Game assemblies are copied from a local Valheim install (client or dedicated server); they are
# never committed. The BepInEx pack is downloaded from Thunderstore at a pinned version and hash,
# so the loader we compile against is byte-identical to the one we deploy.
#
# Usage:
#   scripts/extract-refs.sh            extract (idempotent)
#   scripts/extract-refs.sh --check    verify lib/ still matches the recorded hashes
#
# Override auto-detection with VALHEIM_MANAGED=/path/to/..._Data/Managed

set -euo pipefail

BEPINEX_PACK_VERSION="5.4.2350"   # BepInEx 5.4.23.5
BEPINEX_PACK_SHA256="37a91c000b4e88f2ed7a4bd7d812239852d2e36cbf0ff0a9f5faacfba46b105f"
BEPINEX_PACK_URL="https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/${BEPINEX_PACK_VERSION}/"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALHEIM_REF_DIR="$REPO_ROOT/lib/valheim"
BEPINEX_REF_DIR="$REPO_ROOT/lib/bepinex"
CACHE_DIR="$REPO_ROOT/lib/.cache"
LOCK_FILE="$VALHEIM_REF_DIR/refs.lock.json"

# Game code and its managed dependencies. mscorlib/netstandard/System.* are deliberately excluded:
# the net472 reference assemblies from NuGet provide those, and shipping Unity's copies alongside
# them makes every build fail with duplicate-type errors.
REF_GLOBS=(
  'assembly_*.dll'
  'Unity*.dll'
  'gui_framework.dll'
  'SoftReferenceableAssets.dll'
  'Splatform*.dll'
  'com.rlabrecque.steamworks.net.dll'
)

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

resolve_managed_dir() {
  if [[ -n "${VALHEIM_MANAGED:-}" ]]; then
    [[ -f "$VALHEIM_MANAGED/assembly_valheim.dll" ]] \
      || die "VALHEIM_MANAGED=$VALHEIM_MANAGED has no assembly_valheim.dll"
    printf '%s\n' "$VALHEIM_MANAGED"
    return
  fi

  # The test server installed by scripts/test-server.sh is the preferred source: it is the same
  # build the plugins will run on.
  local test_server_dir="${VALHEIM_TEST_DIR:-${VALHEIM_TEST_CACHE:-$HOME/.cache/valheim-lembitu}/server}"
  local candidates=(
    "$test_server_dir/valheim_server_Data/Managed"
    # Dedicated server installed by SteamCMD
    "$HOME/.steam/steam/steamapps/common/Valheim dedicated server/valheim_server_Data/Managed"
    "$HOME/.local/share/Steam/steamapps/common/Valheim dedicated server/valheim_server_Data/Managed"
    "/opt/valheim/server/valheim_server_Data/Managed"
    # Game client
    "$HOME/.steam/steam/steamapps/common/Valheim/valheim_Data/Managed"
    "$HOME/.local/share/Steam/steamapps/common/Valheim/valheim_Data/Managed"
    "$HOME/Library/Application Support/Steam/steamapps/common/Valheim/valheim.app/Contents/Resources/Data/Managed"
  )
  local dir
  for dir in "${candidates[@]}"; do
    [[ -f "$dir/assembly_valheim.dll" ]] && { printf '%s\n' "$dir"; return; }
  done
  die "no Valheim install found; set VALHEIM_MANAGED to the *_Data/Managed directory"
}

fetch_bepinex_pack() {
  local zip="$CACHE_DIR/BepInExPack_Valheim-${BEPINEX_PACK_VERSION}.zip"
  mkdir -p "$CACHE_DIR"
  if [[ ! -f "$zip" ]]; then
    echo "downloading BepInExPack_Valheim $BEPINEX_PACK_VERSION"
    curl -sSL -o "$zip.tmp" "$BEPINEX_PACK_URL"
    mv "$zip.tmp" "$zip"
  fi
  local got
  got="$(sha256 "$zip")"
  [[ "$got" == "$BEPINEX_PACK_SHA256" ]] \
    || die "BepInEx pack hash mismatch: expected $BEPINEX_PACK_SHA256, got $got"

  rm -rf "$BEPINEX_REF_DIR"
  mkdir -p "$BEPINEX_REF_DIR"
  unzip -q "$zip" -d "$BEPINEX_REF_DIR/pack"
  # The two assemblies plugins compile against live at the top of lib/bepinex/;
  # lib/bepinex/pack/ keeps the whole pack for deploying to a server.
  cp "$BEPINEX_REF_DIR/pack/BepInExPack_Valheim/BepInEx/core/BepInEx.dll" "$BEPINEX_REF_DIR/"
  cp "$BEPINEX_REF_DIR/pack/BepInExPack_Valheim/BepInEx/core/0Harmony.dll" "$BEPINEX_REF_DIR/"
}

write_lock() {
  local managed="$1" file rel
  {
    echo '{'
    printf '  "extractedAt": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "valheimSource": "%s",\n' "$managed"
    printf '  "bepinexPack": "denikson-BepInExPack_Valheim-%s",\n' "$BEPINEX_PACK_VERSION"
    echo '  "files": {'
    local first=1
    for file in "$VALHEIM_REF_DIR"/*.dll "$BEPINEX_REF_DIR"/*.dll; do
      rel="${file#"$REPO_ROOT/"}"
      [[ $first -eq 1 ]] || echo ','
      first=0
      printf '    "%s": "%s"' "$rel" "$(sha256 "$file")"
    done
    echo ''
    echo '  }'
    echo '}'
  } > "$LOCK_FILE"
}

check_lock() {
  [[ -f "$LOCK_FILE" ]] || die "no $LOCK_FILE; run scripts/extract-refs.sh"
  local failures=0 rel expected actual
  while IFS=$'\t' read -r rel expected; do
    if [[ ! -f "$REPO_ROOT/$rel" ]]; then
      echo "missing: $rel"; failures=$((failures + 1)); continue
    fi
    actual="$(sha256 "$REPO_ROOT/$rel")"
    if [[ "$actual" != "$expected" ]]; then
      echo "changed: $rel"; failures=$((failures + 1))
    fi
  done < <(sed -n 's/^    "\(.*\)": "\(.*\)".*$/\1\t\2/p' "$LOCK_FILE")

  if [[ $failures -gt 0 ]]; then
    die "$failures reference assemblies drifted from $LOCK_FILE; re-run scripts/extract-refs.sh"
  fi
  echo "references match $LOCK_FILE"
}

if [[ "${1:-}" == "--check" ]]; then
  check_lock
  exit 0
fi
[[ $# -eq 0 ]] || die "unknown argument: $1"

MANAGED_DIR="$(resolve_managed_dir)"
echo "game assemblies: $MANAGED_DIR"

rm -rf "$VALHEIM_REF_DIR"
mkdir -p "$VALHEIM_REF_DIR"
copied=0
for glob in "${REF_GLOBS[@]}"; do
  for file in "$MANAGED_DIR"/$glob; do
    [[ -f "$file" ]] || continue
    cp "$file" "$VALHEIM_REF_DIR/"
    copied=$((copied + 1))
  done
done
[[ -f "$VALHEIM_REF_DIR/assembly_valheim.dll" ]] || die "assembly_valheim.dll was not copied"

fetch_bepinex_pack
write_lock "$MANAGED_DIR"

echo "copied $copied game assemblies to lib/valheim/"
echo "BepInEx $BEPINEX_PACK_VERSION references in lib/bepinex/, full pack in lib/bepinex/pack/"
echo "recorded hashes in ${LOCK_FILE#"$REPO_ROOT/"}"
