---
projeto: MixNutri
equipe: 1
tipo: entrega
status: implementado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Entrega do item 2 — firmware do ESP32

Item "Firmware do ESP32" do bloco 26 de [[Transcricao integral dos entregaveis]]: histerese, leitura acústica OPERANDO/PARADO, cliente Modbus TCP, MANUAL/AUTO via MQTT e retenção básica em Flash. Primeira versão implementada e testada em 27/10/2026. Resultados em [[Validacao do item 2]].

O circuito é **o mesmo do item 1** ([[Pinagem e componentes do item 1]]); só muda o programa. Parâmetros, tópicos e políticas são **propostas didáticas** para combinar com as equipes 2 e 3, não decisões aprovadas nem limites industriais.

**Projeto no Wokwi (salvo em 27/10/2026):** [MixNutri - Item 2 (firmware ESP32)](https://wokwi.com/projects/479080199406642177). Público, na conta Wokwi do usuário. Os 9 arquivos foram conferidos por SHA-256 contra os desta pasta; o projeto salvo compilou, montou a Flash e conectou ao MQTT.

## Arquivos

| Arquivo | Papel |
| --- | --- |
| [sketch.ino](firmware/sketch.ino) | Programa principal: sensores, controle, MQTT, Modbus, fila, serial |
| [logica.h](firmware/logica.h) | Lógica pura testável no computador: configuração, histerese, MANUAL, classificador, Modbus, fila |
| [partitions.csv](firmware/partitions.csv) | Tabela de partições com `spiffs` para o LittleFS (o Wokwi web não tem essa partição por padrão) |
| [libraries.txt](firmware/libraries.txt) | PubSubClient e ArduinoJson para o Wokwi web |
| diagram.json, sht31/som.chip.* | Circuito e modelos, idênticos ao item 1 (exceto o texto de aviso) |
| [wokwi.toml](firmware/wokwi.toml), [platformio.ini](firmware/platformio.ini), [item2.test.yaml](firmware/testes/wokwi/item2.test.yaml) | Execução local com Wokwi CLI / VS Code (não executado; ver [[Wokwi CLI e VS Code]]) |
| [test_logica.cpp](firmware/testes/test_logica.cpp) | 15 grupos de testes nativos da lógica |
| [mqtt_mini.py](ferramentas/mqtt_mini.py) | Cliente MQTT mínimo em Python, sem dependências, para observar/publicar nos testes |

## O que o firmware faz

| Requisito do bloco 26 | Implementação |
| --- | --- |
| Histerese de UR | Liga em `ur_liga` (55%), desliga em `ur_desliga` (50%), mantém entre eles. Tempo mínimo entre comutações (10 s, didático) para proteger compressor. Falha do SHT31 em AUTO desliga |
| Leitura acústica OPERANDO/PARADO | ADC a 4 kHz, janelas de 64 ms sem componente DC, blocos de ~0,5 s. Nível em **dBFS = 20·log10(RMS/2048)**. OPERANDO ≥ −25 dBFS por 3 s; PARADO ≤ −35 dBFS por 5 s; zona morta mantém. Sem polarização DC → `DESCONHECIDO` |
| Eventos de parada | `PARADA_INICIO` / `PARADA_FIM` com `evento_id`, início no instante da queda (não da confirmação), fim, duração e `motivo_fim`, além de produto e lote |
| Cliente Modbus TCP | Função 03, dois registradores (STATUS_MAQUINA, CODIGO_FALHA), **desligado por padrão** porque o acesso ao CLP não foi autorizado. Perda de comunicação → `DESCONHECIDO`, nunca PARADO; o estado principal volta para o som |
| MANUAL/AUTO via MQTT | MANUAL ON/OFF com validade (padrão 15 min, máx. 8 h), volta a AUTO ao vencer. Rejeita sem `cmd_id`, repetido, `ts` vencido (>120 s com relógio sincronizado), modo ou relé inválidos. O boot é sempre AUTO; MANUAL não é restaurado |
| Configuração remota | Versão crescente, aplicação atômica, validação completa e persistência na NVS. Aceita os campos do Admin (`ur_max`, `histerese`, `limiar_db`, `banda_db`) ou os campos diretos |
| Produto e lote por leitura | Tópico `contexto` grava produto/lote na NVS; toda telemetria e todo evento levam `produto`, `lote_producao`, `lote_capsula`, `lote_po`. Sem contexto: `NAO_INFORMADO` explícito |
| Retenção em Flash em quedas de rede | Fila circular no LittleFS (192 mensagens de até 1000 B, ~16 min de telemetria a 5 s, mais eventos). Sem rede, toda mensagem vai para a Flash; ao reconectar, reenvia em ordem. Cheia, descarta a mais antiga e conta a perda. **Sobrevive a reinício** |

Arquitetura: duas tarefas FreeRTOS. O núcleo 1 lê sensores e controla o relé sem esperar a rede; o núcleo 0 cuida de Wi-Fi, MQTT, Modbus e da fila. As duas se comunicam por filas do FreeRTOS. Relógio por NTP; antes da sincronização, `timestamp_utc` vai `null` e o backend usa o horário de recebimento.

## Contrato MQTT implementado (proposta)

Base `mixnutri/sala01`. Detalhes e exemplos reais em [[Contrato MQTT proposto]].

| Tópico | Sentido | Conteúdo |
| --- | --- | --- |
| `telemetria` | ESP32 → backend | A cada 5 s: clima e qualidade, ruído em dBFS, estado da máquina e fonte, modo, relé e motivo, produto/lote, `boot_id`/`seq`, `fila_flash` |
| `eventos` | ESP32 → backend | BOOT, RELE, MODO, MANUAL_EXPIRADO, SENSOR_FALHA/OK, ESTADO_MAQUINA, PARADA_INICIO/FIM, CONFIG_APLICADA, CONTEXTO_ALTERADO |
| `confirmacoes` | ESP32 → backend | Aceito/rejeitado com `motivo` para cada comando, configuração ou contexto |
| `disponibilidade` | ESP32/broker | `online` ao conectar e Last Will `offline`, ambos com retain |
| `comandos` | Admin → ESP32 | `{"cmd_id":"c1","modo":"MANUAL","rele":"ON","validade_s":600,"ts":1793142591}` ou `{"cmd_id":"c2","modo":"AUTO"}` — **publicar sem retain** |
| `configuracao` | Admin → ESP32 | `{"versao":2,"ur_max":58,"histerese":4,"limiar_db":-22,"banda_db":12}` — pode ser retido |
| `contexto` | Admin/backend → ESP32 | `{"produto":"X","lote_producao":"L1","lote_capsula":"C1"}` — pode ser retido |

Os campos da telemetria seguem os nomes das colunas de `telemetria_sala01` do item 1 (v2), para a equipe 2 mapear direto. O PubSubClient publica com QoS 0; a fila garante retenção enquanto não há conexão, mas não confirmação de entrega pelo broker.

## Como rodar no Wokwi web

1. Abrir um [projeto ESP32 novo](https://wokwi.com/projects/new/esp32).
2. Criar, pelo menu ▼ das abas → "New file…", os arquivos `logica.h`, `libraries.txt`, `partitions.csv`, `sht31.chip.c`, `sht31.chip.json`, `som.chip.c` e `som.chip.json`. Colar o conteúdo de cada um a partir da pasta `firmware`.
3. Substituir `sketch.ino` e `diagram.json`.
4. Iniciar. O primeiro boot mostra erros `esp_littlefs ... Corrupted dir pair`: é a Flash virgem sendo formatada. Em seguida aparece `FILA flash_ok=1`.
5. O serial imprime `ST` a cada 2 s, `TEL` a cada 5 s, `EVT` e `ACK`. Comandos: `1`/`0` (MANUAL ON/OFF), `a` (AUTO), `n` (simular queda de rede), `f` (fila), `r` (reiniciar), `s` (telemetria agora), e `cmd {json}`, `cfg {json}`, `ctx {json}` no mesmo formato do MQTT.
6. Para ver o MQTT de fora: `python3 ferramentas/mqtt_mini.py sub broker.hivemq.com 'mixnutri/sala01/#' log.txt`. Para comandar: `python3 ferramentas/mqtt_mini.py pub broker.hivemq.com mixnutri/sala01/comandos '{"cmd_id":"c1","modo":"AUTO"}'`.

**Broker:** o padrão é o público `broker.hivemq.com`, só para demonstração com dados sintéticos. Qualquer pessoa pode ler e publicar nesses tópicos. Para o sistema da equipe 2, trocar `MQTT_HOST` e `TOPICO_BASE` no topo do `sketch.ino`. No Wokwi, o acesso ao Mosquitto local exige o gateway privado, que é pago no Wokwi web.

## Limites

- Som sintético; dBFS não é dB SPL. Os limiares −25/−35 dBFS valem para o gerador do Wokwi; numa máquina real precisam ser medidos. MAX9814 tem AGC, e o INMP441 é I²S (outro driver).
- Modbus testado contra um CLP inexistente (falha de comunicação) e por testes nativos dos quadros. Não houve teste contra servidor Modbus real ou simulado.
- Comando MANUAL também respeita o tempo mínimo do relé. Política industrial de falha, validade e tempo mínimo continua pendente.
- O `uptime_ms` do evento BOOT após `ESP.restart()` no Wokwi não voltou a zero (artefato do simulador). `boot_id` diferencia os reinícios.
- `inicio_utc` e `fim_utc` são derivados do uptime com resolução de 1 s.
- Integração com PostgreSQL, Node-RED e Grafana (itens 3 a 5) não foi feita nesta entrega.
