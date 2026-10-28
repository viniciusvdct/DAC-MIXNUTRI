---
projeto: MixNutri
equipe: 1
tipo: validacao
status: executado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Validação do item 2

## Ambiente e versão

Execução em 27/10/2026 no Wokwi web (ESP32 DevKit V1, Arduino-ESP32 do próprio Wokwi), com o circuito e os modelos do item 1. Antes de cada execução, o SHA-256 dos 9 arquivos no editor do Wokwi foi comparado com os arquivos locais e conferiu em todos. Versão final: `sketch.ino` `a792682471ee6c2a…`, `logica.h` `30659c8e7ba65607…`, `partitions.csv` `17e9bd19663fe1aa…`.

MQTT: broker público `broker.hivemq.com:1883`, autorizado pelo usuário nesta sessão para dados sintéticos. Um cliente Python no Mac ([mqtt_mini.py](ferramentas/mqtt_mini.py)) assinou `mixnutri/sala01/#`, registrou tudo o que o ESP32 publicou e enviou os comandos dos testes. O tempo de simulação rodou a cerca de 40–55% do tempo real.

## Resultados

| ID | Procedimento | Resultado observado | Conclusão |
| --- | --- | --- | --- |
| I2-N01 | Testes nativos da lógica (clang++, ASan/UBSan, `-Werror`) | 15 grupos OK: configuração, histerese, tempo mínimo, MANUAL e expiração, regressão de tempo, classificador, eventos de parada, dBFS, Modbus FC03, fila circular | Aprovado para a lógica pura |
| I2-W01 | Compilar firmware + 2 chips e dar boot | Compilou; Wi-Fi `Wokwi-GUEST`, NTP e MQTT conectados; telemetria chegou ao Mac a cada 5 s | Aprovado |
| I2-W02 | Primeiro boot sem `partitions.csv` | `partition "spiffs" could not be found`, `FILA flash_ok=0`, evento BOOT perdido | Falha encontrada e corrigida com `partitions.csv` |
| I2-W03 | BOOT antes do MQTT conectar | BOOT gravado na Flash (`fila=1`) e reenviado após conectar (`total reenviado=1`); chegou ao broker | Retenção e reenvio demonstrados |
| I2-W04 | Histerese UR 45 → 60 → 53 → 49 → 53 | OFF → ON → ON → OFF (segurou 10 s por `tempo_minimo`) → OFF | Aprovado |
| I2-W05 | MQTT MANUAL ON com validade 20 s | Aceito; relé ON; `MANUAL_EXPIRADO` em t=64 724 ms, exatamente 20 000 ms após o comando (t=44 724) | Aprovado |
| I2-W06 | Comandos inválidos via MQTT | `ts` de 10 min atrás → `comando_vencido`; mesmo `cmd_id` → `duplicado`; `modo:"TURBO"` → `modo_invalido` | Aprovado |
| I2-W07 | Configuração via MQTT | v2 do Admin (`ur_max` 58, `histerese` 4, `limiar_db` −22, `banda_db` 12) aplicada como 58/54 e −22/−34; v2 repetida → `ja_aplicada`; v3 com desliga > liga → rejeitada; v1 → `versao_antiga` | Aprovado |
| I2-W08 | Contexto via MQTT | Produto/lote aplicados e presentes nas telemetrias e eventos seguintes; produto vazio → rejeitado | Aprovado |
| I2-W09 | Som: tom 80% → 0% → 80% | Queda em t=130 888; `PARADA_INICIO` confirmado em 135 931 (5 s); `PARADA_FIM` com fim 136 502, duração 5 614 ms, `retorno_operacao`, produto e lote; nível parado −49,4 dBFS | Aprovado para o sinal sintético |
| I2-W10 | Som desconectado (0 V) | `ESTADO_MAQUINA` → `DESCONHECIDO`, fonte `indisponivel`; ao reconectar → OPERANDO | Aprovado |
| I2-W11 | Falha de CRC do SHT31 com relé ON | `SENSOR_FALHA`, relé OFF por `sensor_falha`; `SENSOR_OK` ao normalizar; religou 10 s depois (tempo mínimo) | Aprovado |
| I2-W12 | Queda de rede simulada (`n`) | Controle continuou (relé ON por histerese), fila cresceu para 4 e depois 6 com um evento RELE gerado offline | Aprovado |
| I2-W13 | Reinício (`r`) com 6 mensagens na fila | `boot=b2`, `FILA itens=6` após o reboot; config v2 e contexto restaurados da NVS; `total reenviado=8` ao reconectar | **Retenção sobrevive a reinício** |
| I2-W14 | Continuidade no broker | Telemetria b1 seq 0–44: 45 recebidas, nenhuma faltando, nenhuma duplicada; evento offline (seq 29) e BOOT b2 entregues | Aprovado |
| I2-W15 | Modbus habilitado para CLP inexistente (10.255.255.1) | `estado_modbus=DESCONHECIDO`, estado principal voltou para o som (OPERANDO), MQTT continuou conectado; desabilitar por config funcionou | Falha de comunicação tratada; leitura real **não** testada |

## Bug encontrado e corrigido

Na primeira bateria MQTT, `MANUAL_EXPIRADO` chegou no mesmo instante do comando. Causa: o `loop()` lê `millis()` antes de processar o comando, então `agora − manualDesde` fica negativo e, como `uint32_t`, vira um número enorme. A correção usa diferença com sinal (`decorrido()` em `logica.h`) também no tempo mínimo e no classificador. Um teste de regressão foi acrescentado, e ele falharia no código antigo. Os logs dessas execuções ficaram em `evidencias/historico-antes-correcao` e não contam como evidência final.

## Evidências

- [Mensagens MQTT recebidas na execução final](evidencias/mqtt-recebido-execucao-final.log): JSON completo de telemetria, eventos e confirmações.
- [Trecho do serial da execução final](evidencias/wokwi-serial-execucao-final.txt): boot, rede, fila, reinício e comandos recebidos.
- [Testes nativos](evidencias/testes-logica-nativos.txt).
- [Captura do Wokwi durante a execução](evidencias/wokwi-item2-execucao.jpg).

## O que não foi executado

Modbus contra servidor real ou simulado; compilação local com PlatformIO e execução pelo Wokwi CLI (sem token nem toolchain nesta máquina); broker da equipe 2; integração com PostgreSQL, Node-RED ou Grafana; microfone real, calibração acústica e hardware físico. O cenário `testes/wokwi/item2.test.yaml` está pronto, mas não foi rodado. Os resultados acima não validam limiares industriais nem a classificação de uma máquina real.

## Reproduzir os testes nativos

```sh
cd firmware
clang++ -std=c++17 -Wall -Wextra -Werror -fsanitize=address,undefined -I . testes/test_logica.cpp -o /tmp/mixnutri-logica
/tmp/mixnutri-logica
```
