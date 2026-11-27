"""Le a serial do ESP32 por alguns segundos, sem o monitor interativo, e opcionalmente envia comandos.
Util para registrar testes de bancada ou para uma IA acompanhar a placa.

Uso (pasta item2-firmware, com o PlatformIO instalado no .venv, que ja traz o pyserial):
  .venv/bin/python -I ferramentas/serial_esp32.py <porta> <segundos> [--reset] [comando@segundo ...]
Exemplos:
  .venv/bin/python -I ferramentas/serial_esp32.py /dev/cu.usbserial-0001 10 --reset
  .venv/bin/python -I ferramentas/serial_esp32.py /dev/cu.usbserial-0001 30 h@3 l@8 c@12
--reset reinicia a placa pelo pino EN (RTS) sem entrar no modo de gravacao.
"""
import sys
import time

import serial


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    porta, duracao = sys.argv[1], float(sys.argv[2])
    extras = sys.argv[3:]
    comandos = sorted((float(a.split('@')[1]), a.split('@')[0]) for a in extras if '@' in a)

    s = serial.Serial(porta, 115200, timeout=0.2)
    if '--reset' in extras:
        s.dtr = False  # GPIO 0 alto: boot normal
        s.rts = True   # EN baixo: reinicia
        time.sleep(0.1)
        s.rts = False
    inicio = time.time()
    buf = b''
    while time.time() - inicio < duracao:
        while comandos and time.time() - inicio >= comandos[0][0]:
            _, c = comandos.pop(0)
            s.write(c.encode() + b'\n')
            print('>>> enviado "%s" em %.1fs' % (c, time.time() - inicio), flush=True)
        buf += s.read(4096)
        while b'\n' in buf:
            linha, buf = buf.split(b'\n', 1)
            print('%5.1fs %s' % (time.time() - inicio, linha.decode(errors='replace').rstrip()), flush=True)
    s.close()


if __name__ == '__main__':
    main()
