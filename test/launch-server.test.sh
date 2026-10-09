#!/usr/bin/env bash
# Verify maintenance gates, stopped-container startup and launch flags using fake Docker.
# Usage: bash test/launch-server.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export ROOT WORK PYTHONDONTWRITEBYTECODE=1
python3 - <<'PY'
import importlib.util, json, os, pathlib, shutil, subprocess, sys
root, work = pathlib.Path(os.environ['ROOT']), pathlib.Path(os.environ['WORK'])
bin = work/'bin'; bin.mkdir()
fake=bin/'docker'
fake.write_text('''#!/usr/bin/env python3
import datetime as dt,importlib.util,json,os,re,sys
from pathlib import Path
args=sys.argv[1:]
with open(os.environ['TRACE'],'a') as f:f.write(json.dumps(args)+'\\n')
state=Path(os.environ['DOCKER_STATE'])
if args[0]=='inspect':
 if os.environ.get('RUN')=='1':sys.exit(1)
 if '{{.State.Running}}' in args:print(state.read_text().strip())
 elif '{{json .Mounts}}' in args:print(json.dumps([] if os.environ.get('MODE')=='unguarded' else [{'Destination':'/usr/local/bin/valheim-updater','RW':False}]))
elif args[0] in ['start','stop']:
 state.write_text('true' if args[0]=='start' else 'false')
elif args[0]=='logs':
 print('Chainloader startup complete')
 cron=Path(os.environ['CRON'])
 pairs=re.findall(r"command: '([^']+)'\\s+schedule: '([^']+)'",cron.read_text())
 spec=importlib.util.spec_from_file_location('m',Path(os.environ['ROOT'])/'scripts/maintenance-restart.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 records=[];mode=os.environ['MODE']
 cutoff=dt.datetime.fromisoformat(args[args.index('--since')+1]).timestamp() if '--since' in args else 0
 for command,schedule in pairs:
  s,mi,h,d,mo,_=schedule.split();stamp=dt.datetime(2026,int(mo),int(d),int(h),int(mi),int(s),tzinfo=dt.timezone.utc).timestamp()
  if command=='save':
   if mode not in ['missing','undispatched']:
    when=stamp-1 if mode=='stale' else stamp
    records.append((when,'WorldCharacterCheckpointCompleted operation=7, checkpoint=abc, captured=1, persisted=1, pending='+('1' if mode=='pending' else '0')))
   if mode in ['autosave-only','undispatched']:continue
  records.append((stamp+1,"Cron: Job '"+m.job_id(schedule,command)+"' completed."))
 for stamp,line in sorted(records):
  if stamp>=cutoff:print(line)
''');fake.chmod(0o755)
os.environ['PATH']=str(bin)+os.pathsep+os.environ['PATH'];os.environ['HOME']=str(work)
state=work/'docker-state';os.environ['DOCKER_STATE']=str(state)
secret=work/'.config/lembitu/discord-webhooks.env';secret.parent.mkdir(parents=True)
secret.write_text('DISCORD_WEBHOOK_STATUS=https://example.invalid/status\nDISCORD_WEBHOOK_MONITOR=https://example.invalid/monitor\n');secret.chmod(0o600)
spec=importlib.util.spec_from_file_location('m',root/'scripts/maintenance-restart.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
# Independent .NET BinaryWriter/SHA256 oracle, observed with dotnet fsi.
assert m.job_id("0 0 6 7 10 *", "save")=="save-3d78a57ed14e32f42dbdd5eebfc32a6e5a2d5a0d"
class Clock:
 def __init__(self):self.now=1791320000
 def time(self):return self.now
 def monotonic(self):return self.now
 def sleep(self,seconds):self.now+=seconds
count=0
for mode in ['confirmed','missing','pending','undispatched','stale','autosave-only','unguarded','busy-lock','missing-cron','busy-cron','no-webhooks']:
 store=work/mode/'save/ServerManager';store.mkdir(parents=True);cron=store/'cron.yml';cron.write_text('jobs: []\n')
 trace=work/(mode+'.jsonl');os.environ['TRACE']=str(trace);os.environ['CRON']=str(cron);os.environ['MODE']=mode;os.environ['CHECKPOINT_TIMEOUT']='3';state.write_text('true')
 lock=work/'.local/state/lembitu/maintenance.lock';lock.parent.mkdir(parents=True,exist_ok=True)
 if mode=='busy-lock':lock.mkdir()
 if mode=='missing-cron':cron.unlink()
 if mode=='busy-cron':cron.write_text('jobs:\n  - command: save\n')
 if mode=='no-webhooks':secret.unlink()
 clock=Clock();m.time=clock;posted=[]
 m.post=lambda url,msg:posted.append((url,msg,clock.now))
 sys.argv=['maintenance','fake-game',str(store.parent.parent)]
 failed=False
 try:m.main()
 except (RuntimeError,FileNotFoundError,FileExistsError):failed=True
 calls=[json.loads(x)[0] for x in trace.read_text().splitlines()] if trace.exists() else []
 success=mode in ['confirmed','no-webhooks']
 assert ('stop' in calls)==success and failed!=success,mode
 if not success:assert posted[-1][0]=='https://example.invalid/monitor',mode
 if mode not in ['busy-lock','missing-cron','busy-cron','unguarded']:
  assert [x[2]-1791320000 for x in posted[:3]]==[20,320,560]
  assert cron.read_text()=='jobs: []\n'
 if mode=='busy-lock':assert lock.exists();lock.rmdir()
 else:assert not lock.exists()
 if mode=='no-webhooks':assert all(x[0] is None for x in posted)
 print('pass: '+mode);count+=1
# Public shell paths execute the real controller under a virtual-time shim.
repo=work/'repo';(repo/'scripts').mkdir(parents=True);(repo/'config/launch').mkdir(parents=True)
for name in ['launch-server.sh','maintenance-restart.py']:shutil.copy(root/'scripts'/name,repo/'scripts')
(repo/'scripts/lib').mkdir();shutil.copy(root/'scripts/lib/python.sh',repo/'scripts/lib')
shutil.copy(root/'config/launch/launch.env.example',repo/'config/launch')
(repo/'config/launch/launch.secret.env').write_text('SERVER_PASS=fake-only\n')
verify=repo/'scripts/verify-enforced-config.sh';verify.write_text('#!/usr/bin/env bash\nset -euo pipefail\nexit "${VERIFY_FAIL:-0}"\n');verify.chmod(0o755)
shim=work/'clockshim';shim.mkdir();(shim/'sitecustomize.py').write_text('import time\nnow=[1791320000.]\ntime.time=lambda:now[0]\ntime.monotonic=lambda:now[0]\ndef advance(seconds):now[0]+=seconds\ntime.sleep=advance\n')
os.environ['PYTHONPATH']=str(shim);os.environ['DATA_ROOT']=str(work/'data')
store=work/'data/config/save/ServerManager';store.mkdir(parents=True);cron=store/'cron.yml';cron.write_text('jobs: []\n');os.environ['CRON']=str(cron)
marker=work/'.local/state/lembitu/maintenance-until'
for action,mode,running,verify_fail in [('restart','confirmed',True,False),('stop','confirmed',True,False),('restart','missing',True,False),('restart','confirmed',False,False),('start','confirmed',False,False),('start','confirmed',False,True)]:
 os.environ['RUN']='0';os.environ['MODE']=mode;os.environ['VERIFY_FAIL']='1' if verify_fail else '0';state.write_text(str(running).lower());trace=work/(str(count)+'.jsonl');os.environ['TRACE']=str(trace)
 result=subprocess.run(['bash',str(repo/'scripts/launch-server.sh'),action],capture_output=True,text=True)
 calls=[json.loads(x)[0] for x in trace.read_text().splitlines()]
 failed=mode=='missing' or verify_fail
 assert (result.returncode!=0)==failed,result.stderr
 assert ('stop' in calls)==(running and mode!='missing')
 assert ('start' in calls)==(action!='stop' and mode!='missing')
 if not running:assert "{{json .Mounts}}" not in trace.read_text() and "stop" not in calls
 if not failed and action!='stop':assert not marker.exists()
 else:assert int(marker.read_text())>1791320000
 print('pass: shell '+action+' '+('running' if running else 'stopped')+' '+mode+(' verify-failed' if verify_fail else ''));count+=1
# ServerManager's policy is applied then checked before start, from the Pack, once it is installed.
policy=repo/'scripts/servermanager-policy.sh'
policy.write_text('#!/usr/bin/env bash\nset -euo pipefail\nprintf \'["policy","%s","%s"]\\n\' "$1" "$*" >> "$TRACE"\n[[ "${POLICY_FAIL:-}" != "$1" ]]\n');policy.chmod(0o755)
plugin=work/'data/config/bepinex/plugins/sighsorry-ServerManager/ServerManager.dll';plugin.parent.mkdir(parents=True);plugin.write_bytes(b'MZ')
deploy=work/'.config/lembitu/deploy.env'
for case,env,deploy_text,fail,ok in [
  ('env settings',{'LEMBITU_PACK_ROOT':'/packs/v17','LEMBITU_LOAD_SERVER_CHARACTER':'false'},None,'',True),
  ('deploy.env settings',{},'LEMBITU_PACK_ROOT=/packs/v17\nLEMBITU_LOAD_SERVER_CHARACTER=true\n','',True),
  ('no Pack root refused',{'LEMBITU_LOAD_SERVER_CHARACTER':'true'},None,'',False),
  ('enrollment flag required',{'LEMBITU_PACK_ROOT':'/packs/v17','LEMBITU_LOAD_SERVER_CHARACTER':'maybe'},None,'',False),
  ('drift refused',{'LEMBITU_PACK_ROOT':'/packs/v17','LEMBITU_LOAD_SERVER_CHARACTER':'true'},None,'check',False)]:
 for k in ['LEMBITU_PACK_ROOT','LEMBITU_LOAD_SERVER_CHARACTER']:os.environ.pop(k,None)
 os.environ.update(env);os.environ['POLICY_FAIL']=fail;os.environ['MODE']='confirmed';os.environ['VERIFY_FAIL']='0';os.environ['RUN']='0'
 if deploy_text is None:deploy.unlink(missing_ok=True)
 else:deploy.write_text(deploy_text)
 state.write_text('false');trace=work/(str(count)+'.jsonl');os.environ['TRACE']=str(trace)
 result=subprocess.run(['bash',str(repo/'scripts/launch-server.sh'),'start'],capture_output=True,text=True)
 calls=[json.loads(x) for x in trace.read_text().splitlines()] if trace.exists() else []
 names=[c[1] if c[0]=='policy' else c[0] for c in calls]
 assert (result.returncode==0)==ok,result.stderr
 assert ('start' in names)==ok,names
 if ok:
  assert names.index('apply')<names.index('check')<names.index('start'),names
  pol=[c[2] for c in calls if c[0]=='policy']
  want='true' if deploy_text else 'false'
  assert all('--pack /packs/v17' in p and p.endswith('--load-server-character '+want) and '/config/save/ServerManager' in p for p in pol),pol
 print('pass: ServerManager policy '+case);count+=1
plugin.unlink()
for k in ['LEMBITU_PACK_ROOT','LEMBITU_LOAD_SERVER_CHARACTER','POLICY_FAIL']:os.environ.pop(k,None)
deploy.unlink(missing_ok=True)
os.environ['RUN']='1';os.environ['TRACE']=str(work/'run.jsonl')
subprocess.run(['bash',str(repo/'scripts/launch-server.sh'),'run'],check=True,stdout=subprocess.DEVNULL)
args=next(json.loads(x) for x in (work/'run.jsonl').read_text().splitlines() if json.loads(x)[0]=='run')
for flag,value in [('--cpu-shares','4096'),('--memory-reservation','4g'),('--stop-timeout','120')]:assert args[args.index(flag)+1]==value
assert '127.0.0.1:3000:3000/tcp' in args and any(x.endswith('/usr/local/bin/valheim-updater:ro') for x in args)
assert 'UPDATE_CRON=' in args and 'RESTART_CRON=' in args
print('pass: run resource reservations/private map/frozen updater');count+=1
# The frozen start makes the BepInEx/config link the image's installer makes, and refuses data in the way.
for case,prep,ok in [('missing link is created',None,True),('correct link kept','link',True),('real directory refused','dir',False),('wrong link refused','wrong',False)]:
 vroot=work/('valheim-'+str(count));croot=work/('cfg-'+str(count))
 for exe in ['server/valheim_server.x86_64','bepinex/valheim_server.x86_64']:p=vroot/exe;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('');p.chmod(0o755)
 core=vroot/'bepinex/BepInEx/core/BepInEx.dll';core.parent.mkdir(parents=True);core.write_text('')
 link=vroot/'bepinex/BepInEx/config'
 if prep=='link':(croot/'bepinex').mkdir(parents=True);link.symlink_to(croot/'bepinex')
 if prep=='dir':link.mkdir();(link/'mod.cfg').write_text('x')
 if prep=='wrong':link.symlink_to(work)
 env=dict(os.environ,VALHEIM_ROOT=str(vroot),CONFIG_ROOT=str(croot),FROZEN_START_DRY_RUN='1')
 result=subprocess.run(['bash',str(root/'scripts/frozen-valheim-start.sh')],capture_output=True,text=True,env=env)
 assert (result.returncode==0)==ok,result.stderr
 if ok:assert link.is_symlink() and os.readlink(link)==str(croot/'bepinex')
 if prep=='dir':assert (link/'mod.cfg').read_text()=='x'
 print('pass: frozen start '+case);count+=1
# The map's tunnel runs with host networking and its token only in an environment file.
tenv=work/'.config/lembitu/cloudflared.env'
os.environ['RUN']='1';os.environ['TRACE']=str(work/'tunnel-missing.jsonl')
result=subprocess.run(['bash',str(repo/'scripts/launch-server.sh'),'tunnel'],capture_output=True,text=True)
assert result.returncode!=0 and 'wizard-cloudflare' in result.stderr,result.stderr
assert not (work/'tunnel-missing.jsonl').exists() or 'run' not in (work/'tunnel-missing.jsonl').read_text()
print('pass: tunnel refused without its token file');count+=1
tenv.write_text('TUNNEL_TOKEN=fake-tunnel-secret\n');tenv.chmod(0o600)
os.environ['TRACE']=str(work/'tunnel.jsonl')
subprocess.run(['bash',str(repo/'scripts/launch-server.sh'),'tunnel'],check=True,stdout=subprocess.DEVNULL)
targs=next(json.loads(x) for x in (work/'tunnel.jsonl').read_text().splitlines() if json.loads(x)[0]=='run')
assert targs[targs.index('--network')+1]=='host' and targs[targs.index('--env-file')+1]==str(tenv)
assert 'cloudflare/cloudflared:2026.10.0' in targs and targs[-3:]==['tunnel','--no-autoupdate','run']
assert not any('fake-tunnel-secret' in a for a in targs)
print('pass: tunnel uses host networking, a pinned image and an environment file');count+=1
print(str(count)+' passed, 0 failed')
PY
