#!/usr/bin/env bash
# Refresh the native Linux test client from Steam's Linux depots.
#
#   scripts/refresh-test-client.sh --username <steam account>   first run: approve a QR code
#   scripts/refresh-test-client.sh                              later runs: no interaction
#   scripts/refresh-test-client.sh --qr --username <account>    log in by QR code again
#   [--branch <name>]                                           default: public
#
# Native tests run a Linux copy of the game at ~/.cache/valheim-lembitu/client (scripts/test-client.sh,
# scripts/native_session.py), separate from the Steam installation, which stays on Proton (owner,
# 2026-10-19). Copying the Steam install would copy the Windows build, so this downloads the game's
# Linux depots with DepotDownloader into a fresh directory, refuses a download without the native
# binary, adds the steam_appid.txt a copy outside the Steam library needs to start, records where the
# copy came from, and swaps it in under the native-session lock. The copy it replaces stays beside it
# as client.previous until the next refresh.
#
# Login: the first run shows a QR code; approve it in the Steam mobile app. DepotDownloader keeps the
# login token itself, and this script notes the account name (not a secret) in steam-account beside
# the copy, so later runs log in by that name without interaction. DepotDownloader refuses -qr together
# with -username, which is why the name is asked for rather than read. No password is ever typed into
# or stored by this script.
#
# Environment (for tests): VALHEIM_CACHE_DIR (default ~/.cache/valheim-lembitu), DEPOTDOWNLOADER
# (default <cache>/DepotDownloader), LEMBITU_NATIVE_LOCK (default ~/lembitu-native.lock).

set -euo pipefail

APP=892970
CACHE="${VALHEIM_CACHE_DIR:-$HOME/.cache/valheim-lembitu}"
DEPOTDOWNLOADER="${DEPOTDOWNLOADER:-$CACHE/DepotDownloader}"
LOCK="${LEMBITU_NATIVE_LOCK:-$HOME/lembitu-native.lock}"
TARGET="$CACHE/client"
DOWNLOAD="$CACHE/client.download"
PREVIOUS="$CACHE/client.previous"
ACCOUNT_FILE="$CACHE/steam-account"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

USERNAME=""
BRANCH="public"
QR=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --username) [[ $# -ge 2 ]] || die "--username needs a value"; USERNAME="$2"; shift 2 ;;
    --branch) [[ $# -ge 2 ]] || die "--branch needs a value"; BRANCH="$2"; shift 2 ;;
    --qr) QR=1; shift ;;
    -h|--help) sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -x "$DEPOTDOWNLOADER" ]] || die "no DepotDownloader at $DEPOTDOWNLOADER"
mkdir -p "$CACHE"
if [[ "$QR" == 0 && -s "$ACCOUNT_FILE" ]]; then
  account="$(<"$ACCOUNT_FILE")"
  [[ -z "$USERNAME" || "$USERNAME" == "$account" ]] \
    || die "the saved login is $account; add --qr to log in as $USERNAME instead"
  login=(-username "$account" -remember-password)
else
  [[ -n "$USERNAME" ]] \
    || die "first run: pass --username <your Steam account name>; you approve the login with a QR code in the Steam mobile app"
  account="$USERNAME"
  login=(-qr -remember-password)
fi

# Always a fresh directory: a half-finished or failed download never becomes the test client.
rm -rf "$DOWNLOAD"
"$DEPOTDOWNLOADER" -app "$APP" -os linux -branch "$BRANCH" -dir "$DOWNLOAD" "${login[@]}"
printf '%s\n' "$account" > "$ACCOUNT_FILE"

[[ -f "$DOWNLOAD/valheim.x86_64" ]] \
  || die "the download has no valheim.x86_64; the test client is unchanged"
[[ -f "$DOWNLOAD/valheim_Data/Managed/assembly_valheim.dll" ]] \
  || die "the download has no valheim_Data/Managed/assembly_valheim.dll; the test client is unchanged"
# DepotDownloader does not keep the executable bit Steam sets (measured 2026-10-19: valheim.x86_64
# arrived as 0644), and the native session runs the binary directly.
chmod +x "$DOWNLOAD/valheim.x86_64"
find "$DOWNLOAD" -maxdepth 1 -name '*.so*' -exec chmod +x {} +

manifests="$(ls "$DOWNLOAD/.DepotDownloader" 2>/dev/null | sed -n 's/\.manifest$//p' | tr '\n' ' ')"
rm -rf "$DOWNLOAD/.DepotDownloader"
printf '%s\n' "$APP" > "$DOWNLOAD/steam_appid.txt"
printf 'native Linux client, app %s branch %s, depot_manifest %s, downloaded %s by scripts/refresh-test-client.sh\n' \
  "$APP" "$BRANCH" "${manifests:-unrecorded }" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DOWNLOAD/.lembitu-source"

# Swap under the lock every native session holds, so no running session loses its client.
exec 9>"$LOCK"
if ! flock -n 9; then
  echo "a native session holds $LOCK; waiting for it to finish"
  flock 9
fi
rm -rf "$PREVIOUS"
if [[ -d "$TARGET" ]]; then
  mv "$TARGET" "$PREVIOUS"
fi
mv "$DOWNLOAD" "$TARGET"
echo "test client refreshed: $(<"$TARGET/.lembitu-source")"
