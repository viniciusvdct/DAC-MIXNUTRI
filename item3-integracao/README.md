# Item 3 — kit de integração (proposta da equipe 1)

O lado do servidor já funcionando com o firmware do [item 2](../item2-firmware) e o banco do [item 1](../item1-circuito-sql): Mosquitto, PostgreSQL, Node-RED com o painel Admin, Grafana e um simulador Modbus. Segue a estrutura da entrega das etapas 3 e 4 da outra equipe, já com as correções de integração.

**É uma proposta da equipe 1 para as equipes 2 e 3 avaliarem.** Não substitui a entrega delas.

- [Guia de integração para a equipe 2](docs/guia-integracao-equipe2.md): o que adotar e o que mudar, arquivo por arquivo.
- [Contrato MQTT v2](docs/contrato-mqtt-v2.md): tudo o que o firmware publica e aceita.

## Rodar

Requisitos: Docker com Compose v2 e Python 3. Na primeira vez, o Docker baixa as imagens (cerca de 0,5 GB).

```bash
cp .env.exemplo .env              # trocar cada TROCAR_* por uma senha forte
docker compose up -d --build
python3 -I ferramentas/reproduzir_log.py ../item2-firmware/exemplos/mqtt-exemplo.log ferramentas/cenario-boot-fecha-parada.log
```

O último comando reproduz as mensagens reais do firmware (dados sintéticos do Wokwi) mais um cenário de reinício, para o painel ter dados. Depois:

| Endereço | O que é | Login |
| --- | --- | --- |
| http://127.0.0.1:3000 | Grafana, painel "MixNutri sala01" | `GRAFANA_ADMIN_*` do `.env` |
| http://127.0.0.1:1880/dashboard/admin | Painel Admin: limites, histerese, limiar de ruído, modo, produto e lote | `NODERED_ADMIN_*` |
| http://127.0.0.1:1880 | Editor do Node-RED | `NODERED_ADMIN_*` |

Tudo fica só em 127.0.0.1. O PostgreSQL usa a porta 55432 no computador. Para ligar a leitura Modbus com o simulador: `MODBUS_HABILITADO=true docker compose --profile modbus up -d`.

## Receber o firmware do Wokwi ao vivo (teste ponta a ponta)

O Wokwi web só alcança a internet, não o seu computador. Para o firmware rodando no Wokwi chegar a este kit, ligue a ponte do Mosquitto com o broker público onde o firmware publica:

```bash
PONTE_BROKER=broker.hivemq.com:1883 docker compose up -d mosquitto
```

Depois, abra o [projeto do item 2 no Wokwi](https://wokwi.com/projects/479080199406642177) e clique em ▶. A telemetria passa a aparecer no banco e no Grafana. Os comandos, a configuração e o contexto enviados pelo Admin chegam ao ESP32 **sem retain**, para nada ficar retido no broker público.

Roteiro do teste do item 5:

1. No Admin, defina produto e lote.
2. No Wokwi, suba a umidade do SHT31 acima do limite: o relé liga na hora, e depois de 1 minuto acima do limite abre o alerta `UR_ALTA`.
3. Baixe o tom do chip `som` para 0%: em 5 s registra-se a parada, e com a UR ainda alta abre o alerta `UR_ALTA_E_PARADA`, que aparece na linha do tempo do Grafana.
4. No Admin, mande MANUAL e depois AUTO e veja as confirmações.

Só use dados sintéticos: qualquer pessoa pode ler o broker público. A rede precisa liberar a saída na porta 1883; algumas redes de universidade e de empresa bloqueiam. Para desligar a ponte: `docker compose up -d mosquitto`, sem a variável.

## Conteúdo

| Pasta / arquivo | Papel |
| --- | --- |
| `compose.yaml` | Mosquitto 2.0.22, PostgreSQL 18.6, Node-RED 4.1.16 (PostgreSQL 0.16.2 + Dashboard 2.0 1.29.0), Grafana 12.4.13 e simulador Modbus (perfil `modbus`) |
| `.env.exemplo` | Modelo de credenciais sem senhas. O `.env` fica fora do git |
| `mosquitto/` | Sem acesso anônimo; um usuário para o ESP32 e outro para o backend, com ACL por tópico |
| `postgres/02_integracao.sql` | Roda sobre o schema do item 1, que entra sem alteração. Traz registro bruto com deduplicação, funções de gravação, apoio ao Admin e papéis com o mínimo de privilégio |
| `node-red/dados/flows.json` | Aba "MixNutri sala01": recebe `mixnutri/sala01/#` e faz a leitura Modbus (desligada por padrão). Aba "Admin v2": configuração versionada, comando sem retain, produto e lote |
| `node-red/dados/settings.js` | Login no editor, nas páginas e no socket.io do Admin |
| `grafana/` | Datasource somente leitura e o painel: UR/temperatura, ruído em dBFS ("não é dB SPL"), relé e modo, paradas por fonte e alertas |
| `modbus-simulador/` | `server.py` e `Dockerfile` da outra equipe, sem alteração |
| `ferramentas/` | Reprodução do log, cenário de reinício e testes de SQL, ACL, Admin e Grafana |

## Testado

Testado em 28/10/2026 com as mensagens do item 2:

- Mensagens gravadas sem violar nenhuma regra do banco; a duplicata foi descartada.
- Paradas fechadas no retorno da máquina e no reinício do ESP32.
- Testes passando: SQL 8/8, ACL 5/5 e Admin 14/14. O Grafana respondeu às 9 consultas com dados.
- Modbus testado com o simulador, incluindo parada do CLP e perda de comunicação.
- **Ponta a ponta ao vivo (28/10/2026):** firmware no Wokwi → broker público → ponte → este kit. Todas as 40 telemetrias foram gravadas, sem lacuna. Contexto, configuração v8, MANUAL e AUTO, enviados pelo Admin, foram aceitos pelo ESP32. O roteiro do item 5 gerou UR alta, relé ligado, parada com produto e lote e os alertas `UR_ALTA`, `PARADA_MAQUINA` e `UR_ALTA_E_PARADA`. O fim da conexão gerou `DISPOSITIVO_OFFLINE`, tudo visível no Grafana.

**Ainda não testado:**

- ESP32 físico ligado a este broker.
- Envio de alertas por Telegram ou e-mail.

**Limites:** dados sintéticos; ruído em dBFS, não dB SPL; parâmetros didáticos. Parada inferida não mede quebra de cápsula, e correlação não prova causa.
