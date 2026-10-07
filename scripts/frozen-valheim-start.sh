#!/usr/bin/env bash
# Replace the image updater with start-only supervision of an already accepted installation.
# Mounted by launch-server.sh at /usr/local/bin/valheim-updater; never downloads or extracts.
#
# The image's own BepInEx install replaces BepInEx/config with a link to /config/bepinex
# (/usr/local/etc/valheim/common, the mod installer). Without that link the mods write their
# configuration inside the game tree, where the enforced overlay never reaches it. An installation
# the updater never prepared has no link, so this script makes it; a real directory there holds
# configuration of its own and is refused rather than moved.
set -euo pipefail
VALHEIM_ROOT=${VALHEIM_ROOT:-/opt/valheim}
CONFIG_ROOT=${CONFIG_ROOT:-/config}
[[ -x "$VALHEIM_ROOT/server/valheim_server.x86_64" ]] || { echo 'accepted game installation missing' >&2; exit 1; }
[[ -x "$VALHEIM_ROOT/bepinex/valheim_server.x86_64" ]] || { echo 'accepted modded game installation missing' >&2; exit 1; }
[[ -f "$VALHEIM_ROOT/bepinex/BepInEx/core/BepInEx.dll" ]] || { echo 'accepted BepInEx installation missing' >&2; exit 1; }
link="$VALHEIM_ROOT/bepinex/BepInEx/config"
if [[ -L "$link" ]]; then
  [[ "$(readlink "$link")" == "$CONFIG_ROOT/bepinex" ]] \
    || { echo "BepInEx/config points at $(readlink "$link"), not $CONFIG_ROOT/bepinex" >&2; exit 1; }
elif [[ -e "$link" ]]; then
  echo "BepInEx/config is a real directory; move its files into $CONFIG_ROOT/bepinex and remove it" >&2
  exit 1
else
  mkdir -p "$CONFIG_ROOT/bepinex"
  ln -s "$CONFIG_ROOT/bepinex" "$link"
fi
[[ "${FROZEN_START_DRY_RUN:-}" == 1 ]] && exit 0
supervisorctl start valheim-server
exec sleep infinity
