#!/usr/bin/env bash
# Verify ServerManager's discord.yml is generated from the layout files, with no token, 0600.
# Usage: bash test/servermanager-discord.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export ROOT WORK PYTHONDONTWRITEBYTECODE=1
python3 - <<'PY'
import json, os, pathlib, stat, subprocess
root, work = pathlib.Path(os.environ['ROOT']), pathlib.Path(os.environ['WORK'])
cfg = work / 'cfg'; cfg.mkdir(); store = work / 'store'
env = dict(os.environ, LEMBITU_DISCORD_CONFIG=str(cfg))
count = 0
def run():
    return subprocess.run(['python3', str(root / 'scripts/servermanager-discord.py'), str(store)], capture_output=True, text=True, env=env)
def check(name, cond, detail=''):
    global count
    assert cond, f'{name}: {detail}'
    print('pass: ' + name); count += 1
ids = {'DISCORD_GUILD_ID': '111111111111111111', 'DISCORD_OWNER_USER_ID': '222222222222222222',
       'DISCORD_CHANNEL_ADMIN_CONSOLE_ID': '333333333333333333', 'DISCORD_CHANNEL_CHAT_ID': '444444444444444444',
       'DISCORD_OPS_APP_ID': '555555555555555555'}
(cfg / 'discord.env').write_text(''.join(f'{k}={v}\n' for k, v in ids.items()))
routes = ['STATUS', 'ACTIVITY', 'CHAT', 'ADMIN_ALERTS', 'MONITOR', 'PACK_RELEASES']
(cfg / 'discord-webhooks.env').write_text(''.join(f'DISCORD_WEBHOOK_{r}=https://discord.com/api/webhooks/1/{r.lower()}-secret\n' for r in routes))
r = run()
check('generates discord.yml', r.returncode == 0, r.stderr)
target = store / 'discord.yml'
data = json.loads(''.join(l for l in target.read_text().splitlines(True) if not l.startswith('#')))
check('file is private', stat.S_IMODE(target.stat().st_mode) == 0o600)
check('bot uses the guild, owner, admin-console and chat IDs, and no token',
      data['bot'] == {'enabled': True, 'token': '', 'guild_ids': [111111111111111111], 'admin_user_ids': [222222222222222222],
                      'admin_channel_ids': [333333333333333333], 'chat_channel_ids': [444444444444444444]})
by = {w['name']: w for w in data['webhooks']}
check('four ServerManager routes; monitor and Pack-release routes stay ours', sorted(by) == ['Activity', 'Admin alerts', 'Chat', 'Server status'])
check('admin alerts carry the security and character events with Steam IDs',
      'security.alert' in by['Admin alerts']['events'] and 'character.validation' in by['Admin alerts']['events'] and by['Admin alerts']['include_steam_id'] is True)
check('public routes never include Steam IDs', all('include_steam_id' not in by[n] for n in ['Activity', 'Chat', 'Server status']))
check('output prints no webhook secret', 'secret' not in r.stdout + r.stderr)
(cfg / 'discord.env').write_text('DISCORD_GUILD_ID=111111111111111111\n')
r = run()
check('missing channel IDs are refused by name', r.returncode != 0 and 'DISCORD_OWNER_USER_ID' in r.stderr)
print(f'{count} passed, 0 failed')
PY
