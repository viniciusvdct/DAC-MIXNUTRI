---
projeto: MixNutri
equipe: 1
tipo: indice
status: documentado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# MixNutri — base da equipe 1

Base de consulta da IA e memória das sessões do projeto DAC. O usuário cursa Engenharia de Controle e Automação, pertence à equipe 1 e informou que seu grupo assumiu circuito eletrônico, hardware e firmware. Pretende simular toda a sua parte. O simulador ainda não foi escolhido.

Esta pasta integra o cofre UCDB existente, em `8 Semestre/DAC/MixNutri`. As notas funcionam sem plugins adicionais. Não é necessário criar um segundo cofre.

## Atualização mais recente

Em 27/10/2026, foram transcritos os três anexos e preparada uma primeira versão do item 1. Acesse [[Progresso em 2026-10-27]], [[Entrega do item 1]] e [[Indice das transcricoes]]. Resultados e limitações estão em [[Validacao do item 1]].

Na segunda sessão de 27/10/2026, o item 1 passou à versão 2 e o firmware do item 2 foi implementado e testado: [[Entrega do item 2]], [[Validacao do item 2]]. Integração com o Wokwi CLI em [[Wokwi CLI e VS Code]].

## Por onde começar

1. [[Contexto para IA]] — contexto curto para retomar uma conversa.
2. [[Escopo e equipes]] — responsabilidades e interfaces.
3. [[Requisitos e rastreabilidade]] — o que cada documento pede.
4. [[Plano de execucao da equipe 1]] — etapas, esforço estimado, entregas e integração.
5. [[Tarefas da equipe 1]] — próximos passos, ainda não executados.
6. [[Registro de sessoes]] — memória do que foi feito e combinado.

## Mapa das informações

| Área | Notas |
| --- | --- |
| Problema e contexto | [[Visao do desafio]], [[Cronograma e entregas]], [[Pessoas e acompanhamento]] |
| Circuito | [[Arquitetura proposta]], [[Hardware e componentes]] |
| Execução | [[Plano de execucao da equipe 1]], [[Plano de simulacao]], [[Tarefas da equipe 1]] |
| Firmware | [[Firmware e estados]], [[Controle de umidade]], [[Deteccao de parada]], [[Parametros propostos]] |
| Integração | [[Contrato MQTT proposto]], [[Dados para investigar as quebras]] |
| Validação | [[Escolha do simulador]], [[Matriz de testes]], [[Limites da simulacao]], [[Registro de evidencias]] |
| Memória | [[Decisoes]], [[Pendencias e perguntas]], [[Registro de sessoes]] |
| Fontes | [[Catalogo de fontes]], [[Extracao do desafio]], [[Extracao do plano MVP]], [[Referencias tecnicas]] |
| Modelos | [[Modelo de sessao]], [[Modelo de decisao]], [[Modelo de teste]], [[Modelo de secao tecnica]] |

## Como interpretar o conteúdo

- **Confirmado pelo usuário:** sua equipe, área de formação, responsabilidade e intenção de simular.
- **Documentado:** informação presente nas fontes; não implica verificação na fábrica.
- **Proposta:** sugestão técnica para discussão, sem aprovação presumida.
- **Pendente:** falta informação ou decisão.
- **Evidência:** resultado acompanhado de arquivo, procedimento e condições de teste.

Na criação desta base não foram implementados nem executados circuito, firmware, broker ou dashboard. Nenhum teste do produto está aprovado. Os documentos originais foram preservados em [[Catalogo de fontes]].
