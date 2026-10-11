#!/usr/bin/env bash
# Milestone oracle: guild claims, live layers, the Chronicle and Discord's typed events (ADR-0036).
# Exit 0 when every surface passes, 2 when any is missing or fails.
set -uo pipefail
cd "$(dirname "$0")/.."

surfaces=(
  test/webmap-coverage.test.sh
  test/webmap-guilds.test.sh
  test/webmap-live-layers.test.sh
  test/webmap-chronicle.test.sh
  test/backup-world.test.sh
  test/discord-chronicle.test.sh
  test/discord-layout.test.sh
  test/discord-status.test.sh
  test/servermanager-discord.test.sh
)

failed=()
for surface in "${surfaces[@]}"; do
  if [[ ! -f $surface ]]; then
    echo "missing: $surface"
    failed+=("$surface")
  elif bash "$surface"; then
    echo "pass: $surface"
  else
    echo "fail: $surface"
    failed+=("$surface")
  fi
done

if (( ${#failed[@]} )); then
  echo "oracle failed: ${failed[*]}"
  exit 2
fi
echo 'oracle passed'
