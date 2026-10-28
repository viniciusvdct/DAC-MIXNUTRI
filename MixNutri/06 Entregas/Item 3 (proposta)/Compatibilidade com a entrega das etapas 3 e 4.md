---
projeto: MixNutri
equipe: 1
tipo: analise
status: em_revisao
criado: 2026-10-28
atualizado: 2026-10-28
tags:
  - mixnutri
  - equipe1
  - integracao
---

# Compatibilidade com a entrega das etapas 3 e 4

## Origem e alcance

Em 28/10/2026, o usuário encaminhou os arquivos que "a outra equipe enviou" (WhatsApp). O conteúdo cobre as **etapas 3 e 4**: Docker Compose com Mosquitto, PostgreSQL, Node-RED (MQTT, Modbus, S7 opcional, Admin e alertas), Grafana e um simulador Modbus. No plano MVP, essas etapas cabem às equipes 2 e 3. Não está confirmado quem assinou a entrega.

Os 16 arquivos estão em `90 Fontes/Entrega recebida - etapas 3 e 4` (movidos em 28/10/2026 para uma pasta própria), idênticos byte a byte aos anexos ([README](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/README.md), [contrato-integracao](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/contrato-integracao.md), [memorial](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/memorial-etapas-3-4.md), [flows.json](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/flows.json), [001_schema.sql](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/001_schema.sql), [compose.yaml](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/compose.yaml), [sala01.json](../../90%20Fontes/Entrega%20recebida%20-%20etapas%203%20e%204/sala01.json) etc.). O `_env`, que contém senhas, não foi copiado para o cofre.

**Esta nota é uma análise estática feita pela equipe 1 (leitura do código).** O ambiente deles não foi executado e nenhuma mensagem foi enviada. Os números sobre o log vêm de [mqtt-recebido-execucao-final.log](../Item%202/evidencias/mqtt-recebido-execucao-final.log) combinados com a lógica lida no `flows.json`; não são resultado de teste.

## Mapa de tópicos

| Função | Contrato v2 da equipe 1 ([[Contrato MQTT proposto]]) | Contrato da outra equipe |
| --- | --- | --- |
| Prefixo | `mixnutri/sala01/` | `iotmixnutri/sala01/` |
| Telemetria | `telemetria`, QoS 0 (PubSubClient) | `telemetria`, pede QoS 1 |
| Eventos (BOOT, PARADA_INICIO/FIM, RELE, SENSOR_FALHA…) | `eventos` | não existe |
| Confirmações de comando/configuração | `confirmacoes` | não existe |
| Disponibilidade e Last Will | `disponibilidade` | não existe |
| Comando | `comandos`, **sem retain**, `cmd_id`, `modo`, `rele`, `validade_s`, `ts` | `comando` (singular), **retido**, `{"modo","desumidificador"}` |
| Configuração | `configuracao`, `versao` obrigatória, `ur_max`/`histerese`/`limiar_db`/`banda_db` | `configuracao` retido, `umidade_max_pct`/`histerese_pct`/`ruido_operacional_db`/`parada_segundos` |
| Produto e lote | `contexto` e campos em toda leitura | não existe |

## Mapa de campos da telemetria

| Contrato v2 | Outra equipe | Observação |
| --- | --- | --- |
| `timestamp_utc` + `clock_synced` | `timestamp` | O nome difere, então o fluxo deles grava sempre o horário de recebimento |
| `umidade_pct` (`null` se o sensor falha) | `umidade_pct` obrigatório 0–100 | Leitura com falha é descartada inteira |
| `temperatura_c` | `temperatura_c` | Compatível |
| `nivel_ruido` + `unidade_ruido: "dBFS"` (≤ 0) | `ruido_db` (exemplo 66, limiar 60) | Unidades diferentes; o lado deles supõe dB SPL |
| `desumidificador_comandado` | `desumidificador` | O nome difere e o valor fica nulo no banco deles |
| `estado_maquina`, `modo`, `codigo_falha` | iguais | Compatíveis |
| `fonte_estado` + `origem_dados` | `origem` (`esp32`, `modbus`, `s7comm`, `acustico`) | Significados diferentes |
| `device_id`, `boot_id`, `seq`, `uptime_ms`, `produto`, `lote_*`, `clima_valido`, `motivo_rele`, `fila_flash`… | — | Só ficam em `payload_original` (JSONB) |

## Problemas que impedem ou distorcem a integração

1. **Prefixo diferente.** Com o firmware atual (`TOPICO_BASE = "mixnutri/sala01"`), o Node-RED deles não recebe nada.
2. **Paradas do ESP32 violam uma restrição do próprio schema deles.** O fluxo usa `origem = 'esp32'` como padrão. Porém o CHECK de `paradas_maquina_sala01.origem` só aceita `modbus`, `s7comm`, `acustico`, `manual` e `simulador`. Uma telemetria do ESP32 com `PARADO` faria o INSERT falhar. Como o estado `running` só muda depois do INSERT, o erro se repetiria a cada leitura parada. O contrato deles cita `esp32` como origem válida, o que torna o schema inconsistente com o próprio contrato.
3. **Paradas derivadas da telemetria perdem eventos curtos.** O fluxo deles não assina `eventos`; ele abre e fecha paradas comparando o `estado_maquina` de leituras feitas a cada 5 s, com o horário de recebimento e o estado guardado só na memória do Node-RED. No log do item 2, o firmware publicou `PARADA_INICIO`/`PARADA_FIM` de uma parada de 5,6 s. Nenhuma das 59 telemetrias mostra `PARADO` (3 `DESCONHECIDO`, 56 `OPERANDO`). Pela lógica deles, essa parada não seria registrada. Também não há tratamento de BOOT nem de reenvio da fila.
4. **Ruído com unidade presumida.** O painel diz "Nível de ruído (dB)" com unidade `decibel`, e o limiar padrão é 60 dB. O firmware envia dBFS (≤ 0, ex.: −10,8), relativo ao ADC e sem calibração; não é dB SPL. Mesmo renomeando o campo, a classificação acústica deles (`ruido_db < 60` → PARADO) marcaria parada o tempo todo.
5. **Comando retido sem identificador nem validade.** Publicar `{"modo":"MANUAL","desumidificador":true}` com retain faz o broker reenviar um MANUAL ON antigo a cada reconexão ou reinício do ESP32, e esse MANUAL não expira. O contrato v2 proíbe retain em `comandos` justamente por isso. Além disso, o firmware recusaria o comando por faltar `cmd_id` e `rele`.
6. **Configuração sem versão.** O firmware exige `versao` crescente e recusaria o JSON deles (`versao_ausente`). Há também a diferença de nomes e o tempo de parada em segundos (`parada_segundos`, padrão 15 s), enquanto o firmware usa `confirmar_parado_ms` (padrão didático de 5 s).
7. **Falha de sensor descarta a leitura toda.** Com `umidade_pct` nulo, a validação lança erro e perde junto o estado da máquina e o do relé. No log, 1 das 59 leituras está nessa situação.
8. **Sem produto e lote no banco.** A fonte de 27/10 exige produto e lote em cada leitura (ver [[Atualizacao dos entregaveis em 2026-10-27]]). O schema deles não tem essas colunas.
9. **Sem deduplicação nem horário do dispositivo.** Não há chave como `(device_id, boot_id, seq)`. As mensagens reenviadas da fila na Flash entrariam com o horário de chegada, e um reenvio duplicaria linhas.
10. **Duas fontes misturadas na mesma série.** O simulador Modbus grava UR, temperatura e ruído a cada 2 s com `origem = 'modbus'`, na mesma tabela da telemetria do ESP32. As consultas do Grafana não filtram por origem, então as curvas misturariam as duas fontes.

## O que já é compatível ou resolve pendências

- `umidade_pct`, `temperatura_c`, `estado_maquina` (OPERANDO/PARADO/DESCONHECIDO), `modo` (AUTO/MANUAL) e `codigo_falha` têm o mesmo nome e o mesmo domínio.
- A semântica da histerese parece igual: UR máxima = liga e máxima − histerese = desliga. Confirmar com a outra equipe.
- **Modbus (P04):** no desenho deles, o Node-RED é o cliente Modbus FC03. O registrador 3 traz a máquina (1 operando / 0 parada) e o 5 traz o código de falha, com a mesma semântica do firmware. Como o cliente Modbus do firmware vem desligado por padrão, os dois desenhos convivem. Se o ESP32 também for ler, basta configurar `reg_status = 3` e `reg_falha = 5`.
- Grafana com usuário somente leitura e serviços em 127.0.0.1. Eles próprios documentam que o broker anônimo e o Admin sem autenticação servem apenas para bancada.
- O firmware aceita broker anônimo (`MQTT_USUARIO`/`MQTT_SENHA` nulos), então a autenticação não é obstáculo.

Em comum aos dois lados: o Wokwi web só alcança um broker local com o gateway privado (P11). O README deles trata apenas do ESP32 físico na mesma rede.

## Caminhos possíveis (propostas, sem decisão)

| Caminho | O que muda | Efeito |
| --- | --- | --- |
| A. Firmware adota o contrato deles | Prefixo, nomes de campos, formatos de comando e configuração | Perde a segurança do comando (validade, sem retain), produto/lote, eventos de parada, deduplicação e a unidade explícita do ruído |
| B. A outra equipe adota o contrato v2 | Fluxo, schema e painel deles | Maior esforço para eles; o schema v2 do item 1 já existe e foi testado |
| C. Contrato único negociado, com adaptador temporário | Acordo sobre os itens 2 a 9. Enquanto isso, uma aba de tradução no Node-RED deles assina `mixnutri/sala01/#` e converte para o formato interno deles; no sentido contrário, traduz o Admin para `comandos`/`configuracao` v2 | Nenhum firmware muda já; o painel dos dois lados passa a mostrar a mesma coisa |

**Proposta da equipe 1:** caminho C. Os pontos mínimos do acordo seriam:
- corrigir o CHECK de `origem`;
- usar os eventos de parada do firmware;
- deixar comandos sem retain, com `cmd_id` e validade;
- incluir `versao` na configuração;
- declarar a unidade do ruído (dBFS) no campo, no limiar e na legenda;
- aceitar UR nula com indicador de qualidade;
- gravar produto e lote;
- deduplicar por dispositivo, boot e sequência;
- filtrar a origem nos painéis.

## Relação com a proposta do item 3

A pasta [Item 3 (proposta)](README.md) foi montada antes desta entrega e segue o contrato v2. Com a entrega real em mãos, não convém manter uma pilha concorrente. Ela pode servir de referência executável do contrato v2 ou ser reaproveitada como o adaptador do caminho C. Essa escolha é do usuário e do grupo. Nada dela foi executado: o download das imagens ainda depende de permissão. A pilha deles usa outras imagens (download comprimido para arm64, segundo o Docker Hub em 28/10): `eclipse-mosquitto:2.0.20` (~5 MB), `postgres:16.6-alpine` (~105 MB), `nodered/node-red:4.0.9` (~193 MB), `grafana/grafana:11.4.0` (~125 MB) e `python:3.12-alpine` (~19 MB), em torno de 450 MB. Somam-se os pacotes npm instalados no build: FlowFuse Dashboard, Modbus, S7, `pg` e `nodemailer`.

## Perguntas para levar à outra equipe

1. Quem mantém o contrato MQTT e o schema? (o item 1 previa o script SQL da equipe 1)
2. Aceitam o prefixo `mixnutri/sala01/` ou preferem que o firmware mude para `iotmixnutri`?
3. Aceitam comandos sem retain, com `cmd_id` e validade, e configuração com `versao`?
4. Usam os eventos `PARADA_INICIO/FIM` do firmware, ou mantêm a parada inferida pela telemetria? Se mantiverem, como corrigem o CHECK de `origem`?
5. Como o painel vai mostrar o ruído: dBFS com a legenda "não é dB SPL", ou existe calibração para dB SPL?
6. Onde gravam produto e lote? Querem o tópico `contexto`?
7. Qual broker será usado com o Wokwi (gateway privado, broker público só para demonstração ou ESP32 físico)?
