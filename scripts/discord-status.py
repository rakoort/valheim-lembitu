#!/usr/bin/env python3
"""One host-local snapshot; credentials reach curl only through stdin."""
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from zoneinfo import ZoneInfo


def warning(message):
    print(message, file=sys.stderr)


def run(*args, input=None):
    try:
        result = subprocess.run(args, input=input, text=True, capture_output=True, timeout=25)
        text = result.stdout + result.stderr if args[:2] == ('docker', 'logs') else result.stdout
        return result.returncode == 0, text
    except (OSError, subprocess.TimeoutExpired):
        return False, ''


def read_env(path):
    try:
        return dict(line.split('=', 1) for line in Path(path).read_text().splitlines()
                    if '=' in line and not line.startswith('#'))
    except OSError:
        return {}


def setting(key, default):
    return os.environ.get('LEMBITU_' + key, os.path.expanduser(default))


def request(method, url, body, token=''):
    # Neither the webhook URL nor Authorization appears in the process arguments.
    config = 'url = ' + json.dumps(url) + '\n'
    if token:
        config += 'header = ' + json.dumps('Authorization: Bot ' + token) + '\n'
    ok, text = run('curl', '--silent', '--max-time', '15', '--config', '-',
                   '--request', method, '--header', 'Content-Type: application/json',
                   '--header', 'User-Agent: DiscordBot (https://github.com/rakoort/valheim-lembitu, 1)',
                   '--data-binary', json.dumps(body), '--write-out', '\n%{http_code}', input=config)
    try:
        response, code = text.rstrip('\n').rsplit('\n', 1)
        return int(code) if ok else 0, json.loads(response) if response else {}
    except (ValueError, TypeError):
        return 0, {}


def atomic_write(path, value):
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as out:
        json.dump(value, out)
        temporary = Path(out.name)
    temporary.replace(path)


def main():
    path = Path(os.environ['LEMBITU_DISCORD_STATUS_STATE'])
    try:
        state = json.loads(path.read_text())
    except (OSError, ValueError):
        state = {}
    ok, text = run('date', '+%s')
    if not ok:
        raise SystemExit('Clock unavailable')
    now = int(text)
    container = setting('MONITOR_CONTAINER', 'lembitu')
    ok, text = run('docker', 'inspect', '--format', '{{json .State}}', container)
    try:
        info = json.loads(text) if ok else {}
    except ValueError:
        info = {}
    running = info.get('Running') is True
    players = None
    if running:
        ok, text = run('docker', 'exec', container, 'curl', '--fail', '--silent', '--max-time', '8',
                       'http://localhost:2469/players')
        try:
            candidate = json.loads(text)
            if ok and isinstance(candidate, list) and all(isinstance(p, dict) and isinstance(p.get('Name'), str) for p in candidate):
                players = candidate
        except ValueError:
            pass
    try:
        maintenance = now < int(Path(setting('MAINTENANCE_FILE', '~/.local/state/lembitu/maintenance-until')).read_text().strip())
    except (OSError, ValueError):
        maintenance = False
    online = running and players is not None
    status = 'Restarting' if maintenance else 'Online' if online else 'Offline'
    symbol = {'Online': '🟢', 'Offline': '🔴', 'Restarting': '🟠'}[status]
    count = len(players) if players is not None else None
    voice = f'{symbol} {status}' + (f' · {count}/10' if status == 'Online' else '')
    version = 'Unknown'
    uptime = 'Unavailable'
    if running:
        started = info.get('StartedAt', '')
        try:
            # Docker timestamps can carry nanoseconds; datetime accepts/truncates them.
            boot = dt.datetime.fromisoformat(started.replace('Z', '+00:00'))
            seconds = max(0, now - int(boot.timestamp()))
            uptime = f'{seconds // 86400}d {(seconds // 3600) % 24}h {(seconds // 60) % 60}m'
        except ValueError:
            pass
        args = ['docker', 'logs']
        if started:
            args += ['--since', started]
        ok, logs = run(*args, container)
        if ok:
            versions = re.findall(r'Valheim Version:\s*(l-[^\s]+)', logs)
            if versions:
                version = versions[-1]
    try:
        pack = Path(setting('PACK_VERSION_FILE', '~/lembitu/config/bepinex/.lembitu-pack-version')).read_text().strip() or 'Unknown'
    except OSError:
        pack = 'Unknown'
    oslo = dt.datetime.fromtimestamp(now, ZoneInfo('Europe/Oslo'))
    restart = oslo.replace(hour=6, minute=0, second=0, microsecond=0)
    if restart <= oslo:
        restart += dt.timedelta(days=1)
    names = ', '.join(p['Name'].replace('\n', ' ') for p in players) if players else 'None' if online else 'Unavailable'
    content = (f'**Lembitu · {symbol} {status}**\nPlayers: {count if count is not None else "?"}/10 · {names}\n'
               f'Game: {version}\nPack: {pack}\nUptime: {uptime}\n'
               f'Next daily maintenance: <t:{int(restart.timestamp())}:F> (06:00 Europe/Oslo)\n'
               'Web map: https://lembitu-map.astral.ee')
    payload = {'content': content[:2000], 'allowed_mentions': {'parse': []}}
    webhook = read_env(setting('WEBHOOK_FILE', '~/.config/lembitu/discord-webhooks.env')).get('DISCORD_WEBHOOK_STATUS', '').strip().strip('"\'')
    if webhook:
        url = webhook.rstrip('/').split('?', 1)[0]
        message = state.get('message_id')
        code, response = request('PATCH' if message else 'POST',
                                 url + (f'/messages/{message}' if message else '?wait=true'), payload)
        if message and code == 404:
            code, response = request('POST', url + '?wait=true', payload)
        if 200 <= code < 300 and isinstance(response.get('id'), str):
            state['message_id'] = response['id']
        else:
            warning('Discord status webhook delivery failed; retained state for next cycle')
    else:
        warning('DISCORD_WEBHOOK_STATUS missing; not posting status')
    token = read_env(setting('SERVERBOT_FILE', '~/.config/lembitu/discord-serverbot.env')).get('DISCORD_SERVER_BOT_TOKEN', '').strip().strip('"\'')
    channel = read_env(setting('DISCORD_IDS_FILE', '~/.config/lembitu/discord.env')).get('DISCORD_STATUS_VOICE_CHANNEL_ID', '').strip()
    if not token:
        warning('DISCORD_SERVER_BOT_TOKEN missing; not renaming status channel')
    elif not re.fullmatch(r'[0-9]{17,20}', channel):
        warning('DISCORD_STATUS_VOICE_CHANNEL_ID missing/invalid; not renaming status channel')
    elif voice != state.get('rename_text') and now - state.get('rename_at', 0) >= 300:
        code, _ = request('PATCH', 'https://discord.com/api/v10/channels/' + channel, {'name': voice}, token)
        if 200 <= code < 300:
            state.update(rename_text=voice, rename_at=now)
        else:
            # Reserve the interval even on an ambiguous transport failure: Discord may have applied it.
            state['rename_at'] = now
            warning('Discord status channel rename failed; will retry after five minutes')
    atomic_write(path, state)


if __name__ == '__main__':
    main()
