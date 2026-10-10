#!/usr/bin/env bash
# Generate or verify ServerManager's policy from an unpacked Pack, never hand-edited DLL lists.
# Usage: servermanager-policy.sh apply|check --pack <root> --store <savedir>/ServerManager
#                              --load-server-character false|true
# Owns ServerManager.yml and required/optional only; never touches characters, cron or Discord.
set -euo pipefail
# shellcheck source=lib/python.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/python.sh"
run_python - "$@" <<'PY'
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import sys
import struct
import tempfile

parser = argparse.ArgumentParser(description='Apply/check the character-store policy from the Pack')
parser.add_argument('action', choices=('apply', 'check'))
parser.add_argument('--pack', type=Path, required=True)
parser.add_argument('--store', type=Path, required=True)
parser.add_argument('--load-server-character', choices=('false', 'true'), required=True)
args = parser.parse_args()
# Presentation-only mods a client may leave out. ValheimVisualEnhanced is filtered to the client
# process and has no sync; tricep's GPU hangs with it, so it is optional (owner, 2026-10-10).
optional = {'AzuHoverStats', 'AzuClock', 'MouseTweaks', 'CraftingSearch',
            'CompactStatusEffects', 'LiveExperienceTracker', 'oathbound_addon',
            'ValheimVisualEnhanced'}
server_only = {'ValheimWebMap', 'Server_devcommands', 'OdinEye', 'Lembitu.Harness'}
plugins = args.pack / 'BepInEx/plugins'
if not plugins.is_dir():
    parser.error('Pack must contain BepInEx/plugins')
if args.store.is_symlink():
    parser.error('store must not be a symlink')
def managed_dll(file):
    # ServerManager accepts managed references only. Pack media dependencies also
    # contain Windows native DLLs: their extension is not evidence of a plugin.
    data = file.read_bytes()
    if len(data) < 64 or data[:2] != b"MZ":
        return False
    pe = struct.unpack_from("<I", data, 60)[0]
    if pe + 26 > len(data) or data[pe:pe + 4] != b"PE\0\0":
        return False
    optional_header = pe + 24
    magic = struct.unpack_from("<H", data, optional_header)[0]
    directories = optional_header + (96 if magic == 0x10b else 112 if magic == 0x20b else len(data))
    clr = directories + 14 * 8
    if clr + 8 > len(data):
        return False
    rva, size = struct.unpack_from("<II", data, clr)
    return rva != 0 and size != 0

expected = {"required": {}, "optional": {}}
for file in sorted(plugins.rglob('*')):
    if file.is_symlink():
        parser.error('Pack must not contain symlinks')
    if not file.is_file() or file.suffix.lower() != '.dll':
        continue
    relative = file.relative_to(plugins)
    package = relative.parts[0] if len(relative.parts) > 1 else file.stem
    if package in server_only or file.stem in server_only:
        continue
    if not managed_dll(file):
        continue
    side = 'optional' if package in optional or file.stem in optional else 'required'
    expected[side][relative] = file
if not expected['required']:
    parser.error('Pack contains no required DLLs')
settings = (f'serverSettings:\n  maxPlayers: 10\n  maxCharactersPerAccount: 1\n'
            f'  loadServerCharacterOnJoin: {args.load_server_character}\n'
            'startItems: []\ncheatDetection:\n  action: log\nstatCaps:\n  action: log\n').encode()

def digest(file):
    return hashlib.sha256(file.read_bytes()).digest()

def drift():
    problems = []
    config = args.store / 'ServerManager.yml'
    if not config.is_file() or config.is_symlink() or config.read_bytes() != settings:
        problems.append('ServerManager.yml differs from the chosen settings/enrollment phase')
    for side, wanted in expected.items():
        folder = args.store / side
        if folder.is_symlink():
            problems.append(f'{side} is a symlink')
            continue
        present = {p.relative_to(folder): p for p in folder.rglob('*') if p.is_file() or p.is_symlink()}
        for relative in sorted(set(wanted) | set(present)):
            current = present.get(relative)
            source = wanted.get(relative)
            if source is None or current is None or current.is_symlink() or digest(current) != digest(source):
                problems.append(f'{side}/{relative} missing, extra, or hash mismatch')
    return problems

if args.action == 'apply':
    args.store.mkdir(parents=True, exist_ok=True)
    # Build replacements before touching the active policy. Run stopped, before server start:
    # directory swaps are separately atomic, not an atomic policy transaction for a live watcher.
    with tempfile.TemporaryDirectory(prefix='.lembitu-policy-', dir=args.store) as staging:
        staging = Path(staging)
        for side, wanted in expected.items():
            replacement = staging / side
            replacement.mkdir()
            for relative, source in wanted.items():
                target = replacement / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        (staging / 'ServerManager.yml').write_bytes(settings)
        for side in expected:
            target = args.store / side
            if target.is_symlink():
                parser.error(f'{side} must not be a symlink')
            if target.exists():
                shutil.rmtree(target)
            os.replace(staging / side, target)
        os.replace(staging / 'ServerManager.yml', args.store / 'ServerManager.yml')
problems = drift()
for problem in problems:
    print('drift: ' + problem, file=sys.stderr)
if problems:
    sys.exit(1)
print(f"ServerManager policy verified: {len(expected['required'])} required DLLs, "
      f"{len(expected['optional'])} optional DLLs; loadServerCharacterOnJoin={args.load_server_character}")
PY
