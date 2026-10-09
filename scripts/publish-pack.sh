#!/usr/bin/env bash
# Publish an already-built pack, then announce it; never builds or deploys.
set +x
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry=false
out="$ROOT/dist-client"
label='' notes='' changes=''
usage() { echo 'Usage: publish-pack.sh [--dry-run] [--out DIR] --version LABEL --notes-file FILE --changes "Short changes"'; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
while (($#)); do
  case "$1" in
    --dry-run) dry=true; shift ;;
    --out) out=${2:?}; shift 2 ;;
    --version) label=${2:?}; shift 2 ;;
    --notes-file) notes=${2:?}; shift 2 ;;
    --changes) changes=${2:?}; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done
[[ "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die 'a safe --version label is required'
[[ -s "$notes" ]] || die 'a nonempty --notes-file is required'
[[ -n "$changes" && ${#changes} -le 1000 ]] || die '--changes must contain 1–1000 characters'
out="$(cd "$out" && pwd)"
notes="$(cd "$(dirname "$notes")" && pwd)/$(basename "$notes")"
assets=()
for suffix in zip manifest.json versions.txt; do
  asset="$out/lembitu-client-pack-$label.$suffix"
  [[ -s "$asset" ]] || die "missing artifact: $asset"
  assets+=("$asset")
done
for cmd in gh jq; do command -v "$cmd" >/dev/null || die "missing dependency: $cmd"; done
read_value() {
  local file=$1 key=$2 line
  [[ -f "$file" ]] || return 1
  while IFS= read -r line; do
    if [[ "$line" == "$key="* ]]; then printf '%s' "${line#*=}"; return 0; fi
  done < "$file"
  return 1
}
role=$(read_value "$HOME/.config/lembitu/discord.env" DISCORD_ROLE_PLAYER_ID) || die 'missing Player role ID'
[[ "$role" =~ ^[0-9]+$ ]] || die 'invalid Player role ID'
umask 077
work=$(mktemp -d)
trap 'unset webhook; rm -rf "$work"' EXIT
# Preflight Discord configuration before publishing; dry runs do not need a secret.
if ! $dry; then
  command -v curl >/dev/null || die 'missing dependency: curl'
  webhook=$(read_value "$HOME/.config/lembitu/discord-webhooks.env" DISCORD_WEBHOOK_PACK_RELEASES) || die 'missing PACK_RELEASES webhook'
  [[ "$webhook" =~ ^https://discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$ ]] || die 'invalid PACK_RELEASES webhook'
fi
cd "$ROOT"
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die 'cannot resolve GitHub repository'
tag="client-pack-$label"
link="https://github.com/$repo/releases/download/$tag/lembitu-client-pack-$label.zip"
content=$(printf '<@&%s> **Client pack %s**\n%s\nDownload: %s\n**Reinstall required:** replace your old client pack with this release before joining.' "$role" "$label" "$changes" "$link")
jq -n --arg content "$content" --arg role "$role" '{content:$content,allowed_mentions:{parse:[],roles:[$role],users:[],replied_user:false}}' > "$work/post.json"
if $dry; then
  printf 'Would publish %s with three artifacts and notes from %s\n' "$tag" "$notes"
  cat "$work/post.json"
  exit 0
fi
gh release create "$tag" "${assets[@]}" --title "Client pack $label" --notes-file "$notes"
# Send the webhook secret only through curl stdin, never argv, logs or disk.
if ! printf 'url = "%s"\n' "$webhook" | curl --config - --silent --fail --output "$work/response" \
    --header 'Content-Type: application/json' --data-binary "@$work/post.json"; then
  die "release published, but Discord announcement failed; release: https://github.com/$repo/releases/tag/$tag"
fi
printf 'Published and announced client pack %s\n' "$label"
