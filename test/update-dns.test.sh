#!/usr/bin/env bash
# Verify the DNS updater against a fake Cloudflare API and address source, no network.
# Usage: bash test/update-dns.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'kill "${SERVER_PID:-}" 2>/dev/null || true; rm -rf "$WORK"' EXIT
export ROOT WORK PYTHONDONTWRITEBYTECODE=1

cat > "$WORK/fake.py" <<'PY'
import json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
state_path = os.environ['FAKE_STATE']
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def state(self): return json.load(open(state_path))
    def save(self, s): json.dump(s, open(state_path, 'w'))
    def send(self, code, body, raw=False):
        data = body.encode() if raw else json.dumps(body).encode()
        self.send_response(code); self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        s = self.state()
        if self.path == '/ip': return self.send(200, s['ip'], raw=True)
        if self.path == '/private-ip': return self.send(200, '192.168.0.101', raw=True)
        s['calls'].append(['GET', self.path, self.headers.get('Authorization')]); self.save(s)
        if self.headers.get('Authorization') != 'Bearer good-token':
            return self.send(403, {'success': False, 'errors': [{'code': 9109, 'message': 'Invalid access token'}]})
        name = self.path.split('name=')[1]
        return self.send(200, {'success': True, 'result': [r for r in s['records'] if r['name'] == name]})
    def do_PATCH(self):
        s = self.state(); rid = self.path.rsplit('/', 1)[1]
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        s['calls'].append(['PATCH', self.path, body])
        for r in s['records']:
            if r['id'] == rid: r.update(body)
        self.save(s); self.send(200, {'success': True, 'result': {}})
HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
PY

PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
export FAKE_STATE="$WORK/state.json"
python3 "$WORK/fake.py" "$PORT" & SERVER_PID=$!
python3 - "$PORT" <<'PY'
import json, os, pathlib, socket, subprocess, sys, time
port = sys.argv[1]; root = pathlib.Path(os.environ['ROOT']); work = pathlib.Path(os.environ['WORK'])
for _ in range(50):
    try: socket.create_connection(('127.0.0.1', int(port)), 0.2).close(); break
    except OSError: time.sleep(0.1)
state = pathlib.Path(os.environ['FAKE_STATE'])
envfile = work / 'cloudflare.env'
base = f'http://127.0.0.1:{port}'
env = dict(os.environ, LEMBITU_CLOUDFLARE_ENV=str(envfile), LEMBITU_CLOUDFLARE_API=base)
count = 0
def reset(ip, content, token='good-token'):
    state.write_text(json.dumps({'ip': ip, 'calls': [], 'records': [{'id': 'r1', 'name': 'lembitu.astral.ee', 'content': content}]}))
    envfile.write_text(f'CLOUDFLARE_API_TOKEN={token}\nCLOUDFLARE_ZONE=astral.ee\nCLOUDFLARE_ZONE_ID=z1\nCLOUDFLARE_RECORDS=lembitu\n')
def run(*args, sources=None):
    e = dict(env, LEMBITU_IP_SOURCES=sources or f'{base}/ip')
    return subprocess.run(['bash', str(root / 'scripts/update-dns.sh'), *args], capture_output=True, text=True, env=e)
def check(name, cond, detail=''):
    global count
    assert cond, f'{name}: {detail}'
    print('pass: ' + name); count += 1

reset('85.253.100.163', '85.253.16.237')
r = run(); s = json.loads(state.read_text())
check('a changed address updates the record', r.returncode == 0 and s['records'][0]['content'] == '85.253.100.163', r.stderr)
check('only the content is patched', [c[2] for c in s['calls'] if c[0] == 'PATCH'] == [{'content': '85.253.100.163'}])
r = run(); s = json.loads(state.read_text())
check('an unchanged address sends no update', r.returncode == 0 and not any(c[0] == 'PATCH' for c in s['calls'][2:]), r.stdout)
reset('85.253.100.200', '85.253.100.163')
r = run('--dry-run'); s = json.loads(state.read_text())
check('--dry-run changes nothing', r.returncode == 0 and 'would update' in r.stdout and s['records'][0]['content'] == '85.253.100.163')
reset('85.253.100.200', '85.253.100.163')
r = run(sources=f'{base}/private-ip {base}/missing'); s = json.loads(state.read_text())
check('a private or failed address source leaves the record alone', r.returncode != 0 and s['records'][0]['content'] == '85.253.100.163' and not any('dns_records' in c[1] for c in s['calls']), r.stderr)
r = run(sources=f'{base}/private-ip {base}/ip'); s = json.loads(state.read_text())
check('the next source is tried after a bad one', r.returncode == 0 and s['records'][0]['content'] == '85.253.100.200', r.stderr)
reset('85.253.100.200', '85.253.100.163', token='bad-token')
r = run(); s = json.loads(state.read_text())
check('a refused token fails and names the refusal', r.returncode != 0 and 'Invalid access token' in r.stderr and s['records'][0]['content'] == '85.253.100.163')
check('the token never appears in output', 'bad-token' not in r.stdout + r.stderr)
envfile.write_text('CLOUDFLARE_ZONE=astral.ee\n')
r = run()
check('a settings file without the token is refused', r.returncode != 0 and 'CLOUDFLARE_API_TOKEN' in r.stderr)
print(f'{count} passed, 0 failed')
PY
