"""Confere o Grafana provisionado: datasource, painel e o resultado de cada consulta na janela pedida.

Uso: python3 -I ferramentas/verificar_grafana.py [--env .env] [--de 2026-10-27T23:05:00Z] [--ate 2026-10-27T23:35:00Z]
Le o usuario administrador do Grafana no .env (senha nunca impressa). Nao altera nada.
"""
import argparse
import base64
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from reproduzir_log import ler_env  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--env', default=os.path.join(AQUI, '..', '.env'))
    ap.add_argument('--de', default='2026-10-27T23:05:00Z')
    ap.add_argument('--ate', default='2026-10-27T23:35:00Z')
    a = ap.parse_args()
    env = ler_env(a.env)
    auth = base64.b64encode(('%s:%s' % (env['GRAFANA_ADMIN_USUARIO'], env['GRAFANA_ADMIN_SENHA'])).encode()).decode()

    def api(caminho, corpo=None):
        req = urllib.request.Request('http://127.0.0.1:3000' + caminho,
                                     data=json.dumps(corpo).encode() if corpo is not None else None,
                                     headers={'Authorization': 'Basic ' + auth, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b'{}')

    ms = lambda s: str(int(dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp() * 1000))
    ok = True
    st, h = api('/api/datasources/uid/mixnutri-pg/health')
    print('datasource mixnutri-pg: HTTP %s %s' % (st, h.get('status')))
    ok &= st == 200 and h.get('status') == 'OK'
    st, s = api('/api/search?query=MixNutri')
    print('paineis encontrados:', [(x['uid'], x['title'], x.get('folderTitle')) for x in s])
    st, d = api('/api/dashboards/uid/mixnutri-sala01')
    ok &= st == 200
    painel = d['dashboard']
    print('painel %r provisionado=%s, %d graficos' % (painel['title'], d['meta'].get('provisioned'), len(painel['panels'])))
    alvos = [(p['title'], t) for p in painel['panels'] for t in p.get('targets', [])]
    alvos.append(('anotacao: Paradas', painel['annotations']['list'][1]['target']))
    for titulo, t in alvos:
        q = dict(t, datasource={'uid': 'mixnutri-pg', 'type': 'grafana-postgresql-datasource'}, intervalMs=1000,
                 maxDataPoints=500)
        st, r = api('/api/ds/query', {'from': ms(a.de), 'to': ms(a.ate), 'queries': [q]})
        res = r.get('results', {}).get(t['refId'], {})
        quadros = res.get('frames', [])
        linhas = sum(len(f['data']['values'][0]) if f.get('data', {}).get('values') else 0 for f in quadros)
        nomes = sorted({c.get('config', {}).get('displayNameFromDS') or c['name']
                        for f in quadros for c in f['schema']['fields'] if c['name'] != 'time'})
        erro = res.get('error')
        print('%-58s %s %-3s linhas=%-3d %s%s' % (titulo[:58], t['refId'], st, linhas, nomes[:5],
                                                  ' ERRO: ' + erro if erro else ''))
        ok &= st == 200 and not erro and linhas > 0
    print('resultado:', 'OK' if ok else 'FALHOU')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
