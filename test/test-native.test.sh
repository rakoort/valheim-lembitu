#!/usr/bin/env bash
# Steam registration precedes world generation and does not mean clients can connect.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import concurrent.futures
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest

repo = Path(os.environ['REPO_ROOT'])
sys.path.insert(0, str(repo / 'scripts'))
spec = importlib.util.spec_from_file_location('native', repo / 'scripts/test-native.py')
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
import native_session

class ServerReadiness(unittest.TestCase):
    def test_registration_does_not_release_waiting_client(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'scripts').mkdir()
            gate = root / 'allow-host-open'
            server = root / 'scripts/test-server.sh'
            # A real child process emits the two native protocol stages separately.
            # The test controls host opening; registration alone must never release the waiter.
            server.write_text(f'''#!{sys.executable}
from pathlib import Path
import sys
import time
log = Path(sys.argv[sys.argv.index('-logFile') + 1])
log.write_text('Game server connected\\n')
while not Path({str(gate)!r}).exists():
    time.sleep(0.01)
with log.open('a') as stream:
    stream.write('Opened Steam server\\n')
while True:
    time.sleep(1)
''')
            server.chmod(0o755)
            native.ROOT = root
            args = SimpleNamespace(mode='minimal', port=2486, startup_timeout=15, keep_work=False)
            run = native.Run(args, root)
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                waiting = pool.submit(run.start_server, root, 'test-password', 'server')
                try:
                    log = root / 'server-unity.log'
                    deadline = time.monotonic() + 10
                    while not log.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(log.exists(), 'fake server never reached registration')
                    with self.assertRaises(concurrent.futures.TimeoutError,
                                           msg='registration incorrectly reported a joinable server'):
                        waiting.result(timeout=2.5)
                    gate.touch()
                    waiting.result(timeout=5)
                finally:
                    gate.touch()
                    try:
                        waiting.result(timeout=15)
                    finally:
                        run.cleanup()

class PreferenceProfile(unittest.TestCase):
    # Any launch writes the game's own prefs file; only the first-run Settings choice records the
    # language that keeps early Localization off Steamworks, so only that counts.
    def test_only_a_chosen_language_counts_as_initialized(self):
        header = '<unity_prefs version_major="1" version_minor="1">\n'
        with tempfile.TemporaryDirectory() as temporary:
            profile = Path(temporary)
            self.assertFalse(native.preferences_initialized(profile), 'empty profile accepted')
            game = profile / 'unity3d/IronGate/Valheim/prefs'
            game.parent.mkdir(parents=True)
            game.write_text(header + '\t<pref name="ShouldTryAutoLogin" type="int">1</pref>\n</unity_prefs>\n')
            unity = profile / 'unity3d/unknown/unknown/prefs'
            unity.parent.mkdir(parents=True)
            unity.write_text(header + '\t<pref name="MasterVolume" type="float">1</pref>\n</unity_prefs>\n')
            self.assertFalse(native.preferences_initialized(profile), 'profile without a language accepted')
            unity.write_text(header + '\t<pref name="language" type="string">RW5nbGlzaA==</pref>\n</unity_prefs>\n')
            self.assertTrue(native.preferences_initialized(profile), 'initialized profile refused')

class SingleClientOwnership(unittest.TestCase):
    def test_second_client_is_refused_before_install_or_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            session = native_session.Session("ownership", 2486, root=root, directory=root)
            session.server = object()
            session.clients["a"] = SimpleNamespace(process=object())
            with self.assertRaisesRegex(RuntimeError, "only one native client may run"):
                session.boot_client("b")
            self.assertEqual(set(session.clients), {"a"})
            self.assertFalse((root / "work").exists())

unittest.main()
PY
