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
#   - that socket answers. A padded SteamNetworkingSockets ConnectionClosed to 127.0.0.1:2456 gets
#     NoConnection back, 11 fixed bytes, the connection IDs echoed. It asks for no connection, no
#     authentication and no Steam, and the server answers it from its own networking code.
# Exit 0 and one line when ready; exit 1 and the reason when not.
#
# 2457 is not the game's socket. It is the Steam game server's query socket, and under -public 0
# (ra's Round, 2026-10-27: players join by address, the Steam list is off) it never sends a byte:
# not to A2S_INFO, and not to SteamNetworkingSockets' own packets. lembitu-a2s stays in the image
# for -public 1, but it can't be this probe (docs/server-image.md, "Ready").
#
# Environment, for the tests: LEMBITU_RUNTIME (default /run/lembitu), LEMBITU_PROC_NET (default
# /proc/net), LEMBITU_GAME_PORT (default 2456), LEMBITU_PROBE_HOST (default 127.0.0.1).

set -euo pipefail

RUNTIME=${LEMBITU_RUNTIME:-/run/lembitu}
PROC_NET=${LEMBITU_PROC_NET:-/proc/net}
PORT=${LEMBITU_GAME_PORT:-2456}
HOST=${LEMBITU_PROBE_HOST:-127.0.0.1}

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

# The ConnectionClosed (message 36): a 3-byte header (the ID, then the body's length, 12, little
# endian), the body (field 4 to_connection_id "LEMB", field 5 from_connection_id "BMEL", field 3
# reason_code 0), and zeros to 512 bytes, the minimum the server accepts for this message. Its
# NoConnection reply (message 37) echoes the IDs back as field 2 from_connection_id "LEMB" and
# field 3 to_connection_id "BMEL".
# No byte of the request may be 0x0a: bash's printf flushes its output at a newline, so the
# datagram would leave in two pieces, and the server ignores both. That is why the body carries
# reason_code: without it the length is 10, 0x0a.
pad="$(printf '\\x00%.0s' {1..497})"
request="\x24\x0c\x00\x25\x4c\x45\x4d\x42\x2d\x42\x4d\x45\x4c\x18\x00$pad"
expected=25154c454d421d424d454c
# shellcheck disable=SC2016  # the inner script's variables are its own positional arguments
reply="$(timeout 2 "$BASH" -c 'exec 3<>"/dev/udp/$0/$1"; printf "$2" >&3; head -c 11 <&3 | od -An -tx1' \
  "$HOST" "$PORT" "$request" 2>/dev/null | tr -d ' \n' || true)"
[[ "$reply" == "$expected" ]] || not_ready "UDP $PORT did not answer a ConnectionClosed with NoConnection (got: ${reply:-nothing})"

printf 'ready: "Opened Steam server", UDP %s bound, and it answered a ConnectionClosed with NoConnection\n' "$PORT"
