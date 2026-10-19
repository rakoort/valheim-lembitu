#!/usr/bin/env bash
# Behaviour tests for scripts/refresh-test-client.sh: the login it asks DepotDownloader for, the
# swap that keeps one previous copy, and the refusals that must leave the working test client alone.
#
#   test/refresh-test-client.test.sh
#
# A fake DepotDownloader writes a game-shaped directory; nothing is downloaded. flock is stubbed,
# as in the monitor tests, because macOS has none.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REFRESH="$REPO_ROOT/scripts/refresh-test-client.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0

report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

mkdir -p "$WORK/bin"
cat > "$WORK/bin/DepotDownloader" <<'EOF'
#!/usr/bin/env bash
# Records its arguments; FAKE_MODE good|nobinary|fail decides what it leaves in -dir.
printf '%s\n' "$*" > "$FAKE_ARGS"
dir=""
while [[ $# -gt 0 ]]; do [[ "$1" == -dir ]] && dir="$2"; shift; done
[[ "$FAKE_MODE" == fail ]] && exit 1
mkdir -p "$dir/valheim_Data/Managed" "$dir/.DepotDownloader"
printf 'game %s\n' "$FAKE_BUILD" > "$dir/valheim_Data/Managed/assembly_valheim.dll"
touch "$dir/.DepotDownloader/892971_4242.manifest"
# Like the real tool, the fake leaves the binary and libraries without the executable bit.
if [[ "$FAKE_MODE" == good ]]; then printf 'elf\n' > "$dir/valheim.x86_64"; printf 'lib\n' > "$dir/UnityPlayer.so"; fi
exit 0
EOF
printf '#!/bin/sh\necho "$*" >> "$FAKE_LOCKS"\nexit 0\n' > "$WORK/bin/flock"
chmod +x "$WORK/bin/DepotDownloader" "$WORK/bin/flock"

CACHE="$WORK/cache"
export PATH="$WORK/bin:$PATH" VALHEIM_CACHE_DIR="$CACHE" DEPOTDOWNLOADER="$WORK/bin/DepotDownloader"
export LEMBITU_NATIVE_LOCK="$WORK/native.lock" FAKE_ARGS="$WORK/args" FAKE_LOCKS="$WORK/locks"
export FAKE_MODE=good FAKE_BUILD=old

# The stale copy a refresh replaces.
mkdir -p "$CACHE/client/valheim_Data/Managed"
printf 'game 1.0.17\n' > "$CACHE/client/valheim_Data/Managed/assembly_valheim.dll"
game_of() { cat "$1/valheim_Data/Managed/assembly_valheim.dll"; }

if ! "$REFRESH" >/dev/null 2>&1 && [[ ! -e "$FAKE_ARGS" ]] && [[ "$(game_of "$CACHE/client")" == "game 1.0.17" ]]; then
  report ok "a first run without --username is refused before anything downloads"
else
  report fail "a first run without --username is refused before anything downloads"
fi

FAKE_BUILD=one "$REFRESH" --username alice >/dev/null
if [[ "$(<"$FAKE_ARGS")" == *"-qr -remember-password"* && "$(<"$FAKE_ARGS")" != *"-username"* \
   && "$(<"$FAKE_ARGS")" == *"-os linux"* && "$(<"$CACHE/steam-account")" == alice ]]; then
  report ok "the first run logs in by QR code, for the Linux depots, and notes the account name"
else
  report fail "the first run logs in by QR code, for the Linux depots, and notes the account name: $(<"$FAKE_ARGS")"
fi
if [[ "$(game_of "$CACHE/client")" == "game one" && "$(game_of "$CACHE/client.previous")" == "game 1.0.17" \
   && -x "$CACHE/client/valheim.x86_64" && -x "$CACHE/client/UnityPlayer.so" \
   && "$(<"$CACHE/client/steam_appid.txt")" == 892970 && ! -e "$CACHE/client/.DepotDownloader" \
   && "$(<"$CACHE/client/.lembitu-source")" == *"892971_4242"* && -s "$FAKE_LOCKS" && ! -e "$CACHE/client.download" ]]; then
  report ok "the download is swapped in under the lock, executable, with steam_appid.txt and its provenance, the old copy kept"
else
  report fail "the download is swapped in under the lock, executable, with steam_appid.txt and its provenance, the old copy kept"
fi

FAKE_BUILD=two "$REFRESH" >/dev/null
if [[ "$(<"$FAKE_ARGS")" == *"-username alice -remember-password"* && "$(<"$FAKE_ARGS")" != *"-qr"* \
   && "$(game_of "$CACHE/client")" == "game two" && "$(game_of "$CACHE/client.previous")" == "game one" ]]; then
  report ok "a later run reuses the saved login without interaction and keeps only one previous copy"
else
  report fail "a later run reuses the saved login without interaction and keeps only one previous copy: $(<"$FAKE_ARGS")"
fi

if ! FAKE_MODE=nobinary FAKE_BUILD=three "$REFRESH" >/dev/null 2>&1 \
   && [[ "$(game_of "$CACHE/client")" == "game two" && "$(game_of "$CACHE/client.previous")" == "game one" ]]; then
  report ok "a download without the native binary is refused and the test client is unchanged"
else
  report fail "a download without the native binary is refused and the test client is unchanged"
fi

if ! FAKE_MODE=fail "$REFRESH" >/dev/null 2>&1 && [[ "$(game_of "$CACHE/client")" == "game two" ]]; then
  report ok "a failed download leaves the test client unchanged"
else
  report fail "a failed download leaves the test client unchanged"
fi

if ! "$REFRESH" --username bob >/dev/null 2>&1 && [[ "$(<"$CACHE/steam-account")" == alice ]]; then
  report ok "another account name without --qr is refused rather than prompting for a password"
else
  report fail "another account name without --qr is refused rather than prompting for a password"
fi

FAKE_BUILD=four "$REFRESH" --qr --username bob >/dev/null
if [[ "$(<"$FAKE_ARGS")" == *"-qr -remember-password"* && "$(<"$CACHE/steam-account")" == bob \
   && "$(game_of "$CACHE/client")" == "game four" ]]; then
  report ok "--qr logs in by QR code again and notes the new account"
else
  report fail "--qr logs in by QR code again and notes the new account: $(<"$FAKE_ARGS")"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
