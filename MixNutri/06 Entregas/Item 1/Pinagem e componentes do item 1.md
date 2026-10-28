---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Pinagem e componentes do item 1

A pinagem abaixo corresponde a `circuito/diagram.json` de [[Entrega do item 1]]. É um circuito de simulação com carga LED de baixa tensão. Não dimensiona chaveamento de um desumidificador industrial.

| Componente | Pino | Ligação |
| --- | --- | --- |
| ESP32 DevKit V1 | 3V3 | VCC dos modelos SHT31 e som; alimentação da carga LED e pull-ups |
| ESP32 | GND.1 | Terra comum dos modelos, relé e LED |
| SHT31 parcial | SDA | GPIO21, com pull-up 4,7 kΩ a 3V3 |
| SHT31 parcial | SCL | GPIO22, com pull-up 4,7 kΩ a 3V3 |
| SHT31 parcial | Endereço | 0x44, medição 0x2400 sem clock stretching |
| Som sintético | OUT | GPIO34, entrada ADC |
| Relé do simulador | VCC | VIN da placa simulada |
| Relé do simulador | GND | Terra comum |
| Relé do simulador | IN | GPIO26; módulo `npn`, HIGH fecha COM–NO |
| Relé | COM | 3V3 da carga demonstrativa |
| Relé | NO | Resistor 330 Ω → anodo do LED |
| LED | Catodo | GND |
| Relé | NC | Não utilizado |

## Componentes da simulação

Um ESP32 DevKit V1; um modelo SHT31 parcial; um gerador de sinal sonoro; um módulo relé; um LED verde; um resistor 330 Ω; dois resistores 4,7 kΩ. Os dois chips customizados têm código e controles no pacote.

O gerador de som produz um tom de onda quadrada de 200 Hz em torno de 1,65 V, com amplitude de até 0,9 V (controle `amplitudePercent`), somado a um ruído de fundo pseudoaleatório de até ±0,3 V (`ruidoFundoPercent`, padrão 5%). A saída fica limitada a 0–3,3 V. Com `online = 0`, a saída vai a 0 V para simular sensor desconectado. O ESP32 remove o nível médio da janela e calcula RMS em contagens ADC e em dBFS (`20·log10(RMS/2048)`). O modelo não implementa AGC, sensibilidade acústica ou I²S, e o RMS depende da escala do ADC simulada: no Wokwi, tom de 80% resultou em RMS ≈ 589 (−10,8 dBFS) e só o ruído de 5%, em ≈ 7 (≈ −50 dBFS).

O firmware do item 2 usa o mesmo circuito e acrescenta o LED azul da placa (GPIO2) como indicador de rede: aceso com MQTT conectado, piscando devagar só com Wi-Fi, piscando rápido sem rede.

O modelo SHT31 tem controle de temperatura de 0 a 50 °C, UR de 0 a 100%, disponibilidade e falha de CRC. Só implementa os comandos usados no diagnóstico, não todos os modos do sensor. CRC e conversões se baseiam no [datasheet Sensirion](https://sensirion.com/media/documents/213E6A3B/63A5A569/Datasheet_SHT3x_DIS.pdf).

## Correção verificada

A documentação do relé consultada tem descrições que podem induzir a polaridades diferentes. O teste nos contatos mostrou `npn` ativo em HIGH. O código foi corrigido para ON=HIGH/OFF=LOW. Capturas anteriores foram conservadas em `evidencias/historico-antes-correcao` e não devem comprovar o resultado final. Revalidar a polaridade se o componente/atributo mudar.

## Migração física futura

Selecionar os módulos reais antes de reproduzir alimentação e interface. O nome “SHT31 parcial” e o bloco de som são modelos funcionais, sem equivalência de encapsulamento, ganho, precisão ou proteção elétrica. A escolha de relé/interface e a potência do desumidificador permanecem indefinidas no hardware físico.
