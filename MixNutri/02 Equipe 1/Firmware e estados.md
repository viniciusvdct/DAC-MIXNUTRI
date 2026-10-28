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

# Firmware e estados

Requisitos: [[Extracao do plano MVP]], blocos 30–33. **Arquitetura proposta; código ainda inexistente.**

## Estado independente por função

| Função | Estados propostos |
| --- | --- |
| Modo de controle | AUTO, MANUAL |
| Saída comandada | OFF, ON |
| Máquina | DESCONHECIDO, OPERANDO, PARADO |
| Sensor de clima | INICIALIZANDO, VALIDO, FALHA |
| Rede | DESCONECTADO, WIFI_OK, MQTT_OK |

Não codificar o sistema inteiro em um único estado: pode haver AUTO, máquina OPERANDO e MQTT desconectado ao mesmo tempo.

## Ordem de inicialização proposta

1. Definir a saída do atuador em condição inicial documentada, antes de tentar rede.
2. Carregar configuração persistida e validar limites/versão; usar configuração didática se inválida.
3. Inicializar sensores e marcar máquina como DESCONHECIDO.
4. Iniciar agenda de leitura, controle e classificação.
5. Tentar Wi-Fi e MQTT com timeout e novas tentativas sem bloquear o controle.
6. Publicar estado completo ao reconectar, identificando reinício.

## Ciclo proposto

Usar temporização e tarefas curtas, sem esperas longas pela rede. Agendar leitura ambiental, processamento do nível sonoro, controle, eventos e telemetria. No áudio real, a aquisição precisa de sua própria taxa e buffers; ela não se reduz ao intervalo de leitura de um potenciômetro.

## Persistência

Guardar parâmetros aceitos e versão de configuração. No Arduino-ESP32, Preferences usa NVS e preserva valores em reinícios; é apropriado para pequenos valores. Para volumes maiores, avaliar um sistema de arquivos. [Documentação Espressif](https://docs.espressif.com/projects/arduino-esp32/en/latest/api/preferences.html).

Persistir configuração **não** equivale a garantir histórico offline. Se for exigido reenvio de telemetria, definir fila, capacidade, perda admissível, timestamps, duplicação e política de descarte. Não gravar toda amostra em NVS. Não restaurar automaticamente um antigo comando manual ON como se ainda fosse vigente.

Ver [[Controle de umidade]], [[Deteccao de parada]], [[Parametros propostos]] e [[Matriz de testes]].
