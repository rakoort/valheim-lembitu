#!/usr/bin/env bash
# Exercise the capture CLI and its emitted integrity report, never historical captures.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

script = Path(os.environ['REPO_ROOT']) / 'scripts/retain-pair.js'

class CaptureIntegrity(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()

    def capture(self, prefix=''):
        logs = {
            '.nt/review-fix-raw/server-unity.log': prefix,
            '.nt/server/BepInEx/LogOutput.log': 'Chainloader startup complete\n',
        }
        for path, heading in logs.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(heading + f'Workspace {self.root}\nServer ID 123456\n'
                              'Opened Steam server\nZNet Shutdown\nSteam manager on destroy\n')
        for path in ('valheim_server.x86_64', 'UnityPlayer.so',
                     'valheim_server_Data/Managed/assembly_valheim.dll',
                     'BepInEx/core/BepInEx.dll', 'BepInEx/config/BepInEx.cfg'):
            target = self.root / '.nt/server' / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b'fixture binary\n')
        result = self.invoke()
        report = json.loads((self.root / '.nt/evidence/capture-integrity.json').read_text())
        return result, report

    def invoke(self):
        return subprocess.run(['bun', str(script), 'a' * 40, 'fixture'], cwd=self.root,
                              capture_output=True, text=True, timeout=20)

    def test_reader_framing_is_reported_before_failure(self):
        result, report = self.capture('[Showing lines 1-3]\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(report['captures']['unity']['readerFramingAbsent'])
        self.assertTrue(report['captures']['bepinex']['readerFramingAbsent'])

    def test_complete_capture_retains_redacted_bytes(self):
        result, report = self.capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        for capture in report['captures'].values():
            for flag in ('fullSourceRead', 'redactionPreservesLineCount',
                         'retainedByteEquality', 'readerFramingAbsent'):
                self.assertTrue(capture[flag], flag)
        self.assertEqual((self.root / '.nt/evidence/server-unity.log').read_bytes(),
                         b'Workspace <RUN_WORKSPACE>\nServer ID <REDACTED>\n'
                         b'Opened Steam server\nZNet Shutdown\nSteam manager on destroy\n')

    def test_line_loss_is_reported_before_failure(self):
        # A legal workspace name with a newline exercises actual redaction line loss.
        self.root /= 'workspace\nsecond-line'
        result, report = self.capture()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(report['captures']['unity']['redactionPreservesLineCount'])
        self.assertTrue(report['captures']['unity']['retainedByteEquality'])

    def test_existing_capture_is_never_rewritten(self):
        result, _ = self.capture()
        self.assertEqual(result.returncode, 0, result.stderr)
        evidence = self.root / '.nt/evidence'
        before = {path.name: path.read_bytes() for path in evidence.iterdir()}
        (self.root / '.nt/review-fix-raw/server-unity.log').write_text('replacement capture')
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual({path.name: path.read_bytes() for path in evidence.iterdir()}, before)

unittest.main()
PY
