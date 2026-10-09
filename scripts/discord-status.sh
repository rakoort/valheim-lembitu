#!/usr/bin/env bash
# Refresh the Discord status message and rate-limited voice-channel name once.
set +x
set -euo pipefail
umask 077
state=${LEMBITU_DISCORD_STATUS_STATE:-$HOME/.local/state/lembitu/discord-status.json}
mkdir -p "$(dirname "$state")"
exec 9>"$state.lock"
flock -n 9 || exit 0
export LEMBITU_DISCORD_STATUS_STATE="$state"
# shellcheck source=scripts/lib/python.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
run_python "$(dirname "${BASH_SOURCE[0]}")/discord-status.py"
