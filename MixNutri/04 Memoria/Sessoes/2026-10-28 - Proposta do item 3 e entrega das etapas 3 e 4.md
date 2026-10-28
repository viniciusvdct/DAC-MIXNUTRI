---
projeto: MixNutri
equipe: 1
tipo: sessao
status: em_andamento
criado: 2026-10-28
atualizado: 2026-10-28
tags:
  - mixnutri
  - equipe1
---

# 27–28/10/2026 — proposta do item 3 e entrega das etapas 3 e 4

## Contexto e pedido

Sessão iniciada em 27/10/2026 por outra sessão do Claude Code (não diretamente pelo usuário). A tarefa: montar em `06 Entregas/Item 3 (proposta)` um ambiente Docker Compose mínimo para a equipe 2 avaliar a integração com o firmware da equipe 1, deixando explícito que é proposta e não entrega da equipe 2. Também era pedido para solicitar permissão antes de baixar imagens.

Em 28/10/2026, o usuário encaminhou os arquivos que "a outra equipe enviou": a entrega das etapas 3 e 4, com Compose, Node-RED, Grafana, SQL, contrato e memorial.

## Fontes consultadas

[[Contexto para IA]], [[Decisoes]], [[Pendencias e perguntas]], [[Tarefas da equipe 1]], [[2026-10-27 - 02 Item 1 v2 e firmware do item 2]], a versão 2 em [[Contrato MQTT proposto]], `01_schema.sql` do item 1, `sketch.ino` e `logica.h` do item 2, o log `mqtt-recebido-execucao-final.log` e `mqtt_mini.py`. Também metadados do Docker Hub e do npm (versões e tamanhos), sem baixar imagens, e o código-fonte de `node-red-contrib-postgresql` 0.16.2 no GitHub, só para leitura. Em 28/10, os 16 arquivos da outra equipe.

## Trabalho realizado

- **Proposta do item 3:** `compose.yaml` com as quatro portas em 127.0.0.1.
  - Mosquitto sem acesso anônimo, com ACL.
  - SQL `integracao` com registro bruto, deduplicação, funções de gravação e papéis de privilégio mínimo.
  - Fluxo do Node-RED e painel do Grafana provisionados.
  - Ferramentas: reprodução do log com login (reaproveita `mqtt_mini.py` sem alterá-lo), teste de ACL, cenário sintético de BOOT, testes SQL com ROLLBACK e consultas de evidência.
  - Credenciais de teste geradas direto em `.env.exemplo`, sem aparecer no chat.
  - Ver o [README do item 3](../../06%20Entregas/Item%203%20%28proposta%29/README.md).
- **Entrega da outra equipe:** os arquivos já estavam em `90 Fontes`, copiados em 28/10 às 09:30 e idênticos aos anexos (comparação byte a byte). O `_env`, que contém senhas, não foi copiado. Foi feita uma análise estática de compatibilidade: [[Compatibilidade com a entrega das etapas 3 e 4]].

## Decisões

Nenhuma decisão do usuário nesta sessão. Escolhas de implementação da IA, ainda como propostas:
- versões fixas das imagens;
- configuração v1 semeada igual a `configPadrao()`;
- alerta UR_ALTA com persistência de 60 s;
- fechamento no BOOT usando o horário do BOOT;
- tempos de confirmação copiados da versão anterior quando chega `CONFIG_APLICADA`.

Recomendação registrada (não aprovada): caminho C da nota de compatibilidade, com contrato único negociado e um adaptador temporário no Node-RED da outra equipe.

## Testes e evidências

Executado: `docker compose config --quiet`, validação dos JSON (`flows.json`, `flows_cred.json`, painel), `py_compile` das ferramentas e `sh -n` dos scripts. Tudo sem erro.

**Não executado:** subir os contêineres, reproduzir o log, os testes SQL, o teste de ACL, o painel no Grafana e a pilha da outra equipe. Motivo: o download das imagens (~520 MB para a proposta; outras imagens para a pilha deles) ainda não foi autorizado. A análise da entrega da outra equipe é só leitura de código.

## Pendências e próximo passo

- Decisão do usuário/grupo: qual contrato prevalece e o destino da proposta do item 3 (referência v2 ou adaptador).
- Permissão para baixar imagens, conforme o caminho escolhido.
- Levar à outra equipe as perguntas listadas na nota de compatibilidade, principalmente o CHECK de `origem`, o comando retido e a unidade do ruído.
- Ainda não foi criada a nota `Entrega do item 3 (proposta).md`. Será escrita quando houver execução e evidência, ou se o usuário mantiver a proposta mesmo assim.
