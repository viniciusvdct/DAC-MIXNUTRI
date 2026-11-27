// Kit fisico de bancada da equipe 1 (lista de 27/11/2026). Sem senhas: pode ficar no git.
// Usado pelo firmware quando MIXNUTRI_SIMULACAO = 0 (config_local.h) e pelo teste de bancada.
// O Wokwi continua com o circuito do item 1 (SHT31 por I2C) e nao usa este arquivo.
//
// Pecas: ESP32-WROOM-32 DevKit 30 pinos, DHT11 (4 pinos), modulo rele 5 V JQC-3FF-S-Z,
// microfone P2 mono com polarizacao (ver GUIA_MONTAGEM_FISICA.md), LEDs verde, amarelo e vermelho.
#pragma once

// Sensor de clima: 1 = DHT11 de um fio; 0 = SHT31 por I2C (GPIO 21/22), como no Wokwi.
#define CLIMA_DHT11 1
#define PIN_DHT 4  // DATA do DHT11, com resistor de 10 kOhm para 3V3

// LEDs de sinalizacao (cada um com resistor de 330 Ohm para o GND).
#define PIN_LED_PARADA 25  // amarelo: maquina PARADA pela fonte principal (som ou Modbus)
#define PIN_LED_ALERTA 27  // vermelho: UR >= limite de ligar; pisca se o sensor de clima falhar
// O LED verde fica nos contatos COM/NO do rele (carga simulada do desumidificador) e o
// LED azul da placa (GPIO 2) indica a rede.

// Modulo rele: 1 se o nivel HIGH no IN liga o rele; 0 se for ativo em LOW.
// Confirme com o teste de bancada (comandos h e l) antes de gravar o firmware completo.
#define RELE_ATIVO_EM_HIGH 1
