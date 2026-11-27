"""Confere o Grafana provisionado: datasource, painel e o resultado de cada consulta na janela pedida.

Uso: python3 -I ferramentas/verificar_grafana.py [--env .env] [--de 2026-10-27T23:05:00Z] [--ate 2026-10-27T23:35:00Z]
Lê o usuário administrador do Grafana no .env. A senha não é impressa.
"""
import argparse
import base64
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.request

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from reproduzir_log import ler_env  # noqa: E402


PAINEIS_INSPECAO = (9, 10, 11, 12, 13, 14)


def sqlstring(valores):
    """Replica o formatador sqlstring do Grafana e a opção 'All' do painel."""
    return ','.join("'" + valor.replace("'", "''") + "'" for valor in valores or [''])


def valores_dos_quadros(quadros, nome=None):
    valores = []
    for quadro in quadros:
        for campo, coluna in zip(quadro['schema']['fields'], quadro['data']['values']):
            if campo['name'] == nome or (nome is None and campo['type'] == 'number'):
                valores.extend(valor for valor in coluna if valor is not None)
    return valores


def verificar_demonstracao(quadros, linhas):
    totais = {9: [1.4], 10: [500], 11: [7], 12: [1, 2]}
    esperado_por_inspecao = {
        'Inspecionadas': [300, 200], 'Quebradas': [3, 4], 'Índice de quebra (%)': [1, 2],
        'T média (°C)': [25, 25], 'UR média (%)': [62, 53],
        'Leituras de T': [13, 13], 'Leituras de UR': [13, 13],
    }
    ok = True
    for painel, esperado in totais.items():
        observado = sorted(float(valor) for valor in valores_dos_quadros(quadros.get(painel, [])))
        print(f'Demonstração, painel {painel}: {observado} (esperado: {esperado})')
        ok &= observado == esperado
    print(f'Demonstração, amostras das curvas ambientais: {linhas.get(13)} (esperado: 26)')
    ok &= linhas.get(13) == 26 and linhas.get(14) == 2
    for campo, esperado in esperado_por_inspecao.items():
        observado = [float(valor) for valor in valores_dos_quadros(quadros.get(14, []), campo)]
        print(f'Demonstração, {campo}: {observado} (esperado: {esperado})')
        ok &= observado == esperado
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--env', default=os.path.join(AQUI, '..', '.env'))
    ap.add_argument('--url', default='http://127.0.0.1:3000', help='endereço do Grafana')
    ap.add_argument('--de', default='2026-10-27T23:05:00Z')
    ap.add_argument('--ate', default='2026-10-27T23:35:00Z')
    ap.add_argument('--relogio', choices=['medicao', 'recebimento'], default='medicao',
                    help='referência de tempo dos painéis de telemetria')
    ap.add_argument('--produto', action='append', help='produto da inspeção, repetível')
    ap.add_argument('--lote', action='append', help='lote da inspeção, repetível')
    ap.add_argument('--origem', action='append', choices=['simulacao', 'real'], help='origem da inspeção, repetível')
    ap.add_argument('--demonstracao-inspecoes', action='store_true',
                    help='confere o cenário simulado de 200/4 e 300/3 com o log do Wokwi')
    a = ap.parse_args()
    env = ler_env(a.env)
    auth = base64.b64encode(('%s:%s' % (env['GRAFANA_ADMIN_USUARIO'], env['GRAFANA_ADMIN_SENHA'])).encode()).decode()
    url = a.url.rstrip('/')

    def api(caminho, corpo=None):
        req = urllib.request.Request(url + caminho,
                                     data=json.dumps(corpo).encode() if corpo is not None else None,
                                     headers={'Authorization': 'Basic ' + auth, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b'{}')

    ms = lambda s: str(int(dt.datetime.fromisoformat(s.replace('Z', '+00:00')).timestamp() * 1000))
    de, ate = ms(a.de), ms(a.ate)
    variaveis = {'relogio_leituras': [a.relogio], 'produto_inspecao': a.produto,
                 'lote_inspecao': a.lote, 'origem_inspecao': a.origem}
    if a.demonstracao_inspecoes:
        variaveis['produto_inspecao'] = a.produto or ['PRODUTO_TESTE']
        variaveis['lote_inspecao'] = a.lote or ['LOTE_TESTE_01']
        variaveis['origem_inspecao'] = a.origem or ['simulacao']

    st, h = api('/api/datasources/uid/mixnutri-pg/health')
    print('datasource mixnutri-pg: HTTP %s %s' % (st, h.get('status')))
    ok = st == 200 and h.get('status') == 'OK'
    st, s = api('/api/search?query=MixNutri')
    print('painéis encontrados:', [(x['uid'], x['title'], x.get('folderTitle')) for x in s] if st == 200 else [])
    st, d = api('/api/dashboards/uid/mixnutri-sala01')
    if st != 200:
        print('painel mixnutri-sala01: HTTP %s' % st)
        return 1
    painel = d['dashboard']
    print('painel %r provisionado=%s, %d gráficos' % (painel['title'], d['meta'].get('provisioned'), len(painel['panels'])))
    alvos = [(p['id'], p['title'], t) for p in painel['panels'] for t in p.get('targets', [])]
    alvos.append((None, 'anotação: Paradas', painel['annotations']['list'][1]['target']))
    quadros_inspecao, linhas_inspecao = {}, {}
    for painel_id, titulo, t in alvos:
        q = dict(t, datasource={'uid': 'mixnutri-pg', 'type': 'grafana-postgresql-datasource'}, intervalMs=1000,
                 maxDataPoints=500)
        # A API recebe o SQL já interpolado pelo navegador nas consultas normais do painel.
        q['rawSql'] = re.sub(r'\$\{(\w+):sqlstring\}',
                            lambda m: sqlstring(variaveis[m[1]]), q['rawSql'])
        st, r = api('/api/ds/query', {'from': de, 'to': ate, 'queries': [q]})
        resultados = r.get('results', {})
        res = resultados.get(t['refId'], {})
        quadros = res.get('frames', [])
        linhas = sum(len(f['data']['values'][0]) if f.get('data', {}).get('values') else 0 for f in quadros)
        nomes = sorted({c.get('config', {}).get('displayNameFromDS') or c['name']
                        for f in quadros for c in f['schema']['fields'] if c['name'] != 'time'})
        erro = res.get('error')
        print('%-58s %s %-3s linhas=%-3d %s%s' % (titulo[:58], t['refId'], st, linhas, nomes[:5],
                                                  ' ERRO: ' + erro if erro else ''))
        ok &= (st == 200 and t['refId'] in resultados and not erro
               and (painel_id in PAINEIS_INSPECAO or linhas > 0))
        if painel_id in PAINEIS_INSPECAO:
            quadros_inspecao[painel_id], linhas_inspecao[painel_id] = quadros, linhas
    ok &= set(PAINEIS_INSPECAO) == quadros_inspecao.keys()
    if a.demonstracao_inspecoes:
        ok &= verificar_demonstracao(quadros_inspecao, linhas_inspecao)
    print('resultado:', 'OK' if ok else 'FALHOU')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
