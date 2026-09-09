#!/usr/bin/env bash
# Run a Valheim 1.0.7 dedicated server with the plugins from dist/plugins/ loaded, so a plugin can
# be proven to chainload before it goes near the live server.
#
#   scripts/test-server.sh install   download server files, install BepInEx, install our plugins
#   scripts/test-server.sh run       start the server in the foreground (Ctrl-C to stop)
#   scripts/test-server.sh install run
#
# Requires an x86_64 Linux host (astral-bicep): the dedicated server is linux/amd64 only, and its
# Mono runtime dies on Apple Silicon under both Rosetta and QEMU. See docs/build.md.
#
# Game files come from DepotDownloader rather than SteamCMD: no Steam account, no 32-bit
# dependencies, and it is a single self-contained binary.
#
# Environment:
#   VALHEIM_TEST_DIR   where server files live (default ~/.cache/valheim-lembitu/server)
#   VALHEIM_TEST_ARGS  server arguments (default a private world named LembituTest)

set -euo pipefail

DEPOTDOWNLOADER_VERSION="3.4.0"
VALHEIM_SERVER_APPID="896660"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${VALHEIM_TEST_CACHE:-$HOME/.cache/valheim-lembitu}"
SERVER_DIR="${VALHEIM_TEST_DIR:-$CACHE_DIR/server}"
PACK_DIR="$REPO_ROOT/lib/bepinex/pack/BepInExPack_Valheim"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ensure_depotdownloader() {
  local bin="$CACHE_DIR/DepotDownloader" asset
  if [[ -x "$bin" ]]; then printf '%s\n' "$bin"; return; fi
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  asset="DepotDownloader-linux-x64.zip" ;;
    Linux-aarch64) asset="DepotDownloader-linux-arm64.zip" ;;
    Darwin-arm64)  asset="DepotDownloader-macos-arm64.zip" ;;
    Darwin-x86_64) asset="DepotDownloader-macos-x64.zip" ;;
    *) die "no DepotDownloader build for $(uname -s)-$(uname -m)" ;;
  esac
  mkdir -p "$CACHE_DIR"
  echo "downloading DepotDownloader $DEPOTDOWNLOADER_VERSION" >&2
  curl -sSL -o "$CACHE_DIR/depotdownloader.zip" \
    "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOTDOWNLOADER_VERSION}/${asset}"
  unzip -oq "$CACHE_DIR/depotdownloader.zip" -d "$CACHE_DIR"
  chmod +x "$bin"
  printf '%s\n' "$bin"
}

do_install() {
  [[ -d "$PACK_DIR" ]] || die "no BepInEx pack in lib/bepinex/pack/; run scripts/extract-refs.sh"

  local depotdownloader
  depotdownloader="$(ensure_depotdownloader)"
  # Anonymous login: the dedicated server app is free. Re-running validates and repairs.
  "$depotdownloader" -app "$VALHEIM_SERVER_APPID" -os linux -osarch 64 -dir "$SERVER_DIR"

  # BepInEx: the same pinned pack the plugins compile against.
  cp -R "$PACK_DIR/BepInEx" "$SERVER_DIR/"
  cp -R "$PACK_DIR/doorstop_libs" "$SERVER_DIR/"
  cp "$PACK_DIR/doorstop_config.ini" "$PACK_DIR/.doorstop_version" "$SERVER_DIR/"
  cp "$PACK_DIR/start_server_bepinex.sh" "$SERVER_DIR/"
  chmod +x "$SERVER_DIR/start_server_bepinex.sh" "$SERVER_DIR/valheim_server.x86_64"

  "$REPO_ROOT/scripts/install-plugins.sh" "$SERVER_DIR/BepInEx/plugins"
  echo "test server ready in $SERVER_DIR"
}

do_run() {
  [[ -x "$SERVER_DIR/valheim_server.x86_64" ]] || die "no server in $SERVER_DIR; run: scripts/test-server.sh install"
  [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" ]] \
    || die "the dedicated server only runs on x86_64 Linux; use astral-bicep (see docs/build.md)"

  local args=(-name "Lembitu test" -port 2456 -world LembituTest -password lembitutest -public 0)
  if [[ -n "${VALHEIM_TEST_ARGS:-}" ]]; then
    read -r -a args <<< "$VALHEIM_TEST_ARGS"
  fi

  cd "$SERVER_DIR"
  export DOORSTOP_ENABLED=1
  export DOORSTOP_TARGET_ASSEMBLY=./BepInEx/core/BepInEx.Preloader.dll
  export LD_LIBRARY_PATH="./doorstop_libs:./linux64:${LD_LIBRARY_PATH:-}"
  export LD_PRELOAD="libdoorstop_x64.so:${LD_PRELOAD:-}"
  export SteamAppId=892970
  exec ./valheim_server.x86_64 "${args[@]}"
}

[[ $# -gt 0 ]] || die "usage: scripts/test-server.sh install|run"
for cmd in "$@"; do
  case "$cmd" in
    install) do_install ;;
    run) do_run ;;
    *) die "unknown command: $cmd" ;;
  esac
done
