# Montagem e teste do kit físico — MixNutri (equipe 1)

Roteiro para montar o kit de bancada, testar cada peça sem rede e depois ligar o ESP32 ao Mosquitto,
PostgreSQL, Node-RED e Grafana do item 3. Os comandos são para **macOS/Linux** (no Windows, veja a
seção 8).

O kit físico usa peças diferentes das do Wokwi: **DHT11** no lugar do SHT31 e **microfone P2** no lugar
do MAX9814. A configuração dele fica em
[`item2-firmware/firmware/hardware_fisico.h`](item2-firmware/firmware/hardware_fisico.h); a simulação
no Wokwi continua igual.

## 1. Peças

| Qtd. | Peça | Uso |
| --- | --- | --- |
| 1 | ESP32-WROOM-32 DevKit, 30 pinos | Controlador. O LED azul da placa (GPIO 2) indica a rede |
| 1 | DHT11, 4 pinos (sensor sem placa) | Temperatura e umidade |
| 1 | Módulo relé 5 V com relé JQC-3FF-S-Z | Liga o "desumidificador" (aqui, o LED verde) |
| 1 | Microfone P2 mono (TS) | Ruído da máquina |
| 1 | LED verde | Carga do relé (desumidificador simulado) |
| 1 | LED amarelo | Máquina **parada** |
| 1 | LED vermelho | Umidade **acima do limite**; pisca se o DHT11 falhar |
| 4 | Resistor 330 Ω | Um por LED externo, e um de reserva |
| 1 | Resistor 10 kΩ | Pull-up do DHT11 |
| 1 | Resistor 2,2 kΩ | Polarização do microfone de eletreto |
| 2 | Resistor 100 kΩ | Centraliza o sinal do microfone em 1,65 V |
| 1 | Capacitor eletrolítico de 1 a 10 µF (recomendado) | Acopla o microfone ao ESP32 |
| — | Protoboard, jumpers e cabo USB **de dados** | Montagem, gravação e alimentação |

Para ligar o P2: um conector P2 fêmea para protoboard ou duas garras jacaré no plugue
(**ponta = sinal**, **corpo/manga = GND**).

## 2. Ligações

Faça as ligações **com o USB desconectado**. Todos os GND juntos.

| Peça | Pino da peça | ESP32 (DevKit 30 pinos) |
| --- | --- | --- |
| DHT11 | 1 VCC | 3V3 |
| DHT11 | 2 DATA | **D4** (GPIO 4), com 10 kΩ entre DATA e 3V3 |
| DHT11 | 3 | não ligar |
| DHT11 | 4 GND | GND |
| Relé | VCC (+) | **VIN** (5 V do USB) |
| Relé | GND (−) | GND |
| Relé | IN (S) | **D26** (GPIO 26) |
| Relé | COM / NO | 3V3 → COM; NO → 330 Ω → LED verde (perna longa) → LED (perna curta) → GND |
| LED amarelo | perna longa | **D25** (GPIO 25) → 330 Ω → LED → GND |
| LED vermelho | perna longa | **D27** (GPIO 27) → 330 Ω → LED → GND |
| Microfone | ponta (T) | circuito abaixo → **D34** (GPIO 34, entrada analógica) |
| Microfone | manga (S) | GND |

Pinagem do DHT11 de 4 pinos: com a grade voltada para você e os pinos para baixo, da esquerda para a
direita: 1 VCC, 2 DATA, 3 sem ligação, 4 GND.

### Circuito do microfone

Um microfone de eletreto (o comum em microfones P2 de computador e de lapela) precisa de alimentação
pelo resistor de 2,2 kΩ. O ESP32 só lê tensões positivas, então o sinal é centralizado em ~1,65 V pelos
dois resistores de 100 kΩ:

```text
 3V3 ──[ 2,2 kΩ ]──┬──────────── ponta (T) do P2
                   │
                  (+)
             capacitor 1–10 µF
                  (−)
                   │
 3V3 ──[ 100 kΩ ]──┼──[ 100 kΩ ]── GND
                   │
                 GPIO 34
 manga (S) do P2 ───────────────── GND
```

**Sem capacitor:** ligue a ponta direto no GPIO 34, com apenas o 2,2 kΩ até 3V3 (sem os 100 kΩ). Se o
teste de bancada mostrar a média fora da faixa, troque o 2,2 kΩ por 4,7 kΩ ou 10 kΩ.

Limites deste microfone:
- Sem amplificador o sinal é fraco. Na bancada ele mostra palmas, voz alta ou o celular tocando perto;
  na fábrica, precisa ficar perto do motor.
- Se o microfone for **dinâmico** (de karaokê, sem pilha nem alimentação), o sinal fica fraco demais
  sem amplificador. Use um de eletreto ou um módulo com amplificador (MAX9814, KY-037 analógico).

## 3. Teste de bancada (sem rede)

O teste de bancada ([`item2-firmware/bancada/bancada.ino`](item2-firmware/bancada/bancada.ino)) mede
cada peça e mostra uma linha por segundo no monitor serial. Ele não usa Wi-Fi nem o servidor.

```bash
cd item2-firmware
./gravar_esp32.sh bancada
```

Na primeira vez o script instala o PlatformIO em `item2-firmware/.venv` e baixa o toolchain do ESP32
(~1 GB). A porta (`/dev/cu.usbserial-…`) é detectada sozinha. Sair do monitor: `Ctrl+C`.

Ao ligar, os LEDs amarelo, vermelho e azul acendem um por vez. Depois aparece uma linha como esta:

```text
UR=58% T=26.0C | SOM media=2040 (~1.64 V) rms=6.2 dBFS=-50.4 min=2010 max=2075 ok | RELE=LOW
```

Digite no monitor e confira:

| Teste | Como | Esperado | Se não der certo |
| --- | --- | --- | --- |
| LEDs | `t` (ou `1`, `2`, `3`) | Amarelo, vermelho e azul acendem | Perna longa/curta invertida; resistor; pino D25/D27 |
| DHT11 | Observe a linha; sopre no sensor | `UR=..% T=..C`; a UR sobe ao soprar | `DHT11 FALHA`: resistor de 10 kΩ, pino D4, ordem dos pinos, 3V3 |
| Relé | `h` e depois `l` | Estalo e LED verde aceso com **um** dos dois | Veja abaixo |
| Microfone (polarização) | Observe `media` | Entre ~1000 e ~3000 e `ok` | `SEM POLARIZACAO`: circuito do microfone; `SATURANDO`: polarização fora do centro |
| Microfone (sinal) | Bata palmas perto | `dBFS` sobe vários dB e volta | Sinal fraco: aproxime a fonte; confirme que é eletreto |
| Calibração do som | `c` em silêncio; `c` com ruído | Relatório com mediana e p90 de cada caso | Diferença pequena: aproxime o microfone da fonte |

**Relé:** se o LED verde acende com `h` (HIGH), deixe `RELE_ATIVO_EM_HIGH 1` em `hardware_fisico.h`.
Se acende com `l` (LOW), troque para `0`. Se o relé fica sempre ligado, o módulo é ativo em LOW com
optoacoplador e os 3,3 V do ESP32 não bastam para desligá-lo; anote o modelo do módulo e use outro
módulo ou um transistor.

**Limiares de som:** o relatório de `c` sugere os valores. No Admin, *Limiar operando* recebe o p10 do
caso com ruído menos 3 dB, e *Banda até parado* recebe a diferença até o p90 do silêncio mais 3 dB.
Os padrões (−25/−35 dBFS) servem para o Wokwi e quase certamente não servem para este microfone.

## 4. Prepare a rede e o servidor

1. Suba o kit do item 3 (veja o [guia de simulação](GUIA_SIMULACAO.md), seções 3 e 4) e deixe o
   computador e o ESP32 na **mesma rede Wi-Fi de 2,4 GHz**, sem isolamento de clientes (evite rede de
   convidados).
2. Em `item3-integracao`, rode:

   ```bash
   ferramentas/preparar_esp32.sh
   ```

   O script descobre o IP do computador, pede o nome e a senha do Wi-Fi (a senha não aparece), grava
   `item2-firmware/firmware/config_local.h` com as credenciais MQTT do `.env`, publica o Mosquitto nesse
   IP e desliga a ponte com o broker público. Se houver mais de uma rede, use `--ip 192.168.x.y`. Se o
   IP mudar depois, rode de novo com `--force` e regrave o ESP32.
3. No macOS, se aparecer a pergunta sobre conexões de entrada para o Docker/OrbStack, permita.

O `config_local.h` tem senhas: fica fora do git e não deve ser compartilhado.

## 5. Grave o firmware completo

```bash
cd item2-firmware
./gravar_esp32.sh firmware
```

No monitor serial, confira:

1. `HARDWARE clima=DHT11 rele_ativo_em=HIGH` (ou `LOW`, conforme o teste do relé).
2. `FILA flash_ok=1` e `REDE wifi=1 mqtt=1`. O LED azul fica aceso quando o MQTT conecta (pisca
   devagar: só Wi-Fi; rápido: sem Wi-Fi).
3. Linhas `ST` a cada 2 s e `TEL` a cada 5 s, com `origem_dados` `real`.

LEDs no firmware completo:

| LED | Aceso quando |
| --- | --- |
| Verde (contatos do relé) | Desumidificador comandado ligado |
| Vermelho | UR ≥ limite de ligar; pisca se o DHT11 falhar |
| Amarelo | Máquina PARADA (som abaixo do limiar por 5 s) |
| Azul (placa) | MQTT conectado |

## 6. Verifique no Admin e no Grafana

1. Abra o [Admin](http://127.0.0.1:1880/dashboard/admin) (`NODERED_ADMIN_*` do `.env`). Informe produto
   e lote e publique. Ajuste *UR máxima* perto da umidade da sala (o DHT11 lê de 20 a 90 %UR, com
   ±5 %UR) e os limiares de som da calibração. Aguarde as confirmações `aceito`.
2. Abra o [Grafana](http://127.0.0.1:3000) (`GRAFANA_ADMIN_*`), painel **MixNutri sala01**, últimos
   15 minutos. Com o ESP32 físico, o relógio vem do NTP e o seletor **Medição (ESP32)** funciona.
3. Roteiro rápido: sopre no DHT11 (UR sobe → vermelho e relé/verde ligam), faça silêncio por 5 s
   (amarelo acende, parada registrada), faça barulho de novo (parada encerra). No Admin, mande MANUAL e
   AUTO e veja o relé obedecer.

## 7. Problemas comuns

| Sintoma | Conferir |
| --- | --- |
| `Nenhuma placa USB encontrada` | Cabo de **dados** (muitos cabos só carregam), outra porta USB. Placas com chip CH340 em macOS antigo podem precisar do driver do fabricante |
| Falha ao gravar (`Failed to connect`) | Segure o botão **BOOT** da placa quando aparecer `Connecting...` |
| `wifi=0` | Rede de 2,4 GHz, nome e senha; rode `preparar_esp32.sh --force` e regrave |
| `wifi=1 mqtt=0` | IP do computador mudou; Mosquitto `healthy`; firewall do macOS; mesma rede, sem isolamento |
| `DHT11 FALHA` ou `clima=FALHA` | Pull-up de 10 kΩ, pino D4, ordem dos pinos, alimentação 3V3 |
| Som sempre `DESCONHECIDO` | Média fora de 200–3900: circuito do microfone (seção 2) |
| Máquina sempre PARADA ou sempre OPERANDO | Limiares do Admin; refaça a calibração `c` |
| Relé não desliga | Módulo ativo em LOW com 3,3 V: veja o teste do relé (seção 3) |

Não ligue carga de rede elétrica (127/220 V) no relé durante os testes. Um desumidificador real exige
dimensionamento e instalação por profissional habilitado.

## 8. Windows

No PowerShell: `item3-integracao\ferramentas\preparar_esp32.ps1` (como Administrador, com
`-ConfigureFirewall`) e `item2-firmware\compilar_esp32.ps1 -Upload -Port COMx`. O teste de bancada
compila com `pio run -d item2-firmware\bancada -t upload --upload-port COMx`.
