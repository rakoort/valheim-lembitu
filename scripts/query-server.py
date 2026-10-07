#!/usr/bin/env python3
"""Usage: query-server.py HOST QUERY_PORT. Perform a bounded Steam A2S_INFO UDP query.
Run on astral-tricep, not the game host: a local query cannot prove outside reachability.
"""
import socket
import struct
import sys


def query(host, port):
    request = b'\xff\xff\xff\xffTSource Engine Query\x00'
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(5)
        sock.connect((host, int(port)))
        sock.send(request)
        reply = sock.recv(65535)
        if reply[:5] == b'\xff\xff\xff\xffA' and len(reply) == 9:
            sock.send(request + reply[5:9])
            reply = sock.recv(65535)
        if reply[:5] != b'\xff\xff\xff\xffI':
            raise ValueError('not an A2S_INFO reply')
        # Validate the fixed and string fields through the server's player counts.
        pos = 6
        for _ in range(4):
            pos = reply.index(b'\x00', pos) + 1
        app, players, maximum, bots = struct.unpack_from('<HBBB', reply, pos)
        if maximum == 0 or players > maximum or bots > maximum:
            raise ValueError('invalid A2S_INFO counts')
        print(f'A2S reachable: players={players}/{maximum} app={app}')


if __name__ == '__main__':
    try:
        query(sys.argv[1], sys.argv[2])
    except (OSError, ValueError, IndexError, struct.error):
        print('A2S query failed', file=sys.stderr)
        sys.exit(1)
