# Contrato de integração entre as equipes

Este contrato evita que a equipe de firmware, a equipe de redes/BD e a equipe de dashboard usem nomes, unidades ou tópicos diferentes. A referência é sempre uma Sala Piloto: `sala01`.

## MQTT

Broker padrão: Mosquitto TCP `1883`. Prefixo: `iotmixnutri/sala01/`.

| Tópico | Direção | QoS / retain | Uso |
|---|---|---|---|
| `iotmixnutri/sala01/telemetria` | ESP32 → sistema | QoS 1, sem retain | Medidas e estados em JSON |
| `iotmixnutri/sala01/comando` | Node-RED → ESP32 | QoS 1, retain | Modo/acionamento remoto |
| `iotmixnutri/sala01/configuracao` | Node-RED → ESP32 | QoS 1, retain | Limites ambientais atualizados pelo Admin |

Exemplo de telemetria:

```json
{
  "sala_id": "sala01",
  "timestamp": "2026-10-15T12:00:00Z",
  "umidade_pct": 58.4,
  "temperatura_c": 25.2,
  "ruido_db": 66.0,
  "estado_maquina": "OPERANDO",
  "desumidificador": true,
  "modo": "AUTO",
  "origem": "esp32",
  "codigo_falha": 0
}
```

Campos obrigatórios: `umidade_pct` (0–100). `timestamp` deve ser ISO 8601 com fuso horário; quando ausente, o fluxo usa o horário de recebimento. `temperatura_c`, `ruido_db`, `estado_maquina`, `desumidificador`, `modo` e `codigo_falha` podem ser omitidos se não existirem. `estado_maquina` aceita `OPERANDO`, `PARADO` ou `DESCONHECIDO`; `modo` aceita `AUTO` ou `MANUAL`. `origem` deve identificar `esp32`, `modbus`, `s7comm` ou `acustico`.

Comando remoto:

```json
{"modo":"MANUAL","desumidificador":true}
```

O outro comando suportado é `{"modo":"AUTO"}`. O firmware deve assinar o tópico de comando, aplicar a histerese local no modo AUTO e publicar o estado observado no tópico de telemetria. O ESP32 deve manter operação segura local durante queda do broker.

Ao alterar qualquer limite no painel administrativo, o Node-RED salva a configuração no PostgreSQL e publica o conjunto atual no tópico retido `iotmixnutri/sala01/configuracao`, por exemplo:

```json
{"umidade_max_pct":55,"histerese_pct":5,"ruido_operacional_db":60,"parada_segundos":15}
```

O firmware deve assinar esse tópico e aplicar os valores recebidos à lógica local, preservando os valores padrão seguros caso ainda não tenha recebido configuração.

## Mapa de registradores Modbus TCP

FC03 — Holding Registers, endereço inicial zero-based, Unit ID 1, leitura a cada 2 s. O simulador incluído já responde a este mapa.

| HR | Conteúdo | Tipo / escala | Exemplo |
|---:|---|---|---|
| 0 | Umidade relativa | uint16, décimos de % | 584 = 58,4% |
| 1 | Temperatura | int16, décimos de °C | 252 = 25,2 °C |
| 2 | Ruído | uint16, décimos de dB | 660 = 66,0 dB |
| 3 | Máquina | uint16, 1 operando / 0 parada | 1 |
| 4 | Desumidificador | uint16, 1 ligado / 0 desligado | 1 |
| 5 | Código de falha | uint16 | 0 = sem falha |

O fluxo Node-RED converte os registradores para o contrato MQTT interno e encaminha ao mesmo processo de persistência. Ao trocar simulador por CLP, ajuste IP, porta, Unit ID, offsets e escala no nó Modbus. Se o mapa real do CLP tiver ordem ou tipo diferente, documente-o aqui e altere o nó de mapeamento antes da demonstração.

## S7Comm / Siemens

A aba **Integração S7Comm (opcional)** foi incluída no fluxo, mas desabilitada por padrão. Para ativar:

1. Obtenha autorização do responsável pelo CLP e confirme IP, rack, slot, permissão de leitura e os endereços de DB. Não faça escrita no CLP nesta etapa.
2. No editor Node-RED, configure o endpoint `CLP Siemens`: endereço IP, rack/slot e `vartable`.
3. Atualize as variáveis `UMIDADE_PCT`, `TEMPERATURA_C`, `RUIDO_DB`, `MAQUINA_OPERANDO` e `DESUMIDIFICADOR` com os nomes e offsets confirmados pela equipe de Controle e Automação.
4. Habilite a aba S7 e faça Deploy. A saída `s7 in` é convertida para o mesmo formato da telemetria.

Endereços de DB dependem do modelo e da configuração otimizada do PLC. O fluxo vem com um exemplo ilustrativo (`DB1,REAL0`, `DB1,REAL4`, `DB1,REAL8`, `DB1,X12.0`, `DB1,X12.1`), que precisa ser substituído pelos endereços validados. O acesso S7 deve ser somente de leitura para esta entrega.

## Banco, dashboard e alertas

- `telemetria_sala01`: uma linha por medição recebida.
- `paradas_maquina_sala01`: início/fim, origem, ruído, falha e umidade correlacionada.
- `configuracao_alertas`: limite UR, histerese, limiar acústico e duração mínima da parada.
- `alertas_sala01`: histórico de alertas gerados.
- O Grafana lê com o papel `grafana_reader`, que tem apenas permissões SELECT.
- O Node-RED emite alerta de UR acima do limite e máquina parada, com janela anti-repetição de 5 min. O alerta aparece no painel, fica no histórico SQL e pode ser encaminhado para Telegram/e-mail com credenciais no `.env`.
- Para classificação acústica, ruído abaixo de `ruido_operacional_db` por `parada_segundos` muda o estado para PARADO; ruído acima do limite volta para OPERANDO. Um status discreto vindo de Modbus/S7 tem prioridade.
