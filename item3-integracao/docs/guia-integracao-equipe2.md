# Guia de integração — da equipe 1 para as equipes 2 e 3

A equipe 1 (circuito e firmware) entrega o firmware do ESP32 (item 2), o circuito e o script SQL (item 1) e o contrato MQTT v2 ([contrato-mqtt-v2.md](contrato-mqtt-v2.md)). Este kit mostra **o lado do servidor já funcionando com esse contrato**. A estrutura segue a entrega das etapas 3 e 4 que vocês enviaram: Mosquitto, PostgreSQL, Node-RED com Admin e Modbus, Grafana e o mesmo simulador Modbus. Os problemas de integração encontrados foram corrigidos aqui.

É uma **proposta da equipe 1**. A entrega das etapas 3 e 4 continua sendo de vocês, e os seus arquivos originais não foram alterados.

## Rodar em 3 comandos

```bash
cp .env.exemplo .env              # trocar cada TROCAR_* por uma senha forte
docker compose up -d --build      # Mosquitto, PostgreSQL, Node-RED e Grafana em 127.0.0.1
python3 -I ferramentas/reproduzir_log.py ../item2-firmware/exemplos/mqtt-exemplo.log ferramentas/cenario-boot-fecha-parada.log
```

O terceiro comando reproduz as 110 mensagens reais do firmware (log do Wokwi, dados sintéticos) mais um cenário de BOOT. Se o kit for usado fora do repositório, ajuste o caminho do log. Depois:

| Endereço | O que é | Login |
| --- | --- | --- |
| http://127.0.0.1:3000 | Grafana: painel "MixNutri sala01". Use o link *Janela do log reproduzido* | `GRAFANA_ADMIN_*` do `.env` |
| http://127.0.0.1:1880/dashboard/admin | Admin (Dashboard 2.0) no contrato v2 | `NODERED_ADMIN_*` |
| http://127.0.0.1:1880 | Editor do Node-RED | `NODERED_ADMIN_*` |
| `127.0.0.1:1883` | Mosquitto (sem anônimo) | `MQTT_ESP32_*` ou `MQTT_BACKEND_*` |
| `127.0.0.1:55432` | PostgreSQL, banco `mixnutri` | `grafana_leitura` só lê |

Para testar a leitura Modbus com o simulador de vocês: `MODBUS_HABILITADO=true docker compose --profile modbus up -d`.

## Testes prontos (e o resultado da execução de 28/10/2026)

| Comando | Verifica | Evidência |
| --- | --- | --- |
| `reproduzir_log.py` + `consultas_evidencia.sql` | 113 mensagens gravadas, 0 falhas; telemetria, paradas, configurações e alertas | `evidencias/consulta-sql-apos-reproducao.txt` |
| `teste_funcoes.sql` (ROLLBACK) | Duplicata, UR alta com persistência, restrição dBFS, parada simultânea, BOOT, FIM atrasado, INÍCIO de boot antigo, FIM sem INÍCIO | `evidencias/teste-funcoes-sql.txt` (8/8) |
| `testar_acesso_mqtt.py` | Anônimo e senha errada recusados; ESP32 bloqueado em `comandos` | `evidencias/teste-acesso-mqtt.txt` (5/5) |
| `testar_admin.py` | Login no painel; comando sem retain com `cmd_id`, `ts` e validade; configuração com versão crescente e retida; contexto | `evidencias/teste-admin-v2.txt` (14/14) |
| `verificar_grafana.py` | Datasource, painel provisionado e as 9 consultas com dados | `evidencias/grafana-api-consultas.txt` |
| Modbus com o simulador | Parada do CLP; perda de comunicação fecha com `fonte_indisponivel` | `evidencias/teste-modbus-nodered.txt` |
| Navegador | Painel do Grafana e Admin funcionando | `evidencias/*.jpg` |

## Como incorporar

**Caminho 1 (mais simples):** usar o kit como base da entrega de vocês. Copiem o que é só de vocês: a aba S7 (desabilitada), o envio por Telegram/e-mail e o visual do Admin. Os pontos de encaixe estão na tabela abaixo.

**Caminho 2:** corrigir os próprios arquivos. Cada linha diz o que mudar e onde está o equivalente pronto.

| Arquivo de vocês | O que mudar | Por quê | Pronto no kit |
| --- | --- | --- | --- |
| `mosquitto.conf` | `allow_anonymous false`, `password_file`, `acl_file` | O ESP32 só publica dados e só lê comandos; o Admin só escreve comandos, configuração e contexto | `mosquitto/` |
| `compose.yml` | Montar `item1-circuito-sql/banco/01_schema.sql` + `02_integracao.sql`; deixar o Modbus como perfil opcional | Schema único da sala; o simulador não roda por padrão | `compose.yaml` |
| `001_schema.sql` | Trocar pelo schema v2 do item 1 + `postgres/02_integracao.sql` | Produto e lote por leitura, deduplicação, dBFS declarado, parada com `evento_id`/`motivo_fim`, configuração versionada, alertas com início e fim | `postgres/` |
| `flows.json` → `mqtt in` | Assinar `mixnutri/sala01/#` | Prefixo do firmware | aba "MixNutri sala01" |
| `flows.json` → `normalize-mqtt` | Aceitar `umidade_pct = null` (falha do sensor), usar `timestamp_utc`/`clock_synced`, guardar `device_id`/`boot_id`/`seq` | Hoje uma falha descarta a leitura; reenvios da Flash ficam com hora errada e duplicados | `integracao.gravar_telemetria` |
| `flows.json` → `record-stop` | Remover. Gravar `PARADA_INICIO`/`PARADA_FIM` do tópico `eventos` e fechar no `BOOT` | O CHECK de `origem` não aceita `esp32`, e a telemetria a cada 5 s perde paradas curtas (a de 5,6 s do log) | `gravar_parada_inicio/fim`, `gravar_boot` |
| `flows.json` → `persist-alert` | Alertas com início e fim no banco; UR alta só após persistência | Alerta a cada leitura acima do limite, com janela só em memória | funções `abrir_alerta`/`fechar_alertas` |
| `flows.json` → Admin (`ui-manual`, `ui-auto`, `mqtt-command`) | Publicar em `comandos` **sem retain**, com `cmd_id`, `rele`, `validade_s` e `ts` | Comando retido religa o desumidificador a cada reconexão; o firmware recusa sem `cmd_id` | aba "Admin v2" |
| `flows.json` → `save-config` | Publicar `{"versao": N+1, "ur_max", "histerese", "limiar_db", "banda_db"}`; a versão vem de `integracao.proxima_versao_config` | O firmware exige versão crescente; o limiar é em dBFS | aba "Admin v2" |
| `flows.json` → (novo) | Formulário de produto e lote → tópico `contexto` | Exigência de produto e lote por leitura | aba "Admin v2" |
| `flows.json` → `modbus-read`/`map-modbus` | Ler só máquina (HR3) e falha (HR5); gravar paradas com `fonte_estado = modbus`; não gravar UR/temperatura do CLP na telemetria | Hoje as curvas misturam o simulador com o ESP32 | bloco Modbus da aba principal (sem pacote extra) |
| `sala01.json` | Ruído em **dBFS** com a legenda "não é dB SPL"; relé = comando lógico; paradas por fonte | Unidade real do firmware | `grafana/dashboards/` |
| `postgres.yml` | `jsonData.database`, usuário somente leitura | | `grafana/provisioning/` |
| `settings.js` | `adminAuth`; `dashboard.middleware` e `dashboard.ioMiddleware` com login | Sem isso, o Admin abre sem senha (testado: HTTP 200 sem login) | `node-red/dados/settings.js` |
| `_env` | Senhas fortes, fora do git | O arquivo enviado tinha senhas triviais | `.env.exemplo` |

## O que muda no firmware para ligar no broker de vocês

**Nenhuma mudança de lógica.** Basta preencher as constantes de conexão em `sketch.ino` (`MQTT_HOST`, `MQTT_PORTA`, `MQTT_USUARIO`, `MQTT_SENHA`) com o broker e o usuário `MQTT_ESP32_*` definidos por vocês. No Wokwi web, um broker local só é alcançável pelo gateway privado do Wokwi. Com ESP32 físico na mesma rede, vale o `MQTT_BIND` que vocês já previram.

## Fica com vocês (não incluído no kit)

- Envio por Telegram/e-mail. Os alertas ficam em `mixnutri.alertas_emitidos` com `canais` e `status_envio`. Para enviar, consultar `status_envio = 'pendente'` e atualizar para `enviado`/`falha_envio`. O código de envio que vocês já escreveram serve.
- Aba S7Comm (sem acesso ao CLP, deve continuar desabilitada).
- Visual final do Admin e do Grafana.

## Pendências para combinar

1. Qual broker será usado com o Wokwi (gateway privado, broker público só para demonstração ou ESP32 físico)?
2. Ruído: dBFS até existir calibração; dB SPL só com referência de calibração (o schema exige isso).
3. Quem mantém o SQL e o contrato a partir de agora.
4. Limites e tempos são didáticos (ex.: 55 %UR), não industriais.
5. O Wokwi CLI e o ESP32 físico ainda não foram testados com este backend. A integração foi exercitada com o log real reproduzido.
