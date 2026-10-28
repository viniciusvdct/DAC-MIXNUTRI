// Configuracao padrao: simulacao no Wokwi, com broker publico e dados sinteticos.
// Para o ESP32 de verdade, copie config_local.h.exemplo para config_local.h e preencha.
// Quando config_local.h existe, o sketch usa ele no lugar deste arquivo.
#pragma once
#define MIXNUTRI_SIMULACAO 1  // 1 no Wokwi: origem "simulacao" e fonte acustica "sintetico"
static const char *WIFI_SSID = "Wokwi-GUEST", *WIFI_SENHA = "";
static const int WIFI_CANAL = 6;  // acelera a conexao no Wokwi; usar 0 no hardware real
// Broker publico so para demonstracao com dados sinteticos. Trocar pelo Mosquitto da
// equipe 2. No Wokwi, broker local exige o gateway privado (host.wokwi.internal).
// String vazia desliga o MQTT: tudo fica retido na fila da Flash.
static const char *MQTT_HOST = "broker.hivemq.com";
static const uint16_t MQTT_PORTA = 1883;
static const char *MQTT_USUARIO = nullptr, *MQTT_SENHA = nullptr;
static const char *TOPICO_BASE = "mixnutri/sala01";
static const char *DEVICE_ID = "sala01-esp32", *SALA_ID = "sala01";
