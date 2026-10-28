# Item 2 — firmware do ESP32

Firmware da sala piloto. Roda no mesmo circuito do [item 1](../item1-circuito-sql).

| Pasta | Conteúdo |
| --- | --- |
| `firmware/` | `sketch.ino`, `logica.h` (lógica testável no computador), `modbus_cliente.h`, `config_wokwi.h` (rede do Wokwi), `config_local.h.exemplo` (rede do ESP32 real), `partitions.csv`, `libraries.txt`, circuito, chips e testes |
| `ferramentas/mqtt_mini.py` | Cliente MQTT mínimo em Python, sem dependências, para ver e mandar mensagens |
| `exemplos/mqtt-exemplo.log` | Mensagens reais publicadas pelo firmware no Wokwi, com dados sintéticos |

## O que faz

| Função | Como funciona |
| --- | --- |
| Controle de umidade | Liga em `ur_liga` (55%), desliga em `ur_desliga` (50%) e mantém o estado entre os dois. Espera 10 s entre comutações. Com o sensor em falha, desliga |
| Parada da máquina | Lê o som a 4 kHz e calcula o nível em dBFS. Acima de −25 dBFS por 3 s = OPERANDO; abaixo de −35 dBFS por 5 s = PARADO. Gera `PARADA_INICIO` e `PARADA_FIM` com duração, produto e lote |
| Comandos | MANUAL ligado/desligado com validade (padrão 15 min); depois volta sozinho para AUTO. Recusa comando repetido, vencido ou inválido |
| Configuração | Limites, histerese e limiar de ruído com versão crescente; o pedido inteiro é validado antes de aplicar, e a configuração fica salva na memória |
| Produto e lote | Recebidos pelo tópico `contexto`, salvos e enviados em toda mensagem |
| Sem rede | Guarda até 192 mensagens na Flash e reenvia em ordem quando a conexão volta, inclusive depois de reiniciar |
| Modbus TCP | Lê o estado da máquina do CLP, se habilitado pela configuração. Vem desligado |

Os valores são demonstrativos e podem ser mudados pelo tópico `configuracao`.

## Rodar no Wokwi

**Jeito rápido:** abra o [projeto pronto](https://wokwi.com/projects/479080199406642177) e clique em ▶.

**Montando do zero:** crie um [projeto ESP32 novo](https://wokwi.com/projects/new/esp32). Pelo menu ▼ das abas → "New file…", crie `logica.h`, `modbus_cliente.h`, `config_wokwi.h`, `libraries.txt`, `partitions.csv` e os quatro arquivos dos chips, e cole o conteúdo da pasta `firmware/`. Substitua `sketch.ino` e `diagram.json`. A `partitions.csv` é necessária: sem ela, o Wokwi não tem espaço na Flash para a fila.

No primeiro boot aparecem erros `esp_littlefs ... Corrupted dir pair`: é a Flash vazia sendo formatada. Em seguida vem `FILA flash_ok=1`.

No serial aparecem linhas `ST` (estado a cada 2 s), `TEL` (telemetria a cada 5 s), `EVT` (eventos) e `ACK` (respostas). Comandos:

| Digite | Faz |
| --- | --- |
| `1` / `0` | MANUAL ligado / desligado |
| `a` | Volta para AUTO |
| `n` | Simula queda de rede (de novo para voltar) |
| `f` | Mostra a fila da Flash |
| `r` | Reinicia o ESP32 |
| `s` | Envia uma telemetria agora |
| `cmd {...}`, `cfg {...}`, `ctx {...}` | Mesmo JSON dos tópicos `comandos`, `configuracao` e `contexto` |

No Wokwi, o MQTT usa o broker público `broker.hivemq.com`, só para demonstração. Para ver as mensagens de fora:

```sh
python3 ferramentas/mqtt_mini.py sub broker.hivemq.com 'mixnutri/sala01/#' mensagens.log
python3 ferramentas/mqtt_mini.py pub broker.hivemq.com mixnutri/sala01/comandos '{"cmd_id":"c1","modo":"AUTO"}'
```

Qualquer pessoa pode ler e publicar nesse broker. Use só dados de teste.

## Gravar no ESP32 de verdade

A rede e o broker ficam fora do `sketch.ino`:

1. Copie `firmware/config_local.h.exemplo` para `firmware/config_local.h`.
2. Preencha o Wi-Fi de 2,4 GHz, o endereço, o usuário e a senha do broker da equipe 2. `MIXNUTRI_SIMULACAO` já vem `0`, para marcar os dados como reais.
3. Compile para **ESP32 Dev Module** com a tabela `partitions.csv` e as bibliotecas PubSubClient e ArduinoJson 7. O `platformio.ini` já tem tudo isso.

Com o `config_local.h` presente, o sketch usa ele no lugar do `config_wokwi.h`. Esse arquivo fica fora do git, porque tem senhas. Se o módulo relé for ativo em LOW, inverta `RELE_ON` e `RELE_OFF`. A gravação na placa física ainda não foi testada.

O `boot_id` de cada mensagem junta o contador de reinícios com um número aleatório (ex.: `b3-7f3a`). Assim ele não se repete nem quando a memória do ESP32 é apagada, e o banco não confunde mensagens novas com antigas.

## Mensagens MQTT

Base `mixnutri/sala01`. O formato completo está no [contrato MQTT](../item3-integracao/docs/contrato-mqtt-v2.md).

| Tópico | Sentido | Exemplo |
| --- | --- | --- |
| `telemetria` | ESP32 → servidor | Clima, ruído em dBFS, estado da máquina, modo, relé, produto e lote, `boot_id` e `seq` |
| `eventos` | ESP32 → servidor | `BOOT`, `RELE`, `PARADA_INICIO`, `PARADA_FIM`, `SENSOR_FALHA`, `CONFIG_APLICADA`… |
| `confirmacoes` | ESP32 → servidor | `{"cmd_id":"c1","aceito":false,"motivo":"comando_vencido",...}` |
| `comandos` | Admin → ESP32 | `{"cmd_id":"c1","modo":"MANUAL","rele":"ON","validade_s":600,"ts":1793142591}` — **sem retain** |
| `configuracao` | Admin → ESP32 | `{"versao":2,"ur_max":58,"histerese":4,"limiar_db":-22,"banda_db":12}` |
| `contexto` | Admin → ESP32 | `{"produto":"X","lote_producao":"L1","lote_capsula":"C1"}` |

## Testes da lógica

Rodam no computador, sem ESP32:

```sh
cd firmware
clang++ -std=c++17 -Wall -Wextra -Werror -I . testes/test_logica.cpp -o /tmp/logica && /tmp/logica
```

Cobrem histerese, tempo mínimo, MANUAL e expiração, classificação do som, eventos de parada, quadros Modbus e a fila circular.

O cliente Modbus (`modbus_cliente.h`, o mesmo código do ESP32) também tem um teste por rede, contra o simulador Modbus do [kit do item 3](../item3-integracao):

```sh
(cd ../item3-integracao && docker compose --profile modbus up -d modbus-sim)
clang++ -std=c++17 -Wall -Wextra -Werror -I . testes/test_modbus_rede.cpp -o /tmp/modbus-rede && /tmp/modbus-rede 127.0.0.1 5020
```

O teste lê os registradores, confere a exceção de endereço inválido, acompanha a máquina passando de OPERANDO para PARADO e confere que um servidor fora do ar vira DESCONHECIDO.

O `firmware/wokwi.toml` e o `firmware/testes/wokwi/item2.test.yaml` permitem rodar pelo [wokwi-cli](https://github.com/wokwi/wokwi-cli), mas esse caminho ainda não foi testado.

## Limites

O som do Wokwi é sintético, e dBFS não é dB SPL: os limiares precisam ser medidos na máquina real. O cliente Modbus foi testado contra o simulador; o mapa de registradores do CLP real depende da empresa.
