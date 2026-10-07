#!/usr/bin/env bash
# Exercise monitor transitions with fake commands and clock. Usage: bash test/monitor.test.sh
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/fake" <<'PY'
#!/usr/bin/env python3
import datetime,json,os,pathlib,sys
name=pathlib.Path(sys.argv[0]).name
fault=os.environ.get('FAULT','')
now=int(os.environ['NOW'])
if name=='flock': sys.exit(0)
if name=='date': print(now)
if name=='ssh': sys.exit(1 if fault=='query' else 0)
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
export PATH="$tmp/bin:$PATH" ALERTS="$tmp/alerts" LEMBITU_MONITOR_STATE="$tmp/state"
export LEMBITU_QUERY_TARGET=example.invalid LEMBITU_WEBHOOK_FILE="$tmp/webhooks.env"
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
  python3 - "$ALERTS" <<'PY'
import json,sys
messages=[json.loads(line)['content'] for line in open(sys.argv[1])]
assert 'FAULT:' in messages[0] and 'RECOVERY:' in messages[1]
assert messages[0].split('FAULT: ')[1]==messages[1].split('RECOVERY: ')[1]
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
PYTHONDONTWRITEBYTECODE=1 python3 - "$root/scripts/query-server.py" <<'PY'
import importlib.util,socket,struct,sys,threading
spec=importlib.util.spec_from_file_location('probe',sys.argv[1])
probe=importlib.util.module_from_spec(spec); spec.loader.exec_module(probe)
info=b'\xff\xff\xff\xffI\x11name\x00world\x00valheim\x00Valheim\x00'+struct.pack('<HBBB',892,0,10,0)
for challenged,valid in [(False,True),(True,True),(False,False)]:
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); sock.bind(('127.0.0.1',0)); sock.settimeout(3)
    def serve():
        request,addr=sock.recvfrom(4096)
        assert request==b'\xff\xff\xff\xffTSource Engine Query\x00'
        if challenged:
            sock.sendto(b'\xff\xff\xff\xffA1234',addr)
            second,addr=sock.recvfrom(4096); assert second==request+b'1234'
        sock.sendto(info if valid else b'\xff\xff\xff\xffI',addr)
    thread=threading.Thread(target=serve); thread.start()
    try:
        probe.query('127.0.0.1',sock.getsockname()[1])
        assert valid
    except (ValueError,struct.error):
        assert not valid
    finally:
        thread.join(); sock.close()
PY
echo 'pass: real UDP A2S replies, challenge and malformed reply'
echo 'monitor: 26 scenarios passed'
