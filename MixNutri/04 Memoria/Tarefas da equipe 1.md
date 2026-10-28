---
projeto: MixNutri
equipe: 1
tipo: tarefas
status: em_andamento
criado: 2026-10-26
atualizado: 2026-10-28
tags:
  - mixnutri
  - equipe1
---

# Tarefas da equipe 1

Data de referência: 26/10/2026. As tarefas técnicas são propostas. O [[Plano de execucao da equipe 1]] acrescenta estimativas de esforço, sem estabelecer novos prazos ou presumir disponibilidade do grupo.

## Concluído nesta sessão

- [x] Ler os dois documentos fornecidos.
- [x] Preservar originais e extrações pesquisáveis.
- [x] Organizar notas, contexto da IA e modelos de sessão.
- [x] Distinguir requisitos, propostas, dúvidas e limites da simulação.
- [x] Elaborar plano de execução com etapas, entregas, esforço estimado e dependências, conforme pedido posterior do usuário.

## Próxima etapa de definição

- [ ] Escolher simulador e confirmar acesso necessário para MQTT local.
- [ ] Fixar placa ESP32 e sensor de clima da demonstração.
- [ ] Validar substituição de SHT31 por DHT22, se usada.
- [ ] Definir se a primeira demonstração sonora será sintética.
- [ ] Resolver implementação Modbus entre equipes 1 e 2.
- [ ] Acordar parâmetros e política de falhas para a bancada.

## Implementação posterior

- [ ] Desenhar e registrar circuito/pinagem.
- [ ] Criar firmware mínimo de leitura, validação e histerese.
- [ ] Criar detecção de estados e eventos de parada.
- [ ] Adicionar AUTO/MANUAL e configuração persistente.
- [ ] Adicionar MQTT e reconexão sem bloquear controle.
- [ ] Fechar contrato de mensagens com equipe 2.
- [ ] Executar e documentar [[Matriz de testes]].
- [ ] Integrar dashboard com equipe 3.
- [ ] Preparar contribuição ao memorial e à demonstração.

## Dados externos pendentes

- [ ] Faixas e limites reais; especificação do desumidificador.
- [ ] Dados de quebra, lotes, cadência, turnos e climatização.
- [ ] Plano de coleta por semanas para investigar a causa.

Detalhes em [[Pendencias e perguntas]]. Nenhum item concluído deve ser marcado apenas por aparecer como plano em uma nota.

## Progresso do item 1 em 27/10/2026

O checklist anterior é histórico do planejamento. O estado mais recente é o seguinte, com evidências em [[Validacao do item 1]]:

- [x] Transcrever integralmente os três anexos para MD, incluindo a arquitetura em imagem/texto.
- [x] Identificar e mapear os cinco entregáveis do documento novo.
- [x] Preparar diagrama, pinagem, modelos SHT31/som e programa de diagnóstico local.
- [x] Compilar e executar o diagnóstico no Wokwi.
- [x] Implementar SQL com telemetria, paradas, configuração e contexto de produto/lote.
- [x] Executar schema, exemplos, consultas e validações em PostgreSQL isolado.
- [x] Preparar instruções de reprodução do item 1.
- [ ] Confirmar aceitação acadêmica dos modelos customizados/parciais.
- [ ] Revisar com equipe 2 o SQL e o mapeamento das mensagens.
- [ ] Implementar o firmware completo do item 2, inclusive a definição de retenção offline.
- [ ] Integrar MQTT/backend/dashboard e executar o cenário completo.

Consultar [[Progresso em 2026-10-27]] e [[Entrega do item 1]]. Nenhum teste do diagnóstico local deve aprovar automaticamente o firmware final.

## Progresso em 27/10/2026 (segunda sessão)

- [x] Item 1 v2: som com ruído e dBFS, SQL com 4 tabelas, revalidado no Wokwi e no PostgreSQL.
- [x] Firmware do item 2 implementado e testado no Wokwi web com MQTT real (ver [[Validacao do item 2]]).
- [x] Arquivos para Wokwi CLI / VS Code preparados ([[Wokwi CLI e VS Code]]).
- [x] Salvar os projetos no Wokwi com a conta do usuário (públicos): [item 1](https://wokwi.com/projects/479079864657061889), [item 2](https://wokwi.com/projects/479080199406642177).
- [ ] Rodar os cenários com o Wokwi CLI (precisa de token e PlatformIO).
- [ ] Revisar contrato MQTT v2 e SQL v2 com a equipe 2; definir o broker.
- [ ] Testar Modbus contra um servidor simulado (ex.: Node-RED da equipe 2).
- [ ] Caracterizar áudio real e limiares, se houver microfone físico.

## Integração em 28/10/2026

- [x] Preparar a proposta Docker do item 3 (arquivos e sintaxe conferidos; **não executada**).
- [x] Analisar a entrega das etapas 3 e 4 da outra equipe ([[Compatibilidade com a entrega das etapas 3 e 4]]).
- [ ] Levar à outra equipe as perguntas da nota de compatibilidade e acordar um contrato único.
- [ ] Decidir o destino da proposta do item 3 e, se for o caso, autorizar o download das imagens.
- [ ] Testar o firmware (ou o log reproduzido) contra o ambiente que for adotado.
