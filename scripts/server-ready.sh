#!/usr/bin/env bash
# The server image's readiness check (#113; nix/server-image.nix bakes it in as lembitu-ready).
# Ready means both:
#   - the Unity log has said "Game server connected" since this start: lembitu-logmark, the filter
#     on the server's stdout, creates $LEMBITU_RUNTIME/.game-server-connected, and the entrypoint
#     wipes the runtime tree at every start;
#   - the server's UDP socket is bound (/proc/net/udp or udp6). That is 2457, the game port plus
#     one, not 2456: run with -port 2456, the server binds no 2456 socket at all. Its Steam game
#     server socket is 2457, where clients connect (they add one to the port they are given) and
#     where A2S queries land. Read from the running image, 2026-10-27 (docs/server-image.md).
#
# Why not A2S_INFO: with -public 0 (ra's Round, 2026-10-27: players join by address, the Steam list
# is off) the server never answers A2S_INFO on its query port, though it binds it. With -public 1 the
# same image answers within about two minutes. lembitu-a2s stays in the image for -public 1 and for
# querying from outside, but it can't be this probe (docs/server-image.md).
#
# Environment, for the tests: LEMBITU_RUNTIME (default /run/lembitu), LEMBITU_PROC_NET (default
# /proc/net), LEMBITU_SERVER_PORT (default 2457).

set -euo pipefail

RUNTIME=${LEMBITU_RUNTIME:-/run/lembitu}
PROC_NET=${LEMBITU_PROC_NET:-/proc/net}
PORT=${LEMBITU_SERVER_PORT:-2457}

not_ready() { printf 'not ready: %s\n' "$*"; exit 1; }

[[ -e "$RUNTIME/.game-server-connected" ]] || not_ready 'no "Game server connected" in the log yet'

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

printf 'ready: "Game server connected" and UDP %s bound\n' "$PORT"
