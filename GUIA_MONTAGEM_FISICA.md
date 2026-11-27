# Preparação e montagem física — MixNutri

Este roteiro liga o ESP32 do item 2 ao Mosquitto, PostgreSQL, Node-RED e Grafana do item 3. Foi verificada a integração com mensagens sintéticas pela rede local e a compilação do firmware. A placa, os sensores e o relé reais ainda precisam ser testados após a montagem.

## 1. Separe e confira as peças

- ESP32 DevKit V1 (ou placa compatível com o alvo `esp32dev`) e cabo USB **de dados**.
- Módulo SHT31 com endereço I²C `0x44` e alimentação de 3,3 V.
- Módulo de microfone **MAX9814** com saída analógica compatível com a entrada do ESP32 (sinal entre 0 e 3,3 V).
- Módulo relé cuja entrada `IN` aceite o nível de 3,3 V do GPIO 26; confirme a tensão de alimentação exigida pelo módulo.
- Protoboard, jumpers, LED, resistor de 330 Ω e, se o SHT31 não trouxer pull-ups na placa, dois resistores de 4,7 kΩ.
- Computador com Docker Desktop e a pasta deste projeto. O ESP32 e o computador precisam acessar a mesma rede local; o ESP32 usa Wi-Fi de 2,4 GHz.

Confira no rótulo ou na documentação dos módulos reais a posição dos pinos antes de ligar os fios. Diferentes placas podem ter ordens de pinos e tipos de relé diferentes.

## 2. Prepare o computador e a rede

1. Escolha uma rede Wi-Fi de 2,4 GHz que permita que dispositivos se comuniquem entre si. Evite rede de convidados e isolamento de clientes. O computador pode estar no Ethernet da mesma rede local.
2. Inicie o Docker Desktop. Abra um PowerShell na pasta `item3-integracao` e rode `docker compose ps`. Os serviços `mosquitto`, `postgres`, `node-red` e `grafana` devem aparecer como `healthy`. Se não estiverem iniciados, rode `docker compose up -d --build` e confira novamente.
3. Tenha o nome e a senha do Wi-Fi em mãos. A senha será digitada diretamente no PowerShell, sem ser enviada por mensagem. O script usa as credenciais MQTT que já estão no `.env` local.
4. Se possível, reserve no roteador o IP do computador. Se esse IP mudar depois, será necessário reconfigurar o broker e gravar o ESP32 novamente.

## 3. Faça as ligações com tudo desligado

Retire o USB do ESP32 antes de colocar ou mover jumpers. Use o mesmo GND do ESP32 para os módulos.

| Peça | Pino da peça | Ligação |
| --- | --- | --- |
| SHT31 | VCC / GND | ESP32 3V3 / GND |
| SHT31 | SDA / SCL | ESP32 GPIO 21 / GPIO 22 |
| SHT31, se necessário | Pull-up SDA / SCL | Cada linha por 4,7 kΩ até 3V3; confira se a placa já os inclui |
| MAX9814 | VDD / GND / OUT analógico | ESP32 3V3 / GND / GPIO 34 |
| Módulo relé | VCC / GND / IN | ESP32 VIN / GND / GPIO 26, **somente se** o módulo aceitar essas tensões |
| Teste dos contatos do relé | COM / NO | ESP32 3V3 → COM; NO → resistor 330 Ω → anodo do LED; catodo do LED → GND |

O firmware considera `HIGH` no GPIO 26 como relé ligado. Há um LED de status de rede no GPIO 2 da placa, quando presente. O SHT31 é lido no endereço `0x44`; confira a seleção de endereço do módulo.

**Use apenas o LED como carga de teste nesta etapa.** Não conecte equipamento de rede elétrica aos contatos do relé durante a validação do protótipo. A instalação de uma carga de rede elétrica exige dimensionamento e montagem por profissional habilitado.

## 4. Configure a rede do ESP32 e do broker

Com o Docker Desktop iniciado, abra PowerShell **como Administrador** na pasta `item3-integracao` e execute:

```powershell
.\ferramentas\preparar_esp32.ps1 -ConfigureFirewall
```

Digite o nome e a senha do Wi-Fi quando solicitado. O script detecta o IP da rede local, grava `item2-firmware/firmware/config_local.h`, configura o Mosquitto nesse IP e cria uma regra de firewall limitada à sub-rede local. Se houver mais de uma rede local ativa, acrescente `-BrokerIp 192.168.x.x` com o endereço correto do computador. Não compartilhe o `config_local.h`: ele contém senhas.

Se repetir a preparação depois que o arquivo já existir, acrescente `-Force`. Se o computador mudar de IP, repita a preparação com `-Force -ConfigureFirewall` **e grave novamente o ESP32**.

## 5. Grave o firmware

1. Conecte o ESP32 por USB. No Gerenciador de Dispositivos do Windows, veja a porta da placa em **Portas (COM e LPT)**. Se não aparecer, teste outro cabo USB de dados ou instale o driver USB indicado pelo fabricante da sua placa.
2. Abra PowerShell na pasta `item2-firmware` e substitua `COMx` pela porta encontrada:

```powershell
.\compilar_esp32.ps1 -Upload -Port COMx
```

O script usa PlatformIO e contorna o problema do linker com o caminho acentuado desta pasta. Ele impede o envio quando `config_local.h` ainda não existe.

## 6. Verifique primeiro o ESP32, depois a aplicação

Abra o monitor serial na mesma pasta:

```powershell
.\compilar_esp32.ps1 -Monitor -Port COMx
```

1. Espere a inicialização e confira `FILA flash_ok=1` e `REDE wifi=1 mqtt=1`. As linhas `ST` devem mostrar temperatura, umidade, som e estado do relé. `TEL` indica envio de telemetria.
2. Abra [Grafana](http://127.0.0.1:3000) no computador, entre com o usuário e a senha `GRAFANA_ADMIN_*` do `.env` local e selecione o painel **MixNutri sala01**. Ajuste o período para os últimos 15 minutos e atualize. Devem aparecer novos pontos de temperatura, umidade e ruído.
3. Abra o [Admin](http://127.0.0.1:1880/dashboard/admin), usando `NODERED_ADMIN_*` do `.env`. Defina produto e lote e confira depois se as mensagens e os gráficos continuam chegando.
4. Teste o relé apenas com o LED: use o controle manual do Admin, observe a comutação e confirme que `HIGH` corresponde a ligado. Volte ao modo AUTO. Verifique então a resposta à umidade.
5. Teste o som com a máquina em condições conhecidas de parada e operação. O projeto registra **dBFS**, não dB SPL. Ajuste os limiares no Admin com medições reais antes de confiar na classificação de parada.

## 7. Se algo não funcionar

| Sintoma | Conferir primeiro |
| --- | --- |
| Porta COM ausente | Cabo USB de dados, driver USB da placa, outra porta USB |
| `wifi=0` | Nome e senha, rede 2,4 GHz, alcance, rede não isolada; refaça etapa 4 e regrave |
| `wifi=1 mqtt=0` | Docker e Mosquitto `healthy`, IP atual do computador, porta TCP 1883 e regra de firewall; refaça etapa 4 se o IP mudou |
| `clima=FALHA` | Alimentação do SHT31, SDA 21, SCL 22, GND, pull-ups e endereço `0x44` |
| Som sem variação | Saída **analógica** ligada ao GPIO 34, alimentação, GND e faixa de sinal até 3,3 V |
| Relé invertido ou sem comutação | Nível ativo HIGH/LOW, tensão de alimentação do módulo e aceitação de 3,3 V em `IN` |
| Serial transmite, mas gráfico não atualiza | Janela de tempo do Grafana, `node-red` e `postgres` saudáveis, `mqtt=1` no serial |

Referências do próprio projeto: [pinagem e circuito](item1-circuito-sql/README.md), [firmware](item2-firmware/README.md), [kit de integração](item3-integracao/README.md).
