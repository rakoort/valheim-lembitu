#!/usr/bin/env bash
# The server image's readiness check (#113; nix/server-image.nix bakes it in as lembitu-ready).
# Ready means all three:
#   - the Unity log has said "Opened Steam server" since this start. lembitu-logmark, the filter on
#     the server's stdout, creates $LEMBITU_RUNTIME/.steam-server-opened, and the entrypoint wipes
#     the runtime tree at every start. The line comes after world loading, when Valheim opens its
#     listen socket. "Game server connected", 17 to 42 s earlier in the image's runs, is only the
#     Steam registration (docs/build.md, "Server readiness");
#   - the game port, UDP 2456, is bound (/proc/net/udp or udp6). That socket is the one clients
#     connect to, a SteamNetworkingSockets listen socket bound on the IPv6 wildcard, so it shows in
#     udp6;
#   - that socket answers: scripts/sns-probe.sh (lembitu-sns-probe in the image) sends a padded
#     SteamNetworkingSockets ConnectionClosed to 127.0.0.1:2456 and gets NoConnection back, 11 fixed
#     bytes, the connection IDs echoed. The monitor's outside check sends the same probe.
# Exit 0 and one line when ready; exit 1 and the reason when not.
#
# 2457 is not the game's socket. It is the Steam game server's query socket, and under -public 0
# (ra's Round, 2026-10-27: players join by address, the Steam list is off) it never sends a byte:
# not to A2S_INFO, and not to SteamNetworkingSockets' own packets. lembitu-a2s stays in the image
# for -public 1, but it can't be this probe (docs/server-image.md, "Ready").
#
# Environment, for the tests: LEMBITU_RUNTIME (default /run/lembitu), LEMBITU_PROC_NET (default
# /proc/net), LEMBITU_GAME_PORT (default 2456), LEMBITU_PROBE_HOST (default 127.0.0.1). The image
# sets LEMBITU_SNS_PROBE to lembitu-sns-probe's store path; from a checkout it is the sibling
# scripts/sns-probe.sh.

set -euo pipefail

RUNTIME=${LEMBITU_RUNTIME:-/run/lembitu}
PROC_NET=${LEMBITU_PROC_NET:-/proc/net}
PORT=${LEMBITU_GAME_PORT:-2456}
HOST=${LEMBITU_PROBE_HOST:-127.0.0.1}
SNS_PROBE=${LEMBITU_SNS_PROBE:-"$(dirname "${BASH_SOURCE[0]}")/sns-probe.sh"}

not_ready() { printf 'not ready: %s\n' "$*"; exit 1; }

[[ -e "$RUNTIME/.steam-server-opened" ]] || not_ready 'no "Opened Steam server" in the log yet'

# /proc/net/udp's local_address is "<hex address>:<hex port>". An unconnected UDP socket is state
# 07, and the port is upper-case hex, four digits.
want="$(printf '%04X' "$PORT")"
bound=0
for table in "$PROC_NET/udp" "$PROC_NET/udp6"; do
  [[ -r "$table" ]] || continue
  while read -r _ local _ state _; do
    [[ "${local##*:}" == "$want" && "$state" == 07 ]] && { bound=1; break 2; }
  done < <(tail -n +2 "$table")
done
(( bound )) || not_ready "UDP $PORT is not bound"

answer="$("$SNS_PROBE" "$HOST" "$PORT" 2>&1)" || not_ready "UDP $PORT did not answer a ConnectionClosed: $answer"

printf 'ready: "Opened Steam server", UDP %s bound, and it answered a ConnectionClosed with NoConnection\n' "$PORT"
