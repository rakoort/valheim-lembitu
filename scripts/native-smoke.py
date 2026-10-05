#!/usr/bin/env python3
"""Fast pre-flight for the native session library: minimal mode (harness + JsonDotNET only),
one server, one client, lifecycle moves and harness actions except pack-specific GUI.

    ssh astral-tricep nix shell nixpkgs#python3 nixpkgs#xorg.xdpyinfo -c \
        bash lembitu-work/scripts/native-run.sh lembitu-work/scripts/native-smoke.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import native_session
from native_session import require

PORT = 2497


def main():
    with native_session.Session('smoke', PORT, mode='minimal') as session:
        session.boot_server()
        session.boot_client('a', fixtures=True)

        state = session.snapshot('a')
        require(state['steamId'], 'snapshot has no steamId; platform user not signed in')
        require(state['connection'] == 'Connected', 'not connected')

        state = session.command('a', 'fixture.console', target='help')
        require(state['console']['lines'], 'fixture.console produced no output lines')

        session.command('a', 'fixture.customdata', target='lembitu.harness.smoke', text='ok', value=True)
        state = session.snapshot('a')
        require(any(e['key'] == 'lembitu.harness.smoke' and e['value'] == 'ok' for e in state['customData']),
                'customData round-trip failed')

        state = session.command('a', 'key', target='F7')
        require(state['keyPress']['method'] in ('xdotool', 'synthetic'), 'key used an unknown method')
        session.event('key-smoke', result=state['keyPress'])

        character = session.character('a')
        session.make_admin("a")
        session.relaunch_client('a')
        require(session.snapshot('a')['player']['name'] == character, 'rejoin changed the character')
        state = session.snapshot("a")
        require(state["admin"], f"admin not synchronized: {state['adminList']}, {state['localUserId']}")
        session.checked('quit and rejoin as the same character')

        session.restart_server(keep_world=True)
        require(session.snapshot('a')['connection'] == 'Connected', 'lost connection after restart')
        session.checked('server restarted with the world kept')

        session.event("owner-check", check="two separately licensed clients connected and mutually visible",
                      timing="owner, end of build")
        session.quit_client('a')
        session.report['ok'] = True
        print(f"smoke ok; evidence in {session.directory}", flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('smoke interrupted; proof retained', file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print(f'smoke failed: {error}', file=sys.stderr)
        sys.exit(1)
