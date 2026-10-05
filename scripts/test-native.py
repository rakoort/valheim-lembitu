#!/usr/bin/env python3
"""Repeatable real-game acceptance; run on x86_64 Linux with logged-in Steam and X.

python3 scripts/test-native.py --mode full-pack --port 2486 --repeat 2
python3 scripts/test-native.py --mode minimal --port 2496 --repeat 2

Requires built/staged dist/, the pinned BepInEx pack and an initialized native
preference profile (--preferences; docs/build.md, first-run settings). Never installs into the
source games. Copies use Linux reflinks when available (otherwise normal copies).
Each repetition owns private games, saves, characters, world, IPC and process groups.
Proof survives cleanup under --output; minimal success is NOT full-pack acceptance.
Screenshots require human visual inspection; their existence is not rendering proof.

This file is the acceptance coordinator. The engine — installs, config generation and the
enforced overlay, server/client lifecycles, IPC, evidence retention — lives in
scripts/native_session.py, which scenario scripts import directly (see its docstring).
"""

import argparse
import json
import math
import os
from pathlib import Path
import platform
import signal
import socket
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone

import harness
import native_session

ROOT = Path(__file__).resolve().parent.parent

require = native_session.require
save_json = native_session.save_json
preferences_initialized = native_session.preferences_initialized


def inventory_count(state, prefab):
    return sum(item['stack'] for item in state['inventory'] if item['prefab'] == prefab)


class Run:
    """One acceptance repetition on the persistent-session engine.

    The surface is the historical one: private installs and saves under the run directory, a
    single server, one active client at a time, commands against it, retained evidence.
    """

    def __init__(self, args, directory):
        self.args = args
        self.directory = directory
        self.work = directory / 'work'
        self.work.mkdir(parents=True, exist_ok=True)
        self.session = native_session.Session(
            label=directory.name, port=args.port, mode=args.mode, directory=directory,
            keep_work=getattr(args, 'keep_work', False),
            display=getattr(args, 'display', None), preferences=getattr(args, 'preferences', None),
            client_dir=getattr(args, 'client_dir', None), server_dir=getattr(args, 'server_dir', None),
            startup_timeout=getattr(args, 'startup_timeout', 1500.0),
            command_timeout=getattr(args, 'command_timeout', 60.0),
            lifecycle_timeout=getattr(args, 'lifecycle_timeout', 240.0),
            root=ROOT)
        self.session.report.update({'visual_review_required': ['skills.png', 'combat.png']})
        self.current = None

    # ---- historical surface over the engine ---------------------------------------------------

    def event(self, name, **fields):
        self.session.event(name, **fields)
        save_json(self.directory / 'proof.json', self.session.report)

    def checked(self, name):
        self.session.checked(name)
        save_json(self.directory / 'proof.json', self.session.report)

    @property
    def report(self):
        return self.session.report

    def alive(self):
        self.session.alive()

    def command(self, action, expect_ok=True, error_contains=None, **fields):
        return self.session.command(self.current, action, expect_ok=expect_ok,
                                    error_contains=error_contains, **fields)

    def prepare(self, source, name):
        return self.session._prepare(source, name)

    def start_client(self, game, name, password, fixtures):
        client = native_session.Client(
            name=name, character='N' + uuid.uuid4().hex[:12], install=game,
            saves=self.work / (name + '-saves'), control=self.directory / (name + '-control'),
            fixtures=fixtures)
        (client.saves).mkdir(parents=True, exist_ok=True)
        self.session.clients[name] = client
        client.process = self.session._launch(
            name, self._client_command(client, password), game, self.session._client_env(client))
        self.current = name

    def _client_command(self, client, password):
        command = [str(ROOT / 'scripts/test-client.sh'), 'run',
                   '--control-dir', str(client.control), '--save-dir', str(client.saves),
                   '--log-file', str(self.directory / (client.name + '-unity.log'))]
        if client.fixtures:
            command.append('--fixtures')
        command += [f'127.0.0.1:{self.args.port}', password]
        return command

    def wait_ready(self, wrong_password=False):
        self.session._wait_ready(self.session.clients[self.current],
                                 refuse_contains='ErrorPassword' if wrong_password else None)

    def screenshot(self, name):
        path = self.directory / name
        self.command('screenshot', target=str(path))
        with path.open('rb') as image:
            require(image.read(8) == b'\x89PNG\r\n\x1a\n', 'screenshot is not a PNG')

    def move(self):
        before = self.command('snapshot')['player']
        after = self.command('move', x=1, z=0, seconds=2)['player']
        distance = math.hypot(after['x'] - before['x'], after['z'] - before['z'])
        require(distance > 0.5, f'native movement only displaced {distance} metres')

    def spawn(self, prefab, dx, dy=0.3):
        player = self.command('snapshot')['player']
        return self.command('fixture.spawn', target=prefab,
                            x=player['x'] + dx, y=player['y'] + dy, z=player['z'])

    def start_server(self, server_game, password, name):
        # The regression test drives this directly: one server on a caller-chosen game copy.
        self.session.server_password = password
        self.session.server_world = self.session.server_world or 'N' + uuid.uuid4().hex
        self.session.server_saves = self.work / (name + '-saves')
        self.session.server_saves.mkdir(parents=True, exist_ok=True)
        self.session._start_server(server_game, name)

    def quit_client(self):
        client = self.session.clients[self.current]
        self.session.quit_client(client)
        self.session.clients.pop(self.current, None)
        self.current = None

    def gameplay(self):
        state = self.command('snapshot')
        require(state['connection'] == 'Connected', 'not connected')
        self.move()
        self.checked('native movement')
        # The full pack holds PvP off for everyone (Venture Multiplayer Tweaks, enforced; ADR-0019), so
        # there a request to turn it on must not stick. Minimal mode has no such rule.
        pvp_allowed = self.args.mode != 'full-pack'
        for enabled in [True, False]:
            state = self.command('pvp', value=enabled)
            require(state['player']['pvp'] == (enabled and pvp_allowed),
                    'PvP toggle did not apply' if pvp_allowed else 'PvP turned on despite the pack holding it off')
        self.checked('native PvP toggles' if pvp_allowed else 'PvP held off by the pack')
        if self.args.mode == 'full-pack':
            # Lembitu.Guide opens on a fresh character's first join (ADR-0027) and holds Jotunn's
            # input block, which also keeps the inventory from closing; a player closes it first.
            if any(w['name'] == 'LembituGuide' for w in state.get('windows', [])):
                state = self.command('key', target='F1')
                require(not any(w['name'] == 'LembituGuide' for w in state.get('windows', [])),
                        'F1 did not close the first-join guide')
            self.checked('first-join guide closed with F1')
        for target in ['inventory', 'map']:
            for value in [True, False]:
                state = self.command('ui', target=target, value=value)
                require(state['ui'][target] == value, f'{target} did not toggle')
        state = self.command('ui', target='inventory', value=True)
        skills = next((b for b in state['ui']['buttons'] if 'skill' in b['text'].lower()
                       and b['active'] and b['interactable']), None)
        require(skills is not None, 'no observed active Skills button')
        self.command('ui', target=skills['id'], value=True)
        self.screenshot('skills.png')
        state = self.command('ui', target='inventory', value=False)
        inactive = next((b for b in state['ui']['buttons'] if not b['active']), None)
        require(inactive is not None, 'no inactive observed button for rejection test')
        self.command('ui', expect_ok=False, target=inactive['id'], value=True)
        self.command('move', expect_ok=False, x=1, z=0, seconds=0)
        self.command('move', expect_ok=False, x=2, z=0, seconds=1)
        self.command('equip', expect_ok=False, item='nonexistent-' + uuid.uuid4().hex)
        self.checked('UI toggles, observed Skills click and native rejection boundaries')
        require(inventory_count(state, 'Wood') == 0, 'fresh character already has wood')
        for count in range(1, 7):
            state = self.spawn('Wood', 3)
            wood = state['fixtureSpawned']
            state = self.command('interact', target=wood)
            require(inventory_count(state, 'Wood') == count, 'native wood pickup did not increment inventory')
            if count == 1:
                state = self.command('ui', target='inventory', value=True)
                require('Recipe_Club' in state['ui']['recipes'], 'club recipe not observed')
                self.command('craft', expect_ok=False, recipe='Recipe_Club')
                self.command('ui', target='inventory', value=False)
        state = self.command('craft', recipe='Recipe_Club')
        require(inventory_count(state, 'Wood') == 0, 'club did not consume six wood')
        clubs = [item for item in state['inventory'] if item['prefab'] == 'Club']
        require(len(clubs) == 1 and clubs[0]['stack'] == 1, 'craft did not produce one club')
        state = self.command('equip', item=clubs[0]['id'])
        require(any(item['id'] == clubs[0]['id'] and item['equipped'] for item in state['inventory']),
                'native equip did not select club')
        self.command('ui', target='inventory', value=False)
        self.checked('native pickup, insufficient-resource refusal, craft consumption and equip')
        # A Greydwarf survives even a high-roll opening hit; a disappearing corpse
        # cannot establish observed health loss.
        state = self.spawn('Greydwarf', 1.3, 0.2)
        enemy_id = state['fixtureSpawned']
        enemy = next(e for e in state['entities'] if e['id'] == enemy_id)
        require(0 < enemy['health'] == enemy['maxHealth'], 'fixture enemy not alive and unhurt')
        state = self.command('attack', target=enemy_id, seconds=0.2)
        after = next((e for e in state['entities'] if e['id'] == enemy_id), None)
        # The full pack's creature levels can raise a creature's health after it spawns (observed 40
        # at spawn and 74 after one club hit). The scaling keeps damage already taken, so a hit shows
        # as health below the creature's own maximum, not below the first reading.
        require(after is not None and 0 <= after['health'] < after['maxHealth'],
                'attack did not leave the enemy below full health (disappearance is not proof)')
        self.screenshot('combat.png')
        self.checked('native club attack left the enemy below full health')
        # Natural enemy AI, not a damage/death command. The same IPC endpoint remains
        # in use while the local player object disappears during normal respawn.
        state = self.spawn('Skeleton', 1.5)
        old_player = state['player']['id']
        dead = False
        deadline = time.monotonic() + self.args.lifecycle_timeout
        while time.monotonic() < deadline:
            self.alive()
            response = harness.request(self.session.clients[self.current].control,
                                       {'action': 'snapshot'}, self.args.command_timeout)
            self.event('lifecycle-snapshot', response=response)
            if response['ok']:
                player = response['state']['player']
                dead |= player['dead'] and player['health'] <= 0
                if dead and player['id'] != old_player and player['health'] > 0 and not player['dead']:
                    break
            else:
                require('no local player' in response['error'], response['error'])
            time.sleep(0.25)
        else:
            raise RuntimeError('natural death and new living player not observed before deadline')
        # Snapshot does not expose cutscene/teleport state. Wait through native spawn
        # restrictions only; do not mask any other command rejection.
        deadline = time.monotonic() + 60
        while True:
            before = self.command('snapshot')['player']
            response = harness.request(self.session.clients[self.current].control,
                                       {'action': 'move', 'x': 1, 'z': 0, 'seconds': 1},
                                       self.args.command_timeout)
            self.event('respawn-move', response=response)
            if response['ok']:
                after = response['state']['player']
                require(after['id'] == before['id'], 'player changed during respawn movement')
                require(math.hypot(after['x'] - before['x'], after['z'] - before['z']) > 0.5,
                        'native movement after respawn did not displace the player')
                break
            require('cutscene' in response['error'] and time.monotonic() < deadline, response['error'])
            time.sleep(1)
        self.checked('natural death, respawn on same endpoint and movement afterward')

    def execute(self):
        self.session.__enter__()
        server_game = self.prepare(self.args.server_dir, 'server')
        client_game = self.prepare(self.args.client_dir, 'client')
        password = 'N' + uuid.uuid4().hex[:16]
        if self.args.mode == 'full-pack':
            self.session.server_password = password
            self.session.server_world = 'N' + uuid.uuid4().hex
            self.session.server_saves = self.work / 'config-server-saves'
            self.session._generate_configs([server_game, client_game])
            for game in [server_game, client_game]:
                self.session._apply_enforced([game])
            self.checked('generated configs and applied enforced settings before measured boot')
            self.session._apply_dedicated(server_game)
        self.session.server_password = password
        self.session.server_world = self.session.server_world or 'N' + uuid.uuid4().hex
        self.session.server_saves = self.work / 'server-saves'
        self.session.server_saves.mkdir(parents=True, exist_ok=True)
        self.start_server(server_game, password, 'server')
        # Permission checks precede hostile fixtures so a dead player cannot cause
        # a misleading refusal, and a later fresh character cannot inherit combat.
        self.start_client(client_game, 'no-fixtures', password, False)
        self.wait_ready()
        player = self.command('snapshot')['player']
        self.command('fixture.spawn', expect_ok=False, error_contains='-lembitu-fixtures', target='Wood',
                     x=player['x'] + 3, y=player['y'] + 0.3, z=player['z'])
        self.checked('fixtures refused without opt-in')
        self.quit_client()
        # AutoServerPassword saves the password of a good join and enters it itself next time, which
        # turns this check into a join. The refusal under test is the server's, so the client forgets it.
        self.session.forget_saved_password(client_game, label='client')
        self.start_client(client_game, 'wrong-password', password + 'wrong', False)
        self.wait_ready(wrong_password=True)
        self.checked('wrong password rejected with ErrorPassword')
        self.quit_client()
        self.checked('native quit after rejected startup without a local player')
        self.start_client(client_game, 'gameplay', password, True)
        self.wait_ready()
        self.gameplay()
        self.quit_client()
        self.checked('native quit after gameplay and respawn')
        self.session.report['ok'] = True

    def cleanup(self):
        self.session.cleanup()
        save_json(self.directory / 'proof.json', self.session.report)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--mode', required=True, choices=['full-pack', 'minimal'])
    parser.add_argument('--port', type=int, required=True, help='unused UDP base port >= 2480; also reserves next two ports')
    parser.add_argument('--repeat', type=int, default=2)
    parser.add_argument('--client-dir', type=Path, default=Path.home() / '.cache/valheim-lembitu/client')
    parser.add_argument('--server-dir', type=Path, default=Path.home() / '.cache/valheim-lembitu/server')
    parser.add_argument('--preferences', type=Path, default=Path.home() / '.cache/valheim-lembitu/client-preferences',
                        help="initialized native preference profile; the client's XDG_CONFIG_HOME")
    parser.add_argument('--display', default=os.environ.get('LEMBITU_DISPLAY', ':0'))
    parser.add_argument('--output', type=Path, default=Path.home() / '.local/state/lembitu/native-tests')
    parser.add_argument('--startup-timeout', type=float, default=1500)
    parser.add_argument('--command-timeout', type=float, default=60)
    parser.add_argument('--lifecycle-timeout', type=float, default=240)
    parser.add_argument('--keep-work', action='store_true', help='retain disposable installs/saves for diagnosis')
    args = parser.parse_args()
    require(args.repeat > 0, '--repeat must be positive')
    require(2480 <= args.port <= 65533, '--port must be 2480..65533; live/default ports are prohibited')
    require(all(value > 0 and math.isfinite(value) for value in [args.startup_timeout, args.command_timeout, args.lifecycle_timeout]),
            'timeouts must be finite positive numbers')
    require(platform.system() == 'Linux' and platform.machine() == 'x86_64', 'real game requires x86_64 Linux')
    for source, binary in [(args.client_dir, 'valheim.x86_64'), (args.server_dir, 'valheim_server.x86_64')]:
        require((source / binary).is_file(), f'missing {source / binary}')
    args.preferences = args.preferences.expanduser().resolve()
    require(preferences_initialized(args.preferences),
            f'{args.preferences} has no chosen language; run the first-run settings setup in docs/build.md')
    require(subprocess.run(['xdpyinfo', '-display', args.display], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL).returncode == 0, 'start a GPU-backed display first; runner will not own your compositor')
    require(subprocess.run(['pgrep', '-f', 'ubuntu12_32/steam'], stdout=subprocess.DEVNULL).returncode == 0,
            'a logged-in Steam client is required')
    args.client_dir = args.client_dir.resolve()
    args.server_dir = args.server_dir.resolve()
    session = args.output.expanduser().resolve() / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + args.mode + '-' + uuid.uuid4().hex[:8])
    session.mkdir(parents=True)
    print(session, flush=True)
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    successes = []
    for index in range(args.repeat):
        # Check all three without reuse flags before launch; never connect to an
        # existing server merely because its port responds. Readiness is our log.
        sockets = []
        try:
            for port in range(args.port, args.port + 3):
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sockets.append(sock)
                sock.bind(('0.0.0.0', port))
        finally:
            for sock in sockets:
                sock.close()
        directory = session / f'run-{index + 1}'
        directory.mkdir()
        run = Run(args, directory)
        try:
            run.execute()
        except (Exception, KeyboardInterrupt) as error:
            run.report['ok'] = False
            run.event('failure', error=str(error), error_type=type(error).__name__)
            raise
        finally:
            run.cleanup()
            successes.append(run.report['ok'])
            save_json(session / 'summary.json', {'mode': args.mode, 'requested_runs': args.repeat,
                'completed_runs': successes, 'ok': len(successes) == args.repeat and all(successes),
                'full_pack_pass': args.mode == 'full-pack' and len(successes) == args.repeat and all(successes),
                'visual_review_required': True})
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('native test interrupted; proof retained', file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print(f'native test failed: {error}', file=sys.stderr)
        sys.exit(1)
