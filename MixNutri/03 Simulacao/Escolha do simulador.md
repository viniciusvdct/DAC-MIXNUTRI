---
projeto: MixNutri
equipe: 1
tipo: proposta
status: pendente
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Escolha do simulador

Em 26/10/2026, o usuário respondeu **“Ainda não escolhi”**. Não há escolha aprovada.

## Candidato inicial

Wokwi é citado no plano e é um candidato para validar lógica no ESP32. A lista oficial inclui ESP32, DHT22, relé e potenciômetro. SHT31, MAX9814 e INMP441 não aparecem nessa lista consultada; isso não prova impossibilidade via implementação customizada. [Hardware suportado](https://docs.wokwi.com/getting-started/supported-hardware).

Proposta: começar com DHT22, relé, LED e nível sonoro sintético. Tratar o DHT22 como alternativa de simulação, não como validação do driver SHT31. Tratar o potenciômetro como injeção de nível, não como validação de microfone ou áudio.

## Critérios para decidir

| Necessidade | Como avaliar |
| --- | --- |
| Executar firmware e lógica do ESP32 | Candidato Wokwi; testar a placa e as bibliotecas |
| MQTT com Docker local | Verificar caminho de rede e acesso ao gateway antes de assumir integração |
| Usar exatamente SHT31 e microfone | Verificar modelo disponível/customizado ou teste separado de driver |
| Analisar circuito analógico e ganho de áudio | Exige avaliação de ferramenta/modelo elétrico específico |
| Demonstração sem equipamento físico | Separar comportamento lógico de validação industrial |

Não foi feita uma comparação verificada de versões ou licenças do Proteus; ele continua uma alternativa a avaliar se houver exigência da disciplina.

A documentação do Wokwi informa que seu gateway público não alcança a rede local; o privado permite esse acesso e tem requisitos de plano. [Conectividade](https://docs.wokwi.com/guides/esp32-wifi). Não contratar ferramenta antes de escolher a estratégia.

Próxima decisão proposta: aceitar ou não essa primeira simulação lógica, mantendo registrada a diferença para o circuito físico previsto.

## Alvo implementado em 27/10/2026

O item 1 da nova fonte especifica Wokwi. Foi preparado e executado um circuito nesse ambiente com SHT31 customizado parcial e sinal sonoro sintético, sem usar DHT22. Ver [[Entrega do item 1]] e [[Validacao do item 1]]. O usuário não confirmou uma escolha geral para todos os itens; para o item solicitado, o ambiente segue o documento recebido. PostgreSQL foi validado separadamente em instância local temporária.
