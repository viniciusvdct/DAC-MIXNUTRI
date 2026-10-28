---
projeto: MixNutri
equipe: 1
tipo: registro
status: documentado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Decisões

## Confirmado pelo usuário

| ID | Data | Decisão ou fato | Origem |
| --- | --- | --- | --- |
| U01 | 26/10/2026 | É da Engenharia de Controle e Automação e da equipe 1 | Mensagem do usuário |
| U02 | 26/10/2026 | Grupo responsável por circuito/hardware e firmware | Mensagem do usuário |
| U03 | 26/10/2026 | Pretende simular toda a sua parte | Mensagem do usuário |
| U04 | 26/10/2026 | Ainda não escolheu simulador | Resposta à pergunta nesta sessão |
| U05 | 26/10/2026 | Quer base Obsidian para consulta da IA e registro de sessões | Pedido inicial |
| U06 | 26/10/2026 | Solicitou a elaboração de um plano para o projeto | Pedido posterior: “Consegue montar um plano” |

## Organização realizada

A01 — Em 26/10/2026, a IA organizou `DAC/MixNutri` dentro do cofre UCDB existente, preservando documentos e criando notas em Markdown. Não criou configuração de cofre aninhado nem alterou plugins. Trata-se de escolha de organização executada, não de escolha técnica do protótipo.

A02 — Em 26/10/2026, foi elaborado [[Plano de execucao da equipe 1]], com oito etapas e estimativa inicial de 23 a 36 horas para o recorte descrito. O plano foi salvo e vinculado à base. Não houve aprovação presumida de ferramentas, parâmetros, divisão de responsabilidades ou datas.

## Propostas ainda sem aprovação

Wokwi como candidato; DHT22 como alternativa de simulação; entrada sintética de nível de som; limiares, tempos e estados de firmware; tópicos e schema MQTT; políticas de falha e persistência. Nenhuma dessas propostas deve ser descrita como decisão do usuário.

Para novas decisões, usar [[Modelo de decisao]], registrar motivação, responsável, fonte e impacto nos requisitos/testes. Não apagar decisões anteriores ao substituir uma proposta.

## Atualização em 27/10/2026

U07 — O usuário pediu ajuda para entregar o item 1, transcrever todos os arquivos enviados para MD e registrar o progresso.

A03 — Para construir o item 1 indicado no novo documento, foi usado Wokwi como alvo de implementação, com modelo parcial SHT31 I²C e sinal sonoro sintético, diagnóstico local e SQL. É uma escolha de implementação da IA dentro do pedido, não uma declaração de aprovação acadêmica dos modelos nem uma decisão do usuário sobre componentes físicos.

A04 — O teste visual mostrou módulo relé `npn` ativo em HIGH; o código foi corrigido. O histórico de execução anterior à correção foi preservado separadamente. Ver [[Validacao do item 1]].

Continuam pendentes: aceitação dos modelos, microfone real, calibração, divisão Modbus, regras de comando remoto, fila offline e integração. O SQL é proposta implementada/testada em ambiente isolado, ainda sem acordo de adoção com a equipe 2.

## Apresentação do repositório em 27/10/2026

U08 — O usuário pediu a criação de About e README, com foco na equipe 1 e resumo da comunicação com as outras equipes; confirmou https://github.com/viniciusvdct/DAC-MIXNUTRI como destino.

A05 — README e About atualizados nesse repositório, preservando a distinção entre circuito de diagnóstico testado, firmware em desenvolvimento e integração a validar. Registro e cópias em [[Documentacao do repositorio]]. Nenhum código, anexo original ou contato foi enviado.

## Atualização em 27/10/2026 (segunda sessão)

U08 — O usuário pediu para entregar hoje o item 1 e, se possível, os demais; perguntou sobre integração com o Wokwi (ex.: `wokwi-cli`).

U09 — O usuário autorizou publicar telemetria **sintética** no broker público `broker.hivemq.com`, tópico `mixnutri/sala01/*`, para testar MQTT, comandos e reenvio da fila. A autorização vale para esse teste; não aprova o broker público para o sistema.

A05 — Implementação da IA no item 1 v2: ruído de fundo no chip de som, dBFS no diagnóstico e no SQL, tabela `alertas_emitidos` e canais de alerta na configuração. Proposta para aceite do grupo e da equipe 2.

A06 — Implementação da IA no item 2: firmware com os parâmetros listados em [[Entrega do item 2]]. Valores didáticos, não aprovados: −25/−35 dBFS, 3 s/5 s, tempo mínimo de 10 s, MANUAL de 15 min (máx. 8 h), boot em AUTO, Modbus desligado por padrão e com prioridade quando habilitado.

A07 — Wokwi CLI recomendado para regressão automática, e Wokwi web para a entrega. Arquivos preparados e não executados. Ver [[Wokwi CLI e VS Code]].

U10 — Em 27/10/2026 o usuário fez login no Wokwi pelo navegador do app e pediu para salvar os projetos e receber os links. O plano grátis só permite projeto **público**; o usuário autorizou explicitamente salvar assim. Item 1: https://wokwi.com/projects/479079864657061889. Item 2: https://wokwi.com/projects/479080199406642177.
