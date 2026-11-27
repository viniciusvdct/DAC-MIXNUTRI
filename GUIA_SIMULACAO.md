# Como rodar a simulação completa do MixNutri

Este guia usa o **Wokwi no navegador para simular o hardware** e o **Docker no computador para executar
o software**. Ao terminar, você poderá alterar umidade e ruído, observar o relé, registrar paradas e
acompanhar os dados no Admin e no Grafana. Não é preciso comprar nem montar nada.

Os comandos são para terminal **Bash/Zsh (Linux ou macOS)**, partindo da raiz do repositório. No
Windows, use o Git Bash ou o WSL, ou adapte `cp` para `copy`.

## 1. O que será executado

```text
Wokwi: ESP32 + SHT31 + sensor de som + relé
                       ↕
           Broker MQTT público HiveMQ
                       ↕
             Ponte do Mosquitto local
                       ↕
                    Node-RED
                    ↙      ↘
            Painel Admin   PostgreSQL
                               ↑
                            Grafana
```

O Admin também envia comandos e configurações ao ESP32 pelo caminho MQTT de volta. A ponte permite que
o simulador no navegador converse com os serviços locais sem expor portas do computador na internet.

| Parte | Onde roda |
| --- | --- |
| Circuito e firmware completo do item 2 | Wokwi no navegador |
| Mosquitto, Node-RED, PostgreSQL e Grafana | Docker no computador |
| CLP Modbus simulado, opcional | Docker no computador |

**Use apenas dados fictícios de produto e lote.** O broker público pode ser lido por qualquer pessoa.

## 2. Requisitos

- Docker iniciado, com Docker Compose v2 (Docker Desktop, OrbStack ou Docker Engine).
- Python 3 (para os scripts de teste).
- Navegador com acesso à internet, e a rede liberando a saída TCP 1883.

```bash
docker --version
docker compose version
docker info
```

Os três comandos devem terminar sem erro. Se `docker info` não conectar ao daemon, inicie o Docker.

## 3. Prepare o `.env`

```bash
cd item3-integracao
[ -f .env ] || cp .env.exemplo .env
```

Abra `item3-integracao/.env` e troque **todos** os valores `TROCAR_*` por senhas próprias (longas,
diferentes entre si, só letras e números). Para este roteiro, ajuste:

```dotenv
MQTT_BIND=127.0.0.1
PONTE_BROKER=broker.hivemq.com:1883
MODBUS_HABILITADO=false
```

O `.env` tem senhas locais: ele fica fora do git e não deve ir para entregas.

**Volumes de outra cópia do projeto.** Os volumes do Docker são nomeados pelo `COMPOSE_PROJECT_NAME`
(padrão `mixnutri-item3`). Se outra cópia deste projeto já rodou no mesmo computador com senhas
diferentes, o banco antigo é reaproveitado e o Node-RED falha com `password authentication failed for
user "nodered_ingestao"`. Nesse caso, dê outro nome no `.env` (por exemplo
`COMPOSE_PROJECT_NAME=mixnutri-equipe1`) ou use as senhas da cópia antiga.

## 4. Inicie os serviços

Ainda em `item3-integracao`:

```bash
docker compose config --quiet
docker compose up -d --build
docker compose ps
```

A primeira execução baixa as imagens (cerca de 0,5 GB). Devem aparecer `mosquitto`, `postgres`,
`node-red` e `grafana` como `healthy`. O PostgreSQL cria tabelas e funções sozinho na primeira
inicialização com volume vazio.

Para acompanhar os logs (`Ctrl+C` sai, os serviços continuam):

```bash
docker compose logs -f mosquitto node-red
```

Na subida, o log do Mosquitto mostra `Ponte com broker.hivemq.com:1883 ligada` e o do Node-RED
mostra `Connected to broker`.

## 5. Confira o kit sem o Wokwi (opcional, 1 minuto)

Estes scripts usam só a biblioteca padrão do Python e leem as senhas do `.env` sem imprimi-las:

```bash
python3 -I ferramentas/reproduzir_log.py ../item2-firmware/exemplos/mqtt-exemplo.log ferramentas/cenario-boot-fecha-parada.log
python3 -I ferramentas/testar_acesso_mqtt.py
python3 -I ferramentas/testar_admin.py
python3 -I ferramentas/verificar_grafana.py
docker compose exec -T postgres sh -c 'psql -X -q -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < ferramentas/teste_funcoes.sql
```

Esperado: 114 mensagens publicadas, ACL 5/5 OK, Admin 14/14 OK, `resultado: OK` no Grafana e T1 a
T10 OK nas funções. O primeiro comando também deixa dados no painel para conferência.

## 6. Abra as interfaces

| Interface | Endereço | Usuário e senha |
| --- | --- | --- |
| Editor Node-RED | <http://127.0.0.1:1880> | `NODERED_ADMIN_USUARIO` / `NODERED_ADMIN_SENHA` |
| Painel Admin | <http://127.0.0.1:1880/dashboard/admin> | Mesmas do Node-RED |
| Grafana | <http://127.0.0.1:3000> | `GRAFANA_ADMIN_USUARIO` / `GRAFANA_ADMIN_SENHA` |

No editor do Node-RED, o nó MQTT da aba **MixNutri sala01** deve aparecer como conectado.

## 7. Inicie o hardware no Wokwi

Abra o [projeto do item 2 no Wokwi](https://wokwi.com/projects/479080199406642177) e clique em
**▶ Start Simulation**. Ele já tem o circuito e o firmware completo; não é preciso abrir o item 1.

A simulação usa `config_wokwi.h`: Wi-Fi `Wokwi-GUEST` sem senha, broker `broker.hivemq.com:1883` sem
usuário e tópicos `mixnutri/sala01/...`. Não rode o script de preparação do ESP32 físico.

No monitor serial do Wokwi, procure `FILA flash_ok=1` e uma linha com `wifi=1 mqtt=1`. Depois aparecem
`TEL` a cada 5 s, além de `ST`, `EVT` e `ACK`. No primeiro boot, um erro do LittleFS seguido de
`FILA flash_ok=1` é normal (formatação inicial da memória).

Se o projeto online não estiver disponível ou não corresponder aos arquivos locais, monte-o seguindo
**Rodar no Wokwi → Montando do zero** no [README do firmware](item2-firmware/README.md).

## 8. Confira se os dados chegaram

O resumo do Admin passa a mostrar umidade, temperatura, máquina, relé e modo. No Grafana, abra
**MixNutri sala01** (pasta **MixNutri (proposta item 3)**), escolha os últimos 15 minutos e atualize.

Se o relógio do Wokwi atrasar numa simulação lenta, escolha **Horário das leituras → Recebimento (ao
vivo)** no topo do painel: as leituras aparecem pelo horário de chegada ao banco. Paradas e alertas
mantêm os horários originais.

Para conferir no banco:

```bash
docker compose exec -T postgres sh -c 'psql -X -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, data_recebimento, umidade_pct, estado_maquina FROM mixnutri.telemetria_sala01 ORDER BY id DESC LIMIT 5;"'
```

## 9. Teste o comportamento completo (roteiro do item 5)

Parâmetros padrão: liga em 55% UR, desliga em 50% UR, confirmação de operação em 3 s e de parada em 5 s,
tempo mínimo de 10 s entre comutações do relé.

1. **Contexto:** no Admin, informe produto `PRODUTO_TESTE` e lote `LOTE_TESTE_01` e publique. Aguarde
   a confirmação de aceite.
2. **Máquina operando:** no Wokwi, clique no chip `som` e deixe **Tom da máquina** em 80%.
3. **Umidade alta:** clique no SHT31 e ajuste **Umidade sintética** para 60%. O relé liga.
4. **Persistência:** mantenha 60% por mais de 1 minuto: abre o alerta `UR_ALTA`.
5. **Parada:** com a umidade alta, leve o tom para 0%. Em cerca de 5 s registra `PARADA_INICIO` e abre
   `PARADA_MAQUINA` e `UR_ALTA_E_PARADA`, visíveis no Grafana.
6. **Retorno:** tom em 80%. Registra `PARADA_FIM` e fecha os alertas da parada.
7. **Umidade normal:** 49%. O relé desliga e o alerta `UR_ALTA` fecha.
8. **Comando remoto:** no Admin, MANUAL ligado e depois AUTO. Confira as confirmações no painel e no
   serial.

Os tempos são do firmware simulado; com o Wokwi abaixo da velocidade normal, demora mais no relógio do
computador.

### Queda de rede

No monitor serial do Wokwi, envie `n` (bloqueia a rede), `f` (mostra a fila na Flash), `n` de novo
(restaura) e `f` (acompanha o esvaziamento). A fila guarda até 192 mensagens; cheia, descarta as mais
antigas. O controle local continua funcionando durante a queda.

## 10. Modbus simulado (opcional)

No `.env`, `MODBUS_HABILITADO=true`, e:

```bash
docker compose --profile modbus up -d --build
```

O Node-RED passa a ler o simulador (o estado alterna a cada ~35 s) e grava paradas com fonte
**modbus**. Isso não exige ligar o Modbus do ESP32. Para desligar: `MODBUS_HABILITADO=false`,
`docker compose up -d node-red` e `docker compose --profile modbus stop modbus-sim`.

## 11. Encerre e retome

Pare primeiro o Wokwi. Depois, em `item3-integracao`:

```bash
docker compose --profile modbus down
```

Os volumes com o histórico são mantidos (não use `-v` se quiser guardá-los). Para retomar:
`docker compose up -d` (ou com `--profile modbus`).

## 12. Problemas comuns

| Sintoma | O que conferir |
| --- | --- |
| Porta já em uso | Outro serviço em 1880, 1883, 3000 ou 55432 (por exemplo, a referência da outra equipe). Encerre só o que você identificar |
| `password authentication failed for user "nodered_ingestao"` | Volume de outra cópia do projeto com outras senhas. Use outro `COMPOSE_PROJECT_NAME` no `.env` (seção 3) |
| Build do Node-RED com `exit code: 139` | A imagem Alpine deu segfault no Docker Desktop de um integrante; o Dockerfile já usa `4.1.16-debian` |
| Node-RED não conecta ao MQTT | `node-red/dados/flows_cred.json` (só referências `${VAR}`) e `MQTT_BACKEND_*` no `.env` |
| Node-RED não inicia com `EACCES` | Permissão de escrita em `node-red/dados`; não use `chmod 777` |
| Wokwi com `wifi=1 mqtt=0` | Internet e saída TCP 1883 liberada |
| Wokwi publica, mas nada chega ao banco | `PONTE_BROKER=broker.hivemq.com:1883` no `.env`, `docker compose up -d mosquitto` e o log do Mosquitto |
| Admin mostra `undefined` | Versão antiga do `flows.json`: o nó **Validar JSON** precisa de `msg.dados = dados;` |
| Curvas somem, mas o banco recebe | Relógio do Wokwi atrasado: **Horário das leituras → Recebimento (ao vivo)** |
| Admin: "ESP32 informa vN" diferente do banco | Banco recriado com o ESP32 mantendo outra versão; a próxima publicação já usa uma versão acima |
| Alterou arquivos com os serviços rodando | `docker compose restart node-red` ou `restart grafana`. Não edite o fluxo pelo arquivo e pelo editor ao mesmo tempo |
| Alterou o `.env` | `docker compose up -d` (só `restart` não recarrega variáveis) |
| Alterou senhas depois de criar o banco ou o Grafana | Credenciais do banco e do Grafana valem só na primeira inicialização do volume |

## Referências

- [README geral](README.md), [firmware](item2-firmware/README.md), [kit do item 3](item3-integracao/README.md)
- [Contrato MQTT v2](item3-integracao/docs/contrato-mqtt-v2.md)
- [Wi-Fi do Wokwi](https://docs.wokwi.com/guides/esp32-wifi) e
  [variáveis de ambiente no Node-RED](https://nodered.org/docs/user-guide/environment-variables)

A simulação usa dados sintéticos, ruído relativo em dBFS e parâmetros demonstrativos; não substitui a
validação dos sensores e do relé físicos.
