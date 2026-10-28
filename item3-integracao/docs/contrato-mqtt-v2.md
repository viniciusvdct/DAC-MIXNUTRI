# Contrato MQTT v2 — MixNutri, sala piloto `sala01`

Documento da **equipe 1** (circuito e firmware) para as equipes do backend e do dashboard. Descreve exatamente o que o firmware do item 2 publica e aceita. O firmware foi testado em 27/10/2026 no Wokwi com MQTT real e dados sintéticos. O kit desta pasta implementa o lado do servidor. Continua sendo proposta até o aceite das equipes.

## Conexão

| Item | Valor |
| --- | --- |
| Protocolo | MQTT 3.1.1, porta 1883 |
| Base dos tópicos | `mixnutri/sala01/` (constante `TOPICO_BASE` em `sketch.ino`) |
| Identificação | `device_id = "sala01-esp32"`, `sala_id = "sala01"` |
| QoS | O ESP32 publica com QoS 0 (PubSubClient) e assina `comandos`, `configuracao` e `contexto` com QoS 1 |
| Autenticação | O firmware aceita usuário e senha (`MQTT_USUARIO`, `MQTT_SENHA`) ou broker anônimo. O kit usa usuário e senha, com ACL |
| Last Will | `disponibilidade` ← `{"estado":"offline"}`, retido |

## Tópicos

| Tópico | Sentido | Retain | Conteúdo |
| --- | --- | --- | --- |
| `telemetria` | ESP32 → backend | não | A cada `telemetria_ms` (5 s) |
| `eventos` | ESP32 → backend | não | BOOT, RELE, MODO, MANUAL_EXPIRADO, SENSOR_FALHA, SENSOR_OK, ESTADO_MAQUINA, PARADA_INICIO, PARADA_FIM, CONFIG_APLICADA, CONTEXTO_ALTERADO |
| `confirmacoes` | ESP32 → backend | não | Resposta a cada comando, configuração ou contexto |
| `disponibilidade` | ESP32 / broker | **sim** | `online` ao conectar; `offline` pelo Last Will |
| `comandos` | Admin → ESP32 | **proibido** | AUTO / MANUAL com validade |
| `configuracao` | Admin → ESP32 | permitido | Limiares e tempos, com `versao` crescente |
| `contexto` | Admin → ESP32 | permitido | Produto e lote em produção |

## Cabeçalho comum (telemetria, eventos e confirmações)

| Campo | Tipo | Observação |
| --- | --- | --- |
| `schema_version` | inteiro | `2` |
| `device_id`, `sala_id` | texto | Identificação |
| `boot_id` | texto | Muda a cada reinício |
| `seq` | inteiro | Telemetria tem um contador; eventos e confirmações compartilham outro |
| `uptime_ms` | inteiro | Tempo desde o boot |
| `timestamp_utc` | texto ISO 8601 UTC ou `null` | Só vem preenchido com o relógio sincronizado por NTP |
| `clock_synced` | booleano | Se `false`, usar o horário de recebimento |
| `origem_dados` | `simulacao` \| `real` | Toda a bancada atual é `simulacao` |
| `produto`, `lote_producao` | texto | Em toda telemetria e todo evento; sem contexto, valem `NAO_INFORMADO` |
| `lote_capsula`, `lote_po` | texto ou `null` | Opcionais |

## `telemetria`

| Campo | Tipo / unidade | Observação |
| --- | --- | --- |
| `temperatura_c`, `umidade_pct` | número ou `null` | `null` quando `clima_valido = false` (falha do SHT31). Nunca repete o último valor |
| `clima_valido` | booleano | Qualidade da leitura de clima |
| `nivel_ruido` | número ≤ 0 ou `null` | **dBFS** = 20·log10(RMS_ADC/2048), relativo ao ADC. **Não é dB SPL** |
| `unidade_ruido` | `"dBFS"` ou `null` | Sempre conferir antes de exibir |
| `ruido_adc_rms` | número | RMS bruto do ADC (diagnóstico) |
| `fonte_estado` | `sintetico` \| `audio` \| `modbus` \| `indisponivel` | Fonte do `estado_maquina` |
| `estado_maquina` | `OPERANDO` \| `PARADO` \| `DESCONHECIDO` | Estado confirmado |
| `estado_som`, `estado_modbus` | mesmos valores ou `null` | Estado de cada fonte separada |
| `codigo_falha` | inteiro ou `null` | Só com Modbus |
| `modo` | `AUTO` \| `MANUAL` | |
| `manual_restante_s` | inteiro | Tempo até voltar a AUTO |
| `desumidificador_comandado` | booleano | Comando enviado ao relé, **não** confirmação física |
| `motivo_rele` | `histerese` \| `tempo_minimo` \| `manual` \| `sensor_falha` \| `inicial` | Por que o relé está assim |
| `config_version` | inteiro | Versão da configuração aplicada |
| `fila_flash` | inteiro | Mensagens aguardando reenvio na Flash |

Exemplo real (log do item 2):

```json
{"schema_version":2,"device_id":"sala01-esp32","sala_id":"sala01","boot_id":"b1","seq":19,"uptime_ms":100000,
 "timestamp_utc":"2026-10-27T23:10:08Z","clock_synced":true,"origem_dados":"simulacao","produto":"PRODUTO_TESTE",
 "lote_producao":"LOTE_TESTE_01","lote_capsula":"CAP_TESTE","lote_po":null,"temperatura_c":25,"umidade_pct":53,
 "clima_valido":true,"nivel_ruido":-10.8,"unidade_ruido":"dBFS","ruido_adc_rms":589.5,"fonte_estado":"sintetico",
 "estado_maquina":"OPERANDO","estado_som":"OPERANDO","estado_modbus":null,"codigo_falha":null,"modo":"AUTO",
 "manual_restante_s":0,"desumidificador_comandado":false,"motivo_rele":"histerese","config_version":2,"fila_flash":0}
```

## `eventos`

O campo `tipo` identifica o evento. Além do cabeçalho, cada tipo traz:

| `tipo` | Campos |
| --- | --- |
| `BOOT` | `reset_reason`, `config_version`, `fila_flash`, `modo` |
| `RELE` | `desumidificador_comandado`, `motivo`, `modo`, `umidade_pct` |
| `MODO` | `modo`, `cmd_id`, `manual_restante_s` |
| `MANUAL_EXPIRADO` | `modo` (volta a AUTO) |
| `SENSOR_FALHA`, `SENSOR_OK` | `sensor` (`SHT31`) |
| `ESTADO_MAQUINA` | `fonte_estado`, `de`, `para`, `confirmado_desde_ms`, `codigo_falha` |
| `PARADA_INICIO` | `fonte_estado`, `de`, `para`, `evento_id`, `inicio_uptime_ms`, `inicio_utc`, `codigo_falha` |
| `PARADA_FIM` | os anteriores mais `fim_uptime_ms`, `fim_utc`, `duracao_ms` e `motivo_fim` (`retorno_operacao` ou `fonte_indisponivel`) |
| `CONFIG_APLICADA` | `config_version`, `ur_liga`, `ur_desliga`, `limiar_operando_dbfs`, `limiar_parado_dbfs`, `modbus_habilitado` |
| `CONTEXTO_ALTERADO` | o novo produto e lote, no cabeçalho |

O início da parada é o instante em que o som caiu, não o da confirmação. `evento_id` é único por parada e liga o INÍCIO ao FIM.

## `confirmacoes`

`tipo` (`comando` \| `configuracao` \| `contexto`), `cmd_id`, `aceito`, `motivo`, `modo`, `rele` (`ON`/`OFF`), `manual_restante_s`, `config_version`.

Motivos de aceite: `aplicado`, `aplicada`, `ja_aplicada`, `sem_alteracao`.

Motivos de recusa:
- gerais: `json_invalido`, `tipo_invalido`, `inteiro_invalido`;
- de comando: `cmd_id_ausente_ou_longo`, `duplicado`, `ts_invalido`, `comando_vencido`, `modo_invalido`, `rele_invalido`, `validade_fora_faixa`;
- de configuração: `versao_ausente`, `versao_antiga`, `ur_fora_0_100`, `ur_desliga_deve_ser_menor_que_ur_liga`, `limiar_fora_faixa_dbfs`, `limiar_parado_deve_ser_menor`, `confirmar_*_fora_faixa`, `modbus_*`;
- de contexto: `texto_invalido_1_a_32`.

## `comandos` (Admin → ESP32) — nunca retido

```json
{"cmd_id":"admin-1730150000123","modo":"MANUAL","rele":"ON","validade_s":900,"ts":1793142591}
{"cmd_id":"admin-1730150000456","modo":"AUTO"}
```

| Campo | Regra |
| --- | --- |
| `cmd_id` | Obrigatório, até 39 caracteres, diferente do anterior (o repetido é recusado como `duplicado`) |
| `modo` | `AUTO` ou `MANUAL` |
| `rele` | Só no MANUAL: `"ON"`, `"OFF"` ou booleano |
| `validade_s` | Opcional, padrão 900; entre 1 e `manual_validade_max_s` (padrão 28 800). Ao vencer, o firmware volta a AUTO |
| `ts` | Recomendado: segundos Unix. Com o relógio sincronizado, comando com mais de 120 s de diferença é recusado (`comando_vencido`) |

**Por que não reter:** um MANUAL ON retido seria entregue de novo a cada reconexão e religaria o desumidificador com um comando antigo. O ESP32 sempre inicia em AUTO.

## `configuracao` (Admin → ESP32) — pode ser retido

```json
{"cmd_id":"cfg-5","versao":5,"ur_max":58,"histerese":4,"limiar_db":-22,"banda_db":12}
```

- `versao` é obrigatória: inteiro ≥ 1 e crescente. Igual à aplicada → `ja_aplicada`; menor → `versao_antiga`.
- Campos omitidos mantêm o valor atual. A configuração é validada inteira e aplicada de forma atômica, e o ESP32 publica `CONFIG_APLICADA`.
- **Formato do Admin:** `ur_max` (= liga), `histerese` (desliga = `ur_max − histerese`), `limiar_db` (dBFS para OPERANDO) e `banda_db` (PARADO = `limiar_db − banda_db`).
- **Campos diretos:**
  - `ur_liga`, `ur_desliga`;
  - `limiar_operando_dbfs`, `limiar_parado_dbfs`;
  - `confirmar_operando_ms`, `confirmar_parado_ms` (500 a 600 000);
  - `telemetria_ms` (1 000 a 3 600 000), `tempo_min_rele_ms`;
  - `manual_validade_padrao_s`, `manual_validade_max_s`;
  - `modbus` = `{habilitado, host, porta, unit, reg_status, reg_falha, intervalo_ms}`.
- Valores padrão do firmware (didáticos, não industriais): liga 55 %UR, desliga 50 %UR, OPERANDO ≥ −25 dBFS por 3 s, PARADO ≤ −35 dBFS por 5 s.

## `contexto` (Admin → ESP32) — pode ser retido

```json
{"cmd_id":"ctx-3","produto":"PRODUTO_TESTE","lote_producao":"LOTE_TESTE_01","lote_capsula":"CAP_TESTE"}
```

`produto` e `lote_producao` são obrigatórios: texto de 1 a 32 caracteres, sem espaço no início. `lote_capsula` e `lote_po` são opcionais. O valor fica gravado na NVS e passa a acompanhar toda leitura e todo evento.

## `disponibilidade`

Ao conectar, o firmware publica `{"estado":"online","device_id":"sala01-esp32","boot_id":"b2"}` retido. O Last Will é `{"estado":"offline"}`, também retido e sem `device_id`.

## Regras para quem recebe

1. **Deduplicar** por tópico e `(device_id, boot_id, seq)`. Mensagens da fila da Flash podem chegar repetidas e atrasadas.
2. **Horário:** usar `timestamp_utc` quando `clock_synced = true`; caso contrário, o horário de recebimento.
3. **Paradas:** usar `PARADA_INICIO`/`PARADA_FIM` (com `evento_id`), não inferir pela telemetria. A telemetria sai a cada 5 s e perde paradas curtas.
4. **BOOT:** ao receber, fechar as paradas abertas do dispositivo com `motivo_fim = reinicio_dispositivo`.
5. **Ruído:** exibir e configurar em dBFS, com a legenda "não é dB SPL", até existir calibração.
6. **Falha do sensor:** aceitar `umidade_pct = null` e gravar o restante da leitura.
7. **Produto e lote** em cada leitura (exigência do documento de entregáveis).
8. `config_version` corresponde à versão da tabela `configuracao_alertas`.

## Modbus TCP (CLP)

O firmware tem um cliente FC03 **desligado por padrão**, porque o acesso ao CLP não foi autorizado. Ele lê `reg_status` (1 = operando, 0 = parada) e `reg_falha`. O mapa da outra equipe (HR3 = máquina, HR5 = falha, unit 1, porta 5020 no simulador) é compatível: basta `reg_status = 3` e `reg_falha = 5`. No kit, a leitura Modbus fica no Node-RED (também desligada por padrão) e grava paradas com `fonte_estado = modbus`. Perda de comunicação leva a `DESCONHECIDO`, nunca a PARADO.
