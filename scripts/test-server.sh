#!/usr/bin/env bash
# Run a Valheim 1.0.7 dedicated server with the plugins from dist/plugins/ loaded, so a plugin can
# be proven to chainload before it goes near the live server.
#
#   scripts/test-server.sh install                     game files, reference assemblies, BepInEx, plugins
#   scripts/test-server.sh run                         start in the foreground (Ctrl-C to stop)
#   scripts/test-server.sh run -world "My World"       replace the server arguments
#
# Requires an x86_64 Linux host (astral-bicep): the dedicated server is linux/amd64 only, and its
# Mono runtime dies on Apple Silicon under both Rosetta and QEMU. See docs/build.md.
#
# Game files come from DepotDownloader rather than SteamCMD: no Steam account, no 32-bit
# dependencies, and it is a single self-contained binary.
#
# Environment:
#   VALHEIM_TEST_DIR   where server files live (default ~/.cache/valheim-lembitu/server)

set -euo pipefail

DEPOTDOWNLOADER_VERSION="3.4.0"
VALHEIM_SERVER_APPID="896660"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_CACHE_DIR="${VALHEIM_TEST_CACHE:-$HOME/.cache/valheim-lembitu}"
SERVER_DIR="${VALHEIM_TEST_DIR:-$SERVER_CACHE_DIR/server}"
PACK_DIR="$REPO_ROOT/lib/bepinex/pack/BepInExPack_Valheim"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Pinned like the BepInEx pack: this binary downloads the game we test against.
depotdownloader_asset() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  echo "DepotDownloader-linux-x64.zip a999dec66b4850fc961bd50366696d23c2d0fad7b18790e6a5647b2f19097a53" ;;
    Linux-aarch64) echo "DepotDownloader-linux-arm64.zip d9fb612ccebc1db8eeea3b4045d2221ec70431381393ce908fb72f01d4f9c812" ;;
    Darwin-arm64)  echo "DepotDownloader-macos-arm64.zip 60e80c7c496f3f9a079cd3c62036b35d088c27bc0149baf38f009eb57a52f6a5" ;;
    Darwin-x86_64) echo "DepotDownloader-macos-x64.zip 3214b689564d73e9342a8a4aef693de6ad3d293801b0f300a4466f60ec75befb" ;;
    *) die "no DepotDownloader build for $(uname -s)-$(uname -m)" ;;
  esac
}

ensure_depotdownloader() {
  local bin="$SERVER_CACHE_DIR/DepotDownloader" asset expected zip got
  if [[ -x "$bin" ]]; then printf '%s\n' "$bin"; return; fi

  read -r asset expected <<< "$(depotdownloader_asset)"
  zip="$SERVER_CACHE_DIR/$asset"
  mkdir -p "$SERVER_CACHE_DIR"
  echo "downloading DepotDownloader $DEPOTDOWNLOADER_VERSION" >&2
  curl -fsSL -o "$zip.tmp" \
    "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOTDOWNLOADER_VERSION}/${asset}" \
    || { rm -f "$zip.tmp"; die "download failed: $asset"; }
  mv "$zip.tmp" "$zip"
  got="$(sha256 "$zip")"
  [[ "$got" == "$expected" ]] || die "$asset hash mismatch: expected $expected, got $got"

  unzip -oq "$zip" -d "$SERVER_CACHE_DIR"
  chmod +x "$bin"
  printf '%s\n' "$bin"
}

do_install() {
  local depotdownloader
  depotdownloader="$(ensure_depotdownloader)"
  # Anonymous login: the dedicated server app is free. Re-running validates and repairs.
  "$depotdownloader" -app "$VALHEIM_SERVER_APPID" -os linux -osarch 64 -dir "$SERVER_DIR"

  # The server we just installed is also the best source of reference assemblies, and extraction
  # downloads the pinned BepInEx pack we install below.
  VALHEIM_TEST_DIR="$SERVER_DIR" "$REPO_ROOT/scripts/extract-refs.sh"

  # BepInEx: the same pinned pack the plugins compile against.
  cp -R "$PACK_DIR/BepInEx" "$SERVER_DIR/"
  cp -R "$PACK_DIR/doorstop_libs" "$SERVER_DIR/"
  cp "$PACK_DIR/doorstop_config.ini" "$PACK_DIR/.doorstop_version" "$SERVER_DIR/"
  cp "$PACK_DIR/start_server_bepinex.sh" "$SERVER_DIR/"
  chmod +x "$SERVER_DIR/start_server_bepinex.sh" "$SERVER_DIR/valheim_server.x86_64"

  if compgen -G "$REPO_ROOT/dist/plugins/*" > /dev/null; then
    "$REPO_ROOT/scripts/install-plugins.sh" "$SERVER_DIR/BepInEx"
  else
    echo "no plugins built yet; run 'dotnet build' and 'scripts/stage-stack.sh', then scripts/install-plugins.sh $SERVER_DIR/BepInEx"
  fi
  echo "test server ready in $SERVER_DIR"
}

do_run() {
  [[ -x "$SERVER_DIR/valheim_server.x86_64" ]] || die "no server in $SERVER_DIR; run: scripts/test-server.sh install"
  [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]] \
    || die "the dedicated server only runs on x86_64 Linux; use astral-bicep (see docs/build.md)"

  local args=("$@")
  if [[ ${#args[@]} -eq 0 ]]; then
    # 2466, not the usual 2456: bicep already runs the barebones server on the default ports.
    args=(-name "Lembitu test" -port 2466 -world LembituTest -password lembitutest -public 0)
  fi

  cd "$SERVER_DIR"
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY=./BepInEx/core/BepInEx.Preloader.dll
  export LD_LIBRARY_PATH="./doorstop_libs:./linux64:${LD_LIBRARY_PATH:-}"
  export LD_PRELOAD="libdoorstop_x64.so:${LD_PRELOAD:-}"
  export SteamAppId=892970
  exec ./valheim_server.x86_64 "${args[@]}"
}

case "${1:-}" in
  install)
    [[ $# -eq 1 ]] || die "install takes no arguments"
    do_install
    ;;
  run)
    shift
    do_run "$@"
    ;;
  *) die "usage: scripts/test-server.sh install | run [server arguments]" ;;
esac
