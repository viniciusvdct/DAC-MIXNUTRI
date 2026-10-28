"""Testa o Admin v2 do Node-RED sem a interface: dispara as injecoes 'Teste:' pela API do editor
e confere, como o ESP32 veria, o que chegou nos topicos comandos, configuracao e contexto.

Uso (com o kit no ar): python3 -I ferramentas/testar_admin.py [--env .env] [--host 127.0.0.1]

Verifica: login exigido no painel e no editor; comando com cmd_id, ts e validade, sem retain;
configuracao com versao crescente e retida; contexto com produto/lote e retido.
Nenhum ESP32 real esta ligado a este broker local. As senhas sao lidas do .env e nunca impressas.
"""
import argparse
import base64
import json
import os
import socket
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(AQUI, '..', '..', 'item2-firmware', 'ferramentas'))
from mqtt_mini import packet, read_packet, s  # noqa: E402
from reproduzir_log import conectar, encerrar, ler_env  # noqa: E402

TOPICOS = ['mixnutri/sala01/comandos', 'mixnutri/sala01/configuracao', 'mixnutri/sala01/contexto']


def http(url, dados=None, cabecalhos=None):
    req = urllib.request.Request(url, data=dados, headers=cabecalhos or {})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def assinar(sock):
    corpo = struct.pack('>H', 1) + b''.join(s(t) + b'\x01' for t in TOPICOS)
    sock.sendall(packet(0x82, corpo))
    read_packet(sock)  # SUBACK


def coletar(sock, segundos):
    """Lista de (topico, retido, payload) recebidos no intervalo."""
    fim, msgs = time.time() + segundos, []
    sock.settimeout(0.3)
    while time.time() < fim:
        try:
            t, d = read_packet(sock)
        except socket.timeout:
            continue
        if t >> 4 == 3:
            n = struct.unpack('>H', d[:2])[0]
            qos = (t >> 1) & 3
            corpo = d[2 + n + (2 if qos else 0):]
            if qos == 1:
                sock.sendall(packet(0x40, d[2 + n:2 + n + 2]))  # PUBACK
            msgs.append((d[2:2 + n].decode(), bool(t & 1), json.loads(corpo)))
    return msgs


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--env', default=os.path.join(AQUI, '..', '.env'))
    ap.add_argument('--host', default='127.0.0.1')
    a = ap.parse_args()
    env = ler_env(a.env)
    base = 'http://%s:1880' % a.host
    res = []

    st, _ = http(base + '/dashboard/')
    res.append(('painel Admin sem login -> 401', st == 401, 'HTTP %s' % st))
    basic = base64.b64encode(('%s:%s' % (env['NODERED_ADMIN_USUARIO'], env['NODERED_ADMIN_SENHA'])).encode()).decode()
    st, _ = http(base + '/dashboard/', cabecalhos={'Authorization': 'Basic ' + basic})
    res.append(('painel Admin com login -> 200', st == 200, 'HTTP %s' % st))
    st, _ = http(base + '/flows')
    res.append(('API do editor sem token -> 401', st == 401, 'HTTP %s' % st))

    corpo = urllib.parse.urlencode({'client_id': 'node-red-admin', 'grant_type': 'password', 'scope': '*',
                                    'username': env['NODERED_ADMIN_USUARIO'],
                                    'password': env['NODERED_ADMIN_SENHA']}).encode()
    st, r = http(base + '/auth/token', corpo)
    token = json.loads(r).get('access_token') if st == 200 else None
    res.append(('token do editor obtido', bool(token), 'HTTP %s' % st))
    if not token:
        return relatar(res)
    autor = {'Authorization': 'Bearer ' + token}

    esp32 = conectar(a.host, 1883, env['MQTT_ESP32_USUARIO'], env['MQTT_ESP32_SENHA'])
    assinar(esp32)
    coletar(esp32, 1)  # descarta mensagens retidas anteriores
    for no in ('inj_teste_cfg', 'inj_teste_on', 'inj_teste_auto'):
        st, _ = http(base + '/inject/' + no, b'', autor)
        res.append(('injecao %s' % no, st == 200, 'HTTP %s' % st))
        time.sleep(1)
    vivas = coletar(esp32, 3)
    encerrar(esp32)

    cmds = [p for t, _, p in vivas if t.endswith('/comandos')]
    cfgs = [p for t, _, p in vivas if t.endswith('/configuracao')]
    ctxs = [p for t, _, p in vivas if t.endswith('/contexto')]
    on = next((p for p in cmds if p.get('modo') == 'MANUAL'), {})
    res.append(('MANUAL com cmd_id, rele, validade_s e ts',
                bool(on.get('cmd_id')) and on.get('rele') == 'ON' and on.get('validade_s') == 60
                and isinstance(on.get('ts'), int), json.dumps(on)))
    auto = next((p for p in cmds if p.get('modo') == 'AUTO'), {})
    res.append(('AUTO com cmd_id e ts', bool(auto.get('cmd_id')) and 'rele' not in auto, json.dumps(auto)))
    cfg = cfgs[0] if cfgs else {}
    res.append(('configuracao com versao e campos do Admin',
                isinstance(cfg.get('versao'), int) and cfg.get('versao') >= 1
                and {'ur_max', 'histerese', 'limiar_db', 'banda_db'} <= set(cfg), json.dumps(cfg)))
    ctx = ctxs[0] if ctxs else {}
    res.append(('contexto com produto e lote', bool(ctx.get('produto') and ctx.get('lote_producao')), json.dumps(ctx)))

    # Um assinante novo so recebe o que ficou retido no broker.
    novo = conectar(a.host, 1883, env['MQTT_ESP32_USUARIO'], env['MQTT_ESP32_SENHA'])
    assinar(novo)
    retidas = coletar(novo, 2)
    encerrar(novo)
    retido = {t.rsplit('/', 1)[-1]: p for t, r, p in retidas if r}
    res.append(('comando NAO fica retido', 'comandos' not in retido, sorted(retido)))
    res.append(('configuracao retida e a ultima publicada',
                retido.get('configuracao', {}).get('versao') == cfg.get('versao'), retido.get('configuracao')))
    res.append(('contexto retido', retido.get('contexto', {}).get('cmd_id') == ctx.get('cmd_id'), retido.get('contexto')))
    return relatar(res)


def relatar(res):
    for nome, ok, detalhe in res:
        print('%-46s %s  %s' % (nome, 'OK' if ok else 'FALHOU', detalhe))
    return 0 if all(ok for _, ok, _ in res) else 1


if __name__ == '__main__':
    sys.exit(main())
