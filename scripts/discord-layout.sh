#!/usr/bin/env bash
# Reconcile the Run's Discord layout without deleting unrelated resources.
# Usage: discord-layout.sh [--dry-run] [apply | guild NAME CHANNEL-SLUG]
# Requires bash, jq, curl and the wizard's IDs/keychain entry. Dry runs only read Discord.
set +x
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYOUT="$ROOT/config/discord/layout.json"
dry=false
if [[ ${1:-} == --dry-run ]]; then dry=true; shift; fi
mode=${1:-apply}
if [[ $# -gt 0 ]]; then shift; fi
case "$mode" in
  apply) [[ $# == 0 ]] || { echo 'Unexpected arguments' >&2; exit 1; } ;;
  guild) [[ $# == 2 && $2 =~ ^[a-z0-9][a-z0-9-]{0,99}$ && ${#1} -le 80 && -n $1 ]] || { echo 'Usage: discord-layout.sh [--dry-run] guild NAME CHANNEL-SLUG' >&2; exit 1; } ;;
  *) echo 'Usage: discord-layout.sh [--dry-run] [apply | guild NAME CHANNEL-SLUG]' >&2; exit 1 ;;
esac
for cmd in jq curl security; do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }; done
# Read only known non-secret IDs, rather than executing the env file as shell code.
ids="$HOME/.config/lembitu/discord.env"
get_id() {
  local key=$1 value
  value=$(while IFS='=' read -r k v; do [[ $k != "$key" ]] || printf '%s' "$v"; done < "$ids")
  [[ $value =~ ^[0-9]{17,20}$ ]] || { echo "Missing/invalid $key; run scripts/wizard-discord.sh" >&2; exit 1; }
  printf '%s' "$value"
}
guild=$(get_id DISCORD_GUILD_ID)
owner=$(get_id DISCORD_OWNER_USER_ID)
ops=$(get_id DISCORD_OPS_APP_ID)
server=$(get_id DISCORD_SERVER_BOT_APP_ID)
token=$(security find-generic-password -a "$USER" -s lembitu.discord.ops -w 2>/dev/null) || { echo 'Cannot read Ops token; run scripts/wizard-discord.sh' >&2; exit 1; }
[[ -n $token && $token != *$'\n'* && $token != *'"'* && $token != *$'\\'* ]] || { echo 'Invalid keychain token' >&2; exit 1; }
umask 077
work=$(mktemp -d)
trap 'unset token; rm -rf "$work"' EXIT
# Pass the credential through stdin, not curl's process arguments or a token file.
api() {
  local method=$1 path=$2 body=${3:-} status delay line header_delay
  while :; do
    status=$(printf 'header = "Authorization: Bot %s"\n' "$token" | curl --config - --silent --show-error \
      --request "$method" --header 'Content-Type: application/json' \
      --header 'User-Agent: DiscordBot (https://github.com/rakoort/valheim-lembitu, 1)' \
      --data "$body" --dump-header "$work/headers" --output "$work/response" --write-out '%{http_code}' \
      "https://discord.com/api/v10$path" 2>/dev/null) || { echo "Discord transport failed: $method $path" >&2; exit 1; }
    case "$status" in
      2??) cat "$work/response"; return ;;
      429)
        header_delay=''
        while IFS= read -r line; do
          if [[ $line == [Rr][Ee][Tt][Rr][Yy]-[Aa][Ff][Tt][Ee][Rr]:* ]]; then header_delay=${line#*:}; header_delay=${header_delay//$'\r'/}; header_delay=${header_delay// /}; fi
        done < "$work/headers"
        delay=${header_delay:-$(jq -r '.retry_after // empty' "$work/response")}
        [[ $delay =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo 'Discord 429 missing valid Retry-After' >&2; exit 1; }
        echo "Discord rate limit: waiting ${delay}s (all requests paused)" >&2
        sleep "$delay" ;;
      401|403) echo "Discord HTTP $status: $method $path; check bot installation, permissions and role hierarchy; not retrying" >&2; exit 1 ;;
      *) echo "Discord HTTP $status: $method $path; stopped" >&2; exit 1 ;;
    esac
  done
}
roles=$(api GET "/guilds/$guild/roles")
channels=$(api GET "/guilds/$guild/channels")
role_ids=$(jq -nc --arg everyone "$guild" --arg owner "$owner" '{everyone:$everyone,owner:$owner}')
for bot in ops server; do
  if [[ $bot == ops ]]; then app=$ops; else app=$server; fi
  id=$(jq -r --arg app "$app" '[.[] | select(.tags.bot_id == $app)] | if length == 1 then .[0].id else empty end' <<< "$roles")
  [[ -n $id ]] || { echo "Missing unique $bot bot role; complete wizard installation" >&2; exit 1; }
  role_ids=$(jq --arg key "$bot" --arg id "$id" '. + {($key):$id}' <<< "$role_ids")
done
ensure_role() {
  local name=$1 permissions=$2 key=$3 mentionable=${4:-false} matches id actual body
  matches=$(jq --arg n "$name" '[.[] | select(.name == $n and (.managed != true))]' <<< "$roles")
  [[ $(jq length <<< "$matches") -le 1 ]] || { echo "Ambiguous role: $name" >&2; exit 1; }
  id=$(jq -r '.[0].id // empty' <<< "$matches")
  # A webhook can ping a role only when the role is mentionable (the Pack release post pings Player).
  body=$(jq -nc --arg name "$name" --arg p "$permissions" --argjson m "$mentionable" '{name:$name,permissions:$p,mentionable:$m}')
  if [[ -z $id ]]; then
    echo "Create role: $name"
    if $dry; then id="planned-role-$key"; else id=$(api POST "/guilds/$guild/roles" "$body" | jq -er .id); fi
  else
    actual=$(jq -c '.[0] | [.permissions, (.mentionable // false)]' <<< "$matches")
    if [[ $actual != "$(jq -nc --arg p "$permissions" --argjson m "$mentionable" '[$p,$m]')" ]]; then echo "Edit role: $name"; if ! $dry; then api PATCH "/guilds/$guild/roles/$id" "$body" >/dev/null; fi; fi
  fi
  role_ids=$(jq --arg key "$key" --arg id "$id" '. + {($key):$id}' <<< "$role_ids")
}
if [[ $mode == guild ]]; then
  if jq -e --arg n "$2" 'any(.channels[]; .name == $n)' "$LAYOUT" >/dev/null; then
    echo "Guild channel slug is reserved by the layout: $2" >&2; exit 1
  fi
  existing_guild_role=$(jq -r --arg n "Guild · $1" '[.[] | select(.name == $n and .managed != true)] | if length == 1 then .[0].id else "" end' <<< "$roles")
  existing_category=$(jq -r '[.[] | select(.name == "Guilds" and .type == 4)] | if length == 1 then .[0].id else "" end' <<< "$channels")
  if ! jq -e --arg n "$2" --arg p "$existing_category" --arg r "$existing_guild_role" 'all(.[] | select(.name == $n); .type == 0 and .parent_id == $p and $p != "" and $r != "" and any(.permission_overwrites[]?; .type == 0 and .id == $r))' <<< "$channels" >/dev/null; then
    echo "Guild channel slug belongs to another channel or Guild: $2" >&2; exit 1
  fi
fi
while IFS= read -r row; do ensure_role "$(jq -r .name <<< "$row")" "$(jq -r .permissions <<< "$row")" "$(jq -r .name <<< "$row")" "$(jq -r '.mentionable // false' <<< "$row")"; done < <(jq -c '.roles[]' "$LAYOUT")
if [[ $mode == guild ]]; then ensure_role "Guild · $1" 0 Guild; fi
category_ids='{}'
ensure_channel() {
  local name=$1 type=$2 parent=$3 overwrites=$4 matches desired current id result stored=''
  if [[ $type == 2 ]]; then
    stored=$(while IFS='=' read -r k v; do [[ $k != DISCORD_STATUS_VOICE_CHANNEL_ID ]] || printf '%s' "$v"; done < "$ids")
    [[ -z $stored || $stored =~ ^[0-9]{17,20}$ ]] || { echo 'Invalid DISCORD_STATUS_VOICE_CHANNEL_ID' >&2; exit 1; }
  fi
  if [[ -n $stored ]]; then
    matches=$(jq --arg id "$stored" '[.[] | select(.id == $id)]' <<< "$channels")
    if jq -e 'any(.[]; .type != 2)' <<< "$matches" >/dev/null; then
      echo 'Stored status channel is not a voice channel' >&2; exit 1
    fi
  else
    matches=$(jq --arg n "$name" --argjson t "$type" '[.[] | select(.name == $n and .type == $t)]' <<< "$channels")
  fi
  if [[ $type == 0 && ${access:-} == guild ]]; then
    matches=$(jq --arg p "$parent" '[.[] | select(.parent_id == $p)]' <<< "$matches")
  fi
  [[ $(jq length <<< "$matches") -le 1 ]] || { echo "Ambiguous channel/category: $name" >&2; exit 1; }
  id=$(jq -r '.[0].id // empty' <<< "$matches")
  desired=$(jq -nc --arg n "$name" --argjson t "$type" --arg p "$parent" --argjson o "$overwrites" '{name:$n,type:$t,parent_id:(if $p == "" then null else $p end),permission_overwrites:$o}')
  current=$(jq -c '.[0] | {name,type,parent_id:(.parent_id // null),permission_overwrites:((.permission_overwrites // []) | sort_by(.id))}' <<< "$matches")
  if [[ $type == 2 ]]; then
    desired=$(jq --argjson p "$(jq '.status_voice.position' "$LAYOUT")" '. + {position:$p}' <<< "$desired")
    current=$(jq --argjson p "$(jq '.[0].position // null' <<< "$matches")" '. + {position:$p}' <<< "$current")
    # Existing status names belong to the live bot, including during permission repairs.
    if [[ -n $id ]]; then
      desired=$(jq 'del(.name)' <<< "$desired")
      current=$(jq 'del(.name)' <<< "$current")
    fi
  fi
  if [[ -z $id ]]; then
    echo "Create channel/category: $name"
    if $dry; then id="planned-channel-$name"; else result=$(api POST "/guilds/$guild/channels" "$desired"); id=$(jq -er .id <<< "$result"); fi
  elif [[ "$(jq -Sc '.permission_overwrites |= sort_by(.id)' <<< "$desired")" != "$(jq -Sc . <<< "$current")" ]]; then
    echo "Edit channel/category: $name"
    if ! $dry; then api PATCH "/channels/$id" "$desired" >/dev/null; fi
  fi
  channel_id=$id
}
# Explicit owner member overwrite: the owner remains the only human admin.
common=$(jq -nc --argjson ids "$role_ids" '[{id:$ids.owner,type:1,allow:"117760",deny:"0"},{id:$ids.ops,type:0,allow:"117760",deny:"0"},{id:$ids.server,type:0,allow:"117760",deny:"0"}]')
voice_overwrites=$(jq -c --argjson ids "$role_ids" '[.status_voice.permission_overwrites[] | {id:$ids[.subject],type:0,allow,deny}]' "$LAYOUT")
ensure_channel "$(jq -r '.status_voice.name' "$LAYOUT")" "$(jq -r '.status_voice.type' "$LAYOUT")" '' "$voice_overwrites"
status_voice_id=$channel_id
while IFS= read -r name; do
  if [[ $name == Admin || $name == Guilds ]]; then deny=1024; else deny=0; fi
  overwrites=$(jq -nc --argjson c "$common" --arg id "$guild" --arg deny "$deny" '$c + [{id:$id,type:0,allow:"0",deny:$deny}]')
  ensure_channel "$name" 4 '' "$overwrites"
  category_ids=$(jq --arg n "$name" --arg id "$channel_id" '. + {($n):$id}' <<< "$category_ids")
done < <(jq -r '.categories[]' "$LAYOUT")
rows=$(jq -c '.channels[]' "$LAYOUT")
if [[ $mode == guild ]]; then rows="$rows"$'\n'"$(jq -nc --arg n "$2" '{name:$n,category:"Guilds",access:"guild"}')"; fi
channel_ids='{}'
while IFS= read -r row; do
  name=$(jq -r .name <<< "$row"); access=$(jq -r .access <<< "$row")
  parent=$(jq -r --arg n "$(jq -r .category <<< "$row")" '.[$n]' <<< "$category_ids")
  overwrites=$(jq -c --arg a "$access" --argjson ids "$role_ids" --argjson c "$common" '$c + [.permissions[$a][] | {id:$ids[.subject],type:0,allow,deny}]' "$LAYOUT")
  ensure_channel "$name" 0 "$parent" "$overwrites"
  channel_ids=$(jq --arg n "$name" --arg id "$channel_id" '. + {($n):$id}' <<< "$channel_ids")
done <<< "$rows"
while IFS= read -r row; do
  route=$(jq -r .route <<< "$row"); name="Lembitu · $route"
  id=$(jq -r --arg n "$(jq -r .channel <<< "$row")" '.[$n]' <<< "$channel_ids")
  if [[ $id == planned-* ]]; then hooks='[]'; else hooks=$(api GET "/channels/$id/webhooks"); fi
  hook=$(jq -c --arg n "$name" '[.[] | select(.name == $n and .type == 1)] | if length > 1 then error("ambiguous webhook route") else .[0] // null end' <<< "$hooks")
  if [[ $hook == null ]]; then
    echo "Create webhook route: $route"
    if ! $dry; then hook=$(api POST "/channels/$id/webhooks" "$(jq -nc --arg n "$name" '{name:$n}')"); fi
  fi
  if ! $dry; then
    jq -er --arg route "$route" 'if (.token | type) != "string" then error("webhook token unavailable") else "DISCORD_WEBHOOK_" + $route + "=https://discord.com/api/webhooks/" + .id + "/" + .token end' <<< "$hook" >> "$work/webhooks.env"
  fi
done < <(jq -c '.webhooks[]' "$LAYOUT")
if ! $dry; then
  mkdir -p "$HOME/.config/lembitu"
  mv "$work/webhooks.env" "$HOME/.config/lembitu/discord-webhooks.env"
  chmod 600 "$HOME/.config/lembitu/discord-webhooks.env"
  # Replace the discovered IDs in one rename on the same filesystem, retaining wizard IDs. The chat
  # and admin-console IDs feed ServerManager's bot (scripts/servermanager-discord.py).
  ids_tmp=$(mktemp "$HOME/.config/lembitu/.discord.env.XXXXXX")
  while IFS= read -r line || [[ -n $line ]]; do
    case "$line" in DISCORD_ROLE_PLAYER_ID=*|DISCORD_STATUS_VOICE_CHANNEL_ID=*|DISCORD_CHANNEL_CHAT_ID=*|DISCORD_CHANNEL_ADMIN_CONSOLE_ID=*) ;; *) printf '%s\n' "$line" ;; esac
  done < "$ids" > "$ids_tmp"
  printf 'DISCORD_ROLE_PLAYER_ID=%s\nDISCORD_STATUS_VOICE_CHANNEL_ID=%s\nDISCORD_CHANNEL_CHAT_ID=%s\nDISCORD_CHANNEL_ADMIN_CONSOLE_ID=%s\n' \
    "$(jq -r '.Player' <<< "$role_ids")" "$status_voice_id" \
    "$(jq -r '.chat' <<< "$channel_ids")" "$(jq -r '."admin-console"' <<< "$channel_ids")" >> "$ids_tmp"
  chmod 600 "$ids_tmp"
  mv "$ids_tmp" "$ids"
fi
echo 'Layout reconciled; unrelated channels, roles and webhooks preserved.'
