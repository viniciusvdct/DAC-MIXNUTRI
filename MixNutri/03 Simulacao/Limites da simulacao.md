---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-26
atualizado: 2026-10-26
tags:
  - mixnutri
  - equipe1
---

# Limites da simulação

A simulação proposta serve para executar e observar regras de software e integração. O alcance demonstrado dependerá dos componentes e testes efetivamente usados.

| Pode ser demonstrado, após implementação e teste | Continua sem validação apenas por isso |
| --- | --- |
| Histerese com entradas controladas | Faixa ideal de UR da fábrica |
| Estado temporal de máquina com sinal sintético | Robustez de detecção acústica real |
| Comando lógico do relé e LED | Capacidade elétrica e funcionamento do desumidificador |
| Envio/recepção MQTT no ambiente testado | Disponibilidade da rede da planta |
| Persistência em reinício do ambiente testado | Todos os modos de falha de memória/energia física |
| Dashboard com série sintética | Relação causal entre UR e quebra de cápsulas |
| Algoritmo por driver DHT22 | Compatibilidade elétrica e driver SHT31 |

O simulador não certifica EMC, grau IP, imunidade a ruído, precisão ou calibração. O próprio Wokwi informa que não oferece simulação analógica completa. [Referência do potenciômetro](https://docs.wokwi.com/parts/wokwi-potentiometer).

A apresentação deve distinguir dados sintéticos, execução do firmware, resultados físicos e resultados industriais. Não escrever “comprovou a causa”, “mede dB SPL” ou “validado na fábrica” sem evidência correspondente.

Ver [[Dados para investigar as quebras]] e [[Registro de evidencias]].
