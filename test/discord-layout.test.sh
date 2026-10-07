#!/usr/bin/env bash
# Exercise discord-layout.sh against a stateful fake curl API; no network or keychain access.
# Usage: bash test/discord-layout.test.sh (requires python3 and jq).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" FAKE_STATE="$WORK/state.json"
mkdir -p "$HOME/.config/lembitu" "$WORK/bin"
export PATH="$WORK/bin:$PATH"
cat > "$HOME/.config/lembitu/discord.env" <<'ENV'
DISCORD_GUILD_ID=11111111111111111
DISCORD_OWNER_USER_ID=22222222222222222
DISCORD_OPS_APP_ID=33333333333333333
DISCORD_SERVER_BOT_APP_ID=44444444444444444
ENV
cat > "$WORK/bin/security" <<'SH'
#!/usr/bin/env bash
printf '%s' 'FAKE_OPS_TOKEN_DO_NOT_PRINT'
SH
cat > "$WORK/bin/curl" <<'PY'
#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
args=sys.argv[1:]
def arg(k): return args[args.index(k)+1]
assert 'FAKE_OPS_TOKEN_DO_NOT_PRINT' in sys.stdin.read()
p=Path(os.environ['FAKE_STATE'])
s=json.loads(p.read_text()) if p.exists() else {'roles':[{'id':'ops','managed':True,'tags':{'bot_id':'33333333333333333'}},{'id':'server','managed':True,'tags':{'bot_id':'44444444444444444'}}], 'channels':[], 'hooks':{}, 'writes':0,'calls':0,'next':100,'times':[]}
s['calls']+=1;s['times'].append(time.monotonic())
method=arg('--request'); path=args[-1].split('/api/v10')[1].split('/')[1:]
body=json.loads(arg('--data') or '{}');status=200;out={};headers=''
if os.environ.get('FAKE_ERROR') and not s.get('errored'):
 status=int(os.environ['FAKE_ERROR']);s['errored']=True
 headers='Retry-After: 0.15\r\n';out={'retry_after':0.01,'global':True}
elif method=='GET':
 if path[0]=='guilds': out=s[path[2]]
 else: out=s['hooks'].get(path[1],[])
elif method=='POST':
 s['next']+=1;out=dict(body,id=str(s['next']));s['writes']+=1
 if path[0]=='guilds':s[path[2]].append(out)
 else:
  out.update(type=1,token='FAKE_WEBHOOK_SECRET');s['hooks'].setdefault(path[1],[]).append(out)
elif method=='PATCH':
 s['writes']+=1
 items=s['roles'] if path[0]=='guilds' else s['channels']
 target=next(x for x in items if x['id']==path[-1]);target.update(body);out=target
else: raise AssertionError((method,path))
p.write_text(json.dumps(s));Path(arg('--output')).write_text(json.dumps(out));Path(arg('--dump-header')).write_text(headers)
print(status,end='')
PY
chmod +x "$WORK/bin/security" "$WORK/bin/curl"
pass=0 fail=0
report() { if "$@"; then echo "pass: $*"; pass=$((pass+1)); else echo "FAIL: $*"; fail=$((fail+1)); fi; }
run() { bash "$ROOT/scripts/discord-layout.sh" "$@" > "$WORK/output" 2>&1; }
state() { jq -e "$1" "$FAKE_STATE" >/dev/null; }
report run --dry-run
report state '.writes == 0'
report test ! -e "$HOME/.config/lembitu/discord-webhooks.env"
report run
report state '(.roles | length) == 3 and (.channels | length) == 14 and ([.hooks[][]] | length) == 6'
first=$(jq .writes "$FAKE_STATE")
report run
report state ".writes == $first"
report python3 -c 'import os,stat; assert stat.S_IMODE(os.stat(os.environ["HOME"]+"/.config/lembitu/discord-webhooks.env").st_mode)==0o600'
report test "$(wc -l < "$HOME/.config/lembitu/discord-webhooks.env" | tr -d ' ')" = 6
check_visibility() {
  python3 - "$FAKE_STATE" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); player=next(r["id"] for r in s["roles"] if r.get("name")=="Player")
def permissions(name,member):
 c=next(c for c in s["channels"] if c["name"]==name); p=0
 for ident in (["11111111111111111",player] if member else ["11111111111111111"]):
  for o in c["permission_overwrites"]:
   if o["id"]==ident:p=(p & ~int(o["deny"])) | int(o["allow"])
 return p
for member in (False,True):
 for name in ("announcements","rules","status","activity"):
  p=permissions(name,member); assert p & 1024 and not p & 2048, (name,member,p)
 assert permissions("support",member) & 2048
 for name in ("admin-alerts","admin-console"):
  assert not permissions(name,member) & 1024
 assert bool(permissions("password",member)&1024)==member
 assert not permissions("password",member)&2048
 assert bool(permissions("chat",member)&1024)==member
 assert bool(permissions("chat",member)&2048)==member
PY
}
report check_visibility
# Correct an actual permission drift without creating duplicate channels.
jq '(.channels[] | select(.name == "password") | .permission_overwrites) = []' "$FAKE_STATE" > "$WORK/new"
mv "$WORK/new" "$FAKE_STATE"
report run
report state ".writes == $((first+1))"
report run guild Ravens ravens
report state '(.roles | map(select(.name == "Guild · Ravens")) | length) == 1 and (.channels | map(select(.name == "ravens")) | length) == 1'
guild_writes=$(jq .writes "$FAKE_STATE")
report run guild Ravens ravens
report state ".writes == $guild_writes"
report run
report state ".writes == $guild_writes"
reject_collision() {
  if run guild "$1" "$2"; then return 1; fi
  state ".writes == $guild_writes"
}
report reject_collision Intruders chat
report reject_collision Intruders ravens
# An unrelated channel outside Guilds must not be moved into it.
jq '.channels += [{id:"unrelated",name:"outside",type:0,parent_id:null,permission_overwrites:[]}]' "$FAKE_STATE" > "$WORK/new"
mv "$WORK/new" "$FAKE_STATE"
report reject_collision Intruders outside
report state '.channels[] | select(.id == "unrelated") | .parent_id == null'
rm "$FAKE_STATE"
export FAKE_ERROR=429
report run
report python3 -c 'import json,os; s=json.load(open(os.environ["FAKE_STATE"])); assert s["times"][1]-s["times"][0]>=0.15'
rm "$FAKE_STATE"
export FAKE_ERROR=403
if run apply; then echo 'FAIL: 403 stops'; fail=$((fail+1)); else echo 'pass: 403 stops'; pass=$((pass+1)); fi
report state '.calls == 1 and .writes == 0'
report python3 -c 'import sys; s=open(sys.argv[1]).read(); assert "HTTP 403" in s and "not retrying" in s and "FAKE_OPS_TOKEN_DO_NOT_PRINT" not in s and "FAKE_WEBHOOK_SECRET" not in s' "$WORK/output"
rm "$FAKE_STATE"
export FAKE_ERROR=401
if run apply; then echo 'FAIL: 401 stops'; fail=$((fail+1)); else echo 'pass: 401 stops'; pass=$((pass+1)); fi
report state '.calls == 1'
unset FAKE_ERROR
rm "$FAKE_STATE"
report run
report python3 -c 'import sys; s=open(sys.argv[1]).read(); assert "FAKE_OPS_TOKEN_DO_NOT_PRINT" not in s and "FAKE_WEBHOOK_SECRET" not in s' "$WORK/output"
printf '%s passed; %s failed\n' "$pass" "$fail"
[[ $fail == 0 ]]
