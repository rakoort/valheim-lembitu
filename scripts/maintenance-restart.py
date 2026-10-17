#!/usr/bin/env python3
"""Warn through ServerManager cron, confirm its save, then stop. Called by launch-server.sh."""
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request


def docker(*args):
    return subprocess.check_output(['docker', *args], stderr=subprocess.STDOUT, text=True, timeout=150 if args[0] == 'stop' else 30)


def post(url, message):
    if not url:
        print('warning: Discord webhook missing; not posting', file=sys.stderr)
        return
    try:
        # Discord's Cloudflare refuses Python's default "Python-urllib" agent (HTTP 403, error 1010).
        headers = {'Content-Type': 'application/json', 'User-Agent': 'DiscordBot (https://github.com/rakoort/valheim-lembitu, 1)'}
        request = urllib.request.Request(url, json.dumps({'content': message, 'allowed_mentions': {'parse': []}}).encode(), headers, method='POST')
        with urllib.request.urlopen(request, timeout=15) as response:
            response.read()
    except Exception:
        print('warning: Discord delivery failed', file=sys.stderr)


def replace(path, text):
    fd, name = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(text)
        os.chmod(name, path.stat().st_mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def job_id(schedule, command):
    # ServerManager 1.2.3 ServerScheduleSettings.CreateId:308: .NET BinaryWriter UTF-8 strings,
    # chance=1 double, gameTime=false, timezone UTC, then three counted lists.
    def string(value):
        data = value.encode()
        size = len(data)
        prefix = bytearray()
        while size >= 128:
            prefix.append((size & 127) | 128)
            size >>= 7
        prefix.append(size)
        return bytes(prefix) + data
    data = string(schedule) + struct.pack('<d?', 1.0, False) + string('UTC')
    data += struct.pack('<i', 1) + string(command) + struct.pack('<ii', 0, 0)
    return command.split()[0] + '-' + hashlib.sha256(data).hexdigest()[:40]


def main():
    container, config = sys.argv[1:]
    root = Path(config) / 'save' / 'ServerManager'
    cron = root / 'cron.yml'
    state = Path.home() / '.local/state/lembitu'
    state.mkdir(parents=True, exist_ok=True)
    lock = state / 'maintenance.lock'
    secrets = Path.home() / '.config/lembitu/discord-webhooks.env'
    values = dict(os.environ)
    if secrets.exists():
        for line in secrets.read_text().splitlines():
            if line.startswith('DISCORD_WEBHOOK_') and '=' in line:
                key, value = line.split('=', 1)
                values[key] = value
    alert = values.get('DISCORD_WEBHOOK_MONITOR')
    original = None
    locked = False
    try:
        lock.mkdir()
        locked = True
        (state / 'maintenance-until').write_text(str(int(time.time()) + 1800) + '\n')
        mounts = json.loads(docker('inspect', '--format', '{{json .Mounts}}', container))
        if not any(m['Destination'] == '/usr/local/bin/valheim-updater' and not m['RW'] for m in mounts):
            raise RuntimeError('container lacks the read-only frozen updater replacement; recreate it before maintenance')
        original = cron.read_text()
        if not re.search(r'^jobs:\s*\[\]\s*$', original, re.M):
            original = None
            raise RuntimeError('maintenance requires cron.yml jobs: []; refuses to replace another schedule')
        # Twenty seconds permits settings reload; each six-field cron occurrence is date-scoped.
        start = int(time.time()) + 20
        # Vanilla ZNet.HardSaveBlock refuses a save within 60 s of the last one, and on a dedicated
        # server the refusal throws (it reads a null distribution platform), so ServerManager reports
        # the save job command_failed. The world saves itself every 300 s, so a second save 70 s
        # after the first cannot fall in the same window: one of the two runs (2026-10-11).
        saves = (600, 670)
        events = [(0, 'announce Maintenance restart in 10 minutes.'),
                  (300, 'announce Maintenance restart in 5 minutes.'),
                  (540, 'announce Maintenance restart in 1 minute.')] + [(offset, 'save') for offset in saves]
        lines = ['timezone: UTC', 'interval: 1', 'jobs:']
        announced, saved = [], []
        for offset, command in events:
            when = dt.datetime.fromtimestamp(start + offset, dt.timezone.utc)
            schedule = f'{when.second} {when.minute} {when.hour} {when.day} {when.month} *'
            (saved if command == 'save' else announced).append((start + offset, job_id(schedule, command)))
            lines += [f"  - command: '{command}'", f"    schedule: '{schedule}'", '    log: true']
        replace(cron, '\n'.join(lines) + '\n')
        time.sleep(max(0, start + saves[0] - time.time()))
        deadline = time.monotonic() + saves[-1] - saves[0] + int(os.environ.get('CHECKPOINT_TIMEOUT', '120'))
        while time.monotonic() < deadline:
            completed = docker('logs', '--since', dt.datetime.fromtimestamp(start, dt.timezone.utc).isoformat(), container)
            jobs = set(re.findall(r"Cron: Job '([^']+)' completed\.", completed))
            confirmed = False
            for save_at, save_id in saved:
                logs = docker('logs', '--since', dt.datetime.fromtimestamp(save_at, dt.timezone.utc).isoformat(), container)
                save_done = logs.find(f"Cron: Job '{save_id}' completed.")
                # ServerManager 1.2.3 ServerScheduleRuntime:588-616 binds this job to its own save
                # operation and fails if another operation replaces it. Its completed log (:681) follows
                # that operation's successful retained-character checkpoint, not dispatch.
                if save_done >= 0 and re.search(r'WorldCharacterCheckpointCompleted\b[^\n]*\bpending=0(?:\s|$)', logs[:save_done]):
                    confirmed = True
                    break
            if confirmed and {job for _, job in announced}.issubset(jobs):
                replace(cron, original)
                docker('stop', '--time', '120', container)
                print('maintenance: confirmed scheduled world/character checkpoint; container stopped')
                return
            time.sleep(1)
        raise RuntimeError('no confirmed scheduled world/character checkpoint; restart aborted, container left running')
    except BaseException:
        post(alert, 'Lembitu maintenance aborted. Inspect the maintenance unit log; no stop is attempted without a confirmed checkpoint.')
        raise
    finally:
        if original is not None:
            replace(cron, original)
        if locked:
            lock.rmdir()


if __name__ == '__main__':
    def interrupted(_signum, _frame):
        raise RuntimeError('maintenance interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except Exception as error:
        print('error: maintenance failed: ' + (str(error) if isinstance(error, RuntimeError) else type(error).__name__), file=sys.stderr)
        sys.exit(1)
