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

unittest.main()
PY
