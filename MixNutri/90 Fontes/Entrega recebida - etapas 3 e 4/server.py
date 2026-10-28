"""Servidor Modbus TCP mínimo para bancada; suporta FC03 (holding registers)."""
import math
import socketserver
import struct
import time


def registers(now=None):
    now = time.time() if now is None else now
    humidity = 52 + 8 * max(0, math.sin(now / 45))
    temperature = 24 + 2 * math.sin(now / 80)
    noise = 68 if int(now / 35) % 2 == 0 else 28
    running = 1 if noise >= 60 else 0
    dehumidifier = 1 if humidity >= 55 else 0
    return [round(humidity * 10), round(temperature * 10), round(noise * 10), running, dehumidifier, 0]


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        while True:
            header = self._read(7)
            if not header:
                return
            transaction, protocol, length, unit = struct.unpack(">HHHB", header)
            pdu = self._read(length - 1)
            if not pdu:
                return
            function = pdu[0]
            if function != 3 or len(pdu) != 5:
                response = bytes([function | 0x80, 1])
            else:
                start, count = struct.unpack(">HH", pdu[1:5])
                regs = registers()
                if count < 1 or count > 125 or start + count > len(regs):
                    response = bytes([function | 0x80, 2])
                else:
                    values = regs[start:start + count]
                    response = bytes([function, len(values) * 2]) + b"".join(struct.pack(">H", v & 0xFFFF) for v in values)
            mbap = struct.pack(">HHHB", transaction, protocol, len(response) + 1, unit)
            self.request.sendall(mbap + response)

    def _read(self, size):
        data = b""
        while len(data) < size:
            chunk = self.request.recv(size - len(data))
            if not chunk:
                return b""
            data += chunk
        return data


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    print("Modbus TCP simulator listening on :5020", flush=True)
    with Server(("0.0.0.0", 5020), Handler) as server:
        server.serve_forever()
