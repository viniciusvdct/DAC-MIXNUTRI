---
projeto: MixNutri
equipe: 1
tipo: sessao
status: concluido
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# 27/10/2026 (segunda sessão) — item 1 v2 e firmware do item 2

## Contexto e pedido

O usuário reenviou `Desafio10_MixNutri_Entregáveis.docx` (idêntico ao original do cofre, conferido byte a byte) e pediu para entender o projeto e entregar **hoje** o item 1, e se possível os demais. Reafirmou que é da Engenharia de Controle e Automação, equipe 1. Perguntou se há forma melhor de integrar com o Wokwi, por exemplo o `wokwi-cli`, e convidou a revisar e melhorar a estrutura montada antes com outra IA.

## Fontes consultadas

Notas de contexto, decisões, pendências, tarefas, progresso, sessão anterior, notas do item 1, contrato MQTT, firmware/estados, parâmetros, detecção de parada, controle de umidade e [[Transcricao integral dos entregaveis]] (blocos 25–29). Documentação oficial do Wokwi: README do wokwi-cli, uso do CLI, cenários, configuração do projeto, Wi-Fi do ESP32, limites do CI e hardware suportado.

## Trabalho realizado

**Item 1 v2:** chip `som` com ruído de fundo e opção de desconectar; diagnóstico com dBFS; SQL com `alertas_emitidos`, canais/persistência de alerta na configuração, `histerese_pp`, `motivo_fim` e dBFS coerente; dados demo em dBFS; testes SQL ampliados para 18 verificações; teste C do chip atualizado; `wokwi.toml`, `platformio.ini` e cenário para o Wokwi CLI.

**Item 2:** firmware completo em `06 Entregas/Item 2/firmware`: histerese com tempo mínimo, classificação acústica em dBFS com eventos de parada, MANUAL/AUTO, configuração e contexto via MQTT, cliente Modbus TCP (desligado por padrão), fila na Flash (LittleFS) com reenvio, persistência na NVS e duas tarefas FreeRTOS. Lógica pura em `logica.h` com 15 grupos de testes nativos. Também `partitions.csv`, arquivos para o Wokwi CLI e o cliente `mqtt_mini.py`.

Notas: [[Entrega do item 2]], [[Validacao do item 2]], [[Wokwi CLI e VS Code]], versão 2 em [[Contrato MQTT proposto]] e atualizações das notas do item 1.

## Decisões

- O usuário autorizou, nesta sessão, publicar telemetria sintética no broker público `broker.hivemq.com` para testar o MQTT. Os comandos dos testes foram publicados sem retain.
- Escolhas de implementação da IA, ainda **propostas**: dBFS como unidade de ruído; limiares −25/−35 dBFS; tempo mínimo de 10 s; validade MANUAL de 15 min (máx. 8 h); boot sempre em AUTO; fila de 192 × 1 KB; Modbus desligado por padrão; prioridade Modbus > som quando habilitado; sentinela `NAO_INFORMADO` para produto/lote; tabela `alertas_emitidos` sem destinatários.
- Projetos salvos como públicos no Wokwi, com autorização explícita do usuário (U10 em [[Decisoes]]).

## Testes e evidências

Executado e com evidência: SQL v2 em PostgreSQL 18.4 temporário (socket local, sem TCP), testes C dos modelos, testes nativos do firmware com ASan/UBSan, item 1 v2 no Wokwi web e item 2 no Wokwi web com MQTT real. Arquivos do Wokwi conferidos por SHA-256 contra os locais antes de cada execução. Detalhes em [[Validacao do item 1]] e [[Validacao do item 2]].

Falhas encontradas e corrigidas na sessão: (1) o Wokwi web não tem partição `spiffs` → `partitions.csv`; (2) MANUAL expirava na hora por subtração `uint32_t` com "agora" anterior ao comando → diferença com sinal e teste de regressão. Logs anteriores à correção estão em `Item 2/evidencias/historico-antes-correcao`.

Não executado: Wokwi CLI e VS Code (sem token e sem toolchain), PlatformIO, Modbus contra servidor real ou simulado, broker da equipe 2, backend, dashboard, hardware físico.

## Pendências e próximo passo

Links de entrega: o usuário fez login no Wokwi e autorizou salvar os projetos como públicos (o plano grátis não tem "Unlisted"). Item 1: https://wokwi.com/projects/479079864657061889; item 2: https://wokwi.com/projects/479080199406642177. Os arquivos foram conferidos por SHA-256 depois de salvos e os dois projetos rodaram. Falta revisar com o grupo e a orientação. Depois: aceite do contrato MQTT v2 e do SQL v2 pela equipe 2; definir o broker da integração (o gateway privado é pago no Wokwi web); calibrar limiares com áudio real; definir a política industrial de falha e de tempo mínimo; mapa real de registradores do CLP, se autorizado. Itens 3 a 5 dependem das equipes 2 e 3.

## Notas alteradas

[[Entrega do item 1]], [[Validacao do item 1]], [[Modelo de dados do item 1]], [[Pinagem e componentes do item 1]], [[Entrega do item 2]], [[Validacao do item 2]], [[Wokwi CLI e VS Code]], [[Contrato MQTT proposto]], [[Decisoes]], [[Pendencias e perguntas]], [[Tarefas da equipe 1]], [[Progresso em 2026-10-27]], [[Contexto para IA]], [[Registro de evidencias]], [[Registro de sessoes]] e `AGENTS.md`.
