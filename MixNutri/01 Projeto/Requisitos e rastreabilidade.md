---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Requisitos e rastreabilidade

D = [[Extracao do desafio]]. M = [[Extracao do plano MVP]]. Números de bloco referem-se à extração linear do DOCX, não a páginas.

| ID | Requisito ou restrição | Fonte | Responsável principal | Situação nesta base |
| --- | --- | --- | --- | --- |
| R01 | Coletar UR/temperatura e cruzar com índice de quebra | D p. 2–3 | Todas, com empresa | Pendente de dados reais |
| R02 | Prototipar sensores, painel e alertas | D p. 3 | Equipes 1–3 | Planejado |
| R03 | Recomendar controle ambiental e/ou especificação da cápsula | D p. 3 | Equipe e orientação | Depende de análise |
| R04 | Observar variação por semanas e separar efeito de lote | D p. 2 | Todas | Não validável apenas em simulação |
| R05 | Não usar sílica gel como solução nas cápsulas | D p. 2 | Todas | Restrição documentada |
| R06 | Uma sala piloto, ESP32 e relé | M blocos 3–6 | Equipe 1 | Proposto para simulação |
| R07 | Sensor SHT31/DHT22 | M bloco 6; bloco 27 cita SHT31 | Equipe 1 | Seleção pendente |
| R08 | Histerese local de UR no ESP32 | M blocos 30–31 | Equipe 1 | Não implementado |
| R09 | Nível de ruído e classificação OPERANDO/PARADO | M blocos 15–21, 32 | Equipe 1 | Não implementado |
| R10 | Suporte Modbus TCP | M blocos 11–14, 32, 56 | Equipes 1 e 2 | Fronteira pendente |
| R11 | AUTO/MANUAL por MQTT e retenção em Flash | M bloco 33 | Equipe 1 | Semântica proposta |
| R12 | Mosquitto, PostgreSQL, Node-RED, Grafana em Compose | M blocos 6, 34–35 | Equipe 2 | Fora da implementação atual |
| R13 | SQL telemetria_sala01, paradas_maquina_sala01, configuracao_alertas | M bloco 28 | Alinhar com equipe 2 | Nomes documentados |
| R14 | Dashboard com clima, ruído, relé e paradas | M blocos 38–40 | Equipe 3 | Semântica/unidade pendentes |
| R15 | Formulário com UR máx., histerese e limiar de som | M bloco 40 | Equipe 3 | Contrato a combinar |
| R16 | Cenário UR alta → relé; queda de som/Modbus → parada → alerta | M blocos 41–47 | Todas | Cenário planejado |
| R17 | Alertas automáticos Telegram/e-mail/dashboard | M bloco 47 | Equipes 2 e 3 | Canal a definir |
| R18 | Memorial técnico PDF e demonstração em tempo real/vídeo pitch | M blocos 24, 48–50 | Todas | Ainda não produzidos |
| R19 | Gabinete IP65 se possível no MVP | M bloco 6 | Equipe 1 | Não representa certificação do simulado |
| R20 | Selagem como bônus complementar | D p. 2 | A combinar | Sem inclusão automática no MVP |

As instruções de entrega dentro das fontes são requisitos documentais do projeto. Elas não autorizam, por si, contato com pessoas, publicação, operação de máquina ou instalação de serviços. O pedido do usuário orienta a ação atual: organizar a base e preparar ajuda para a simulação.

## Complementos do documento de entregáveis recebido em 27/10/2026

E = [[Transcricao integral dos entregaveis]]. Os registros abaixo especificam o recorte atual sem apagar a origem dos requisitos anteriores.

| ID | Requisito/atualização | Fonte | Estado |
| --- | --- | --- | --- |
| R21 | Produto e lote em cada leitura ambiental | E bloco 11 | Campos implementados no SQL; alimentação pelo nó/backend pendente |
| R22 | Item 1 inclui Wokwi com ESP32, SHT31, relé, LED e sensor de som mais SQL | E bloco 25 | Primeira versão implementada; modelos parciais e aceitação a confirmar |
| R23 | Retenção de dados em Flash em quedas de rede | E bloco 26 | Não implementada no diagnóstico; semântica/capacidade pendentes |
| R24 | Som como padrão; alternativa Modbus condicionada a acesso autorizado ao CLP | E bloco 19 e Figura 1 | Circuito tem sinal sintético; leitura industrial não realizada |

Ver [[Atualizacao dos entregaveis em 2026-10-27]], [[Entrega do item 1]] e [[Validacao do item 1]].
