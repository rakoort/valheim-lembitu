#!/usr/bin/env bash
# Check one cycle. Usage: monitor.sh; thresholds in config/monitor/settings.json.
# Requires Linux flock, docker, curl, ssh, systemctl, free and df, and python3 or nix. Never changes
# the server.
set -euo pipefail
state=${LEMBITU_MONITOR_STATE:-$HOME/.local/state/lembitu/monitor.json}
mkdir -p "$(dirname "$state")"
umask 077
exec 9>"$state.lock"
flock -n 9 || exit 0
export LEMBITU_MONITOR_STATE="$state"
LEMBITU_QUERY_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/query-server.py"
LEMBITU_MONITOR_SETTINGS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config/monitor" && pwd)/settings.json"
export LEMBITU_QUERY_SCRIPT LEMBITU_MONITOR_SETTINGS
# shellcheck source=lib/python.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
run_python - <<'PY'
import datetime
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys


def run(*args, input=None):
    try:
        result = subprocess.run(args, input=input, text=True, capture_output=True, timeout=25)
        output = result.stdout + result.stderr if args[:2] == ('docker', 'logs') else result.stdout
        return result.returncode == 0, output
    except (OSError, subprocess.TimeoutExpired):
        return False, ''


defaults = json.loads(pathlib.Path(os.environ['LEMBITU_MONITOR_SETTINGS']).read_text())
def setting(name, default):
    return os.environ.get('LEMBITU_' + name, defaults.get(name, default))

path = pathlib.Path(os.environ['LEMBITU_MONITOR_STATE'])
secret_file = pathlib.Path(os.environ.get('LEMBITU_WEBHOOK_FILE', os.path.expanduser('~/.config/lembitu/discord-webhooks.env')))
secrets = {}
if secret_file.exists():
    for line in secret_file.read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            key, value = line.split('=', 1)
            secrets[key] = value.strip().strip('"').strip("'")
webhook = secrets.get('DISCORD_WEBHOOK_MONITOR', os.environ.get('DISCORD_WEBHOOK_MONITOR', ''))
if not webhook:
    print('DISCORD_WEBHOOK_MONITOR missing; not posting', file=sys.stderr)
target = setting('QUERY_TARGET', '')
# A LAN or overlay hostname cannot substitute for an owner-supplied public game address.
if target and not re.fullmatch(r'[A-Za-z0-9_.:-]+', target):
    raise SystemExit('Invalid query target')
port = int(setting('QUERY_PORT', '2457'))
if not 1 <= port <= 65535:
    raise SystemExit('Invalid query port')
ok, text = run('date', '+%s')
if not ok:
    raise SystemExit('Clock unavailable')
now = int(text)
state = json.loads(path.read_text()) if path.exists() else {'started': now, 'faults': {}}
faults = {}
container = setting('MONITOR_CONTAINER', 'lembitu')
ok, text = run('docker', 'inspect', '--format', '{{.State.Running}}', container)
running = ok and text.strip() == 'true'
faults['container down'] = (not running, 120)
# OdinEye binds inside the container's network namespace; no host port is exposed.
ok, text = run('docker', 'exec', container, 'curl', '--fail', '--silent', '--max-time', '8',
               'http://localhost:2469/players')
try:
    players = json.loads(text)
    responsive = ok and isinstance(players, list)
except ValueError:
    responsive = False
faults['OdinEye unresponsive'] = (not responsive, 120)
if target:
    # ssh joins its arguments into one line for the remote login shell (fish on these hosts), so
    # the command is a single quoted `sh -c` that every shell passes through unchanged.
    remote = ' '.join(shlex.quote(x) for x in ['sh', '-c', os.environ['REMOTE_PYTHON'], 'sh', target, str(port)])
    ok, _ = run('ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
                setting('QUERY_HOST', 'astral-tricep'), remote,
                input=pathlib.Path(os.environ['LEMBITU_QUERY_SCRIPT']).read_text())
    faults['outside A2S unreachable'] = (not ok, 120)
else:
    print('LEMBITU_QUERY_TARGET missing; outside reachability not checked', file=sys.stderr)
ok, logs = run('docker', 'logs', '--timestamps', '--since', '15m', container)
last_save = state.get('last_save', 0)
if ok:
    for line in logs.splitlines():
        if 'World save (5/5) done. Total time [' in line:
            try:
                stamp = datetime.datetime.fromisoformat(line.split()[0].replace('Z', '+00:00')).timestamp()
                last_save = max(last_save, int(stamp))
            except ValueError:
                pass
if not last_save:
    last_save = state['started']
state['last_save'] = last_save
faults['world save overdue'] = (not ok or now - last_save >= 600, 0)
ok, text = run('systemctl', '--user', 'show', setting('BACKUP_UNIT', 'lembitu-backup.service'),
               '--property=Result', '--property=ExecMainStatus', '--property=LoadState')
props = dict(line.split('=', 1) for line in text.splitlines() if '=' in line)
faults['backup or off-host copy failed'] = (not ok or props.get('LoadState') != 'loaded'
    or props.get('Result') != 'success' or props.get('ExecMainStatus') != '0', 0)
ok, text = run('docker', 'stats', '--no-stream', '--format', '{{json .}}', container)
try:
    stats = json.loads(text)
    cpu = float(stats['CPUPerc'].rstrip('%'))
    usage = stats['MemUsage'].split('/')[0].strip()
    match = re.fullmatch(r'([0-9.]+)\s*([KMGT]?i?B)', usage)
    powers = {'B': 1, 'kB': 1000, 'KB': 1000, 'KiB': 1024, 'MB': 1000**2,
              'MiB': 1024**2, 'GB': 1000**3, 'GiB': 1024**3, 'TB': 1000**4, 'TiB': 1024**4}
    memory = float(match[1]) * powers[match[2]] / 1024**3
    faults['container CPU high'] = (cpu >= float(setting('CPU_PERCENT', '200')), 120)
    faults['container memory high'] = (memory >= float(setting('MEMORY_GIB', '8')), 0)
except (ValueError, KeyError, TypeError):
    ok = False
faults['container statistics unavailable'] = (not ok, 120)
ok, text = run('free', '-m')
try:
    row = next(line.split() for line in text.splitlines() if line.startswith('Mem:'))
    used = 100 * (1 - int(row[-1]) / int(row[1]))
    faults['host memory high'] = (used >= float(setting('HOST_MEMORY_PERCENT', '90')), 0)
except (StopIteration, ValueError, IndexError, ZeroDivisionError):
    ok = False
faults['host memory statistics unavailable'] = (not ok, 120)
# Aggregate host CPU uses deltas between cycles, not load average or cumulative uptime.
try:
    ticks = list(map(int, pathlib.Path(setting('PROC_STAT', '/proc/stat')).read_text().splitlines()[0].split()[1:9]))
    total, idle = sum(ticks), ticks[3] + ticks[4]
    previous = state.get('cpu')
    high = False
    if previous and total > previous[0]:
        high = 100 * (1 - (idle - previous[1]) / (total - previous[0])) >= float(setting('HOST_CPU_PERCENT', '90'))
    state['cpu'] = [total, idle]
    faults['host CPU high'] = (high, 120)
    faults['host CPU statistics unavailable'] = (False, 120)
except (OSError, ValueError, IndexError):
    faults['host CPU statistics unavailable'] = (True, 120)
ok, text = run('df', '-P', setting('MONITOR_DISK', os.path.expanduser('~/lembitu')))
try:
    percent = int(text.splitlines()[-1].split()[-2].rstrip('%'))
    faults['disk high'] = (percent >= float(setting('DISK_PERCENT', '85')), 0)
except (ValueError, IndexError):
    ok = False
faults['disk statistics unavailable'] = (not ok, 120)
# Planned maintenance never advances availability-fault timers. Preserve any already
# delivered fault so a genuine recovery can still be reported after the window.
maintenance_path = pathlib.Path(setting('MAINTENANCE_FILE', os.path.expanduser('~/.local/state/lembitu/maintenance-until')))
try:
    maintenance = now < int(maintenance_path.read_text().strip())
except FileNotFoundError:
    maintenance = False
except (OSError, ValueError):
    print('Invalid maintenance marker; evaluating health normally', file=sys.stderr)
    maintenance = False
availability = {'container down', 'OdinEye unresponsive', 'outside A2S unreachable',
                'world save overdue', 'container statistics unavailable'}
failed_delivery = False
for name, (bad, delay) in faults.items():
    record = state['faults'].setdefault(name, {'since': None, 'alerted': False})
    if maintenance and name in availability:
        record['since'] = None
        continue
    message = None
    if bad:
        if record['since'] is None:
            record['since'] = now
        if not record['alerted'] and now - record['since'] >= delay:
            message = 'FAULT: ' + name
    else:
        record['since'] = None
        if record['alerted']:
            message = 'RECOVERY: ' + name
    if message:
        if not webhook:
            continue
        payload = json.dumps({'content': 'Lembitu ' + message, 'allowed_mentions': {'parse': []}})
        # Keep the secret out of argv and suppress curl diagnostics that might include it.
        config = 'url = ' + json.dumps(webhook) + '\n'
        delivered, _ = run('curl', '--fail', '--silent', '--max-time', '10', '--config', '-',
                           '-H', 'Content-Type: application/json', '--data-binary', payload, input=config)
        if delivered:
            record['alerted'] = bad
            print(message)
        else:
            failed_delivery = True
            print('Webhook delivery failed; transition will retry')
temporary = path.with_suffix('.tmp')
temporary.write_text(json.dumps(state))
temporary.replace(path)
if failed_delivery:
    print('Webhook unavailable; check completed and transitions retained', file=sys.stderr)
PY
