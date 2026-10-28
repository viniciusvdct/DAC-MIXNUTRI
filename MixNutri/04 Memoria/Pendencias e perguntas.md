---
projeto: MixNutri
equipe: 1
tipo: pendencias
status: aberto
criado: 2026-10-26
atualizado: 2026-10-28
tags:
  - mixnutri
  - equipe1
---

# Pendências e perguntas

## Decisões da equipe 1

| ID | Pendente | Efeito |
| --- | --- | --- |
| P01 | Simulador ainda não escolhido | Define circuito disponível e rede |
| P02 | SHT31 obrigatório ou DHT22 aceito na demonstração? | Define driver e fidelidade |
| P03 | Entrada sonora sintética aceita ou áudio real exigido? | Define escopo de aquisição e evidência |
| P04 | Cliente Modbus no ESP32, Node-RED ou ambos? | Define responsabilidade e testes |
| P05 | Placa ESP32 e pinagem | Evita depender de conexões não definidas |
| P06 | Semântica MANUAL, validade e retorno a AUTO | Evita comando obsoleto |
| P07 | Política de falha de sensor e tempos do atuador | Define comportamento observável |

## Informações da empresa

Taxa e método de contagem de quebra; cadência; turnos; UR/temperatura atuais; climatização; lotes e especificação da cápsula; características do desumidificador e sua interface; local e ruído de instalação; existência/permissão de comunicação com CLP; confirmação dos relatos da visita e dos contatos.

Não há faixa ideal, mapa de registradores, código de falha real ou calibração acústica nos anexos.

## Integração entre equipes

Broker, autenticação, acesso de rede, tópicos, QoS/retained, schema, relógio, marcação sintética, qualidade, deduplicação, eventos de parada, unidade do ruído e confirmação de comandos. Confirmar titularidade do SQL e pertinência de S7Comm. Confirmar canal de alerta e critério de aceitação da demonstração.

## Acompanhamento

O OpenProject não foi consultado para status atual. As datas do relatório permanecem como referência documental. A formação da equipe é informada em números, sem nomes; não preencher integrantes por suposição.

Quando uma resposta chegar, registrar fonte/data em [[Decisoes]], atualizar a nota temática e preservar esta pergunta como resolvida em histórico ou sessão.

## Revisão após o documento de entregáveis recebido em 27/10/2026

- P01: o item 1 da nova fonte já especifica Wokwi. Foi usado como alvo do pacote atual; isso não registra uma escolha geral expressa pelo usuário para todo o projeto.
- P02: para o novo item 1, a referência é SHT31. Foi preparado modelo parcial I²C; confirmar aceitação para avaliação e não trocar por DHT22 sem acordo.
- P03/P05: há sinal sonoro sintético e pinagem do circuito em [[Pinagem e componentes do item 1]]. Escolha do microfone físico e aceitação do modelo continuam pendentes.
- P04: a figura indica som como padrão e Modbus se o CLP for liberado. O cliente Modbus continua citado no item 2; alinhar execução e responsável.
- P08: esclarecer o que deve ser retido em Flash em quedas de rede, capacidade, reenvio e perda admissível. Persistência de configuração isoladamente não atende necessariamente à retenção de dados.
- P09: definir origem, atualização e sincronização do produto/lote em cada leitura. O SQL já reserva os campos, mas o diagnóstico local não publica essas informações.
- P10: cadência de 620 cáps./min documentada para a visita de 17/09/2026; validar por produto/condição. Faixas reais e dados de quebra continuam faltando.

Consultar [[Atualizacao dos entregaveis em 2026-10-27]] para a localização de cada informação no documento novo.

## Revisão em 27/10/2026 (segunda sessão)

- P08 (retenção em Flash): implementada uma fila de 192 mensagens no LittleFS com reenvio em ordem, que sobrevive a reinício e descarta a mais antiga quando cheia. Falta confirmar com a orientação se a capacidade (~16 min a 5 s) e a perda admissível atendem.
- P09 (produto/lote): implementado o tópico `contexto` (retido, persistido na NVS). Falta definir quem publica e quando o lote muda.
- P11: qual broker usar na integração? No Wokwi web, o Mosquitto local exige o gateway privado, que é pago; o broker público só serve para demonstração.
- P12: aceite da unidade dBFS e dos limiares; o dashboard ("ruído em dB") deve exibir dBFS com essa legenda, e não dB SPL.
- P13: o Admin envia `ur_max`/`histerese`/`limiar_db`/`banda_db` ou `ur_liga`/`ur_desliga`/limiares diretos? O firmware aceita os dois formatos.
- P14: confirmar se `set-control` do Wokwi CLI funciona com os controles dos chips customizados.

## Revisão em 28/10/2026 (entrega das etapas 3 e 4 recebida)

A outra equipe enviou Compose, Node-RED, Grafana, SQL e contrato próprios (arquivos em `90 Fontes/Entrega recebida - etapas 3 e 4`). Análise estática em [[Compatibilidade com a entrega das etapas 3 e 4]]; nada foi executado.

- P04 (Modbus): no desenho deles, o Node-RED é o cliente Modbus FC03 (HR3 = máquina 1/0, HR5 = falha), com a mesma semântica do firmware. Falta confirmar se o cliente do ESP32 continua desligado.
- P11 (broker): o README deles cobre só o ESP32 físico na mesma rede. Para o Wokwi, continua sem definição.
- P12 (ruído): o painel e o limiar deles usam "dB" (60 dB), como se fosse SPL. O firmware envia dBFS; acordar a unidade e a legenda.
- P15: qual contrato prevalece? Os prefixos diferem (`mixnutri` × `iotmixnutri`), assim como comando (retido, sem `cmd_id`/validade) e configuração (sem `versao`); faltam os tópicos de eventos, confirmações, disponibilidade e contexto.
- P16: o CHECK de `paradas_maquina_sala01.origem` deles não aceita `esp32`, que é a origem padrão do próprio fluxo. Paradas vindas do ESP32 falhariam.
- P17: o schema deles não grava produto/lote nem deduplica por dispositivo, boot e sequência. Quem mantém o SQL? O item 1 previa o script da equipe 1.
- P18: destino da proposta do item 3 (referência do contrato v2 ou adaptador) e permissão para baixar as imagens.
