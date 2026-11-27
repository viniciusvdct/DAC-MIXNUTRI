"""Envia as duas inspeções simuladas do roteiro, com identificadores fixos."""
import argparse
import base64
import json
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
from reproduzir_log import ler_env  # noqa: E402
from testar_admin import http  # noqa: E402


INSPECOES = (
    ('d732b8fe-9ed4-4de6-947e-4681c04a5c49', '23:10:08', '23:11:13', 200, 4),
    ('d732b8fe-9ed4-4de6-947e-4681c04a5c50', '23:11:13', '23:12:20', 300, 3),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env', default=AQUI.parent / '.env')
    parser.add_argument('--porta-admin', type=int, default=1880)
    args = parser.parse_args()
    env = ler_env(args.env)
    usuario = env['NODERED_ADMIN_USUARIO']
    senha = env['NODERED_ADMIN_SENHA']
    autenticacao = base64.b64encode(f'{usuario}:{senha}'.encode()).decode()
    cabecalhos = {'Authorization': f'Basic {autenticacao}', 'Content-Type': 'application/json'}
    url = f'http://127.0.0.1:{args.porta_admin}/dashboard/api/inspecoes'

    for envio_id, inicio, fim, total, quebradas in INSPECOES:
        inspecao = {
            'envio_id': envio_id,
            'sala_id': 'sala01',
            'maquina': 'Encapsuladora piloto',
            'produto': 'PRODUTO_TESTE',
            'lote_producao': 'LOTE_TESTE_01',
            'inicio': f'2026-10-27T{inicio}Z',
            'fim': f'2026-10-27T{fim}Z',
            'ponto_inspecao': 'Saída da encapsuladora',
            'total_inspecionado': total,
            'quantidade_quebrada': quebradas,
            'origem_dados': 'simulacao',
        }
        codigo, resposta = http(url, json.dumps(inspecao).encode(), cabecalhos)
        if codigo not in (200, 201):
            print(f'Falha ao enviar a inspeção de {total} cápsulas (HTTP {codigo}).', file=sys.stderr)
            return 1
        registro = json.loads(resposta)
        status_esperado = 'gravada' if codigo == 201 else 'duplicada'
        if registro.get('status') != status_esperado or not registro.get('id'):
            print(f'Resposta inesperada para a inspeção de {total} cápsulas.', file=sys.stderr)
            return 1
        print(f'Inspeção {registro["id"]} {status_esperado} — {quebradas}/{total} cápsulas quebradas.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
