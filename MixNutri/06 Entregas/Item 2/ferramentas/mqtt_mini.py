"""Cliente MQTT 3.1.1 minimo (sem dependencias) para observar e publicar no teste.
Uso:
  mqtt_mini.py sub <host> <topico> <arquivo_log>
  mqtt_mini.py pub <host> <topico> <payload> [retain]
"""
import socket, struct, sys, time, os, random

def enc_len(n):
    out = bytearray()
    while True:
        b = n % 128; n //= 128
        out.append(b | (0x80 if n else 0))
        if not n: return bytes(out)

def s(x):
    b = x.encode() if isinstance(x, str) else x
    return struct.pack('>H', len(b)) + b

def packet(t, body):
    return bytes([t]) + enc_len(len(body)) + body

def read_packet(sock):
    h = sock.recv(1)
    if not h: raise ConnectionError('fechado')
    mult, n = 1, 0
    while True:
        b = sock.recv(1)[0]
        n += (b & 127) * mult; mult *= 128
        if not b & 128: break
    data = b''
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk: raise ConnectionError('fechado')
        data += chunk
    return h[0], data

def connect(host, cid):
    sock = socket.create_connection((host, 1883), timeout=15)
    body = s('MQTT') + bytes([4, 2]) + struct.pack('>H', 60) + s(cid)
    sock.sendall(packet(0x10, body))
    t, d = read_packet(sock)
    assert t == 0x20 and d[1] == 0, ('CONNACK', t, d)
    return sock

def main():
    modo, host, topico = sys.argv[1], sys.argv[2], sys.argv[3]
    cid = 'mixnutri-teste-%04x' % random.randrange(65536)
    sock = connect(host, cid)
    if modo == 'pub':
        retain = len(sys.argv) > 5 and sys.argv[5] == 'retain'
        payload = sys.argv[4].encode()
        sock.sendall(packet(0x30 | (1 if retain else 0), s(topico) + payload))
        sock.sendall(packet(0xE0, b''))
        print('publicado', topico, len(payload), 'bytes', 'retain' if retain else '')
        return
    log = open(sys.argv[4], 'a', buffering=1)
    sock.sendall(packet(0x82, struct.pack('>H', 1) + s(topico) + b'\x00'))
    sock.settimeout(20)
    ultimo_ping = time.time()
    while True:
        try:
            t, d = read_packet(sock)
        except socket.timeout:
            t = None
        if t is not None and t >> 4 == 3:
            n = struct.unpack('>H', d[:2])[0]
            top = d[2:2 + n].decode(errors='replace')
            off = 2 + n + (2 if (t >> 1) & 3 else 0)
            log.write('%s %s%s %s\n' % (time.strftime('%H:%M:%S'), top, ' [retido]' if t & 1 else '',
                                        d[off:].decode(errors='replace')))
        if time.time() - ultimo_ping > 30:
            sock.sendall(packet(0xC0, b'')); ultimo_ping = time.time()

if __name__ == '__main__':
    main()
