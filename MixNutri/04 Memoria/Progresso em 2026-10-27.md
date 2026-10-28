---
projeto: MixNutri
equipe: 1
tipo: progresso
status: em_andamento
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Progresso em 27/10/2026

## Situação

Foram transcritos os três anexos enviados, incluindo a figura de arquitetura do documento novo. Foi implementada uma primeira versão do item 1 com arquivos de circuito, modelos customizados e script SQL. A validação corrente está em [[Validacao do item 1]]. Nenhum resultado desta etapa é validação industrial ou demonstração integrada com o backend.

| Frente | Avanço comprovável | O que falta |
| --- | --- | --- |
| Documentação | Três transcrições integrais MD; originais preservados; figura extraída e transcrita | Atualizar quando houver novas versões |
| Circuito Wokwi | ESP32, SHT31 parcial, som sintético, relé e LED; diagnóstico compilado/executado | Aceitação dos modelos para a entrega acadêmica |
| Banco | Schema, dados demo, consultas e testes executados em PostgreSQL 18 isolado | Revisão e integração pela equipe 2 |
| Firmware item 2 | Programa diagnóstico e histerese didática para testar circuito | MQTT, Modbus conforme divisão, persistência/fila offline, classificação de estados e firmware completo |
| Backend e dashboard | Contratos/propostas documentados | Não implementados nesta etapa; alinhar equipes 2 e 3 |
| Validação industrial | Nenhuma medição real realizada por esta sessão | Faixas, acústica real, lotes, produção/quebra e semanas de coleta |

## Dependências principais

Confirmar aceitação dos modelos SHT31/som; decidir como o contexto produto/lote chega ao nó/backend; alinhar responsabilidade e mapa Modbus; esclarecer retenção de dados na Flash. Wokwi passou a ser o alvo de implementação do item 1 porque está indicado na fonte nova, sem presumir decisão geral do usuário para todas as etapas.

As primeiras capturas revelaram inversão da polaridade do relé no diagnóstico. O código foi corrigido para o módulo `npn` e o histórico foi separado das evidências finais. Consultar [[Pinagem e componentes do item 1]] antes de trocar o módulo.

## Próximo passo

Revisar [[Entrega do item 1]] com o grupo, confirmar aceitação dos modelos parciais e então avançar ao firmware do item 2. Não marcar MQTT, Modbus, retenção offline ou backend como entregues por existir um diagnóstico local.

## Atualização (segunda sessão)

| Frente | Avanço comprovável | O que falta |
| --- | --- | --- |
| Item 1 v2 | Som com ruído e dBFS; SQL com 4 tabelas e 18 verificações; revalidado no Wokwi e no PostgreSQL | Link do Wokwi na conta do usuário; aceite do grupo |
| Item 2 firmware | Implementado; 15 grupos de testes nativos; 15 verificações no Wokwi com MQTT real (duas falhas encontradas e corrigidas), incluindo queda de rede + reinício sem perda de telemetria | Modbus real; broker da equipe 2; aceite de parâmetros |
| Wokwi CLI | `wokwi.toml`, `platformio.ini` e cenários prontos | Token do usuário e execução |
| Itens 3–5 | Contrato MQTT v2 e SQL v2 prontos para a equipe 2 consumir | Implementação das equipes 2 e 3 |

Ver [[Entrega do item 2]], [[Validacao do item 2]] e [[2026-10-27 - 02 Item 1 v2 e firmware do item 2]].

Links de entrega no Wokwi (públicos, conta do usuário): [item 1](https://wokwi.com/projects/479079864657061889) e [item 2](https://wokwi.com/projects/479080199406642177). Conferidos por SHA-256 e executados depois de salvos.
