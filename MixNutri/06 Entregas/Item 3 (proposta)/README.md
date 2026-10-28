# MixNutri Item 3 (proposta) — ambiente de integração

**Proposta da equipe 1 para a equipe 2 avaliar. Não é a entrega da equipe 2.** Situação em 28/10/2026: arquivos preparados e com a sintaxe conferida, **ainda não executados**, porque o download das imagens Docker aguarda permissão. A outra equipe enviou a própria entrega das etapas 3 e 4, que usa um contrato diferente. Antes de seguir, ler [Compatibilidade com a entrega das etapas 3 e 4](Compatibilidade%20com%20a%20entrega%20das%20etapas%203%20e%204.md).

Segue o contrato MQTT v2 do firmware do item 2 e grava no schema v2 do item 1 (`../Item 1/banco/01_schema.sql`, montado sem alteração).

| Pasta / arquivo | Papel |
| --- | --- |
| `compose.yaml` | Mosquitto 2.0.22, PostgreSQL 18.6, Node-RED 4.1.16 (+ `node-red-contrib-postgresql` 0.16.2) e Grafana 12.4.13, todos em 127.0.0.1 (PostgreSQL na porta 55432) |
| `.env.exemplo` | Modelo de credenciais **sem senhas reais**; copiar para `.env` e trocar cada `TROCAR_*`. O `.env` com as senhas de teste geradas em 27/10/2026 fica só na máquina local, fora do git |
| `mosquitto/` | Sem acesso anônimo; usuários do ESP32 e do backend, com ACL por tópico |
| `postgres/02_integracao.sql` | Schema `integracao`: registro bruto com deduplicação, configuração v1 igual ao firmware, funções de gravação (telemetria, paradas com fechamento no BOOT, alertas) e papéis com privilégio mínimo |
| `node-red/dados/flows.json` | Assina `mixnutri/sala01/#`, separa por canal e tipo de evento e chama as funções SQL; erros vão para o registro bruto |
| `grafana/` | Datasource somente leitura e o painel: UR/temperatura, ruído em dBFS ("não é dB SPL"), relé e modo, paradas, alertas |
| `ferramentas/` | Reprodução do log do item 2 com login, teste de acesso/ACL, cenário sintético de BOOT, testes SQL com ROLLBACK e consultas de evidência |

Uso previsto, ainda não executado:

```bash
cp .env.exemplo .env   # depois trocar cada TROCAR_* por uma senha forte
docker compose up -d --build
python3 -I ferramentas/reproduzir_log.py "../Item 2/evidencias/mqtt-recebido-execucao-final.log" ferramentas/cenario-boot-fecha-parada.log
```

Limites: dados sintéticos; ruído em dBFS, não dB SPL; parâmetros de alerta didáticos; parada inferida não mede quebra de cápsula; o Wokwi web só alcança um broker local com o gateway privado.
