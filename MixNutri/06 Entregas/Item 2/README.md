# MixNutri Item 2 — firmware do ESP32

Primeira versão para revisão acadêmica, testada em 27/10/2026 no Wokwi web com MQTT real (broker público, dados sintéticos).

- Projeto no Wokwi: https://wokwi.com/projects/479080199406642177
- [Entrega e instruções](Entrega%20do%20item%202.md)
- [Validação, resultados e limites](Validacao%20do%20item%202.md)

Pasta `firmware`: copiar para um projeto ESP32 do Wokwi `sketch.ino`, `diagram.json`, `logica.h`, `libraries.txt`, `partitions.csv` e os quatro arquivos dos chips. O circuito é o mesmo do item 1.

Implementa histerese com tempo mínimo, classificação acústica OPERANDO/PARADO em dBFS (não dB SPL), eventos de parada com produto/lote, MANUAL/AUTO e configuração via MQTT, contexto produto/lote e fila de mensagens na Flash que sobrevive a queda de rede e reinício. O cliente Modbus TCP existe, mas vem desligado por padrão: o acesso ao CLP não foi autorizado e a leitura real não foi testada.

Parâmetros e tópicos são propostas didáticas a combinar com as equipes 2 e 3.
