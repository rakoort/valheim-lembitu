#!/usr/bin/env bash
# Ask a Valheim game port whether its SteamNetworkingSockets listen socket answers.
#
#   scripts/sns-probe.sh HOST PORT
#
# Exit 0 and "NoConnection from HOST:PORT" when the reply is the exact one below; exit 1 and the
# reason when nothing or anything else comes back within 2 s; exit 2 on a usage error.
#
# Two places use it, so it is one script: the server image's readiness check (scripts/server-ready.sh,
# against 127.0.0.1:2456 inside the Pod) and the monitor's outside check (scripts/monitor.sh, sent
# over ssh to astral-tricep and run there against the public game address). It needs bash, for
# /dev/udp, and coreutils.
#
# Why this packet. Under -public 0 (ra's Round, 2026-10-27) Valheim answers no A2S_INFO on any port,
# and its Steam query port, the game port + 1, sends nothing at all. The game port is a
# SteamNetworkingSockets socket (GameNetworkingSockets, steamnetworkingsockets_udp.cpp). It answers
# a ConnectionClosed (message 36) for a connection it doesn't have with a NoConnection (37) that
# echoes the two connection IDs. That asks for no connection, no authentication and no Steam, the
# reply is the same 11 bytes every time, and the server logs nothing. Measured on the server image
# under -public 0, and on today's -public 1 container on astral-bicep, 2026-10-27
# (docs/server-image.md, "Ready").
#
# The request: a 3-byte header (the message ID, then the body's length, 12, little endian), the body
# (field 4 to_connection_id "LEMB", field 5 from_connection_id "BMEL", field 3 reason_code 0), then
# zeros to 512 bytes, the minimum the server accepts for this message: it ignores a shorter one. The
# reply: 25, then field 2 from_connection_id "LEMB" and field 3 to_connection_id "BMEL".
#
# The datagram must leave as one write. bash's printf flushes its output at every newline byte, so a
# 0x0a anywhere in the request would split it in two, and the server ignores both pieces. The body
# carries reason_code so its length is 12 rather than 10 (0x0a), and dd re-blocks the bytes into a
# single 512-byte write in any case.

set -euo pipefail

usage() { printf 'usage: sns-probe.sh HOST PORT\n' >&2; exit 2; }
[[ $# -eq 2 ]] || usage
host=$1 port=$2
[[ $host =~ ^[A-Za-z0-9_.:-]+$ ]] || usage
[[ $port =~ ^[0-9]+$ ]] || usage
(( port >= 1 && port <= 65535 )) || usage

request="\x24\x0c\x00\x25\x4c\x45\x4d\x42\x2d\x42\x4d\x45\x4c\x18\x00$(printf '\\x00%.0s' {1..497})"
expected=25154c454d421d424d454c

if ! exec 3<>"/dev/udp/$host/$port"; then
  printf 'no NoConnection from %s:%s (cannot open a UDP socket to it)\n' "$host" "$port"
  exit 1
fi
# shellcheck disable=SC2059  # the request is a printf format on purpose: its \x escapes are the bytes
printf "$request" | dd bs=512 count=1 iflag=fullblock status=none >&3 2>/dev/null || true
reply="$(timeout 2 head -c 11 <&3 2>/dev/null | od -An -tx1 | tr -d ' \n' || true)"
exec 3>&-

if [[ $reply == "$expected" ]]; then
  printf 'NoConnection from %s:%s\n' "$host" "$port"
  exit 0
fi
printf 'no NoConnection from %s:%s (got: %s)\n' "$host" "$port" "${reply:-nothing}"
exit 1
