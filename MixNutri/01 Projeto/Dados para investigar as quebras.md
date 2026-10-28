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

# Dados para investigar as quebras

O desafio original exige associar ambiente e índice de quebra. O MVP de parada/ruído cobre parte da instrumentação, mas não mede diretamente cápsulas quebradas. Fonte: [[Extracao do desafio]], páginas 2–3; extensão de escopo em [[Extracao do plano MVP]].

## Dados reais ainda necessários

| Campo | Por que registrar | Origem a combinar |
| --- | --- | --- |
| Data/hora, fuso e sala | Alinhar séries e eventos | ESP32/backend |
| Temperatura e UR, validade da leitura | Condição ambiental | Nó de sensores |
| Lote e especificação da cápsula | Separar efeito da matéria-prima | Empresa/registro operacional |
| Produto, turno e intervalo | Evitar misturar condições distintas | Empresa |
| Total produzido e total quebrado | Taxa com denominador conhecido | Empresa/contagem |
| Cadência | Contextualizar produção e paradas | Máquina/empresa |
| Estado e fonte da máquina | Saber se o dado é inferido ou lido | Acústico ou Modbus |
| Relé comandado e retorno, se houver | Separar ordem de funcionamento efetivo | Firmware/atuador |
| Climatização e intervenções | Identificar mudanças de processo | Empresa |

Proposta de definição: `taxa_quebra = quebradas / produzidas_no_mesmo_intervalo * 100`. Validar com a empresa qual denominador, intervalo e método serão usados; não calcular taxa se o denominador for zero ou desconhecido.

## Análise que a simulação não substitui

Coleta por semanas; sincronização dos registros; comparação entre lotes; controle de mudanças de produto e turno; separação de falhas de sensor e falhas de processo. Ruído baixo pode resultar de interferência, posição ou outro regime de funcionamento. Umidade elevada próxima de uma parada não prova que a umidade causou a parada ou a quebra.

Dados sintéticos deverão levar identificação explícita. Não misturar demonstração e medições da planta no mesmo conjunto sem marcadores de origem.

## Complemento da nova fonte

[[Transcricao integral dos entregaveis]], bloco 11, explicita produto e lote em cada leitura. O bloco 8 registra coleta manual diária por volta das 15h, insuficiente para observar o turno inteiro. O bloco 10 registra 620 cáps./min após ajuste na visita de 17/09/2026, sem fixar cadência de todos os produtos. O SQL do item 1 já contém produto/lote por linha; não há ainda ingestão automática nem modelo de contagem de quebras.
