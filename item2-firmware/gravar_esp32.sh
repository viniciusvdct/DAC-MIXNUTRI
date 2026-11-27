#!/usr/bin/env bash
# Compila, grava e abre o monitor serial do ESP32 no macOS/Linux (equivalente ao compilar_esp32.ps1).
#
# Uso: ./gravar_esp32.sh [bancada|firmware] [tudo|compilar|gravar|monitor] [porta]
#   bancada   teste dos componentes, sem rede (comece por ele)
#   firmware  firmware completo; para gravar exige firmware/config_local.h
#             (gerado por ../item3-integracao/ferramentas/preparar_esp32.sh)
#   tudo      grava e abre o monitor (padrao). Sair do monitor: Ctrl+C
# A porta e detectada sozinha quando so ha uma placa USB ligada (ex.: /dev/cu.usbserial-0001).
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
ALVO="${1:-bancada}"
ACAO="${2:-tudo}"
PORTA="${3:-}"

case "$ALVO" in bancada|firmware) ;; *) echo "Alvo invalido: $ALVO (use bancada ou firmware)" >&2; exit 2 ;; esac
case "$ACAO" in tudo|compilar|gravar|monitor) ;; *) echo "Acao invalida: $ACAO" >&2; exit 2 ;; esac

# PlatformIO: ambiente do projeto (.venv) ou o instalado no sistema; instala no .venv se faltar.
PIO="$AQUI/.venv/bin/pio"
if [ ! -x "$PIO" ]; then
  if command -v pio >/dev/null 2>&1; then
    PIO="$(command -v pio)"
  else
    echo "Instalando PlatformIO em $AQUI/.venv (so na primeira vez)..."
    python3 -m venv "$AQUI/.venv"
    "$AQUI/.venv/bin/pip" install -q platformio
  fi
fi

if [ "$ALVO" = firmware ] && [ "$ACAO" != compilar ] && [ "$ACAO" != monitor ] &&
   [ ! -f "$AQUI/firmware/config_local.h" ]; then
  echo "Falta firmware/config_local.h (Wi-Fi e broker). Rode antes:" >&2
  echo "  ../item3-integracao/ferramentas/preparar_esp32.sh" >&2
  exit 1
fi

detectar_porta() {
  local portas=()
  local p
  for p in /dev/cu.usbserial* /dev/cu.SLAB_USBtoUART* /dev/cu.wchusbserial* /dev/cu.usbmodem* \
           /dev/ttyUSB* /dev/ttyACM*; do
    [ -e "$p" ] && portas+=("$p")
  done
  if [ "${#portas[@]}" -eq 1 ]; then
    PORTA="${portas[0]}"
  elif [ "${#portas[@]}" -eq 0 ]; then
    echo "Nenhuma placa USB encontrada. Confira o cabo (precisa ser de DADOS) e tente outra porta USB." >&2
    echo "Placas com chip CH340 podem exigir driver no macOS antigo; veja o GUIA_MONTAGEM_FISICA.md." >&2
    exit 1
  else
    echo "Mais de uma porta serial: ${portas[*]}. Informe a porta: $0 $ALVO $ACAO <porta>" >&2
    exit 1
  fi
}

if [ "$ACAO" != compilar ] && [ -z "$PORTA" ]; then detectar_porta; fi

case "$ACAO" in
  compilar) "$PIO" run -d "$AQUI/$ALVO" ;;
  gravar)   "$PIO" run -d "$AQUI/$ALVO" -t upload --upload-port "$PORTA" ;;
  monitor)  "$PIO" device monitor -p "$PORTA" -b 115200 ;;
  tudo)
    "$PIO" run -d "$AQUI/$ALVO" -t upload --upload-port "$PORTA"
    echo "Gravado em $PORTA. Abrindo o monitor serial (Ctrl+C para sair)..."
    "$PIO" device monitor -p "$PORTA" -b 115200
    ;;
esac
