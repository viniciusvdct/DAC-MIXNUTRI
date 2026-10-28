"""Reproduz no Mosquitto local as mensagens de um log no formato do mqtt_mini.py (item 2).

Uso (na pasta do item 3, com o ambiente no ar):
  python3 -I ferramentas/reproduzir_log.py [--env .env] [--host 127.0.0.1] [--porta 1883]
                                          [--intervalo 0.05] <arquivo.log> [...]

Os topicos do dispositivo (telemetria, eventos, confirmacoes, disponibilidade) saem com o usuario
do ESP32; comandos, configuracao e contexto com o do backend/Admin, como pede a ACL. QoS 0 e sem
retain, como o PubSubClient do firmware. As senhas sao lidas do .env e nunca impressas.
O cliente do item 2 nao tem login; este script reaproveita as funcoes dele sem altera-lo.
"""
import argparse
import os
import random
import socket
import struct
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, '..', '..', 'item2-firmware', 'ferramentas'))
from mqtt_mini import packet, read_packet, s  # noqa: E402

DO_ADMIN = {'comandos', 'configuracao', 'contexto'}


def ler_env(caminho):
    valores = {}
    with open(caminho, encoding='utf-8') as f:
        for linha in f:
            linha = linha.strip()
            if linha and not linha.startswith('#') and '=' in linha:
                chave, valor = linha.split('=', 1)
                valores[chave.strip()] = valor.strip()
    return valores


def conectar(host, porta, usuario, senha):
    sock = socket.create_connection((host, porta), timeout=15)
    cid = 'mixnutri-reproducao-%04x' % random.randrange(65536)
    # MQTT 3.1.1: sessao limpa + usuario + senha (flags 0xC2)
    corpo = s('MQTT') + bytes([4, 0xC2]) + struct.pack('>H', 60) + s(cid) + s(usuario) + s(senha)
    sock.sendall(packet(0x10, corpo))
    t, d = read_packet(sock)
    if t != 0x20 or d[1] != 0:
        raise SystemExit('CONNACK recusado para %s (codigo %s)' % (usuario, d[1] if len(d) > 1 else '?'))
    return sock


def encerrar(sock):
    # Com QoS 0 nao ha confirmacao: o PINGRESP mostra que o broker ja leu tudo o que veio antes.
    sock.sendall(packet(0xC0, b''))
    t, _ = read_packet(sock)
    sock.sendall(packet(0xE0, b''))
    sock.close()
    return t == 0xD0


def ler_log(caminho):
    with open(caminho, encoding='utf-8') as f:
        for linha in f:
            linha = linha.rstrip('\n')
            if not linha.strip() or linha.startswith('#'):
                continue
            _hora, topico, payload = linha.split(' ', 2)
            if payload.startswith('[retido] '):
                payload = payload[len('[retido] '):]
            yield topico, payload


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('logs', nargs='+')
    ap.add_argument('--env', default=os.path.join(AQUI, '..', '.env'))
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--porta', type=int, default=1883)
    ap.add_argument('--intervalo', type=float, default=0.05, help='segundos entre mensagens')
    a = ap.parse_args()

    env = ler_env(a.env)
    esp32 = conectar(a.host, a.porta, env['MQTT_ESP32_USUARIO'], env['MQTT_ESP32_SENHA'])
    backend = conectar(a.host, a.porta, env['MQTT_BACKEND_USUARIO'], env['MQTT_BACKEND_SENHA'])
    contagem = {}
    for caminho in a.logs:
        for topico, payload in ler_log(caminho):
            canal = topico.rsplit('/', 1)[-1]
            (backend if canal in DO_ADMIN else esp32).sendall(packet(0x30, s(topico) + payload.encode()))
            contagem[canal] = contagem.get(canal, 0) + 1
            time.sleep(a.intervalo)
    ok = encerrar(esp32) & encerrar(backend)
    print('publicadas %d mensagens (%s); broker confirmou leitura: %s' % (
        sum(contagem.values()), ', '.join('%s=%d' % kv for kv in sorted(contagem.items())),
        'sim' if ok else 'NAO'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
