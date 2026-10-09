#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" RECORD="$WORK/record"
mkdir -p "$HOME/.config/lembitu" "$WORK/bin" "$WORK/artifacts"
export PATH="$WORK/bin:$PATH"
printf 'DISCORD_ROLE_PLAYER_ID=12345\n' > "$HOME/.config/lembitu/discord.env"
printf 'DISCORD_WEBHOOK_PACK_RELEASES=https://discord.com/api/webhooks/98765/fake_secret\n' > "$HOME/.config/lembitu/discord-webhooks.env"
printf 'Fixed inventory overlap.\n' > "$WORK/notes"
for suffix in zip manifest.json versions.txt; do printf fixture > "$WORK/artifacts/lembitu-client-pack-demo.$suffix"; done
cat > "$WORK/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == 'repo view' ]]; then echo example/lembitu; exit; fi
printf '%s\n' "$@" > "$RECORD.gh"
[[ ${FAIL_RELEASE:-0} == 0 ]]
SH
cat > "$WORK/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$RECORD.curl"
while (($#)); do
  case "$1" in
    --config) [[ "$2" == - ]]; cat > "$RECORD.config"; shift 2 ;;
    --data-binary) cp "${2#@}" "$RECORD.post"; shift 2 ;;
    *) shift ;;
  esac
done
[[ ${FAIL_POST:-0} == 0 ]]
SH
chmod +x "$WORK/bin/gh" "$WORK/bin/curl"
publish() { "$ROOT/scripts/publish-pack.sh" --out "$WORK/artifacts" --version demo --notes-file "$WORK/notes" --changes 'Fixed inventory overlap. @everyone' "$@"; }
publish --dry-run > "$WORK/dry"
[[ ! -e "$RECORD.gh" && ! -e "$RECORD.curl" ]]
grep -q 'Reinstall required' "$WORK/dry"
publish > "$WORK/log"
[[ $(head -3 "$RECORD.gh" | tail -1) == client-pack-demo ]]
for suffix in zip manifest.json versions.txt; do grep -Fxq "$WORK/artifacts/lembitu-client-pack-demo.$suffix" "$RECORD.gh"; done
grep -Fxq -- --notes-file "$RECORD.gh"
grep -Fxq "$WORK/notes" "$RECORD.gh"
jq -e '.allowed_mentions == {parse:[],roles:["12345"],users:[],replied_user:false} and (.content | contains("client-pack-demo/lembitu-client-pack-demo.zip")) and (.content | contains("Reinstall required"))' "$RECORD.post" >/dev/null
if grep -q fake_secret "$RECORD.curl" "$WORK/log" "$WORK/dry"; then exit 1; fi
rm "$RECORD.curl"
if FAIL_RELEASE=1 publish > "$WORK/failure" 2>&1; then exit 1; fi
[[ ! -e "$RECORD.curl" ]]
if FAIL_POST=1 publish > "$WORK/failure" 2>&1; then exit 1; fi
grep -q 'release published, but Discord announcement failed' "$WORK/failure"
for suffix in zip manifest.json versions.txt; do
  mv "$WORK/artifacts/lembitu-client-pack-demo.$suffix" "$WORK/missing"
  rm -f "$RECORD.gh" "$RECORD.curl"
  if publish > "$WORK/failure" 2>&1; then exit 1; fi
  [[ ! -e "$RECORD.gh" && ! -e "$RECORD.curl" ]]
  mv "$WORK/missing" "$WORK/artifacts/lembitu-client-pack-demo.$suffix"
done
printf 'pass: release assets, notes, dry-run, restricted mentions, secrets and failure boundaries\n'
