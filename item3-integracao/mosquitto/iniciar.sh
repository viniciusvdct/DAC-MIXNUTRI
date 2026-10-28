#!/bin/sh
# Gera passwd (hash) e ACL a partir das variaveis do .env e inicia o Mosquitto.
# As senhas nao ficam gravadas em texto no volume nem nos arquivos versionados.
set -eu
: "${MQTT_ESP32_USUARIO:?}" "${MQTT_ESP32_SENHA:?}" "${MQTT_BACKEND_USUARIO:?}" "${MQTT_BACKEND_SENHA:?}"

cfg=/mosquitto/config
cp /mixnutri/mosquitto.conf "$cfg/mosquitto.conf"
sed -e "s/@ESP32@/$MQTT_ESP32_USUARIO/" -e "s/@BACKEND@/$MQTT_BACKEND_USUARIO/" \
  /mixnutri/acl.modelo > "$cfg/acl"

rm -f "$cfg/passwd"
touch "$cfg/passwd"
chmod 0600 "$cfg/passwd" "$cfg/acl"
mosquitto_passwd -b "$cfg/passwd" "$MQTT_ESP32_USUARIO" "$MQTT_ESP32_SENHA"
mosquitto_passwd -b "$cfg/passwd" "$MQTT_BACKEND_USUARIO" "$MQTT_BACKEND_SENHA"
chown mosquitto:mosquitto "$cfg/passwd" "$cfg/acl"
chown -R mosquitto:mosquitto /mosquitto/data

# Ponte opcional com um broker publico (PONTE_BROKER=host:porta), para testar com o firmware
# rodando no Wokwi web, que so alcanca a internet. Somente dados sinteticos. Traz o que o
# ESP32 publica e leva comandos/configuracao/contexto SEM retain (nada fica retido no broker
# publico). Desligada quando PONTE_BROKER esta vazia. A rede precisa liberar a porta de saida.
if [ -n "${PONTE_BROKER:-}" ]; then
  sufixo=$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')
  cat >> "$cfg/mosquitto.conf" <<EOF_PONTE

connection ponte-wokwi
address ${PONTE_BROKER}
clientid mixnutri-ponte-${sufixo}
bridge_protocol_version mqttv311
cleansession true
keepalive_interval 30
try_private false
notifications false
bridge_outgoing_retain false
topic mixnutri/sala01/telemetria in 0
topic mixnutri/sala01/eventos in 0
topic mixnutri/sala01/confirmacoes in 0
topic mixnutri/sala01/disponibilidade in 0
topic mixnutri/sala01/comandos out 1
topic mixnutri/sala01/configuracao out 1
topic mixnutri/sala01/contexto out 1
EOF_PONTE
  echo "Ponte com ${PONTE_BROKER} ligada (somente dados sinteticos)"
fi

exec mosquitto -c "$cfg/mosquitto.conf"
