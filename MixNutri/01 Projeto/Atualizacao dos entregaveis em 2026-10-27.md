---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Atualização dos entregáveis em 27/10/2026

Fonte recebida em 27/10/2026: [[Transcricao integral dos entregaveis]]. A data de recebimento não é uma data editorial do documento. O conteúdo é requisito documental; não autoriza, por si, contatos, publicação ou acesso ao CLP.

## Novas informações documentadas

| Informação | Localização | Consequência para o projeto |
| --- | --- | --- |
| Leitura atual é manual, uma vez ao dia, por volta das 15h, em papel A4 | Bloco 8 | O sistema deve permitir observar variações dentro e entre turnos |
| Na visita de 17/09/2026 houve parada da SaintyCo Smart Line; após ajuste produziu 620 cáps./min | Bloco 10 | Detecção automática de paradas é requisito explícito; cadência é observação contextual, não valor universal |
| Produto altera densidade do pó, disco e configuração | Bloco 11 | Cada leitura ambiental precisa ter produto e lote |
| Ambientes visitados têm termo-higrômetro e parâmetros da empresa | Bloco 12 | Solicitar faixas reais e comparação com instrumento de referência |
| Qualidade analisa pó, pesa primeiras cápsulas e seleciona no polimento | Bloco 13 | Dados de qualidade podem contextualizar a análise; integração ainda não definida |
| Primeiro piloto em uma sala; ESP32 + SHT31 + relé com histerese | Blocos 17–18 | O novo documento especifica SHT31 |
| Som é estratégia padrão; CLP/Modbus depende de autorização | Bloco 19 e legenda da Figura 1 | Não presumir acesso industrial |

## Cinco entregáveis enumerados pela ordem do texto

1. **Circuito eletrônico e modelagem de dados:** simulação no Wokwi com ESP32, SHT31, relé, LED e som; SQL de telemetria, paradas e configuração de alertas (bloco 25).
2. Firmware: histerese, acústica OPERANDO/PARADO, cliente Modbus TCP, MANUAL/AUTO via MQTT e retenção de dados em Flash em quedas de rede (bloco 26).
3. Backend: Compose, Mosquitto, PostgreSQL, Node-RED e Grafana; recepção e correlação temporal (bloco 27).
4. Dashboard e Admin: séries, linha do tempo e ajuste de limites (bloco 28).
5. Teste integrado de falha e alerta (bloco 29).

O item 1 não é somente um desenho: inclui também SQL. O usuário pediu ajuda com esse item completo. A propriedade final/manutenção do banco deve continuar alinhada à equipe 2. O programa de diagnóstico criado para verificar o circuito não constitui entrega do firmware completo do item 2.

## Diferenças frente às propostas anteriores

- DHT22 constava como opção no plano anterior e como proposta inicial da IA. Para o item 1 atual, foi preparado um modelo funcional parcial do **SHT31**, sem apresentar DHT22 como equivalente de protocolo.
- Foi criado um gerador de sinal analógico sintético para representar o som. Ele não reproduz AGC do MAX9814, interface I²S do INMP441 ou acústica da fábrica.
- Persistir somente parâmetros não basta para afirmar retenção de dados em quedas de rede. Especificar a fila/histórico offline do item 2.
- “dB” aparece na fonte, mas não define calibração SPL. A demonstração de circuito usa ADC RMS, com unidade explícita.
- O relatório anterior deixava a cadência a levantar. A nova fonte registra 620 cáps./min na visita; ainda faltam valores por produto/condição e confirmação operacional.

Ver [[Entrega do item 1]], [[Progresso em 2026-10-27]] e [[Pendencias e perguntas]].
