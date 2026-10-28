---
projeto: MixNutri
equipe: 1
tipo: plano
status: proposto
criado: 2026-10-26
atualizado: 2026-10-26
tags:
  - mixnutri
  - equipe1
---

# Plano de simulação

**Sequência proposta para a equipe 1; nenhuma etapa técnica está executada.** Base: [[Extracao do plano MVP]] e [[Escopo e equipes]].

Para estimativas de esforço, entregas por etapa, dependências entre equipes e primeira sessão de implementação, consultar [[Plano de execucao da equipe 1]], elaborado a pedido do usuário em 26/10/2026. Esta nota conserva o detalhamento dos cenários de simulação.

## Etapa 0 alinhar o que será demonstrado

Escolher simulador, placa e sensor. Resolver SHT31 versus DHT22, som real versus entrada sintética e papel do Modbus. Confirmar que a demonstração não será apresentada como validação da fábrica. Saída: decisão registrada e escopo combinado.

## Etapa 1 ambiente e atuador local

Montar circuito mínimo de ESP32, sensor de clima, relé e LED. Ler e validar temperatura/UR, implementar histerese e log serial. Variar UR em torno dos dois limiares, inspecionar contatos do relé e verificar saída de partida. Saída: esquema e evidências dos testes T01–T04.

## Etapa 2 estado da máquina

Introduzir nível sintético ou driver de som definido. Implementar DESCONHECIDO/OPERANDO/PARADO, limiares e tempos de confirmação. Mostrar que silêncio breve não gera parada. Saída: logs com valores, transições e temporização, testes T05–T07.

## Etapa 3 firmware resiliente

Adicionar AUTO/MANUAL, validação de parâmetros, persistência e tentativas de rede sem bloquear o controle. Definir validade de comandos e comportamento de falhas. Saída: evidências de T08–T12, T14–T17 conforme escopo.

## Etapa 4 integração com equipes 2 e 3

Fixar [[Contrato MQTT proposto]] em versão acordada. Validar broker e caminho de rede, entregar mensagens reais do firmware ao backend. Confirmar correspondência das unidades e do estado do relé no dashboard. Demonstrar alternativa Modbus se permanecer exigida. Saída: mensagens recebidas, histórico e tela com origem explícita.

## Etapa 5 roteiro integrado

1. Registrar versão do firmware, configuração e origem sintética.
2. Mostrar clima abaixo do limiar e máquina OPERANDO.
3. Elevar UR acima do limite: demonstrar o comando do relé.
4. Reduzir nível sintético pelo tempo configurado: demonstrar PARADO e evento.
5. Exibir os mesmos dados no backend/dashboard e o alerta escolhido.
6. Baixar UR abaixo do limiar de desligamento e demonstrar a histerese.
7. Demonstrar uma falha de rede e a continuidade do controle local.

A proximidade temporal entre UR alta e parada é um cenário criado para teste. Não é uma conclusão causal.

## Etapa 6 documentação

Contribuir ao memorial com diagrama, código/versionamento, decisões, parâmetros, testes e limitações. Gravar demonstração/vídeo conforme combinação da equipe. Usar [[Registro de evidencias]] e [[Modelo de secao tecnica]].
