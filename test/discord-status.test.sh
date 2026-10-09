#!/usr/bin/env bash
# Exercise the actual status cycle with fake Docker, clock and Discord transport.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/fake" <<'PY'
#!/usr/bin/env python3
import datetime,json,os,pathlib,sys
name=pathlib.Path(sys.argv[0]).name
now=int(os.environ['NOW'])
if name=='flock': sys.exit(0)
if name=='date': print(now)
if name=='docker':
    if sys.argv[1]=='inspect':
        print(json.dumps({'Running':os.environ.get('FAULT')!='container','StartedAt':'2026-10-09T00:00:00Z'}))
    elif sys.argv[1]=='exec':
        if os.environ.get('FAULT')=='odin': sys.exit(7)
        print(json.dumps([] if os.environ.get('EMPTY') else [{'Name':'Asta','SteamId':'private'},{'Name':'Bjorn','SteamId':'private2'}]))
    elif sys.argv[1]=='logs':
        assert '--since' in sys.argv
        print('Valheim Version: l-0.221.12',file=sys.stderr)
if name=='curl':
    config=sys.stdin.read()
    assert 'status-secret' not in ' '.join(sys.argv) and 'bot-secret' not in ' '.join(sys.argv)
    method=sys.argv[sys.argv.index('--request')+1]
    body=json.loads(sys.argv[sys.argv.index('--data-binary')+1])
    kind='rename' if '/channels/' in config else 'edit' if '/messages/' in config else 'create'
    with open(os.environ['CALLS'],'a') as out: out.write(json.dumps({'kind':kind,'body':body,'now':now})+'\n')
    if kind=='edit' and os.environ.get('GONE'):
        print('{}\n404')
    elif kind=='rename':
        assert 'Authorization: Bot bot-secret' in config
        print('{}\n200')
    else:
        assert 'status-secret' in config
        print('{"id":"123456789012345678"}\n200')
PY
chmod +x "$tmp/bin/fake"
for cmd in docker date curl flock; do ln -s fake "$tmp/bin/$cmd"; done
export PATH="$tmp/bin:$PATH" CALLS="$tmp/calls" NOW=1791504000 FAULT='' EMPTY='' GONE=''
export LEMBITU_DISCORD_STATUS_STATE="$tmp/state.json" LEMBITU_WEBHOOK_FILE="$tmp/webhooks.env"
export LEMBITU_SERVERBOT_FILE="$tmp/bot.env" LEMBITU_DISCORD_IDS_FILE="$tmp/ids.env"
export LEMBITU_PACK_VERSION_FILE="$tmp/pack" LEMBITU_MAINTENANCE_FILE="$tmp/maintenance"
printf 'DISCORD_WEBHOOK_STATUS=https://example.invalid/status-secret\n' >"$LEMBITU_WEBHOOK_FILE"
printf 'DISCORD_SERVER_BOT_TOKEN=bot-secret\n' >"$LEMBITU_SERVERBOT_FILE"
printf 'DISCORD_STATUS_VOICE_CHANNEL_ID=123456789012345679\n' >"$LEMBITU_DISCORD_IDS_FILE"
printf 'v17\n' >"$LEMBITU_PACK_VERSION_FILE"
cycle() { bash "$root/scripts/discord-status.sh" >>"$tmp/output" 2>&1; }
cycle
NOW=$((NOW+60)); cycle
FAULT=container; NOW=$((NOW+60)); cycle
NOW=$((NOW+180)); cycle
printf '%s\n' "$((NOW+1200))" >"$LEMBITU_MAINTENANCE_FILE"
NOW=$((NOW+300)); cycle
rm "$LEMBITU_MAINTENANCE_FILE"
FAULT=; EMPTY=1; NOW=$((NOW+300)); cycle
EMPTY=; GONE=1; NOW=$((NOW+60)); cycle
GONE=; FAULT=odin; NOW=$((NOW+300)); cycle
rm "$LEMBITU_WEBHOOK_FILE" "$LEMBITU_SERVERBOT_FILE"
NOW=$((NOW+300)); cycle
python3 - "$CALLS" "$tmp/output" <<'PY'
import json,sys
rows=[json.loads(s) for s in open(sys.argv[1])]
posts=[r for r in rows if r['kind']=='create']
edits=[r for r in rows if r['kind']=='edit']
renames=[r for r in rows if r['kind']=='rename']
assert len(posts)==2 and len(edits)==7,(len(posts),len(edits))
first=posts[0]['body']['content']
assert '<t:1791518400:F>' in first  # 2026-10-09 06:00 Oslo = 04:00 UTC, ahead of this sample.
for value in ('Online','2/10','Asta, Bjorn','l-0.221.12','v17','0d 0h 0m','06:00 Europe/Oslo','https://lembitu-map.astral.ee'): assert value in first,value
assert 'private' not in first
assert posts[0]['body']['allowed_mentions']=={'parse':[]}
assert 'Offline' in edits[1]['body']['content']
assert 'Restarting' in edits[3]['body']['content']
assert '0/10 · None' in edits[4]['body']['content']
assert 'Offline' in edits[-1]['body']['content'] and '?/10' in edits[-1]['body']['content']
assert [r['body']['name'] for r in renames]==['🟢 Online · 2/10','🔴 Offline','🟠 Restarting','🟢 Online · 0/10','🔴 Offline']
assert all(b['now']-a['now']>=300 for a,b in zip(renames,renames[1:]))
output=open(sys.argv[2]).read()
assert 'DISCORD_WEBHOOK_STATUS missing' in output and 'DISCORD_SERVER_BOT_TOKEN missing' in output
assert 'status-secret' not in output and 'bot-secret' not in output
print('discord-status: online/names, empty, offline, OdinEye failure, maintenance, create/edit/404, rename throttling, missing secrets and secrecy passed')
PY
# Real curl smoke against a local fake HTTP server, including the credential transport.
PATH="${PATH#"$tmp/bin:"}" PYTHONDONTWRITEBYTECODE=1 python3 - "$root/scripts/discord-status.py" <<'PY'
import http.server,importlib.util,json,sys,threading
spec=importlib.util.spec_from_file_location('status',sys.argv[1])
status=importlib.util.module_from_spec(spec); spec.loader.exec_module(status)
seen=[]
class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self): self.reply()
    def do_PATCH(self): self.reply()
    def log_message(self,*args): pass
    def reply(self):
        body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        seen.append((self.command,self.path,body,self.headers.get('Authorization')))
        self.send_response(404 if self.path.endswith('/gone') else 200)
        self.end_headers(); self.wfile.write(b'{"id":"123456789012345678"}')
server=http.server.HTTPServer(('127.0.0.1',0),Handler)
thread=threading.Thread(target=server.serve_forever); thread.start()
base=f'http://127.0.0.1:{server.server_port}/webhooks/local-secret'
try:
    assert status.request('POST',base+'?wait=true',{'content':'online'})[0]==200
    assert status.request('PATCH',base+'/messages/gone',{'content':'offline'})[0]==404
    assert status.request('PATCH',base+'/channels/123',{'name':'🟢 Online · 2/10'},'bot-secret')[0]==200
    assert seen[0][:3]==('POST','/webhooks/local-secret?wait=true',{'content':'online'})
    assert seen[2][2:]==({'name':'🟢 Online · 2/10'},'Bot bot-secret')
finally:
    server.shutdown(); thread.join(); server.server_close()
print('discord-status: real curl local HTTP create, 404 and authenticated rename passed')
PY
