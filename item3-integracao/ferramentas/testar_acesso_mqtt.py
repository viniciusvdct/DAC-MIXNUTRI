"""Testa o controle de acesso do Mosquitto da proposta do item 3.

Uso: python3 -I ferramentas/testar_acesso_mqtt.py [--env .env] [--host 127.0.0.1] [--porta 1883]

1. conexao anonima recusada; 2. senha errada recusada; 3. ESP32 nao consegue publicar em
comandos (ACL); 4. controle positivo: o backend publica em comandos e recebe a propria mensagem.
Publica no maximo duas mensagens em mixnutri/sala01/comandos (cmd_id teste-acl-*), sem retain.
Nenhum ESP32 real esta ligado a este broker local. As senhas sao lidas do .env e nunca impressas.
"""
import argparse
import os
import random
import socket
import struct
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(AQUI, '..', '..', 'item2-firmware', 'ferramentas'))
from mqtt_mini import packet, read_packet, s  # noqa: E402
from reproduzir_log import encerrar, ler_env  # noqa: E402

TOPICO = 'mixnutri/sala01/comandos'


def conectar(host, porta, usuario=None, senha=None):
    """Devolve (socket, codigo do CONNACK)."""
    sock = socket.create_connection((host, porta), timeout=10)
    flags = 0x02 | (0x80 if usuario is not None else 0) | (0x40 if senha is not None else 0)
    corpo = s('MQTT') + bytes([4, flags]) + struct.pack('>H', 30) + s('mixnutri-acl-%04x' % random.randrange(65536))
    if usuario is not None:
        corpo += s(usuario)
    if senha is not None:
        corpo += s(senha)
    sock.sendall(packet(0x10, corpo))
    t, d = read_packet(sock)
    return sock, (d[1] if t == 0x20 and len(d) > 1 else -1)


def recebidas(sock, segundos):
    """Payloads publicados recebidos no socket durante o intervalo."""
    fim, msgs = time.time() + segundos, []
    sock.settimeout(0.3)
    while time.time() < fim:
        try:
            t, d = read_packet(sock)
        except socket.timeout:
            continue
        if t >> 4 == 3:
            n = struct.unpack('>H', d[:2])[0]
            msgs.append(d[2 + n + (2 if (t >> 1) & 3 else 0):].decode(errors='replace'))
    return msgs


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--env', default=os.path.join(AQUI, '..', '.env'))
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--porta', type=int, default=1883)
    a = ap.parse_args()
    env = ler_env(a.env)
    resultados = []

    sock, rc = conectar(a.host, a.porta)
    sock.close()
    resultados.append(('conexao anonima recusada', rc != 0, 'CONNACK %s' % rc))

    sock, rc = conectar(a.host, a.porta, env['MQTT_ESP32_USUARIO'], 'senha-errada-%06x' % random.randrange(1 << 24))
    sock.close()
    resultados.append(('senha errada recusada', rc != 0, 'CONNACK %s' % rc))

    ouvinte, rc = conectar(a.host, a.porta, env['MQTT_BACKEND_USUARIO'], env['MQTT_BACKEND_SENHA'])
    ouvinte.sendall(packet(0x82, struct.pack('>H', 1) + s(TOPICO) + b'\x00'))
    t, d = read_packet(ouvinte)
    resultados.append(('backend assina comandos', rc == 0 and t == 0x90 and d[-1] != 0x80, 'SUBACK %s' % d[-1]))

    esp32, rc = conectar(a.host, a.porta, env['MQTT_ESP32_USUARIO'], env['MQTT_ESP32_SENHA'])
    esp32.sendall(packet(0x30, s(TOPICO) + b'{"cmd_id":"teste-acl-negado","teste":"ESP32 nao pode publicar aqui"}'))
    encerrar(esp32)
    msgs = recebidas(ouvinte, 3)
    resultados.append(('ESP32 bloqueado em comandos (ACL)', not any('teste-acl-negado' in m for m in msgs),
                       '%d mensagem(ns) recebida(s)' % len(msgs)))

    ouvinte.sendall(packet(0x30, s(TOPICO) + b'{"cmd_id":"teste-acl-positivo","teste":"controle positivo da ACL; ignorar"}'))
    msgs = recebidas(ouvinte, 3)
    resultados.append(('backend publica em comandos (controle positivo)', any('teste-acl-positivo' in m for m in msgs),
                       '%d mensagem(ns) recebida(s)' % len(msgs)))
    encerrar(ouvinte)

    for nome, ok, detalhe in resultados:
        print('%-50s %s (%s)' % (nome, 'OK' if ok else 'FALHOU', detalhe))
    return 0 if all(ok for _, ok, _ in resultados) else 1


if __name__ == '__main__':
    sys.exit(main())
