#!/usr/bin/env python3
"""Persistent native Valheim test sessions: the engine behind scripts/test-native.py and the
library scenario scripts import to drive the real game on a Linux host with logged-in Steam
and a GPU-backed X display.

Session layout: one evidence directory (default ~/lembitu-native-tests/<stamp>-<label>/) holds
events.jsonl, summary.json, every log, every IPC control directory, installed-file manifests and
screenshots. Disposable game installs and save directories live under evidence/work/ and are
removed on cleanup unless keep_work is set. Only process groups the session launched are
signalled. Only one native session may run at a time on a host: wrap the whole scenario, and any
rsync feeding it, in `flock ~/lembitu-native.lock`.

Scenario usage:

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
    import native_session

    with native_session.Session(label="demo", port=2486) as session:
        password = session.boot_server(admin=True)      # full Pack from dist/, enforced config
        session.boot_client("a", fixtures=True)         # fresh character, harness opt-in
        state = session.snapshot("a")
        session.command("a", "fixture.console", target="help")
        session.quit_client("a")
        session.boot_client("a", character=session.character("a"), fresh_character=False)
        session.restart_server(keep_world=True)
        session.quit_client("a")
        session.boot_client("b")                        # sequential client, own install/saves

Clients install from dist/ (default) or from a client Pack zip (install=path/to/pack.zip); both
install Lembitu.Harness on top, because the Pack itself ships without it. `exclude=("Lembitu.Guide",)`
removes named plugins from one install so a full-Pack server's refusal at join can be observed.
Only one client may run at a time. The owner performs two-player checks at the end of the build
with separate licensed Steam identities; one account fails Steam session-ticket authentication.
Admin support writes Steam_<ID> into the server's adminlist.txt; the server reloads that file
within ten seconds and the client must rejoin to see it.
"""

from __future__ import annotations

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
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

import harness

def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def save_json(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')
    temporary.replace(path)


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def preferences_initialized(profile):
    # Valheim's first-run Settings stores the chosen language here. Without it, the first
    # Localization access migrates platform keys through Steamworks before Steam starts; the
    # throw lands in Herbalist's and AdditiveDamageModifier's Awake, so they never write config.
    prefs = profile / 'unity3d/unknown/unknown/prefs'
    return prefs.is_file() and 'name="language"' in prefs.read_text(errors='replace')


def ports_free(port, count=4):
    # Check without reuse flags before launch; never connect to an existing server merely because
    # its port responds. Readiness is our log, not a socket probe.
    sockets = []
    try:
        for offset in range(count):
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sockets.append(sock)
            sock.bind(('0.0.0.0', port + offset))
    finally:
        for sock in sockets:
            sock.close()


def steam_id_cache_path(home=None):
    return Path(home or Path.home()) / '.cache/valheim-lembitu/native/steamid.txt'


def cached_steam_id(home=None):
    try:
        value = steam_id_cache_path(home).read_text(encoding='utf-8').strip()
        return value or None
    except OSError:
        return None


@dataclass
class Client:
    name: str
    character: str
    install: Path
    saves: Path
    control: Path
    fixtures: bool
    process: subprocess.Popen | None = None
    spec_install: object = 'dist'
    exclude: tuple = ()


class Session:
    """One owned slice of the real game: a test server, N harness clients, retained evidence."""

    def __init__(self, label, port, *, mode='full-pack', output=None, directory=None,
                 keep_work=False, display=None, preferences=None, client_dir=None,
                 server_dir=None, startup_timeout=1500.0, command_timeout=60.0,
                 lifecycle_timeout=240.0, root=None, tool_path=None):
        self.label = label
        self.port = port
        self.mode = mode
        self.keep_work = keep_work
        self.display = display or os.environ.get('LEMBITU_DISPLAY', ':0')
        self.startup_timeout = float(startup_timeout)
        self.command_timeout = float(command_timeout)
        self.lifecycle_timeout = float(lifecycle_timeout)
        self.root = Path(root or Path(__file__).resolve().parent.parent)
        self.preferences = Path(preferences or Path.home() / '.cache/valheim-lembitu/client-preferences')
        # The licensed client lives in a Steam library on some hosts (astral-tricep) and in the
        # cache on others (astral-bicep); LEMBITU_CLIENT_DIR selects it without flags.
        self.client_dir = Path(client_dir or os.environ.get('LEMBITU_CLIENT_DIR')
                               or Path.home() / '.cache/valheim-lembitu/client')
        self.server_dir = Path(server_dir or os.environ.get('LEMBITU_SERVER_DIR')
                               or Path.home() / '.cache/valheim-lembitu/server')
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.directory = (Path(directory) if directory
                          else Path(output or Path.home() / 'lembitu-native-tests') / f'{stamp}-{label}')
        self.work = self.directory / 'work'
        self.tool_path = Path(tool_path) if tool_path else Path.home() / '.cache/valheim-lembitu/tools/bin'
        self.clients: dict[str, Client] = {}
        self.server = None
        self.server_saves = None
        self.server_world = None
        self.server_password = None
        self.streams = []
        self.processes = []
        self.report = {'label': label, 'mode': mode, 'port': port, 'ok': False, 'checks': [],
                       'events_file': 'events.jsonl', 'started': utc_now()}
        self._entered = False

    # ---- lifecycle ---------------------------------------------------------------------------

    def __enter__(self):
        require(2480 <= self.port <= 65530, 'session port must be 2480..65530; live/default ports are prohibited')
        require(platform.system() == 'Linux' and platform.machine() == 'x86_64',
                'real game requires x86_64 Linux')
        require(self.mode in ('full-pack', 'minimal'), f'unknown mode: {self.mode}')
        for value in [self.startup_timeout, self.command_timeout, self.lifecycle_timeout]:
            require(value > 0 and math.isfinite(value), 'timeouts must be finite positive numbers')
        for source, binary in [(self.client_dir, 'valheim.x86_64'), (self.server_dir, 'valheim_server.x86_64')]:
            require((source / binary).is_file(), f'missing {source / binary}')
        self.preferences = self.preferences.expanduser().resolve()
        require(preferences_initialized(self.preferences),
                f'{self.preferences} has no chosen language; run the first-run settings setup in docs/build.md')
        require(subprocess.run(['xdpyinfo', '-display', self.display], stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL).returncode == 0,
                'start a GPU-backed display first; the session does not own the compositor')
        require(subprocess.run(['pgrep', '-f', 'ubuntu12_32/steam'], stdout=subprocess.DEVNULL).returncode == 0,
                'a logged-in Steam client is required')
        ports_free(self.port)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.work.mkdir(parents=True, exist_ok=True)
        self.client_dir = self.client_dir.resolve()
        self.server_dir = self.server_dir.resolve()
        self.event('session-open', display=self.display, mode=self.mode)
        self._entered = True
        return self

    def __exit__(self, exc_type, exc, tb):
        self.cleanup()
        return False

    def checked(self, name):
        self.report['checks'].append(name)
        self.event('passed', check=name)
        print(f'pass: {self.directory.name}: {name}', flush=True)

    def event(self, name, **fields):
        entry = {'time': utc_now(), 'name': name, **fields}
        with (self.directory / 'events.jsonl').open('a') as stream:
            stream.write(json.dumps(entry, allow_nan=False) + '\n')
        save_json(self.directory / 'summary.json', self.report)

    # ---- process engine ----------------------------------------------------------------------

    def alive(self):
        for label, process in [('server', self.server)] + [
                (f'client {name}', client.process) for name, client in self.clients.items()]:
            if process is not None:
                require(process.poll() is None, f'{label} exited early: {process.returncode}')

    def _launch(self, name, command, cwd, env):
        stream = (self.directory / (name + '.log')).open('wb')
        self.streams.append(stream)
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        self.processes.append(process)
        self.event('launch', process=name, pid=process.pid)
        return process

    def _stop(self, process):
        # Only groups created by _launch(); never search for or kill other game PIDs.
        if process is None or process not in self.processes:
            return
        for sig, timeout in [(signal.SIGINT, 20), (signal.SIGTERM, 10), (signal.SIGKILL, 5)]:
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                break
            try:
                process.wait(timeout=timeout)
                # A runtime wrapper may exit before its child. Escalate only inside this process
                # group, even after its leader was reaped.
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

    # ---- installs ----------------------------------------------------------------------------

    def _prepare(self, source, name, install='dist', exclude=()):
        """A pristine game copy plus the pinned loader plus the chosen plugin source."""
        target = self.work / name
        if target.exists():
            # Installs are disposable and per-boot: a fresh copy cannot inherit another boot's
            # plugins, generated configs or AutoServerPassword state. Saves live elsewhere.
            shutil.rmtree(target)
        target.mkdir()
        # Do not bring existing plugins, generated configs, saves or logs into a run.
        excluded = {'BepInEx', 'doorstop_libs', 'doorstop_config.ini', '.doorstop_version',
                    'start_game_bepinex.sh', 'start_server_bepinex.sh', 'worlds',
                    'worlds_local', 'characters', 'characters_local', 'config'}
        for entry in source.iterdir():
            if entry.name in excluded or entry.suffix == '.log':
                continue
            subprocess.run(['cp', '-aL', '--reflink=auto', str(entry), str(target / entry.name)], check=True)
        pack = self.root / 'lib/bepinex/pack/BepInExPack_Valheim'
        for part in ['BepInEx', 'doorstop_libs']:
            shutil.copytree(pack / part, target / part)
        for part in ['doorstop_config.ini', '.doorstop_version', 'start_game_bepinex.sh']:
            shutil.copy2(pack / part, target / part)
        launcher = target / 'start_game_bepinex.sh'
        launcher.chmod(launcher.stat().st_mode | 0o111)
        # The pristine loader pack may include sample plugins/config. Own these trees fully.
        for part in ['plugins', 'patchers', 'config']:
            tree = target / 'BepInEx' / part
            if tree.exists():
                shutil.rmtree(tree)
            tree.mkdir()
        with (self.directory / ('install-' + name + '.log')).open('wb') as log:
            if install == 'dist':
                self._install_dist(target, log)
            else:
                self._install_pack(target, Path(install), log)
        self._apply_exclusions(target, exclude)
        files = self._installed_manifest(target)
        save_json(self.directory / f'installed-{name}.json', files)
        require(any(path.endswith('Lembitu.Harness.dll') for path in files), 'harness not installed')
        return target

    @staticmethod
    def _installed_manifest(target):
        files = {}
        for folder in ['plugins', 'patchers', 'config']:
            for file in sorted((target / 'BepInEx' / folder).rglob('*')):
                if file.is_file():
                    with file.open('rb') as stream:
                        digest = hashlib.sha256()
                        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                            digest.update(chunk)
                    files[str(file.relative_to(target / 'BepInEx'))] = digest.hexdigest()
        return files

    def _install_dist(self, target, log):
        dist = self.root / 'dist'
        if self.mode == 'minimal':
            dist = self.work / 'minimal-dist'
            if not dist.exists():
                (dist / 'plugins').mkdir(parents=True)
                for filename in ['Lembitu.Harness.dll', 'Newtonsoft.Json.dll']:
                    found = list((self.root / 'dist/plugins').rglob(filename))
                    require(len(found) == 1, f'expected one staged {filename}, found {len(found)}')
                    shutil.copy2(found[0], dist / 'plugins' / filename)
        subprocess.run([str(self.root / 'scripts/install-plugins.sh'), '--dist', str(dist),
                        str(target / 'BepInEx')], stdout=log, stderr=subprocess.STDOUT, check=True)

    def _install_pack(self, target, pack_zip, log):
        """Install from a client Pack zip. The Pack is the complete BepInEx overlay a player
        extracts, so its own loader (with the file(1) probe patch) wins; only the test harness is
        added on top, because build-client-pack.sh excludes the harness from player packs."""
        require(pack_zip.is_file(), f'client pack zip not found: {pack_zip}')
        listing = subprocess.run(['unzip', '-Z1', str(pack_zip)], stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True)
        require(listing.returncode == 0, f'cannot read client pack: {listing.stdout}')
        require('start_game_bepinex.sh' in listing.stdout and 'doorstop_config.ini' in listing.stdout,
                f'{pack_zip} is not a complete client install overlay (no loader)')
        subprocess.run(['unzip', '-oq', str(pack_zip), '-d', str(target)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
        launcher = target / 'start_game_bepinex.sh'
        launcher.chmod(launcher.stat().st_mode | 0o111)
        harness_dll = list((self.root / 'dist/plugins').rglob('Lembitu.Harness.dll'))
        require(len(harness_dll) == 1, f'expected one built Lembitu.Harness.dll, found {len(harness_dll)}')
        shutil.copy2(harness_dll[0], target / 'BepInEx/plugins/Lembitu.Harness.dll')
        log.write(f'installed client pack {pack_zip} + Lembitu.Harness.dll\n'.encode())

    def _apply_exclusions(self, target, exclude):
        if not exclude:
            return
        plugins = target / 'BepInEx/plugins'
        removed = []
        for name in exclude:
            candidates = [p for p in (plugins / name, plugins / f'{name}.dll') if p.exists()]
            require(candidates, f'excluded plugin {name} is not installed in {plugins}')
            for tree in candidates:
                if tree.is_dir():
                    shutil.rmtree(tree)
                else:
                    tree.unlink()
                removed.append(str(tree.relative_to(target / 'BepInEx')))
        save_json(self.directory / f'excluded-{target.name}.json', {'removed': removed})
        self.event('plugins-excluded', install=target.name, removed=removed)

    # ---- server ------------------------------------------------------------------------------

    def boot_server(self, *, password=None, world=None, fresh=True, save_dir=None, admin=False):
        """Prepare and start the test server. full-pack mode generates configs through one
        disposable client and applies the enforced overlay first; a kept save dir (fresh=False,
        or save_dir given) skips the generation round trip because its configs already exist,
        but still gets the (idempotent) enforced overlay. Returns the join password."""
        require(self._entered, 'use the session as a context manager (or call __enter__ first)')
        require(self.server is None, 'server already running; restart_server() or stop it first')
        self.server_password = password or ('N' + uuid.uuid4().hex[:16])
        self.server_world = world or ('N' + uuid.uuid4().hex)
        self.server_saves = Path(save_dir) if save_dir else self._fresh_saves('server')
        server_game = self._prepare(self.server_dir, 'server')
        if self.mode == 'full-pack':
            if fresh and save_dir is None:
                self._generate_configs([server_game])
            else:
                self.event('config-generation-skipped', reason='kept save dir')
            self._apply_enforced([server_game])
            self._apply_dedicated(server_game)
        if admin:
            known = cached_steam_id()
            if known:
                self.write_adminlist(known)
            else:
                self.event('admin-deferred', reason='no cached Steam ID yet; call make_admin() after the first join')
        self._start_server(server_game, 'server')
        self.checked('server ready with the enforced overlay' if self.mode == 'full-pack'
                     else 'server ready')
        return self.server_password

    def _fresh_saves(self, name):
        path = self.work / (name + '-saves')
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _generate_configs(self, games):
        """full-pack setup: mods write their configs on first boot in a disposable world. The
        generation server runs on its own save dir with the same password; the measured boot
        follows afterwards with the real one."""
        client_game = self._prepare(self.client_dir, 'config')
        keep_saves = self.server_saves
        self.server_saves = self._fresh_saves('config-server')
        self._start_server(games[0], 'config-server')
        config_client = Client(
            name='config-client', character='N' + uuid.uuid4().hex[:12],
            install=client_game, saves=self._fresh_saves('config-client'),
            control=self.work / 'config-client-control', fixtures=False)
        self.clients['config-client'] = config_client
        try:
            self._start_client_process(client_game, config_client)
            self._wait_generated_configs([games[0], client_game])
        finally:
            if config_client.process is not None:
                try:
                    self.quit_client(config_client)
                except Exception as error:
                    self.event('cleanup-quit-failed', client='config-client', error=str(error))
            self._stop(self.server)
            self.server = None
            self.clients.pop('config-client', None)
            self.server_saves = keep_saves
        # A fresh measured world starts with the launch roster, not setup-client assignments.
        dedicated = games[0] / 'config/bepinex'
        dedicated.mkdir(parents=True, exist_ok=True)
        for source in (self.root / 'config/dedicated').rglob('*'):
            if source.is_file() and source.suffix != '.cfg':
                destination = dedicated / source.relative_to(self.root / 'config/dedicated')
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, destination)
                self.event('dedicated-roster-seeded', file=str(destination))
        for game in games[1:]:
            shutil.copytree(client_game / 'BepInEx/config', game / 'BepInEx/config', dirs_exist_ok=True)
        self.checked('generated configs in a disposable world')

    def _apply_enforced(self, games):
        for game in games:
            with (self.directory / (f'enforce-{game.name}.log')).open('wb') as log:
                subprocess.run([str(self.root / 'scripts/apply-enforced-config.sh'),
                                str(game / 'BepInEx/config')], stdout=log,
                               stderr=subprocess.STDOUT, check=True)
        self.event('enforced-config-applied', games=[str(game) for game in games])

    def _apply_dedicated(self, server_game):
        destination = server_game / 'config/bepinex'
        with (self.directory / 'dedicated-server.log').open('wb') as log:
            subprocess.run([str(self.root / 'scripts/apply-dedicated-config.sh'), str(destination)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
        manifest = {str(path.relative_to(destination)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in sorted(destination.rglob('*')) if path.is_file()}
        save_json(self.directory / 'dedicated-server.json', manifest)
        self.event('dedicated-config-applied', destination=str(destination), files=manifest)

    def _wait_generated_configs(self, games):
        targets = list((self.root / 'config/enforced').rglob('*.cfg'))
        deadline = time.monotonic() + self.startup_timeout
        missing = []
        while time.monotonic() < deadline:
            self.alive()
            missing = [str(target.relative_to(self.root / 'config/enforced'))
                       for game in games for target in targets
                       if not (game / 'BepInEx/config' / target.relative_to(self.root / 'config/enforced')).is_file()]
            log = self.directory / 'config-client-unity.log'
            loaded = log.exists() and 'Chainloader startup complete' in log.read_text(errors='replace')
            if loaded and not missing:
                self.event('configuration-generated')
                return
            time.sleep(1)
        raise RuntimeError(f'configuration generation timed out; missing: {missing}')

    def _start_server(self, server_game, name):
        env = dict(os.environ, VALHEIM_TEST_DIR=str(server_game))
        log_name = name + '-unity'
        self.server = self._launch(log_name, [str(self.root / 'scripts/test-server.sh'), 'run',
            '-name', 'Native acceptance', '-port', str(self.port), '-world', self.server_world,
            '-password', self.server_password, '-public', '0', '-savedir', str(self.server_saves),
            '-logFile', str(self.directory / (log_name + '.log'))], self.root, env)
        deadline = time.monotonic() + self.startup_timeout
        log = self.directory / (log_name + '.log')
        while time.monotonic() < deadline:
            self.alive()
            text = log.read_text(errors='replace') if log.exists() else ''
            # Steam registration precedes world generation; hosting opens only afterward.
            if 'Opened Steam server' in text:
                self.event('server-ready', marker='Opened Steam server', world=self.server_world)
                return
            time.sleep(1)
        raise RuntimeError('server did not open its Steam listener after world generation')

    def restart_server(self, *, keep_world=True):
        """Stop the server and start it again. keep_world=True reuses the same save dir and world
        name, so the world and its characters survive; SIGINT lets the server save first."""
        require(self.server is not None, 'no running server to restart')
        self.event('server-restart', keep_world=keep_world)
        running = [client for client in self.clients.values() if client.process is not None]
        for client in running:
            self.quit_client(client.name)
        self._stop(self.server)
        self.server = None
        previous_log = self.directory / "server-unity.log"
        if previous_log.exists():
            number = len(list(self.directory.glob("server-before-restart-*.log"))) + 1
            previous_log.rename(self.directory / f"server-before-restart-{number}.log")
        if not keep_world:
            self.server_saves = self._fresh_saves('server')
            self.server_world = 'N' + uuid.uuid4().hex
        self._start_server(self.work / 'server', 'server')
        self.checked('server restarted' + (' with the same world' if keep_world else ''))
        for client in running:
            self.boot_client(client.name, character=client.character, fresh_character=False,
                             fixtures=client.fixtures, install=client.spec_install, exclude=client.exclude)

    def write_adminlist(self, steam_id):
        """Write the admin list into the server's save dir. The server reloads the file at most
        ten seconds after it changes (SyncedList m_loadInterval); joining clients receive the list
        at join, so a client must (re)join afterwards to act as admin."""
        require(steam_id, 'no Steam ID for adminlist.txt; join once and call make_admin()')
        platform_id = steam_id if steam_id.startswith("Steam_") else "Steam_" + steam_id
        require(self.server_saves is not None, 'server save dir unknown; boot the server first')
        path = self.server_saves / 'adminlist.txt'
        lines = path.read_text(errors='replace').splitlines() if path.exists() else []
        if platform_id not in lines:
            with path.open("a") as stream:
                stream.write(platform_id + "\n")
        self.event('adminlist-written', path=str(path), steam_id=steam_id)
        return steam_id

    def make_admin(self, client, *, wait_reload=11.0):
        """Read the client's own Steam ID from its snapshot, cache it, and write it into
        adminlist.txt. The client must rejoin (or a fresh client join) to receive the list."""
        state = self.snapshot(client)
        steam_id = state['steamId']
        require(steam_id, f'client {client} snapshot has no steamId; is the platform user signed in?')
        try:
            steam_id_cache_path().parent.mkdir(parents=True, exist_ok=True)
            steam_id_cache_path().write_text(steam_id + '\n')
        except OSError as error:
            self.event('steam-id-cache-failed', error=str(error))
        self.write_adminlist(steam_id)
        if wait_reload:
            time.sleep(wait_reload)  # SyncedList reloads at most every ten seconds.
        return steam_id

    # ---- clients -----------------------------------------------------------------------------

    def boot_client(self, name, *, character=None, fresh_character=True, fixtures=True,
                    install='dist', exclude=(), join_refusal=None):
        """Prepare a private install for this client and join the running test server. A fresh
        character is created when fresh_character is set; otherwise `character` must name an
        existing profile in this client's save dir. join_refusal='<text>' requires the server to
        refuse the join with that text (e.g. over a missing mandatory plugin). Returns the
        Client; readiness state proves either outcome."""
        require(self.server is not None, 'boot the server before joining clients')
        require(not any(client.process is not None for client in self.clients.values()),
                "only one native client may run; quit the current client before boot_client()")
        existing = self.clients.get(name)
        require(existing is None or existing.process is None,
                f'client {name} is running; quit_client() first')
        if not fresh_character:
            require(character, 'boot_client(fresh_character=False) requires an existing character name')
        character = character or ('N' + uuid.uuid4().hex[:12])
        install_game = self._prepare(self.client_dir, f'client-{name}',
                                     install=install, exclude=tuple(exclude))
        saves = self.work / f'{name}-saves'
        saves.mkdir(parents=True, exist_ok=True)
        control = self.work / f'{name}-control'
        if control.exists():
            shutil.rmtree(control)  # A fresh control directory per launch; retained status is not liveness.
        client = Client(name=name, character=character, install=install_game, saves=saves,
                        control=control, fixtures=bool(fixtures), spec_install=install,
                        exclude=tuple(exclude))
        self.clients[name] = client
        self._start_client_process(install_game, client)
        status = self._wait_ready(client, refuse_contains=join_refusal)
        if join_refusal is None:
            self.checked(f'client {name} joined as {character}' +
                         (' with fixtures' if fixtures else ''))
        else:
            self.event('join-refused', client=name, contains=join_refusal, status=status)
            self.checked(f'client {name} refused at join as expected')
        return client

    def relaunch_client(self, name, **boot_args):
        """Quit a client and boot it again as the same character from its own save dir."""
        client = self.clients.get(name)
        require(client is not None, f'unknown client: {name}')
        self.quit_client(name)
        boot_args.setdefault('character', client.character)
        boot_args.setdefault('fresh_character', False)
        boot_args.setdefault('fixtures', client.fixtures)
        boot_args.setdefault('install', client.spec_install)
        boot_args.setdefault('exclude', client.exclude)
        return self.boot_client(name, **boot_args)

    def _client_env(self, client):
        env = dict(os.environ, VALHEIM_CLIENT_DIR=str(client.install),
                   LEMBITU_DISPLAY=self.display, LEMBITU_CHARACTER=client.character,
                   XDG_CONFIG_HOME=str(self.preferences))
        if self.tool_path.is_dir():
            # Real OS input for the key action: xdotool on the client's display (nix-provisioned).
            env['PATH'] = str(self.tool_path) + os.pathsep + env.get('PATH', '')
        return env

    def _start_client_process(self, game, client):
        command = [str(self.root / 'scripts/test-client.sh'), 'run',
                   '--control-dir', str(client.control), '--save-dir', str(client.saves),
                   '--log-file', str(self.directory / (client.name + '-unity.log'))]
        if client.fixtures:
            command.append('--fixtures')
        command += [f'127.0.0.1:{self.port}', self.server_password or '']
        client.process = self._launch(client.name, command, game, self._client_env(client))
        return client

    def _wait_ready(self, client, refuse_contains=None):
        deadline = time.monotonic() + self.startup_timeout
        while time.monotonic() < deadline:
            status = harness.read_json(client.control / 'status.json')
            if status:
                if status.get('error'):
                    self.event('startup-status', client=client.name, status=status)
                    require(refuse_contains is not None and refuse_contains in status['error'],
                            f'client {client.name} startup failed: {status["error"]}')
                    return status
                if status.get('ready'):
                    require(refuse_contains is None,
                            f'client {client.name} joined although a refusal was expected')
                    self.event('startup-status', client=client.name, status=status)
                    return status
            self.alive()
            time.sleep(1)
        raise RuntimeError(f'client {client.name} readiness timed out')

    def raw(self, client, command, timeout=None):
        """One harness request; returns the full response dict and records it as evidence."""
        client = self.clients[client] if isinstance(client, str) else client
        self.alive()
        response = harness.request(client.control, command, timeout or self.command_timeout)
        self.event('command', client=client.name, command=command, response=response)
        return response

    def command(self, client, action, expect_ok=True, error_contains=None, **fields):
        response = self.raw(client, dict(action=action, **fields))
        require(response['ok'] == expect_ok,
                f'{action}: expected ok={expect_ok}: {response["error"]}')
        if not expect_ok:
            require(bool(response['error']), f'{action}: refusal has no error')
        if error_contains is not None:
            require(error_contains in response['error'],
                    f'{action}: unexpected refusal: {response["error"]}')
        return response['state']

    def snapshot(self, client):
        return self.command(client, 'snapshot')

    def quit_client(self, name):
        client = self.clients[name] if isinstance(name, str) else name
        process = client.process
        require(process is not None, f'no owned client process for {client.name}')
        try:
            response = harness.request(client.control, {'action': 'quit'}, self.command_timeout)
            self.event('command', client=client.name, command={'action': 'quit'}, response=response)
            require(response['ok'] and response['state'] is None, 'native quit failed: ' + response['error'])
            # A quit acknowledgement is not process exit. Unity must finish its save/unmount/Steam
            # shutdown before another client starts.
            code = process.wait(timeout=self.command_timeout)
            require(code == 0, f'native client shutdown exited {code}')
            self.event('client-exited', client=client.name, returncode=code)
        finally:
            self._stop(process)
            client.process = None

    def forget_saved_password(self, install_dir, label=''):
        """AutoServerPassword saves the password of a good join and enters it itself next time;
        checks that need the server's own refusal must forget it first."""
        path = Path(install_dir) / 'BepInEx/config/AutoServerPassword/passwords.json'
        path.unlink(missing_ok=True)
        self.event('saved-password-forgotten', install=str(install_dir) if label == '' else label,
                   path=str(path))

    def character(self, name):
        client = self.clients.get(name)
        require(client is not None, f'unknown client: {name}')
        return client.character

    def save_dir(self, name):
        client = self.clients.get(name)
        require(client is not None, f'unknown client: {name}')
        return client.saves

    def control_dir(self, name):
        client = self.clients.get(name)
        require(client is not None, f'unknown client: {name}')
        return client.control

    # ---- shutdown ----------------------------------------------------------------------------

    def stop_all(self):
        for name in list(self.clients):
            client = self.clients[name]
            if client.process is not None and client.process.poll() is None:
                try:
                    self.quit_client(name)
                except Exception as error:
                    self.event('cleanup-quit-failed', client=name, error=str(error))
        if self.server is not None:
            self._stop(self.server)
            self.server = None

    def cleanup(self):
        self.stop_all()
        for process in reversed(self.processes[:]):
            self._stop(process)
        for stream in self.streams:
            stream.close()
        # Preserve generated mod logs/config as well as IPC, screenshots and Unity logs.
        if self.work.exists():
            for install in sorted(self.work.glob('*')):
                bepinex = install / 'BepInEx'
                if not bepinex.exists():
                    continue
                tag = install.name
                dedicated = install / 'config/bepinex'
                if dedicated.is_dir():
                    shutil.copytree(dedicated, self.directory / (tag + '-dedicated-config'), dirs_exist_ok=True)
                for source in list(bepinex.glob('*.log')) + [bepinex / 'config']:
                    if source.is_dir():
                        shutil.copytree(source, self.directory / (tag + '-config'), dirs_exist_ok=True)
                    elif source.is_file():
                        shutil.copy2(source, self.directory / (tag + '-' + source.name))
        if not self.keep_work and self.work.exists():
            shutil.rmtree(self.work)
        self.report['finished'] = utc_now()
        self.event('cleanup-complete', work_preserved=self.keep_work)
