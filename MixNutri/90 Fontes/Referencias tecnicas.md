---
projeto: MixNutri
equipe: 1
tipo: fontes
status: documentado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Referências técnicas

Documentação primária consultada em 26/10/2026 para orientar propostas. Não substitui os requisitos do desafio. Disponibilidade de componentes e condições de acesso podem mudar; verificar novamente ao implementar.

| Fonte | Uso nesta base |
| --- | --- |
| [Hardware suportado Wokwi](https://docs.wokwi.com/getting-started/supported-hardware) | Verificar componentes listados para a primeira simulação |
| [DHT22 Wokwi](https://docs.wokwi.com/parts/wokwi-dht22) | Pinos, ajuste de UR/temperatura e recomendação de biblioteca para ESP32 |
| [Relé Wokwi](https://docs.wokwi.com/parts/wokwi-relay-module) | Contatos, pino IN e atributos; testar polaridade na prática |
| [Potenciômetro Wokwi](https://docs.wokwi.com/parts/wokwi-potentiometer) | Entrada sintética e limitação de simulação analógica |
| [Rede ESP32 Wokwi](https://docs.wokwi.com/guides/esp32-wifi) | Caminho para broker e diferenças entre gateways |
| [Configuração Wokwi VS Code](https://docs.wokwi.com/vscode/project-config) | Alternativa de ambiente local a avaliar |
| [Preferences Arduino-ESP32](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/preferences.html) | Persistência de pequenos parâmetros em NVS |
| [MAX9814 Analog Devices](https://www.analog.com/en/products/max9814.html) | Característica AGC e cuidado com inferência por amplitude |

Não foram fixadas versões de bibliotecas ou contratos de licença. Não houve instalação de simulador, aquisição de componentes ou configuração de serviço nesta sessão.

## Complementos consultados em 27/10/2026

- [Chips customizados Wokwi](https://docs.wokwi.com/chips-api/getting-started), [definição JSON](https://docs.wokwi.com/chips-api/chip-json), [atributos](https://docs.wokwi.com/chips-api/attributes), [I²C](https://docs.wokwi.com/chips-api/i2c), [API analógica](https://docs.wokwi.com/chips-api/analog) e [temporização](https://docs.wokwi.com/chips-api/time): interfaces usadas nos modelos do item 1.
- [Datasheet SHT3x-DIS, Sensirion](https://sensirion.com/media/documents/213E6A3B/63A5A569/Datasheet_SHT3x_DIS.pdf): comandos, CRC e conversões implementados parcialmente no diagnóstico.

Não foram copiados dados de fábrica para o projeto de teste. O uso de API analógica simples e de um protocolo parcial não valida características físicas dos módulos.
