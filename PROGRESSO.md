# PROGRESSO — contexto para retomar o trabalho (equipe 1)

Arquivo vivo: cada etapa concluída é registrada aqui, com o que mudou, como foi testado e o que falta.
Serve para uma pessoa ou uma IA retomar o projeto sem reler tudo. Não coloque senhas aqui.

## Contexto em 10 linhas

- Desafio 10 NEOINDÚSTRIA MS (SENAI-MS/UCDB) para a MixNutri: quebra intermitente de cápsulas na
  encapsuladora; suspeita de umidade/temperatura. Sala piloto = 1 ESP32.
- **Equipe 1 (nós):** circuito (item 1), firmware ESP32 (item 2) e uma *proposta* de kit de integração
  (item 3) para as equipes 2 (rede/BD) e 3 (dashboards) avaliarem.
- Fluxo: ESP32 (SHT31 + MAX9814 + relé) → MQTT/Mosquitto → Node-RED → PostgreSQL → Grafana; Admin no
  Node-RED Dashboard 2.0 publica configuração, comandos e contexto (produto/lote) de volta ao ESP32.
- Contrato MQTT: [`item3-integracao/docs/contrato-mqtt-v2.md`](item3-integracao/docs/contrato-mqtt-v2.md).
- Datas: validação com a indústria até 27/11/2026; entrega e apresentação de 30/11 a 11/12/2026.
- **Prioridade combinada:** deixar a simulação (Wokwi + Docker) funcionando perfeitamente; só depois
  montar o hardware físico; depois integrar com as equipes 2 e 3.

## Fonte da verdade

- A versão "ubuntu" do pacote `MixNutri_Entrega_Integrada` (25/11/2026) é a mais nova da equipe.
  Sua pasta `Projeto_integrado/` foi copiada sem alterações para este repositório na branch
  `atualizacao-entrega-ubuntu` (o `main` do GitHub estava em 28/10/2026).
- Ficaram **fora** do repositório (é público): `Documentos_de_apoio/` (relatório do desafio é
  confidencial) e `Referencia_dashboard_BD_original/` (entrega da outra equipe).
- Revisão completa feita em 26/11/2026: `../REVISAO_MIXNUTRI.md` (fora do repositório).

## Ambiente de desenvolvimento (macOS desta máquina)

- Docker via OrbStack (`orb start` / `orb stop`). Compose v2.
- O compose tem `name: mixnutri-item3`: **toda cópia do projeto compartilha os mesmos volumes**.
  Existem volumes `mixnutri-item3_*` de 28/10 com senhas antigas. Para rodar com outro `.env` sem
  conflito, usar `COMPOSE_PROJECT_NAME=<outro_nome>` no `.env` (ou `docker compose -p <nome>`).
- PlatformIO instalado em `item2-firmware/.venv` (ignorado pelo git) e toolchain em `~/.platformio`;
  espressif32 8.0.0, ArduinoJson 7.4.3, PubSubClient 2.8, DHT sensor library 1.4.7, Adafruit Unified
  Sensor 1.1.15. `item2-firmware/gravar_esp32.sh` instala o PlatformIO sozinho se faltar.
- ESP32 desta máquina aparece em `/dev/cu.usbserial-0001` (driver nativo do macOS). O IP do Mac na rede
  local muda; `preparar_esp32.sh --verificar` mostra o atual.
- Ler a serial sem o monitor interativo (útil para IA):
  `item2-firmware/.venv/bin/python -I item2-firmware/ferramentas/serial_esp32.py /dev/cu.usbserial-0001 10 --reset`
  (aceita comandos com horário, ex.: `h@3 l@8 c@12`).
- Testes nativos: `clang++ -std=c++17 -I item2-firmware/firmware item2-firmware/firmware/testes/test_logica.cpp`
  e `clang -std=c11 -I item1-circuito-sql/testes item1-circuito-sql/testes/test_models.c`.

## Estado atual

| Parte | Estado |
| --- | --- |
| Item 1 (circuito Wokwi + SQL) | Pronto; testes OK |
| Item 2 (firmware) | Pronto em simulação; suporta o kit físico (DHT11, LEDs, polaridade do relé); compila nos dois modos |
| Kit físico de bancada | ESP32 gravado com o teste de bancada pelo macOS; sensores, relé e LEDs ainda a ligar e validar |
| Item 3 (kit Docker) | Funciona; correções da revisão aplicadas e testadas (ver registro) |
| Ponta a ponta Wokwi → ponte → kit | **Aprovado** em 27/11/2026: roteiro do item 5 completo e queda de rede sem perda |
| Alertas e-mail/Telegram | Não implementado (pendente para integração) |
| Registro de taxa de quebra | Não existe (pendente para integração) |
| Hardware físico | Não montado |

## Registro de trabalho

### 26/11/2026 — sincronização com a versão ubuntu

- Branch `atualizacao-entrega-ubuntu` criada a partir do `main`.
- `Projeto_integrado/` da versão ubuntu copiado por cima do repositório; conferido com `diff -r`
  (idêntico). Entram: guia de montagem física, scripts PowerShell, `MQTT_BIND`, Node-RED Debian,
  correções `msg.dados` (Admin) e filtro de tempo do Grafana.
- Commit `833364b` (só a cópia da versão ubuntu, sem alterações).

### 26/11/2026 — correções para a simulação ficar estável

1. **Telemetria perdida quando o Node-RED reinicia.** Causa: o nó de broker do Node-RED tinha
   `autoUnsubscribe: true` (ao parar, cancela a assinatura da sessão persistente) e o Mosquitto não
   enfileira QoS 0 (o ESP32 publica QoS 0). Correção: `autoUnsubscribe: false` em
   `node-red/dados/flows.json` e `queue_qos0_messages true` + `max_queued_messages 5000` em
   `mosquitto/mosquitto.conf`. Teste: Node-RED parado, 3 telemetrias publicadas, Node-RED religado →
   antes 0/3 gravadas, depois **3/3**.
2. **Versão de configuração após recriar o banco.** O ESP32 físico guarda a versão na NVS; com o banco
   novo, `gravar_telemetria` não achava a versão e nenhum alerta de UR abria, e o Admin publicava
   versões que o ESP32 recusava ou "aceitava" sem aplicar (`ja_aplicada`). Correção em
   `postgres/02_integracao.sql`:
   - `gravar_telemetria`: versão desconhecida → alertas pela configuração ativa, leitura sem
     `configuracao_id`, aviso no resultado (`config vN desconhecida no banco...`).
   - nova `integracao.versao_config_dispositivo(sala)`: última `config_version` informada pelo ESP32.
   - `proxima_versao_config` passa a considerar essa versão; `estado_admin` devolve `versao_esp32`.
   - Admin (nó **Preencher campos**): mostra "ESP32 informa vN" quando difere do banco.
   - Testes novos T9 e T10 em `ferramentas/teste_funcoes.sql`.
   - O firmware não foi alterado (o projeto do Wokwi continua igual ao repositório).
3. **Índice** `telemetria_por_dispositivo_instante` em `02_integracao.sql` (o schema do item 1 segue
   sem alteração). Medido com 30 dias (518 mil linhas): 104–127 ms → 0,2–0,8 ms por leitura com UR alta.
4. **Nome do projeto Docker:** `COMPOSE_PROJECT_NAME` explícito no `.env.exemplo`, explicado no README
   do item 3 e no guia. O `.env` local desta máquina usa `mixnutri-equipe1` (os volumes antigos
   `mixnutri-item3_*` de 28/10 não foram tocados).
5. **Item 1 não compilava no PlatformIO** (`Nothing to build`): o filtro `-<*> +<sketch.ino>` exclui o
   `.ino.cpp` gerado. Corrigido para `+<*> -<testes-wokwi/> -<*.chip.c>` (mesmo padrão do item 2).
   `platform` fixado em `espressif32@8.0.0` nos dois `platformio.ini`.
6. **Documentação:** novo [`GUIA_SIMULACAO.md`](GUIA_SIMULACAO.md) (limpo a partir de
   `guia_simulacao_wokwi+docker.md` do pacote: sem os passos de "correção" que já estavam aplicados, com
   caminhos da raiz do repositório, tabela de problemas atualizada); links no README raiz; ordem do
   texto corrigida no README do item 2.

**Testes rodados depois das correções (stack do zero, projeto `mixnutri-equipe1`):**

| Teste | Resultado |
| --- | --- |
| `test_logica.cpp` / `test_models.c` | OK / OK |
| PlatformIO item 1 (diagnóstico) | OK, Flash 22,9% |
| PlatformIO item 2 (firmware) | OK, RAM 17,8%, Flash 77,6% |
| `reproduzir_log.py` | 114 mensagens, nenhuma rejeitada |
| `testar_acesso_mqtt.py` | 5/5 |
| `testar_admin.py` | 14/14 |
| `teste_funcoes.sql` | T1–T10 OK |
| `verificar_grafana.py` | `resultado: OK` |
| Restart do Node-RED | 3/3 telemetrias preservadas |

### 26/11/2026 — ponta a ponta com o Wokwi (parcial)

- Ponte ligada (`PONTE_BROKER=broker.hivemq.com:1883`) e projeto do item 2 aberto no Wokwi pelo
  navegador embutido do app. O BOOT (`b1-e9d6`) e a primeira telemetria chegaram ao banco local:
  o caminho Wokwi → HiveMQ → ponte → Node-RED → PostgreSQL funciona.
- O painel do navegador estava oculto e a simulação rodou a ~3% da velocidade: o ESP32 simulado
  perdia o keepalive e o HiveMQ derrubava a conexão (offline/online alternando). Simulação parada.
  **Refazer com o navegador visível** (ou no Chrome) e seguir o roteiro da seção 9 do guia.
- Observado: ao ligar a ponte, chega o `disponibilidade` **retido no HiveMQ** de execuções anteriores
  (de qualquer pessoa) e abre um `DISPOSITIVO_OFFLINE` falso até o ESP32 conectar. Baixo impacto.

### 27/11/2026 00:45–00:53 UTC — roteiro do item 5 ao vivo: APROVADO

Wokwi (projeto público do item 2, firmware igual ao do repositório) → HiveMQ → ponte → kit local com as
correções. Navegador visível: simulação a ~35–45% da velocidade real. Boot `b1-0289`.

| Passo | Resultado no banco |
| --- | --- |
| Admin → ESP32 (`testar_admin.py`): contexto, config v7 (UR máx 58, histerese 4, limiar −22 dBFS, banda 12), MANUAL ON, AUTO | 4 confirmações `aceito`; `CONFIG_APLICADA v7` registrada e ativa; telemetria passa a sair com `PRODUTO_TESTE / LOTE_TESTE_02` e config 7 |
| UR 45 → 60% | Evento `RELE` ON (`histerese`); `UR_ALTA` aberto após 60 s (valor 60, limite 58) |
| Tom do som 80 → 0% | `PARADA_INICIO` com produto/lote; alertas `PARADA_MAQUINA` e `UR_ALTA_E_PARADA` |
| Tom 0 → 80% | `PARADA_FIM` (duração 8 s, `retorno_operacao`); alertas da parada fechados |
| UR 60 → 49% | `RELE` OFF (`histerese`); `UR_ALTA` fechado |
| Serial `n` (rede bloqueada ~50 s) e `n` de novo | `FILA itens=4` durante a queda; depois 34 telemetrias, seq 0..33, **0 faltando**, 0 erros de gravação |

Observações:
- O relógio do ESP32 simulado fica atrás do real quando o Wokwi roda abaixo de 100% (ex.: medição
  00:48:18 recebida 00:52:48). Para ver ao vivo, usar **Horário das leituras → Recebimento (ao vivo)**.
- Com o painel do navegador oculto, o Wokwi cai para ~3% e o HiveMQ derruba a conexão por keepalive.
  Para demonstrações: navegador em primeiro plano.
- As credenciais do Grafana/Admin não são lidas pela IA; o login nas interfaces é feito pela pessoa.

### 27/11/2026 — capturas do Grafana

- Capturas reais do cenário acima salvas em [`docs/capturas/`](docs/capturas/) (visão geral + 6
  painéis em 800×450, prontas para o slide 12 e o memorial), com um README explicando cada uma.
- Como foram tiradas: painel isolado por URL
  `/d-solo/mixnutri-sala01?panelId=N&from=...&to=...&var-relogio_leituras=medicao` no navegador do app,
  após o login feito pela pessoa (a IA não lê senhas do `.env`). Ids: 2 UR/temperatura, 3 ruído,
  4 relé/modo, 5 linha do tempo de paradas, 6 paradas, 7 alertas.
- Para captura em resolução maior: abrir a mesma URL num navegador com janela grande.

### 27/11/2026 — commits e PR

- Branch `atualizacao-entrega-ubuntu` enviada ao GitHub com dois commits: `833364b` (versão ubuntu sem
  alterações) e `bd6c929` (correções, guias, progresso e capturas).
- PR aberto para o `main`: https://github.com/viniciusvdct/DAC-MIXNUTRI/pull/1 (sem conflitos; o
  repositório não tem CI).
- Ambiente local deixado no ar: projeto Docker `mixnutri-equipe1` com `PONTE_BROKER` ligado no `.env`
  local. Para desligar a ponte: apagar o valor de `PONTE_BROKER` e `docker compose up -d mosquitto`;
  para parar tudo: `docker compose --profile modbus down` (mantém os volumes).

### 27/11/2026 — PR #1 mergeado

- PR #1 mergeado no `main` (merge commit `774e8ff`, preserva os três commits). O `main` passa a ser a
  versão atual da equipe 1. A branch `atualizacao-entrega-ubuntu` continua no GitHub.
- Próxima fase combinada: hardware físico.

### 27/11/2026 — hardware: preparação da bancada (branch `hardware-bancada`)

Lista de peças informada pela equipe: ESP32-WROOM-32 DevKit 30 pinos, **DHT11** de 4 pinos (no lugar do
SHT31), módulo relé 5 V Tongling JQC-3FF-S-Z, **microfone P2 mono TS** (no lugar do MAX9814) e LEDs
verde, amarelo e vermelho; resistores e protoboard disponíveis.

O que foi feito:
- `item2-firmware/firmware/hardware_fisico.h` (no git, sem senhas): `CLIMA_DHT11 1`, `PIN_DHT 4`,
  `PIN_LED_PARADA 25` (amarelo), `PIN_LED_ALERTA 27` (vermelho), `RELE_ATIVO_EM_HIGH 1`. Só é incluído
  quando `MIXNUTRI_SIMULACAO = 0` (config_local.h); o Wokwi continua com SHT31 e não muda.
- Firmware (`sketch.ino`): leitura do DHT11 a cada 2 s (Adafruit DHT), evento `SENSOR_FALHA` com
  `"sensor":"DHT11"`, polaridade do relé configurável, LED vermelho = UR ≥ ur_liga (pisca na falha do
  sensor), LED amarelo = máquina PARADA, linha `HARDWARE clima=... rele_ativo_em=...` no boot.
  Compila nos dois modos sem avisos novos (Wokwi: Flash 77,6%; kit físico: 76,0%). Testes de lógica OK.
- **Teste de bancada** `item2-firmware/bancada/` (sem rede): uma linha por segundo com DHT11, som
  (média DC, RMS, dBFS, mín/máx, diagnóstico de polarização/saturação) e nível do relé; comandos
  `h`/`l`/`r` (relé), `t`/`1`/`2`/`3` (LEDs), `d` (DHT11), `c` (calibração do som por 10 s com
  percentis e sugestão de limiares).
- Scripts macOS/Linux: `item2-firmware/gravar_esp32.sh [bancada|firmware] [tudo|compilar|gravar|monitor]`
  (detecta a porta) e `item3-integracao/ferramentas/preparar_esp32.sh` (pede SSID/senha no terminal sem
  mostrar, grava `config_local.h` com as credenciais MQTT do `.env`, `MQTT_BIND` = IP da rede local,
  desliga `PONTE_BROKER`, recria o Mosquitto). Testado numa cópia: escape de aspas/barras, permissão
  600, `.env` preservado.
- Mosquitto publicado no IP da rede local do Mac pelo OrbStack: ACL 5/5 por esse IP; depois
  voltou para 127.0.0.1 (o `.env` local ainda está com a ponte HiveMQ e 127.0.0.1).
- `GUIA_MONTAGEM_FISICA.md` reescrito para o kit novo (peças, ligações, circuito de polarização do
  microfone, teste de bancada, rede, gravação, LEDs, problemas, Windows). README atualizado.

Placa real:
- ESP32 em `/dev/cu.usbserial-0001`; gravado com o teste de bancada (upload OK). Com a placa sem nada
  ligado: LEDs de teste ok no boot, `DHT11 FALHA` e som `SEM POLARIZACAO` (GPIO 34 flutuando, média ~68)
  — esperado antes da montagem.

Decisões:
- Microfone P2 assumido como **eletreto** (comum em P2 de PC/lapela): 2,2 kΩ para 3V3 + capacitor
  1–10 µF + divisor 2× 100 kΩ centralizando em 1,65 V. Se for dinâmico, o sinal é fraco demais sem
  amplificador. O firmware exige média do ADC entre 200 e 3900 (senão "sensor ausente").
- Polaridade do relé a confirmar na bancada (`h`/`l`); módulos ativos em LOW com optoacoplador podem
  não desligar com 3,3 V.

## Alinhamento com as equipes 2 e 3 (análise de 27/11/2026)

**Situação.** A entrega das equipes 2 e 3 ("Solução - MixNutri - Dashboard + BD", guardada no pacote
como `Referencia_dashboard_BD_original/`) usa um contrato diferente do firmware. O pacote integrado
(`LEIA-ME-ENVIO.md`) já diz que a execução usa o kit da equipe 1 (`Projeto_integrado/item3-integracao`)
e mantém a entrega delas só como referência. O que falta é **as três equipes confirmarem essa decisão**
e trazer para o kit o que só existe na entrega delas. O "como" de cada diferença já está em
[`item3-integracao/docs/guia-integracao-equipe2.md`](item3-integracao/docs/guia-integracao-equipe2.md).

Diferenças entre a entrega delas e o firmware (contrato v2):

| Ponto | Equipes 2/3 | Firmware / kit da equipe 1 |
| --- | --- | --- |
| Prefixo MQTT | `iotmixnutri/sala01/` | `mixnutri/sala01/` |
| Comando | `comando`, retido, `{"modo","desumidificador"}` | `comandos`, **sem** retain, com `cmd_id`, `rele`, `validade_s`, `ts` |
| Configuração | `{"umidade_max_pct","histerese_pct","ruido_operacional_db","parada_segundos"}` | `{"versao","cmd_id","ur_max","histerese","limiar_db","banda_db"}` com versão crescente |
| Telemetria | `timestamp`, `ruido_db` (dB), `desumidificador`, `origem: esp32` | `timestamp_utc`+`clock_synced`, `nivel_ruido` em **dBFS** (negativo), `desumidificador_comandado`, `origem_dados`, `fonte_estado`, produto/lote |
| Paradas | Classificadas no Node-RED pela telemetria | Classificadas no ESP32; eventos `PARADA_INICIO/FIM`, fechadas no `BOOT` |
| Tópicos extras | — | `eventos`, `confirmacoes`, `disponibilidade`, `contexto` (produto/lote) |
| Broker | Anônimo | Usuário/senha e ACL por tópico |
| Banco | Tabelas próprias (`alertas_sala01`, `origem` sem `esp32`) | Schema v2 do item 1 + `integracao.*` |
| Modbus | HR3 máquina, HR5 falha | Compatível (mesmo mapa) |

Consequência: **sem essa decisão, o ESP32 não conversa com a entrega delas** (tópicos e campos
diferentes; com limiar de 60 dB e ruído em dBFS negativo, toda leitura viraria PARADO).

O que só existe na entrega delas e precisa vir para o kit integrado:
1. Envio de alertas por **Telegram e e-mail** (nós `telegram-ready`/`email-ready`, `nodemailer`).
2. Aba **S7Comm** (desabilitada; depende de `node-red-contrib-s7`).
3. No Admin, a **duração mínima da parada** (`parada_segundos`); o firmware já aceita
   `confirmar_parado_ms` na configuração, mas o Admin v2 não tem o campo.
4. Visual/identidade do Admin e do Grafana que elas fizeram.

O que é de todos (ninguém tem ainda):
5. **Registro da taxa de quebra** por lote/turno (objetivo central do desafio): tabela, formulário no
   Admin e painel no Grafana.
6. **Memorial técnico integrado**: o `memorial-etapas-3-4.md` delas descreve o contrato antigo
   (`iotmixnutri`, broker anônimo, `alertas_sala01`); precisa ser reescrito para o que roda.
7. Um **contrato único**: adotar o `contrato-mqtt-v2.md` e aposentar o `contrato-integracao.md` delas.
8. Tirar os rótulos "proposta da equipe 1" / "não é a entrega da equipe 2" do kit (fluxos do Node-RED,
   pasta e título do painel no Grafana, aba do Admin) e dar o crédito às três equipes.
9. Demonstração: em qual computador roda o servidor, qual rede Wi-Fi o ESP32 usa e como o `.env`
   (senhas) é passado entre as pessoas sem ir para o git ou para grupo de mensagem.
10. Recomendações de controle ambiental (entregável 3) e vídeo pitch.

## Pendências

1. **Bancada:** montar conforme o guia, rodar `./gravar_esp32.sh bancada` e validar LEDs, DHT11, relé
   (polaridade → `hardware_fisico.h`) e microfone (polarização + calibração `c` em silêncio e com ruído).
2. **Firmware completo no kit:** `preparar_esp32.sh` (Wi-Fi) → `./gravar_esp32.sh firmware` → conferir
   `wifi=1 mqtt=1`, Admin (limiares da calibração, UR máx perto da umidade da sala) e Grafana.
3. Opcional no firmware (exige atualizar o projeto do Wokwi): responder `ja_aplicada` só se os valores
   forem iguais; contador `descartes` atômico; padrão Modbus 3/5 como no simulador.
4. Integração com equipes 2 e 3: confirmar que o kit da equipe 1 é o backend integrado e seguir a
   lista da seção "Alinhamento com as equipes 2 e 3".
5. Commitar a branch `hardware-bancada` (teste de bancada, suporte a DHT11, scripts e guia) — ainda local.
