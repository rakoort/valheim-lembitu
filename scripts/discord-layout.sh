#!/usr/bin/env bash
# Reconcile the Run's Discord layout without deleting unrelated resources.
# Usage: discord-layout.sh [--dry-run] [apply]
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
  *) echo 'Usage: discord-layout.sh [--dry-run] [apply]' >&2; exit 1 ;;
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
# A guide file split into Discord posts. Every post is checked before anything is written, because a
# post Discord refuses half-way would leave the channel out of order.
guide_posts() {
  jq -Rs 'split("\n---\n") | map(sub("^\\s+"; "") | sub("\\s+$"; ""))' "$ROOT/$1"
}
while IFS= read -r guide; do
  [[ -f $ROOT/$guide ]] || { echo "Missing guide file: $guide" >&2; exit 1; }
  guide_posts "$guide" | jq -e 'length > 0 and all(.[]; length > 0 and length <= 2000)' >/dev/null \
    || { echo "Guide posts must be non-empty and at most 2000 characters: $guide" >&2; exit 1; }
done < <(jq -r '.channels[] | .guide // empty' "$LAYOUT")
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
# Guilds are declared in the layout: each gets a role, a private text channel named by its slug
# and a voice channel, all under Guilds. Checked before any write, so a slug that collides with a
# layout channel, another Guild or a channel outside Guilds stops the run with nothing changed.
guilds_category=$(jq -r '[.[] | select(.name == "Guilds" and .type == 4)] | if length == 1 then .[0].id else "" end' <<< "$channels")
jq -e '[.guilds[]?.slug] | length == (unique | length)' "$LAYOUT" >/dev/null || { echo 'Duplicate Guild slug in the layout' >&2; exit 1; }
while IFS= read -r row; do
  gname=$(jq -r .name <<< "$row"); slug=$(jq -r .slug <<< "$row")
  [[ -n $gname && ${#gname} -le 80 && $slug =~ ^[a-z0-9][a-z0-9-]{0,99}$ ]] || { echo "Invalid Guild entry: $row" >&2; exit 1; }
  if jq -e --arg n "$slug" 'any(.channels[]; .name == $n)' "$LAYOUT" >/dev/null; then
    echo "Guild channel slug is reserved by the layout: $slug" >&2; exit 1
  fi
  if ! jq -e --arg n "$slug" --arg p "$guilds_category" 'all(.[] | select(.name == $n and .type == 0); .parent_id == $p and $p != "")' <<< "$channels" >/dev/null; then
    echo "Guild channel slug belongs to a channel outside Guilds: $slug" >&2; exit 1
  fi
done < <(jq -c '.guilds[]?' "$LAYOUT")
while IFS= read -r row; do ensure_role "$(jq -r .name <<< "$row")" "$(jq -r .permissions <<< "$row")" "$(jq -r .name <<< "$row")" "$(jq -r '.mentionable // false' <<< "$row")"; done < <(jq -c '.roles[]' "$LAYOUT")
while IFS= read -r row; do ensure_role "Guild · $(jq -r .name <<< "$row")" 0 "guild:$(jq -r .slug <<< "$row")"; done < <(jq -c '.guilds[]?' "$LAYOUT")
category_ids='{}'
ensure_channel() {
  local name=$1 type=$2 parent=$3 overwrites=$4 topic=${5:-} kind=${6:-} matches desired current id result stored=''
  if [[ $kind == status ]]; then
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
  if [[ $kind == guild ]]; then
    matches=$(jq --arg p "$parent" '[.[] | select(.parent_id == $p)]' <<< "$matches")
  fi
  [[ $(jq length <<< "$matches") -le 1 ]] || { echo "Ambiguous channel/category: $name" >&2; exit 1; }
  id=$(jq -r '.[0].id // empty' <<< "$matches")
  desired=$(jq -nc --arg n "$name" --argjson t "$type" --arg p "$parent" --argjson o "$overwrites" '{name:$n,type:$t,parent_id:(if $p == "" then null else $p end),permission_overwrites:$o}')
  current=$(jq -c '.[0] | {name,type,parent_id:(.parent_id // null),permission_overwrites:((.permission_overwrites // []) | sort_by(.id))}' <<< "$matches")
  # A channel's topic shows in its header, so a link there is one click away (the web map channel).
  if [[ -n $topic ]]; then
    desired=$(jq --arg t "$topic" '. + {topic:$t}' <<< "$desired")
    current=$(jq --arg t "$(jq -r '.[0].topic // ""' <<< "$matches")" '. + {topic:$t}' <<< "$current")
  fi
  if [[ $kind == status ]]; then
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
ensure_channel "$(jq -r '.status_voice.name' "$LAYOUT")" "$(jq -r '.status_voice.type' "$LAYOUT")" '' "$voice_overwrites" '' status
status_voice_id=$channel_id
while IFS= read -r name; do
  if [[ $name == Admin || $name == Guilds ]]; then deny=1024; else deny=0; fi
  overwrites=$(jq -nc --argjson c "$common" --arg id "$guild" --arg deny "$deny" '$c + [{id:$id,type:0,allow:"0",deny:$deny}]')
  ensure_channel "$name" 4 '' "$overwrites"
  category_ids=$(jq --arg n "$name" --arg id "$channel_id" '. + {($n):$id}' <<< "$category_ids")
done < <(jq -r '.categories[]' "$LAYOUT")
rows=$(jq -c '.channels[]' "$LAYOUT")
channel_ids='{}'
while IFS= read -r row; do
  name=$(jq -r .name <<< "$row"); access=$(jq -r .access <<< "$row")
  parent=$(jq -r --arg n "$(jq -r .category <<< "$row")" '.[$n]' <<< "$category_ids")
  overwrites=$(jq -c --arg a "$access" --argjson ids "$role_ids" --argjson c "$common" '$c + [.permissions[$a][] | {id:$ids[.subject],type:0,allow,deny}]' "$LAYOUT")
  ensure_channel "$name" 0 "$parent" "$overwrites" "$(jq -r '.topic // ""' <<< "$row")"
  channel_ids=$(jq --arg n "$name" --arg id "$channel_id" '. + {($n):$id}' <<< "$channel_ids")
  # A row's message is posted once by the Ops bot and pinned; it is never edited or reposted.
  message=$(jq -r '.message // ""' <<< "$row")
  if [[ -n $message && $channel_id != planned-* ]]; then
    posted=$(api GET "/channels/$channel_id/messages?limit=50" | jq --arg a "$ops" 'any(.[]; .author.id == $a)')
    if [[ $posted != true ]]; then
      echo "Post pinned message: $name"
      if ! $dry; then
        mid=$(api POST "/channels/$channel_id/messages" "$(jq -nc --arg c "$message" '{content:$c,allowed_mentions:{parse:[]}}')" | jq -er .id)
        api PUT "/channels/$channel_id/messages/pins/$mid" >/dev/null
      fi
    fi
  elif [[ -n $message ]]; then
    echo "Post pinned message: $name"
  fi
  # A row's guide is a file of posts split on '---' lines, kept in order by the Ops bot: a changed
  # post is edited in place, a missing one posted after the others, a surplus one deleted.
  guide=$(jq -r '.guide // ""' <<< "$row")
  if [[ -n $guide ]]; then
    posts=$(guide_posts "$guide")
    if [[ $channel_id == planned-* ]]; then existing='[]'; else
      existing=$(api GET "/channels/$channel_id/messages?limit=100" | jq -c --arg a "$ops" '[.[] | select(.author.id == $a)] | sort_by([(.id | length), .id])')
    fi
    count=$(jq length <<< "$posts"); have=$(jq length <<< "$existing")
    for ((i = 0; i < count; i++)); do
      body=$(jq -c --argjson i "$i" '{content:.[$i],flags:4,allowed_mentions:{parse:[]}}' <<< "$posts")
      if ((i < have)); then
        if [[ $(jq -c --argjson i "$i" '.[$i].content' <<< "$existing") != "$(jq -c .content <<< "$body")" ]]; then
          echo "Edit guide post $((i + 1)): $name"
          if ! $dry; then api PATCH "/channels/$channel_id/messages/$(jq -r --argjson i "$i" '.[$i].id' <<< "$existing")" "$body" >/dev/null; fi
        fi
      else
        echo "Post guide post $((i + 1)): $name"
        if ! $dry; then api POST "/channels/$channel_id/messages" "$body" >/dev/null; fi
      fi
    done
    for ((i = count; i < have; i++)); do
      echo "Delete surplus guide post $((i + 1)): $name"
      if ! $dry; then api DELETE "/channels/$channel_id/messages/$(jq -r --argjson i "$i" '.[$i].id' <<< "$existing")" >/dev/null; fi
    done
  fi
done <<< "$rows"
# Guild channels: only the Guild's role, the owner and the bots see them. The voice channel lets
# members connect, speak, use voice activity and stream.
guilds_parent=$(jq -r '.Guilds' <<< "$category_ids")
while IFS= read -r row; do
  gname=$(jq -r .name <<< "$row"); slug=$(jq -r .slug <<< "$row")
  overwrites=$(jq -nc --argjson c "$common" --arg e "$guild" --arg r "$(jq -r --arg k "guild:$slug" '.[$k]' <<< "$role_ids")" \
    '$c + [{id:$e,type:0,allow:"0",deny:"1024"},{id:$r,type:0,allow:"117760",deny:"0"}]')
  ensure_channel "$slug" 0 "$guilds_parent" "$overwrites" '' guild
  overwrites=$(jq -nc --argjson c "$common" --arg e "$guild" --arg r "$(jq -r --arg k "guild:$slug" '.[$k]' <<< "$role_ids")" \
    '$c + [{id:$e,type:0,allow:"0",deny:"1049600"},{id:$r,type:0,allow:"36701696",deny:"0"}]')
  ensure_channel "🔊 $gname" 2 "$guilds_parent" "$overwrites" '' guild
done < <(jq -c '.guilds[]?' "$LAYOUT")
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
