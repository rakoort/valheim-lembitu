#!/usr/bin/env bash
# Exercise character policy generation, enrollment phases and consumer-visible DLL drift.
# Usage: bash test/servermanager-policy.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
passed=0; failed=0
report() { if [[ "$1" == ok ]]; then echo "pass: $2"; passed=$((passed + 1)); else echo "FAIL: $2"; failed=$((failed + 1)); fi; }
mkdir -p "$WORK/pack/BepInEx/plugins/Combat" "$WORK/pack/BepInEx/plugins/Tally" \
  "$WORK/pack/BepInEx/plugins/AzuClock" "$WORK/pack/BepInEx/plugins/oathbound_addon" \
  "$WORK/pack/BepInEx/plugins/Server_devcommands" "$WORK/store/characters/account"
write_managed() {
  python3 - "$1" "$2" <<'PY'
import struct
import sys
from pathlib import Path
data = bytearray(512)
data[:2] = b"MZ"
struct.pack_into("<I", data, 60, 128)
data[128:132] = b"PE\0\0"
struct.pack_into("<H", data, 152, 0x10b)
struct.pack_into("<II", data, 152 + 96 + 14 * 8, 1, 72)
Path(sys.argv[1]).write_bytes(data + sys.argv[2].encode())
PY
}
write_managed "$WORK/pack/BepInEx/plugins/Combat/Combat.dll" combat
write_managed "$WORK/pack/BepInEx/plugins/Tally/Tally.dll" tally
write_managed "$WORK/pack/BepInEx/plugins/AzuClock/AzuClock.dll" clock
write_managed "$WORK/pack/BepInEx/plugins/oathbound_addon/Addon.dll" addon
write_managed "$WORK/pack/BepInEx/plugins/Server_devcommands/server_devcommands.dll" admin
printf native > "$WORK/pack/BepInEx/plugins/Combat/libvlc.dll"
printf character > "$WORK/store/characters/account/Hero.fch"
printf 'jobs: []\n' > "$WORK/store/cron.yml"
run() { "$ROOT/scripts/servermanager-policy.sh" "$1" --pack "$WORK/pack" --store "$WORK/store" --load-server-character "${2:-false}" > "$WORK/out" 2>&1; }
if run apply && [[ -f "$WORK/store/required/Tally/Tally.dll" ]] \
  && [[ -f "$WORK/store/optional/AzuClock/AzuClock.dll" ]] \
  && [[ -f "$WORK/store/optional/oathbound_addon/Addon.dll" ]] \
  && [[ ! -e "$WORK/store/required/Server_devcommands" ]] \
  && [[ ! -e "$WORK/store/required/Combat/libvlc.dll" ]] \
  && [[ "$(cat "$WORK/store/characters/account/Hero.fch")" == character ]] \
  && [[ "$(cat "$WORK/store/cron.yml")" == 'jobs: []' ]]; then report ok "requires Tally, permits presentation omission, excludes admin tools and preserves character/cron files"; else report fail "requires Tally, permits presentation omission, excludes admin tools and preserves character/cron files"; fi
printf altered > "$WORK/store/required/Tally/Tally.dll"
if ! run check && grep -q 'Tally/Tally.dll' "$WORK/out"; then report ok "altered required DLL fails drift check"; else report fail "altered required DLL fails drift check"; fi
run apply
rm "$WORK/store/optional/AzuClock/AzuClock.dll"
if ! run check; then report ok "missing optional reference fails policy drift check (not client admission)"; else report fail "missing optional reference fails policy drift check (not client admission)"; fi
run apply
printf retired > "$WORK/store/required/Retired.dll"
if ! run check && run apply && [[ ! -e "$WORK/store/required/Retired.dll" ]]; then report ok "extra retired reference is rejected and removed on regeneration"; else report fail "extra retired reference is rejected and removed on regeneration"; fi
if ! run check true && run apply true && run check true && ! run check false; then report ok "enrollment phase is explicit and checked"; else report fail "enrollment phase is explicit and checked"; fi
printf '\nstatCaps:\n  action: kick\n' >> "$WORK/store/ServerManager.yml"
if ! run check true; then report ok "settings drift fails rather than silently accepting kick policy"; else report fail "settings drift fails rather than silently accepting kick policy"; fi
rm -rf "$WORK/pack/BepInEx/plugins"
mkdir -p "$WORK/pack/BepInEx/plugins"
if ! run apply; then report ok "empty Pack cannot erase active admission references"; else report fail "empty Pack cannot erase active admission references"; fi
printf '%s passed, %s failed\n' "$passed" "$failed"
[[ "$failed" == 0 ]]
