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

exec mosquitto -c "$cfg/mosquitto.conf"
