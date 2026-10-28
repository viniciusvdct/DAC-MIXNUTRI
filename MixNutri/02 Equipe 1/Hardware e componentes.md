---
projeto: MixNutri
equipe: 1
tipo: proposta
status: proposto
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Hardware e componentes

Base documental: [[Extracao do plano MVP]], blocos 6, 15–21, 27 e 56. A tabela abaixo é planejamento, não lista de compra nem circuito validado.

| Função | Citado no plano | Caminho proposto para começar |
| --- | --- | --- |
| Processamento/rede | ESP32 | Um modelo ESP32 definido antes da pinagem |
| Clima | SHT31/DHT22 | DHT22 se a simulação for Wokwi e a substituição for aceita |
| Acionamento | Relé | Módulo relé e LED como carga demonstrativa |
| Som | MAX9814 ou INMP441 | Entrada sintética de nível; etapa posterior de áudio |
| Gabinete | IP65 se possível no MVP; IP66 no completo | Documentar como requisito físico futuro |

## Interfaces a definir

SHT31 usa uma interface diferente do DHT22; não são substitutos de pinagem. O nome `SDA` do componente DHT22 no Wokwi indica o pino de dados e não torna o sensor I²C. Separar o driver na aplicação. [Referência DHT22](https://docs.wokwi.com/parts/wokwi-dht22).

MAX9814 é uma opção de front-end analógico; INMP441 é a opção I²S citada no plano. Não compartilhar uma pinagem presumida entre as duas. Validar o datasheet do módulo efetivamente escolhido antes de desenhar seu circuito. O MAX9814 possui AGC, de modo que a inferência simples por amplitude precisa considerar o ganho variável. [Fabricante](https://www.analog.com/en/products/max9814.html). Esta última observação é uma interpretação técnica, não resultado de ensaio.

## Checklist de definição do circuito

- [ ] Escolher placa exata e registrar versão.
- [ ] Definir driver de clima e GPIOs sem conflito com a placa.
- [ ] Definir som sintético, analógico ou I²S e suas unidades.
- [ ] Documentar alimentação, referência de terra, resistores e níveis de sinal de cada módulo.
- [ ] Escolher GPIO e polaridade do relé; testar os contatos NO/NC e a inicialização.
- [ ] Separar o estado lógico `desumidificador_on` da saída elétrica do GPIO.
- [ ] Definir LED, resistor e carga apenas demonstrativa na simulação.
- [ ] Registrar esquema, lista de componentes e limitações.

O Wokwi modela relé com IN, VCC/GND e contatos COM/NO/NC. Confirmar o comportamento do componente e seus atributos no teste; não presumir polaridade a partir de exemplos genéricos. [Referência do relé](https://docs.wokwi.com/parts/wokwi-relay-module).

Um relé comandado não comprova que um desumidificador real ligou. A instalação física dependerá da interface de comando, corrente, equipamento e condições reais ainda desconhecidas. A base atual não dimensiona chaveamento de rede elétrica nem certifica grau IP.

## Implementação do item 1 em 27/10/2026

A referência mais recente e concreta do circuito é [[Pinagem e componentes do item 1]]: ESP32 DevKit V1, SHT31 customizado parcial em I²C, sinal analógico sintético, relé `npn` ativo em HIGH e LED nos contatos. O DHT22 desta nota era uma proposta anterior, não foi usado nessa implementação. Aceitação do modelo e escolha dos módulos físicos continuam pendentes.
