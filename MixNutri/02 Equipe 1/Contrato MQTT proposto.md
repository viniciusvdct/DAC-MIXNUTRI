---
projeto: MixNutri
equipe: 1
tipo: proposta
status: proposto
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Contrato MQTT proposto

**Rascunho de integração a combinar com equipes 2 e 3.** Tópicos, nomes, QoS e bibliotecas não são definidos pelos documentos. O exemplo usa apenas dados sintéticos.

| Tópico proposto | Origem → destino | Conteúdo |
| --- | --- | --- |
| mixnutri/sala01/telemetria | ESP32 → backend | Clima, nível e estado |
| mixnutri/sala01/eventos | ESP32 → backend | Transições e falhas |
| mixnutri/sala01/comandos | Admin/backend → ESP32 | AUTO/MANUAL e intenção de saída |
| mixnutri/sala01/configuracao | Admin/backend → ESP32 | Limiares e tempos |
| mixnutri/sala01/confirmacoes | ESP32 → backend | Aceitação/rejeição e configuração aplicada |
| mixnutri/sala01/disponibilidade | ESP32/broker → consumidores | Online/offline e Last Will a definir |

## Exemplo de telemetria

```json
{
  "schema_version": 1,
  "device_id": "sala01-esp32",
  "boot_id": "demo-001",
  "seq": 42,
  "uptime_ms": 210000,
  "timestamp_utc": null,
  "clock_synced": false,
  "origem_dados": "simulacao",
  "temperatura_c": 25.0,
  "umidade_pct": 58.0,
  "clima_valido": true,
  "nivel_ruido": 0.75,
  "unidade_ruido": "normalizado_0_1",
  "fonte_estado": "sintetico",
  "estado_maquina": "OPERANDO",
  "modo": "AUTO",
  "desumidificador_comandado": true,
  "config_version": 1
}
```

`desumidificador_comandado` é o comando lógico; não é confirmação física. `timestamp_utc` só deve conter horário real sincronizado; antes disso, o backend registra o horário de recebimento e conserva o uptime. Medições inválidas usam `null` e um indicador de qualidade, nunca o último valor como se fosse novo.

## Regras propostas

- Definir unidades explicitamente. O dashboard só pode exibir dB SPL se a origem realmente suportar isso.
- Identificar mensagens por dispositivo, reinício e sequência para deduplicação.
- Comandos devem ter identificador e validade. Não reexecutar um MANUAL ON antigo ao reconectar. A regra de TTL depende de relógio válido ou de expiração local bem definida.
- Aplicar configuração válida de forma atômica e confirmar versão aplicada.
- Política de retained, QoS, confirmação, Last Will e reconexão precisa ser combinada e testada com a biblioteca escolhida.
- Persistir parâmetros no nó não substitui o banco histórico da equipe 2.

## Integração de rede

O gateway público do Wokwi não acessa diretamente a rede local. Para broker local, avaliar gateway privado e requisitos de acesso; `host.wokwi.internal` é o endereço de host documentado nesse caminho. [Rede do ESP32 no Wokwi](https://docs.wokwi.com/guides/esp32-wifi).

Antes de implementar, combinar roteamento, autenticação, TLS quando aplicável e dados usados na demonstração. Esta base não contém senhas nem endpoint inventado.

## Complemento de produto e lote em 27/10/2026

O documento novo exige produto e lote em cada leitura (bloco 11 de [[Transcricao integral dos entregaveis]]). Incluir no acordo de mensagens `produto`, `lote_producao`, `lote_capsula` e `lote_po`, com os dois últimos opcionais quando desconhecidos. Não inventar lote real. Definir se o contexto chega ao nó ou se o backend o associa com vigência temporal auditável.

O exemplo anterior é um rascunho de versão 1 e ainda não cobre esse complemento. O diagnóstico do item 1 imprime somente serial; não publica esse JSON nem grava no banco. O script demonstrativo SQL usa valores normalizados e o diagnóstico imprime ADC RMS; não assumir conversão direta nem integração existente. Ver [[Modelo de dados do item 1]].

## Versão 2 implementada no firmware do item 2 (27/10/2026)

O firmware de [[Entrega do item 2]] publica e assina os tópicos abaixo, base `mixnutri/sala01`. Continua sendo **proposta**: precisa do aceite das equipes 2 e 3. Mudanças em relação ao rascunho v1: o ruído passou de `normalizado_0_1` para **dBFS**; entraram produto/lote, `estado_som`, `estado_modbus`, `motivo_rele`, `fila_flash` e o tópico `contexto`. Os nomes batem com as colunas de `telemetria_sala01` (SQL v2 do item 1).

| Tópico | Sentido | Retain | Observação |
| --- | --- | --- | --- |
| `telemetria` | ESP32 → backend | não | A cada `telemetria_ms` (5 s) |
| `eventos` | ESP32 → backend | não | BOOT, RELE, MODO, MANUAL_EXPIRADO, SENSOR_FALHA/OK, ESTADO_MAQUINA, PARADA_INICIO/FIM, CONFIG_APLICADA, CONTEXTO_ALTERADO |
| `confirmacoes` | ESP32 → backend | não | `tipo` (comando/configuracao/contexto), `cmd_id`, `aceito`, `motivo` |
| `disponibilidade` | ESP32/broker | sim | `{"estado":"online",...}` e Last Will `{"estado":"offline"}` |
| `comandos` | Admin → ESP32 | **proibido** | MANUAL exige `rele` (`"ON"`/`"OFF"` ou booleano); `validade_s` opcional (padrão 900, máx. 28 800); `ts` em segundos Unix é recomendado |
| `configuracao` | Admin → ESP32 | permitido | `versao` crescente e obrigatória; campos parciais aplicados sobre a configuração atual |
| `contexto` | Admin/backend → ESP32 | permitido | `produto` e `lote_producao` obrigatórios (1–32 caracteres); `lote_capsula` e `lote_po` opcionais |

Exemplo real de telemetria recebida do Wokwi (dados sintéticos):

```json
{"schema_version":2,"device_id":"sala01-esp32","sala_id":"sala01","boot_id":"b1","seq":19,
 "uptime_ms":100000,"timestamp_utc":"2026-10-27T23:10:08Z","clock_synced":true,"origem_dados":"simulacao",
 "produto":"PRODUTO_TESTE","lote_producao":"LOTE_TESTE_01","lote_capsula":"CAP_TESTE","lote_po":null,
 "temperatura_c":25,"umidade_pct":53,"clima_valido":true,"nivel_ruido":-10.8,"unidade_ruido":"dBFS",
 "ruido_adc_rms":589.5,"fonte_estado":"sintetico","estado_maquina":"OPERANDO","estado_som":"OPERANDO",
 "estado_modbus":null,"codigo_falha":null,"modo":"AUTO","manual_restante_s":0,
 "desumidificador_comandado":false,"motivo_rele":"histerese","config_version":2,"fila_flash":0}
```

Exemplo real de fim de parada (omitidos `clock_synced`, `origem_dados`, `lote_capsula` e `lote_po`, presentes na mensagem original):

```json
{"schema_version":2,"device_id":"sala01-esp32","sala_id":"sala01","boot_id":"b1","seq":21,"uptime_ms":139849,
 "timestamp_utc":"2026-10-27T23:10:48Z","tipo":"PARADA_FIM","produto":"PRODUTO_TESTE","lote_producao":"LOTE_TESTE_01",
 "fonte_estado":"sintetico","de":"PARADO","para":"OPERANDO","evento_id":"sala01-esp32-b1-sintetico-1",
 "inicio_uptime_ms":130888,"inicio_utc":"2026-10-27T23:10:40Z","fim_uptime_ms":136502,"fim_utc":"2026-10-27T23:10:45Z",
 "duracao_ms":5614,"motivo_fim":"retorno_operacao","codigo_falha":null}
```

Pontos para a equipe 2: deduplicar por `(device_id, boot_id, seq)`, já garantido pela chave única do SQL; mensagens reenviadas da Flash chegam atrasadas, então usar `timestamp_utc` quando `clock_synced` e, caso contrário, o horário de recebimento; ao receber `BOOT`, fechar paradas abertas do dispositivo com `motivo_fim = reinicio_dispositivo`; `configuracao_id` do SQL vem do mapeamento de `config_version`. O PubSubClient publica com QoS 0.
