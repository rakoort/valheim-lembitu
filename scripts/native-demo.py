#!/usr/bin/env python3
"""End-to-end demonstration of the native session library and harness actions, on astral-tricep.

Run (the tree must be pushed to ~/lembitu-stage first):

    rsync -a --delete --exclude dist-client --exclude '**/bin/' --exclude '**/obj/' \
          --exclude .git ./ astral-tricep:lembitu-stage/
    ssh astral-tricep nix shell nixpkgs#python3 nixpkgs#xorg.xdpyinfo -c \
        bash lembitu-work/scripts/native-run.sh lembitu-work/scripts/native-demo.py

What it proves, in order: full-Pack server boot with the enforced overlay; a client joining with
fixtures and admin (fixture opt-in refusal, adminlist, rejoin, admin console output); a snapshot
carrying HUD messages, customData and custom windows with button IDs; a real F7 keypress opening
the Marketplace window; quit and rejoin as the same character; a server restart that keeps the
world; a client missing Lembitu.Guide being refused at join; and a client installed from the
shipped client Pack zip. Two-player acceptance belongs to the owner at the end of the build.
"""

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import native_session

PORT = 2486
LABEL = 'demo'


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    with native_session.Session(LABEL, PORT) as session:
        password = session.boot_server(admin=True)
        # The overlay is asserted, not assumed, on the measured server install (#69); the output
        # doubles as Pack acceptance evidence for whoever staged dist/ last.
        verify = subprocess.run(
            [str(Path(__file__).resolve().parent / 'verify-enforced-config.sh'),
             str(session.work / 'server' / 'BepInEx' / 'config')],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        session.event('verify-enforced', exit=verify.returncode,
                      output=verify.stdout[-4000:])
        require(verify.returncode == 0, f'enforced config verification failed: {verify.stdout[-500:]}')
        session.checked('enforced overlay verified on the server config')

        # ---- join with fixtures and admin ------------------------------------------------------
        session.boot_client('a', fixtures=True)
        steam_id = session.make_admin('a')
        session.event('admin-steam-id', steam_id=steam_id)
        session.relaunch_client('a')
        state = session.snapshot('a')
        require(state['admin'], f'client a is not admin after rejoin (steamId {steam_id})')
        session.checked('admin after adminlist write and rejoin')

        # ---- console: help output, and an admin-only server command --------------------------
        state = session.command('a', 'fixture.console', target='help')
        require(state['console']['lines'], 'console produced no output lines')
        session.event('console-help', lines=state['console']['lines'])
        state = session.command("a", "fixture.console", target="banned")
        session.event("console-admin", lines=state["console"]["lines"])
        require("Banned users" in state["console"]["lines"],
                f"server did not return admin-only banned list: {state['console']['lines']}")
        session.checked('fixture.console output and server-side admin command')

        # ---- HUD message, customData, custom window ------------------------------------------
        player = session.snapshot('a')['player']
        state = session.command("a", "fixture.spawn", target="Wood",
                                x=player["x"] + 2, y=player["y"] + 0.3, z=player["z"])
        wood = state["fixtureSpawned"]
        state = session.command('a', 'interact', target=wood)
        require(state['recentMessages'], 'no HUD messages observed after a pickup')
        session.event('hud-messages', messages=state['recentMessages'][-5:])
        session.command('a', 'fixture.customdata', target='lembitu.harness.demo', text='1', value=True)
        state = session.snapshot('a')
        custom = {entry['key']: entry['value'] for entry in state['customData']}
        require(custom.get('lembitu.harness.demo') == '1', 'customData round-trip failed')
        require(any(w['custom'] for w in state['windows']), 'no custom window visible')
        session.checked('snapshot carries HUD messages, customData and custom windows')

        # ---- key press opens the Marketplace window ------------------------------------------
        before = {w['name'] for w in session.snapshot('a')['windows']}
        state = session.command('a', 'key', target='F7')
        session.event('key-press', result=state['keyPress'])
        after = session.snapshot('a')['windows']
        opened = [w for w in after if w['name'] not in before and w['custom']]
        if not opened and state['keyPress']['method'] == 'xdotool':
            session.event('key-retry', reason='xdotool press opened nothing; trying InputSystem events')
            state = session.command('a', 'key', target='F7', method='synthetic')
            after = session.snapshot('a')['windows']
            opened = [w for w in after if w['name'] not in before and w['custom']]
        require(opened, f'F7 opened no custom window; windows now: {[w["name"] for w in after]}')
        window = opened[0]
        require(window['buttons'], 'the opened custom window has no observed buttons')
        require(any("MARKETPLACE" in text.upper() for text in window["texts"]),
                f"F7 opened {window['name']}, not the Marketplace")
        session.command('a', 'screenshot', target=str(session.directory / 'marketplace.png'))
        session.event('key-opened-window', window=window['name'], buttons=len(window['buttons']))
        session.checked('key press observed through the opened window and its button IDs')
        session.command('a', 'key', target='F7')  # close it again before the join tests

        # ---- quit, rejoin as the same character ----------------------------------------------
        character = session.character('a')
        session.relaunch_client('a')
        state = session.snapshot('a')
        require(state['player']['name'] == character,
                f'rejoined as {state["player"]["name"]!r}, not {character!r}')
        session.checked('quit and rejoin as the same character')

        # ---- server restart keeping the world -------------------------------------------------
        session.restart_server(keep_world=True)
        state = session.snapshot('a')
        require(state['connection'] == 'Connected', 'client not connected after server restart')
        require(any(session.directory.glob("server-before-restart-*.log")),
                "first server boot log was not preserved")
        require("Opened Steam server" in (session.directory / "server-unity.log").read_text(errors="replace"),
                "second server boot not observed")
        session.checked('server restarted with the world kept')

        session.event("owner-check", check="two separately licensed clients connected and mutually visible",
                      timing="owner, end of build")

        session.quit_client("a")
        session.boot_client("probe-exclude", fixtures=False, exclude=("Lembitu.Guide",),
                            join_refusal="")
        server_log = (session.work / "server/BepInEx/LogOutput.log").read_text(errors="replace")
        refusal_lines = [line for line in server_log.splitlines()
                         if "Missing mod on client: Lembitu.Guide" in line]
        require(refusal_lines, "server has no Guide refusal log line")
        session.event("exclude-refusal", server_lines=refusal_lines)
        session.quit_client("probe-exclude")
        session.checked("client without Lembitu.Guide refused at join")

        packs = sorted(Path("/tmp/lembitu-client-pack").glob("lembitu-client-pack-*.zip"))
        require(packs, "no client Pack zip under /tmp/lembitu-client-pack")
        session.boot_client("packtest", fixtures=False, install=packs[-1])
        state = session.snapshot("packtest")
        require(state["connection"] == "Connected", "pack client not connected")
        session.checked("client Pack zip installs and joins the full-Pack server")
        session.quit_client("packtest")

        session.report['ok'] = True
        print(json.dumps({"ok": True, "evidence": str(session.directory)}, indent=2))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print('demo interrupted; proof retained', file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print(f'demo failed: {error}', file=sys.stderr)
        sys.exit(1)
