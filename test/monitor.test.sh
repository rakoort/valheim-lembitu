#!/usr/bin/env bash
# Exercise monitor transitions with fake commands and clock. Usage: bash test/monitor.test.sh
# The outside check is real end to end except for the network hop: the fake ssh runs the command the
# monitor sends, with its stdin, through `sh -c` here, and the probe it carries talks UDP to a fake
# game port on 127.0.0.1. That port answers as Valheim does under -public 0 (only a SteamNetworkingSockets
# ConnectionClosed, with NoConnection), as a query port that answers only A2S_INFO, or not at all.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'kill "$(cat "$tmp/game.pid" 2>/dev/null)" 2>/dev/null || true; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/game.py" <<'PY'
# The fake game port. Mode file: "sns" answers a ConnectionClosed (36) of at least 512 bytes with
# NoConnection (37), the IDs echoed (GameNetworkingSockets, steamnetworkingsockets_udp.cpp); "a2s"
# answers only A2S_INFO, as a public query port does; "wrong" answers a ConnectionClosed with 11
# bytes that echo other IDs; "silent" answers nothing. Every datagram's length and first bytes go
# to the log.
import socket,struct,sys
mode_file,port_file,log=sys.argv[1:4]
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('127.0.0.1',0))
open(port_file,'w').write(str(s.getsockname()[1]))
def fixed32(body,tag):
    i=0
    while i<len(body):
        key=body[i]; i+=1
        if key&7==5:
            if key==tag: return body[i:i+4]
            i+=4
        elif key&7==0:
            while body[i]&0x80: i+=1
            i+=1
        else: return None
while True:
    pkt,peer=s.recvfrom(65536)
    with open(log,'a') as out: out.write('%d %s\n'%(len(pkt),pkt[:3].hex()))
    mode=open(mode_file).read().strip()
    if mode=='a2s' and pkt.startswith(b'\xff\xff\xff\xffTSource Engine Query\x00'):
        s.sendto(b'\xff\xff\xff\xffI\x11name\x00world\x00valheim\x00Valheim\x00'+struct.pack('<HBBB',892,0,10,0),peer)
    elif mode=='sns' and len(pkt)>=512 and pkt[0]==36:
        body=pkt[3:3+struct.unpack_from('<H',pkt,1)[0]]
        to,frm=fixed32(body,0x25),fixed32(body,0x2d)
        if to and frm: s.sendto(b'\x25\x15'+to+b'\x1d'+frm,peer)
    elif mode=='wrong' and len(pkt)>=512 and pkt[0]==36:
        s.sendto(b'\x25\x15XXXX\x1dYYYY',peer)
PY
printf 'sns\n' >"$tmp/game.mode"
python3 "$tmp/game.py" "$tmp/game.mode" "$tmp/game.port" "$tmp/game.log" &
echo "$!" >"$tmp/game.pid"
for _ in $(seq 50); do [[ -s "$tmp/game.port" ]] && break; sleep 0.1; done
cat >"$tmp/bin/fake" <<'PY'
#!/usr/bin/env python3
import datetime,json,os,pathlib,subprocess,sys
name=pathlib.Path(sys.argv[0]).name
fault=os.environ.get('FAULT','')
now=int(os.environ['NOW'])
if name=='flock': sys.exit(0)
if name=='date': print(now)
if name=='ssh':
    # ssh -o BatchMode=yes -o ConnectTimeout=8 HOST COMMAND: run COMMAND as the remote login shell
    # would, with the monitor's stdin.
    args=sys.argv[1:]
    assert args[:4]==['-o','BatchMode=yes','-o','ConnectTimeout=8'] and len(args)==6, args
    with open(os.environ['SSH_LOG'],'a') as out: out.write(args[4]+' '+args[5]+'\n')
    sys.exit(subprocess.run(['sh','-c',args[5]],stdin=sys.stdin).returncode)
if name=='curl':
    sys.stdin.read()
    if fault=='webhook': sys.exit(22)
    with open(os.environ['ALERTS'],'a') as out: out.write(sys.argv[-1]+'\n')
if name=='docker':
    cmd=sys.argv[1]
    if cmd=='inspect': print('false' if fault=='container' else 'true')
    if cmd=='exec':
        if fault=='odin': sys.exit(7)
        print('[]')
    if cmd=='logs':
        stamp=now-601 if fault=='save' else now
        print(datetime.datetime.fromtimestamp(stamp,datetime.timezone.utc).isoformat()+' World save (5/5) done. Total time [43ms]',file=sys.stderr)
    if cmd=='stats': print(json.dumps({'CPUPerc':'250%' if fault=='cpu' else '9.91%', 'MemUsage':'9GiB / 125GiB' if fault=='memory' else '1.777GiB / 125GiB'}))
if name=='systemctl': print('LoadState=loaded\nResult='+('exit-code' if fault in ('backup','offhost') else 'success')+'\nExecMainStatus='+('1' if fault in ('backup','offhost') else '0'))
if name=='free': print('Mem: 1000 990 10 0 0 '+('50' if fault=='hostmemory' else '620'))
if name=='df': print('Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/test 100 50 50 '+('90%' if fault=='disk' else '55%')+' /test')
PY
chmod +x "$tmp/bin/fake"
for cmd in docker curl date ssh systemctl free df flock; do ln -s fake "$tmp/bin/$cmd"; done
export PATH="$tmp/bin:$PATH" ALERTS="$tmp/alerts" LEMBITU_MONITOR_STATE="$tmp/state" SSH_LOG="$tmp/ssh.log"
LEMBITU_GAME_PORT=$(cat "$tmp/game.port")
export LEMBITU_QUERY_TARGET=127.0.0.1 LEMBITU_GAME_PORT
export LEMBITU_WEBHOOK_FILE="$tmp/webhooks.env"
printf 'DISCORD_WEBHOOK_MONITOR=https://example.invalid/webhook\n' >"$LEMBITU_WEBHOOK_FILE"
chmod 600 "$LEMBITU_WEBHOOK_FILE"
export LEMBITU_PROC_STAT="$tmp/stat" NOW=10000 FAULT=
export LEMBITU_MAINTENANCE_FILE="$tmp/maintenance-until"
: >"$ALERTS"
user_ticks=10000 idle_ticks=90000 previous_clock=$NOW
cycle() {
  delta=$((NOW-previous_clock))
  if [[ $FAULT == hostcpu ]]; then
    user_ticks=$((user_ticks+delta*10))
  else
    user_ticks=$((user_ticks+delta)); idle_ticks=$((idle_ticks+delta*9))
  fi
  previous_clock=$NOW
  printf 'cpu %s 0 0 %s 0 0 0 0\n' "$user_ticks" "$idle_ticks" >"$LEMBITU_PROC_STAT"
  if [[ $FAULT == query ]]; then printf 'silent\n'; else printf '%s\n' "${GAME_MODE:-sns}"; fi >"$tmp/game.mode"
  bash "$root/scripts/monitor.sh" >"$tmp/output"
}
assert_count() {
  local count
  count=$(wc -l <"$ALERTS" | tr -d ' ')
  [[ "$count" == "$1" ]] || { echo "FAIL: expected $1 alerts, got $count"; cat "$ALERTS"; exit 1; }
}
# A full healthy hour, including save timestamps emitted on stderr, stays silent.
for ((i=0;i<61;i++)); do cycle; NOW=$((NOW+60)); done
assert_count 0
echo 'pass: healthy hour is silent'
for scenario in container odin query save backup offhost memory cpu hostcpu hostmemory disk; do
  rm -f "$LEMBITU_MONITOR_STATE"
  : >"$ALERTS"
  FAULT=; cycle
  FAULT=$scenario; NOW=$((NOW+60)); cycle
  case "$scenario" in container|odin|query|cpu|hostcpu)
    assert_count 0; NOW=$((NOW+119)); cycle; assert_count 0
    NOW=$((NOW+1)); cycle;;
    save) NOW=$((NOW+601)); cycle;;
  esac
  assert_count 1
  NOW=$((NOW+60)); cycle; assert_count 1
  FAULT=; NOW=$((NOW+60)); cycle; assert_count 2
  NOW=$((NOW+60)); cycle; assert_count 2
  python3 - "$ALERTS" "$scenario" <<'PY'
import json,sys
messages=[json.loads(line)['content'] for line in open(sys.argv[1])]
assert 'FAULT:' in messages[0] and 'RECOVERY:' in messages[1]
assert messages[0].split('FAULT: ')[1]==messages[1].split('RECOVERY: ')[1]
if sys.argv[2]=='query': assert messages[0]=='Lembitu FAULT: outside game port unreachable', messages
PY
  echo "pass: $scenario fault once, recovery once"
done
# An undelivered recovery is retained and retried, not silently consumed.
FAULT=memory; NOW=$((NOW+60)); cycle
FAULT=webhook; NOW=$((NOW+60))
cycle
FAULT=; cycle
assert_count 4
echo 'pass: failed webhook transition retries'
rm -f "$LEMBITU_WEBHOOK_FILE"
FAULT=memory; NOW=$((NOW+60)); cycle
assert_count 4
echo 'pass: missing webhook is nonfatal and silent'
printf 'DISCORD_WEBHOOK_MONITOR=https://example.invalid/webhook\n' >"$LEMBITU_WEBHOOK_FILE"
for end in expired removed; do
  for scenario in container odin query save; do
    rm -f "$LEMBITU_MONITOR_STATE"
    : >"$ALERTS"
    FAULT=; NOW=$((NOW+60)); cycle
    until=$((NOW+1200)); printf '%s\n' "$until" >"$LEMBITU_MAINTENANCE_FILE"
    FAULT=$scenario
    for advance in 60 600 60; do NOW=$((NOW+advance)); cycle; assert_count 0; done
    if [[ $end == expired ]]; then NOW=$until; else rm "$LEMBITU_MAINTENANCE_FILE"; fi
    cycle
    if [[ $scenario != save ]]; then
      assert_count 0; NOW=$((NOW+119)); cycle; assert_count 0
      NOW=$((NOW+1)); cycle
    fi
    assert_count 1; NOW=$((NOW+60)); cycle; assert_count 1
    FAULT=; NOW=$((NOW+60)); cycle; assert_count 2
    rm -f "$LEMBITU_MAINTENANCE_FILE"
    echo "pass: maintenance $end/$scenario suppresses timers then faults and recovers once"
  done
done
for scenario in memory backup offhost; do
  rm -f "$LEMBITU_MONITOR_STATE"; : >"$ALERTS"
  printf '%s\n' "$((NOW+1200))" >"$LEMBITU_MAINTENANCE_FILE"
  FAULT=$scenario; cycle; assert_count 1
  NOW=$((NOW+60)); cycle; assert_count 1
  FAULT=; NOW=$((NOW+60)); cycle; assert_count 2
  echo "pass: maintenance does not suppress $scenario"
done
rm -f "$LEMBITU_MAINTENANCE_FILE"
# Every probe left as one 512-byte datagram, a ConnectionClosed whose length byte is not 0x0a.
awk '$0 != "512 240c00" { bad=1; print "FAIL: datagram " $0 } END { exit bad }' "$tmp/game.log"
[[ -s "$tmp/game.log" ]] || { echo 'FAIL: the fake game port received nothing'; exit 1; }
echo 'pass: each probe is one 512-byte ConnectionClosed'
# A port that answers only A2S_INFO, all the old check needed, is unreachable to this one.
rm -f "$LEMBITU_MONITOR_STATE"; : >"$ALERTS"
GAME_MODE=a2s; FAULT=; NOW=$((NOW+60)); cycle; assert_count 0
NOW=$((NOW+120)); cycle; assert_count 1
grep -q 'FAULT: outside game port unreachable' "$ALERTS" || { echo 'FAIL: A2S-only port not reported'; exit 1; }
GAME_MODE=sns; NOW=$((NOW+60)); cycle; assert_count 2
echo 'pass: a port answering only A2S faults; the game port answering recovers'
# The defaults: game port 2456, probed from astral-tricep.
rm -f "$LEMBITU_MONITOR_STATE"; : >"$SSH_LOG"
(unset LEMBITU_GAME_PORT; NOW=$((NOW+60)); cycle)
[[ "$(cat "$SSH_LOG")" == "astral-tricep sh -c 'exec bash -s -- \"\$@\"' sh 127.0.0.1 2456" ]] \
  || { echo 'FAIL: default probe was:'; cat "$SSH_LOG"; exit 1; }
echo 'pass: by default the probe goes from astral-tricep to game port 2456'
# The probe itself: an exact reply only, nothing from an unbound port, and usage errors.
probe() { bash "$root/scripts/sns-probe.sh" "$@"; }
printf 'sns\n' >"$tmp/game.mode"
[[ "$(probe 127.0.0.1 "$LEMBITU_GAME_PORT")" == "NoConnection from 127.0.0.1:$LEMBITU_GAME_PORT" ]] \
  || { echo 'FAIL: probe did not accept NoConnection'; exit 1; }
for mode in wrong a2s silent; do
  printf '%s\n' "$mode" >"$tmp/game.mode"
  if out=$(probe 127.0.0.1 "$LEMBITU_GAME_PORT"); then echo "FAIL: probe accepted $mode: $out"; exit 1; fi
done
echo 'pass: the probe accepts only the exact NoConnection'
python3 -c 'import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])' >"$tmp/free.port"
start=$SECONDS
if probe 127.0.0.1 "$(cat "$tmp/free.port")" >/dev/null; then echo 'FAIL: unbound port accepted'; exit 1; fi
(( SECONDS - start <= 3 )) || { echo 'FAIL: probe of an unbound port took over 3 s'; exit 1; }
echo 'pass: an unbound port fails within the timeout'
for args in '' '127.0.0.1' '127.0.0.1 0' '127.0.0.1 65536' '127.0.0.1 x' 'bad;host 2456' '127.0.0.1 2456 extra'; do
  set +e; # shellcheck disable=SC2086  # the cases are word lists on purpose
  probe $args 2>/dev/null; rc=$?; set -e
  [[ $rc == 2 ]] || { echo "FAIL: probe '$args' exited $rc, not 2"; exit 1; }
done
echo 'pass: probe usage errors exit 2'
echo 'monitor: 31 scenarios passed'
