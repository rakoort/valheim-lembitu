#!/usr/bin/env python3
"""Repeatable real-game acceptance; run on x86_64 Linux with logged-in Steam and X.

python3 scripts/test-native.py --mode full-pack --port 2486 --repeat 2
python3 scripts/test-native.py --mode minimal --port 2496 --repeat 2

Requires built/staged dist/ and the pinned BepInEx pack. Never installs into the
source games. Copies use Linux reflinks when available (otherwise normal copies).
Each repetition owns private games, saves, characters, world, IPC and process groups.
Proof survives cleanup under --output; minimal success is NOT full-pack acceptance.
Screenshots require human visual inspection; their existence is not rendering proof.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import signal
import socket
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone

import harness

ROOT = Path(__file__).resolve().parent.parent


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def save_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')
    temporary.replace(path)


def inventory_count(state, prefab):
    return sum(item['stack'] for item in state['inventory'] if item['prefab'] == prefab)


class Run:
    def __init__(self, args, directory):
        self.args = args
        self.directory = directory
        self.work = directory / 'work'
        self.work.mkdir()
        self.processes = []
        self.streams = []
        self.control = None
        self.client = None
        self.server = None
        self.report = {'mode': args.mode, 'ok': False, 'checks': [],
                       'visual_review_required': ['skills.png', 'combat.png'],
                       'events_file': 'events.jsonl'}

    def event(self, name, **fields):
        entry = {'time': datetime.now(timezone.utc).isoformat(), 'name': name, **fields}
        with (self.directory / 'events.jsonl').open('a') as stream:
            stream.write(json.dumps(entry, allow_nan=False) + '\n')
        save_json(self.directory / 'proof.json', self.report)

    def checked(self, name):
        self.report['checks'].append(name)
        self.event('passed', check=name)
        print(f'pass: {self.directory.name}: {name}', flush=True)

    def command(self, action, expect_ok=True, error_contains=None, **fields):
        self.alive()
        response = harness.request(self.control, dict(action=action, **fields), self.args.command_timeout)
        self.event('command', command=dict(action=action, **fields), response=response)
        require(response['ok'] == expect_ok,
                f'{action}: expected ok={expect_ok}: {response["error"]}')
        if not expect_ok:
            require(bool(response['error']), f'{action}: refusal has no error')
        if error_contains is not None:
            require(error_contains in response['error'], f'{action}: unexpected refusal: {response["error"]}')
        return response['state']

    def alive(self):
        for label, process in [('server', self.server), ('client', self.client)]:
            if process is not None:
                require(process.poll() is None, f'{label} exited early: {process.returncode}')

    def launch(self, name, command, cwd, env):
        stream = (self.directory / (name + '.log')).open('wb')
        self.streams.append(stream)
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        self.processes.append(process)
        self.event('launch', process=name, pid=process.pid)
        return process

    def stop(self, process):
        # Only groups created by launch(); never search for or kill other game PIDs.
        if process is None or process not in self.processes:
            return
        for sig, timeout in [(signal.SIGINT, 20), (signal.SIGTERM, 10), (signal.SIGKILL, 5)]:
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                break
            try:
                process.wait(timeout=timeout)
                # A runtime wrapper may exit before its child. Escalate only
                # inside this process group, even after its leader was reaped.
                for child_signal in [signal.SIGTERM, signal.SIGKILL]:
                    try:
                        os.killpg(process.pid, child_signal)
                    except ProcessLookupError:
                        break
                    time.sleep(0.2)
                break
            except subprocess.TimeoutExpired:
                continue
        self.processes.remove(process)
        self.event('stopped', pid=process.pid, returncode=process.poll())

    def quit_client(self):
        client = self.client
        require(client is not None, 'no owned client to quit')
        try:
            response = harness.request(self.control, {'action': 'quit'}, self.args.command_timeout)
            self.event('command', command={'action': 'quit'}, response=response)
            require(response['ok'] and response['state'] is None, 'native quit failed: ' + response['error'])
            # A quit acknowledgement is not process exit. Unity must finish its
            # save/unmount/Steam shutdown before another client starts.
            code = client.wait(timeout=self.args.command_timeout)
            require(code == 0, f'native client shutdown exited {code}')
            self.event('client-exited', returncode=code)
        finally:
            self.stop(client)
            self.client = None

    def prepare(self, source, name):
        target = self.work / name
        target.mkdir()
        # Do not bring existing plugins, generated configs, saves or logs into a run.
        excluded = {'BepInEx', 'doorstop_libs', 'doorstop_config.ini', '.doorstop_version',
                    'start_game_bepinex.sh', 'start_server_bepinex.sh', 'worlds',
                    'worlds_local', 'characters', 'characters_local'}
        for entry in source.iterdir():
            if entry.name in excluded or entry.suffix == '.log':
                continue
            subprocess.run(['cp', '-aL', '--reflink=auto', str(entry), str(target / entry.name)], check=True)
        pack = ROOT / 'lib/bepinex/pack/BepInExPack_Valheim'
        for name in ['BepInEx', 'doorstop_libs']:
            shutil.copytree(pack / name, target / name)
        for name in ['doorstop_config.ini', '.doorstop_version', 'start_game_bepinex.sh']:
            shutil.copy2(pack / name, target / name)
        launcher = target / 'start_game_bepinex.sh'
        launcher.chmod(launcher.stat().st_mode | 0o111)
        # The pristine loader pack may include sample plugins/config. Own these trees fully.
        for name in ['plugins', 'patchers', 'config']:
            tree = target / 'BepInEx' / name
            if tree.exists():
                shutil.rmtree(tree)
            tree.mkdir()
        dist = ROOT / 'dist'
        if self.args.mode == 'minimal':
            dist = self.work / 'minimal-dist'
            if not dist.exists():
                (dist / 'plugins').mkdir(parents=True)
                for filename in ['Lembitu.Harness.dll', 'Newtonsoft.Json.dll']:
                    found = list((ROOT / 'dist/plugins').rglob(filename))
                    require(len(found) == 1, f'expected one staged {filename}, found {len(found)}')
                    shutil.copy2(found[0], dist / 'plugins' / filename)
        with (self.directory / ('install-' + target.name + '.log')).open('wb') as log:
            subprocess.run([str(ROOT / 'scripts/install-plugins.sh'), '--dist', str(dist),
                            str(target / 'BepInEx')], stdout=log, stderr=subprocess.STDOUT, check=True)
        files = {}
        for folder in ['plugins', 'patchers', 'config']:
            for file in sorted((target / 'BepInEx' / folder).rglob('*')):
                if file.is_file():
                    with file.open('rb') as stream:
                        digest = hashlib.sha256()
                        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                            digest.update(chunk)
                    files[str(file.relative_to(target / 'BepInEx'))] = digest.hexdigest()
        save_json(self.directory / ('installed-' + target.name + '.json'), files)
        require(any(path.endswith('Lembitu.Harness.dll') for path in files), 'harness not installed')
        return target

    def start_client(self, game, name, password, fixtures):
        self.control = self.directory / (name + '-control')
        self.control.mkdir()
        saves = self.work / (name + '-saves')
        saves.mkdir()
        env = dict(os.environ, VALHEIM_CLIENT_DIR=str(game), LEMBITU_DISPLAY=self.args.display,
                   LEMBITU_CHARACTER='N' + uuid.uuid4().hex[:12])
        command = [str(ROOT / 'scripts/test-client.sh'), 'run',
                   '--control-dir', str(self.control), '--save-dir', str(saves),
                   '--log-file', str(self.directory / (name + '-unity.log'))]
        if fixtures:
            command.append('--fixtures')
        command += [f'127.0.0.1:{self.args.port}', password]
        self.client = self.launch(name, command, game, env)

    def wait_ready(self, wrong_password=False):
        deadline = time.monotonic() + self.args.startup_timeout
        while time.monotonic() < deadline:
            status = harness.read_json(self.control / 'status.json')
            if status:
                if status.get('error'):
                    self.event('startup-status', status=status)
                    require(wrong_password and 'ErrorPassword' in status['error'],
                            f'client startup failed: {status["error"]}')
                    return
                if status.get('ready'):
                    require(not wrong_password, 'wrong password unexpectedly joined')
                    self.event('startup-status', status=status)
                    return
            self.alive()
            time.sleep(1)
        raise RuntimeError('client readiness timed out')

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

    def gameplay(self):
        state = self.command('snapshot')
        require(state['connection'] == 'Connected', 'not connected')
        self.move()
        self.checked('native movement')
        for enabled in [True, False]:
            state = self.command('pvp', value=enabled)
            require(state['player']['pvp'] == enabled, 'native PvP toggle did not apply')
        self.checked('native PvP toggles')
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
        require(enemy['health'] > 0, 'fixture enemy not alive')
        state = self.command('attack', target=enemy_id, seconds=0.2)
        after = next((e for e in state['entities'] if e['id'] == enemy_id), None)
        require(after is not None and 0 <= after['health'] < enemy['health'],
                'attack did not observe enemy health decrease (disappearance is not proof)')
        self.screenshot('combat.png')
        self.checked('native club attack decreased observed enemy health')
        # Natural enemy AI, not a damage/death command. The same IPC endpoint remains
        # in use while the local player object disappears during normal respawn.
        state = self.spawn('Skeleton', 1.5)
        old_player = state['player']['id']
        dead = False
        deadline = time.monotonic() + self.args.lifecycle_timeout
        while time.monotonic() < deadline:
            self.alive()
            response = harness.request(self.control, {'action': 'snapshot'}, self.args.command_timeout)
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
            response = harness.request(self.control, {'action': 'move', 'x': 1, 'z': 0, 'seconds': 1}, self.args.command_timeout)
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

    def start_server(self, server_game, password, name):
        saves = self.work / (name + '-saves')
        saves.mkdir()
        env = dict(os.environ, VALHEIM_TEST_DIR=str(server_game))
        self.server = self.launch(name, [str(ROOT / 'scripts/test-server.sh'), 'run',
            '-name', 'Native acceptance', '-port', str(self.args.port), '-world', 'N' + uuid.uuid4().hex,
            '-password', password, '-public', '0', '-savedir', str(saves),
            '-logFile', str(self.directory / (name + '-unity.log'))], ROOT, env)
        deadline = time.monotonic() + self.args.startup_timeout
        while time.monotonic() < deadline:
            self.alive()
            log = self.directory / (name + '-unity.log')
            text = log.read_text(errors='replace') if log.exists() else ''
            if 'Game server connected' in text:
                self.event('server-ready', marker='Game server connected')
                return
            time.sleep(1)
        raise RuntimeError('server did not report Game server connected')

    def wait_generated_configs(self, games):
        targets = list((ROOT / 'config/enforced').rglob('*.cfg'))
        deadline = time.monotonic() + self.args.startup_timeout
        while time.monotonic() < deadline:
            self.alive()
            missing = [str(target.relative_to(ROOT / 'config/enforced'))
                       for game in games for target in targets
                       if not (game / 'BepInEx/config' / target.relative_to(ROOT / 'config/enforced')).is_file()]
            log = self.directory / 'config-client-unity.log'
            loaded = log.exists() and 'Chainloader startup complete' in log.read_text(errors='replace')
            if loaded and not missing:
                self.event('configuration-generated')
                return
            time.sleep(1)
        raise RuntimeError(f'configuration generation timed out; missing: {missing}')

    def execute(self):
        server_game = self.prepare(self.args.server_dir, 'server')
        client_game = self.prepare(self.args.client_dir, 'client')
        password = 'N' + uuid.uuid4().hex[:16]
        if self.args.mode == 'full-pack':
            self.start_server(server_game, password, 'config-server')
            self.start_client(client_game, 'config-client', password, False)
            # Configuration generation is setup, not an unconfigured gameplay gate.
            self.wait_generated_configs([server_game, client_game])
            self.quit_client()
            self.stop(self.server)
            self.server = None
            for game in [server_game, client_game]:
                with (self.directory / ('enforce-' + game.name + '.log')).open('wb') as log:
                    subprocess.run([str(ROOT / 'scripts/apply-enforced-config.sh'),
                                    str(game / 'BepInEx/config')], stdout=log,
                                   stderr=subprocess.STDOUT, check=True)
            self.checked('generated configs and applied enforced settings before measured boot')
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
        self.report['ok'] = True

    def cleanup(self):
        if self.client is not None and self.client.poll() is None:
            try:
                self.quit_client()
            except Exception as error:
                self.event('cleanup-quit-failed', error=str(error))
        for process in reversed(self.processes[:]):
            self.stop(process)
        for stream in self.streams:
            stream.close()
        # Preserve generated mod logs/config as well as IPC, screenshots and Unity logs.
        for game in ['client', 'server']:
            bepinex = self.work / game / 'BepInEx'
            if bepinex.exists():
                for source in list(bepinex.glob('*.log')) + [bepinex / 'config']:
                    if source.is_dir():
                        shutil.copytree(source, self.directory / (game + '-config'), dirs_exist_ok=True)
                    elif source.is_file():
                        shutil.copy2(source, self.directory / (game + '-' + source.name))
        if not self.args.keep_work:
            shutil.rmtree(self.work)
        self.event('cleanup-complete', work_preserved=self.args.keep_work)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--mode', required=True, choices=['full-pack', 'minimal'])
    parser.add_argument('--port', type=int, required=True, help='unused UDP base port >= 2480; also reserves next two ports')
    parser.add_argument('--repeat', type=int, default=2)
    parser.add_argument('--client-dir', type=Path, default=Path.home() / '.cache/valheim-lembitu/client')
    parser.add_argument('--server-dir', type=Path, default=Path.home() / '.cache/valheim-lembitu/server')
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
