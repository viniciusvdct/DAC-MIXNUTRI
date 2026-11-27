#!/usr/bin/env bash
# Prepara o ESP32 fisico e o Mosquitto para a rede local (macOS/Linux). Equivale ao preparar_esp32.ps1.
#
# - Descobre o IPv4 deste computador na rede local (ou use --ip).
# - Pede o nome e a senha do Wi-Fi de 2,4 GHz no terminal (a senha nao aparece nem vai para o historico).
# - Grava ../../item2-firmware/firmware/config_local.h com as credenciais MQTT do ESP32 lidas do .env
#   (nada e impresso). Esse arquivo fica fora do git.
# - No .env: MQTT_BIND=<IP> (Mosquitto escuta na rede local) e PONTE_BROKER vazio (sem broker publico).
# - Recria o servico mosquitto (docker compose up -d mosquitto).
#
# Uso, na pasta item3-integracao:  ferramentas/preparar_esp32.sh [--ip 192.168.x.y] [--force]
#                                  [--sem-compose] [--verificar]
#   --force       substitui um config_local.h existente (ex.: mudou a rede ou o IP)
#   --verificar   so confere IP e credenciais, sem gravar nada
# Para automatizar (sem perguntas): variaveis MIXNUTRI_WIFI_SSID e MIXNUTRI_WIFI_SENHA.
set -euo pipefail

KIT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_ARQ="$KIT/.env"
CONFIG="$KIT/../item2-firmware/firmware/config_local.h"
IP="" FORCAR=0 COMPOSE=1 VERIFICAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP="${2:-}"; shift 2 ;;
    --force) FORCAR=1; shift ;;
    --sem-compose) COMPOSE=0; shift ;;
    --verificar) VERIFICAR=1; shift ;;
    --config) CONFIG="${2:-}"; shift 2 ;;  # usado nos testes do script
    *) echo "Opcao desconhecida: $1" >&2; exit 2 ;;
  esac
done

falha() { echo "ERRO: $*" >&2; exit 1; }

[ -f "$ENV_ARQ" ] || falha "crie primeiro $ENV_ARQ (cp .env.exemplo .env e troque os TROCAR_*)"
if [ -f "$CONFIG" ] && [ "$FORCAR" -eq 0 ] && [ "$VERIFICAR" -eq 0 ]; then
  falha "config_local.h ja existe. Use --force para substituir (ex.: mudou a rede ou o IP)."
fi

# Valor de uma variavel do .env, sem imprimir.
valor_env() { sed -n "s/^$1=//p" "$ENV_ARQ" | tail -n 1; }
MQTT_USUARIO="$(valor_env MQTT_ESP32_USUARIO)"
MQTT_SENHA="$(valor_env MQTT_ESP32_SENHA)"
[ -n "$MQTT_USUARIO" ] && [ -n "$MQTT_SENHA" ] || falha "MQTT_ESP32_USUARIO/MQTT_ESP32_SENHA ausentes no .env"
case "$MQTT_SENHA" in TROCAR_*) falha "troque MQTT_ESP32_SENHA no .env antes (ainda esta TROCAR_...)" ;; esac

# IPv4 da rede local: interface da rota padrao.
if [ -z "$IP" ]; then
  if [ "$(uname)" = Darwin ]; then
    IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
    [ -n "$IFACE" ] && IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null || true)"
  else
    IP="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')"
  fi
fi
[ -n "$IP" ] || falha "nao encontrei o IPv4 da rede local; informe com --ip 192.168.x.y"
case "$IP" in
  10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) ;;
  *) falha "$IP nao parece um IP de rede local (10.x, 172.16-31.x ou 192.168.x)" ;;
esac

if [ "$VERIFICAR" -eq 1 ]; then
  echo "Verificacao OK: broker em $IP:1883, credenciais MQTT do ESP32 presentes no .env."
  exit 0
fi

# Wi-Fi: variaveis de ambiente (automacao) ou perguntas no terminal.
SSID="${MIXNUTRI_WIFI_SSID:-}"
SENHA="${MIXNUTRI_WIFI_SENHA:-}"
if [ -z "$SSID" ]; then read -r -p "Nome da rede Wi-Fi de 2,4 GHz do ESP32: " SSID; fi
if [ -z "${MIXNUTRI_WIFI_SENHA+x}" ]; then
  read -r -s -p "Senha do Wi-Fi (nao aparece; vazia = rede aberta): " SENHA
  echo
fi

bytes() { printf %s "$1" | wc -c | tr -d ' '; }
[ "$(bytes "$SSID")" -ge 1 ] && [ "$(bytes "$SSID")" -le 32 ] || falha "o SSID deve ter de 1 a 32 bytes"
if [ -n "$SENHA" ] && { [ "${#SENHA}" -lt 8 ] || [ "${#SENHA}" -gt 63 ]; }; then
  falha "a senha WPA2 deve ter de 8 a 63 caracteres (ou ficar vazia para rede aberta)"
fi

# Texto entre aspas em C: escapa \ e "; recusa caracteres de controle.
c_texto() {
  case "$1" in *[[:cntrl:]]*) falha "SSID ou senha com caractere de controle" ;; esac
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

umask 077
{
  echo "// Gerado por item3-integracao/ferramentas/preparar_esp32.sh em $(date '+%d/%m/%Y %H:%M')."
  echo "// Arquivo local com senhas: nao publique nem compartilhe (fica fora do git)."
  echo "#pragma once"
  echo "#define MIXNUTRI_SIMULACAO 0  // dados reais; o hardware do kit vem de hardware_fisico.h"
  echo "static const char *WIFI_SSID = $(c_texto "$SSID"), *WIFI_SENHA = $(c_texto "$SENHA");"
  echo "static const int WIFI_CANAL = 0;"
  echo "static const char *MQTT_HOST = \"$IP\";"
  echo "static const uint16_t MQTT_PORTA = 1883;"
  echo "static const char *MQTT_USUARIO = $(c_texto "$MQTT_USUARIO"), *MQTT_SENHA = $(c_texto "$MQTT_SENHA");"
  echo "static const char *TOPICO_BASE = \"mixnutri/sala01\";"
  echo "static const char *DEVICE_ID = \"sala01-esp32\", *SALA_ID = \"sala01\";"
} > "$CONFIG"
SENHA="" MQTT_SENHA=""

# .env: Mosquitto na rede local e sem ponte com broker publico (ESP32 fisico).
TMP="$(mktemp "$ENV_ARQ.XXXXXX")"
awk -v ip="$IP" '
  /^MQTT_BIND=/   { print "MQTT_BIND=" ip; b = 1; next }
  /^PONTE_BROKER=/ { print "PONTE_BROKER="; next }
  { print }
  END { if (!b) print "MQTT_BIND=" ip }' "$ENV_ARQ" > "$TMP"
cat "$TMP" > "$ENV_ARQ" && rm -f "$TMP"

echo "config_local.h gravado (broker $IP:1883). .env: MQTT_BIND=$IP e ponte publica desligada."
if [ "$COMPOSE" -eq 1 ]; then
  (cd "$KIT" && docker compose up -d mosquitto)
fi
echo "Proximo passo: ../item2-firmware/gravar_esp32.sh firmware   (grava e abre o monitor serial)"
echo "No monitor, confira 'FILA flash_ok=1' e 'REDE wifi=1 mqtt=1'."
if [ "$(uname)" = Darwin ]; then
  echo "Se o macOS perguntar se aceita conexoes de entrada para o Docker/OrbStack, permita."
fi
