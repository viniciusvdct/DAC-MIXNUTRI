# MVP IoT-MixNutri — Etapas 3 e 4

Projeto demonstrativo para a Sala Piloto 01: broker MQTT, PostgreSQL, integração Modbus TCP/S7Comm, painel administrativo no Node-RED e dashboard analítico no Grafana.

## Iniciar

Requisitos: Docker Desktop ou Docker Engine com Compose v2. Na pasta deste projeto:

```bash
cp .env.example .env
# edite as senhas em .env antes de iniciar
docker compose up --build -d
docker compose ps
```

Endereços locais:

| Serviço | Endereço |
|---|---|
| Editor Node-RED | http://localhost:1880 |
| Painel Admin | http://localhost:1880/dashboard/admin |
| Grafana | http://localhost:3000 (usuário/senha em `.env`) |
| MQTT Mosquitto | `localhost:1883` |
| PostgreSQL | `localhost:5432` |
| Simulador Modbus | `localhost:5020` |

O Node-RED consulta o simulador Modbus automaticamente e persiste dados no PostgreSQL. O dashboard Grafana vem provisionado com painéis de UR, temperatura, ruído, estado da máquina, desumidificador, paradas e alertas. O painel Admin salva limites, publica-os retidos no tópico MQTT de configuração e permite enviar comandos AUTO/MANUAL.

Para ESP32 físico na mesma rede, ajuste `MQTT_BIND` no `.env` para o IP da interface LAN do computador que hospeda o Compose (por exemplo, `192.168.0.20`) e use esse IP no firmware. Libere a porta 1883 apenas na rede de bancada. A configuração inicial do broker aceita clientes anônimos para facilitar a simulação; não publique essa porta na internet. Antes de uma implantação real, configure usuário/senha e ACL no Mosquitto.

## Teste rápido

```bash
docker compose logs -f node-red
```

Após cerca de 2 segundos, devem começar as leituras Modbus simuladas. Veja a tabela `telemetria_sala01` no PostgreSQL ou abra o Grafana. Para enviar amostra MQTT manualmente (com `mosquitto-clients` instalado no host):

```bash
mosquitto_pub -h localhost -t iotmixnutri/sala01/telemetria -q 1 -m '{"sala_id":"sala01","timestamp":"2026-10-15T12:00:00Z","umidade_pct":58,"temperatura_c":25.2,"ruido_db":66,"estado_maquina":"OPERANDO","desumidificador":true,"modo":"AUTO","origem":"esp32"}'
```

## O que está incluído

- `compose.yaml`: Mosquitto, PostgreSQL, Node-RED, Grafana e simulador Modbus TCP com verificações de saúde.
- `postgres/init/`: tabelas de telemetria, eventos de parada, configuração e alertas; usuário somente leitura para Grafana.
- `node-red/flows.json`: recepção MQTT, leitura FC03, persistência, classificação acústica com limiar/duração, fechamento de paradas, painel admin e envio opcional Telegram/e-mail.
- `grafana/`: datasource PostgreSQL e dashboard carregados automaticamente.
- `docs/contrato-integracao.md`: contrato de MQTT e mapa Modbus/S7 para alinhar as equipes.
- `docs/memorial-etapas-3-4.md`: texto base para incorporar ao memorial acadêmico.

## Observações de operação

- Os volumes persistem entre reinicializações. Para apagar todos os dados de demonstração, use `docker compose down -v` (isso remove os bancos e configurações armazenados).
- Scripts de inicialização do PostgreSQL rodam apenas na primeira criação do volume. Se mudar o schema depois de inicializado, crie uma migration e aplique-a ao banco existente.
- O S7Comm está em uma aba desabilitada do Node-RED para evitar tentativas de conexão até que o endereço, rack/slot e endereços de DB reais sejam confirmados. Veja as instruções de habilitação no contrato de integração.
- O modo acústico classifica como parada quando o nível fica abaixo do limiar pelo tempo definido. Para fontes Modbus/S7, o status digital do CLP prevalece.
- Telegram e e-mail são opcionais e ficam desligados se as variáveis correspondentes do `.env` permanecerem vazias. Alertas de UR e parada também aparecem no Node-RED e são gravados no PostgreSQL para consulta no Grafana.
- Nesta versão acadêmica, o acesso HTTP aos serviços é local por padrão e o Admin Node-RED não inclui autenticação. Não exponha os serviços fora da bancada sem acrescentar autenticação, TLS e regras de rede.
