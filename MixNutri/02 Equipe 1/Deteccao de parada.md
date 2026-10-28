---
projeto: MixNutri
equipe: 1
tipo: proposta
status: proposto
criado: 2026-10-26
atualizado: 2026-10-26
tags:
  - mixnutri
  - equipe1
---

# Detecção de parada

Fonte: [[Extracao do plano MVP]], blocos 9–21 e 32. Duas estratégias são previstas. A escolha e a divisão de implementação estão pendentes.

## Estratégia A Modbus TCP

Node-RED ou ESP32 lê registradores do CLP ou de um simulador. O texto usa exemplos `STATUS_MAQUINA` 1/0 e `CODIGO_FALHA` 101/102. Esses nomes e números **não são mapa de registradores confirmado**. Definir servidor, porta, função, endereço, base de endereçamento, tipo de dado, unit ID quando aplicável, intervalo e timeout.

Registrar qualidade e idade do dado. Comunicação perdida ou leitura vencida deve indicar DESCONHECIDO, não PARADO. A frase “precisão absoluta” do plano é uma alegação da fonte: mesmo a leitura digital depende de mapeamento e validade corretos.

## Estratégia B som

O plano sugere MAX9814 ou INMP441, medição por janelas e queda persistente do som por N segundos para indicar parada. Limiar e duração precisam ser medidos ou configurados.

Proposta para testar a lógica com uma entrada sintética normalizada de 0 a 1:

- Acima de 0,60 por 3 segundos contínuos: OPERANDO.
- Abaixo de 0,40 por 5 segundos contínuos: PARADO.
- Entre os limiares: manter o estado confirmado e reiniciar os temporizadores de confirmação.
- Na partida: DESCONHECIDO até confirmação.
- Entrada inválida ou vencida: DESCONHECIDO e cancelar confirmação pendente.

Esses valores são didáticos. A máquina de estados deve gerar um evento por transição confirmada, sem repetir uma parada a cada leitura.

## Áudio real e unidade

Para uma futura implementação de áudio, propor amostragem em janelas, remoção do nível médio DC quando aplicável e cálculo de RMS, seguido de caracterização dos estados reais. Taxa de amostragem, duração da janela e limiares ainda não foram escolhidos.

`20*log10(rms/referencia)` só tem significado com referência definida. Amplitude de ADC, dB relativos/dBFS e dB SPL não são intercambiáveis. Sem calibração acústica e cadeia de ganho conhecida, publicar nível relativo ou normalizado. O [MAX9814 possui AGC](https://www.analog.com/en/products/max9814.html); inferimos que seu ganho variável exige cuidado em classificadores baseados em amplitude.

## Limitações e eventos

Ruído de outra máquina, pessoas, mudança de posição e falha do sensor podem alterar a classificação. Registrar método (`audio`, `modbus` ou `sintetico`), estado, qualidade, duração e transição. Não deduzir um código de falha industrial apenas pelo silêncio.
