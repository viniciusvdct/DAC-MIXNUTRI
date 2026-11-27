"""Gera uma copia do painel-projeto.html em arquivo unico, com as capturas embutidas, para mandar por
WhatsApp ou e-mail (abre em qualquer navegador, sem a pasta capturas/).

Uso (na raiz do repositorio):  python3 -I docs/empacotar_painel.py [saida.html]
Padrao da saida: docs/painel-projeto-arquivo-unico.html (fora do git).
"""
import base64
import re
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
ORIGEM = AQUI / 'painel-projeto.html'
TIPOS = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png'}


def embutir(m):
    arquivo = AQUI / m.group(1)
    tipo = TIPOS[arquivo.suffix.lower()]
    dados = base64.b64encode(arquivo.read_bytes()).decode('ascii')
    return 'src="data:%s;base64,%s"' % (tipo, dados)


def main():
    saida = Path(sys.argv[1]) if len(sys.argv) > 1 else AQUI / 'painel-projeto-arquivo-unico.html'
    html = ORIGEM.read_text(encoding='utf-8')
    html, n = re.subn(r'src="(capturas/[^"]+)"', embutir, html)
    saida.write_text(html, encoding='utf-8')
    print('%s: %d imagens embutidas, %.0f KB' % (saida, n, saida.stat().st_size / 1024))


if __name__ == '__main__':
    main()
