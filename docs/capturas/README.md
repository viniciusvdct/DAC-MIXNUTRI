# Capturas do Grafana — teste ponta a ponta (27/11/2026)

Capturas reais do painel **MixNutri sala01** depois do roteiro do item 5 rodado ao vivo:
firmware do item 2 no Wokwi → broker público HiveMQ → ponte do Mosquitto → kit do item 3
(Node-RED, PostgreSQL, Grafana). **Dados sintéticos.** Detalhes do teste em
[`PROGRESSO.md`](../../PROGRESSO.md).

- Janela: 27/11/2026 00:45:00–00:49:30 UTC, exibida no fuso do navegador (UTC−4: 20:45–20:49 de 26/11).
- Seletor **Horário das leituras = Medição (ESP32)**.
- Configuração v7 publicada pelo Admin: liga em 58% UR, desliga em 54% UR, operando ≥ −22 dBFS,
  parado ≤ −34 dBFS. As linhas tracejadas mudam de 55/50 para 58/54 no momento em que o ESP32 aplica a v7.

| Arquivo | O que mostra |
| --- | --- |
| `00-dashboard-visao-geral.jpg` | Painel inteiro (resolução menor) |
| `01-umidade-temperatura.jpg` | UR sobe de 45% para 60%, passa do limite de 58% e volta para 49%; faixa vermelha = parada |
| `02-ruido-dbfs.jpg` | Queda do ruído abaixo do limiar de parada e retorno; dBFS é relativo ao ADC, não dB SPL |
| `03-rele-modo.jpg` | Relé: MANUAL ligado pelo Admin, AUTO, liga por histerese com a UR alta e desliga com a UR normal |
| `04-linha-tempo-paradas.jpg` | Parada de 8 s pelo som (ESP32); sem paradas por Modbus (desligado) |
| `05-paradas-registradas.jpg` | A parada com início, fim, duração e motivo `retorno_operacao` |
| `06-alertas-emitidos.jpg` | `UR_ALTA`, `PARADA_MAQUINA` e `UR_ALTA_E_PARADA` abertos e fechados |

Observações para quem for usar as imagens:
- O `DISPOSITIVO_OFFLINE` de 20:27–20:45 na tabela de alertas é de uma execução anterior, quando o
  navegador do Wokwi ficou oculto e a simulação caiu para ~3% da velocidade.
- Coincidência de UR alta com parada é correlação temporal, não prova de causa.
- O envio de alertas por e-mail/Telegram ainda não está implementado ("somente dashboard").
