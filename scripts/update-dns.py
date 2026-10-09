#!/usr/bin/env python3
"""Keep Lembitu's game name pointing at astral-bicep's current home address.

astral-bicep sits behind a home router whose public address changes. Each run asks for the current
IPv4 address and updates every A record named in CLOUDFLARE_RECORDS whose content differs. Settings
come from ~/.config/lembitu/cloudflare.env, written by scripts/wizard-cloudflare.sh:
CLOUDFLARE_API_TOKEN, CLOUDFLARE_ZONE, CLOUDFLARE_ZONE_ID and CLOUDFLARE_RECORDS (space-separated
names under the zone). The token is read from that file and sent only in a request header.

Usage: update-dns.py [--dry-run]. Exit 0 when the records match, 1 on any failure.
"""
import ipaddress
import json
import os
import pathlib
import sys
import urllib.request

ENV = pathlib.Path(os.environ.get('LEMBITU_CLOUDFLARE_ENV', pathlib.Path.home() / '.config/lembitu/cloudflare.env'))
API = os.environ.get('LEMBITU_CLOUDFLARE_API', 'https://api.cloudflare.com/client/v4')
IP_SOURCES = os.environ.get('LEMBITU_IP_SOURCES', 'https://api.ipify.org https://ipv4.icanhazip.com').split()


def settings():
    values = {}
    for line in ENV.read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            values[key.strip()] = value.strip()
    missing = [k for k in ('CLOUDFLARE_API_TOKEN', 'CLOUDFLARE_ZONE', 'CLOUDFLARE_ZONE_ID', 'CLOUDFLARE_RECORDS') if not values.get(k)]
    if missing:
        raise SystemExit(f'{ENV} lacks {", ".join(missing)}; re-run scripts/wizard-cloudflare.sh')
    return values


def public_ip():
    # Two sources must not be trusted blindly: the first answer that parses as a public IPv4 wins.
    for url in IP_SOURCES:
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                text = response.read().decode().strip()
            address = ipaddress.IPv4Address(text)
            if address.is_global:
                return str(address)
        except (OSError, ValueError):
            continue
    raise SystemExit('no source returned a public IPv4 address; records left unchanged')


def call(token, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(API + path, data=data, method=method, headers={
        'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            reply = json.load(response)
    except urllib.error.HTTPError as error:
        reply = json.load(error)
    if not reply.get('success'):
        raise SystemExit(f'Cloudflare refused {method} {path.split("?")[0]}: {reply.get("errors")}')
    return reply['result']


def main():
    dry = '--dry-run' in sys.argv[1:]
    cfg = settings()
    token, zone, zone_id = cfg['CLOUDFLARE_API_TOKEN'], cfg['CLOUDFLARE_ZONE'], cfg['CLOUDFLARE_ZONE_ID']
    address = public_ip()
    for name in cfg['CLOUDFLARE_RECORDS'].split():
        fqdn = f'{name}.{zone}'
        records = call(token, 'GET', f'/zones/{zone_id}/dns_records?type=A&name={fqdn}')
        if not records:
            raise SystemExit(f'{fqdn} has no A record; re-run scripts/wizard-cloudflare.sh')
        record = records[0]
        if record['content'] == address:
            print(f'{fqdn} already {address}')
            continue
        if dry:
            print(f'would update {fqdn}: {record["content"]} -> {address}')
            continue
        call(token, 'PATCH', f'/zones/{zone_id}/dns_records/{record["id"]}', {'content': address})
        print(f'updated {fqdn}: {record["content"]} -> {address}')


if __name__ == '__main__':
    main()
