---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Escopo e equipes

Fontes: declaração do usuário em 26/10/2026 e [[Extracao do plano MVP]], especialmente blocos 6, 26–40 e 56.

| Responsável | Responsabilidade documentada | Interface |
| --- | --- | --- |
| Equipe 1, usuário | Kit físico/simulado ESP32 + SHT31 + relé + som; firmware C++ com histerese e detecção sonora | Telemetria e eventos MQTT; receber parâmetros e comandos |
| Equipe 2 | Docker Compose, Mosquitto, PostgreSQL, Node-RED, MQTT do ESP32 e registradores Modbus simulados | Contrato de mensagens e conectividade |
| Equipe 3 | Grafana unificado e Admin no Node-RED Dashboard | Consumo dos dados e configuração |

A entrega “Circuito Eletrônico e Modelagem de Dados” agrupa hardware e SQL no texto detalhado, mas a tabela final direciona Redes/BD à equipe 2. Para este usuário, a responsabilidade confirmada é circuito/hardware e firmware. A propriedade final do SQL deve ser alinhada entre equipes.

## MVP versus escopo completo

| Aspecto | Escopo completo | MVP documental |
| --- | --- | --- |
| Abrangência | N salas | Uma sala piloto de encapsulamento |
| Nó | N gabinetes IP66 | Um protótipo em bancada/simulado, gabinete IP65 se possível |
| Sensores/atuador | Vários pontos | ESP32, SHT31/DHT22, relé, som ou Modbus |
| Estado da máquina | Integração cabeada ou Wi-Fi | Registradores Modbus TCP ou inferência acústica não invasiva |
| Servidor | Estrutura de várias salas | Um Compose com Mosquitto, PostgreSQL, Node-RED e Grafana |

## Ambiguidades a resolver

O detalhamento do firmware pede detecção acústica **e suporte a cliente Modbus TCP**. A tabela da equipe 2 também atribui leitura Modbus ao backend. Proposta: definir uma fonte principal e uma alternativa, além do responsável por cada cliente. Não assumir que a alternativa dispensou a entrega descrita.

S7Comm aparece na etapa 3 do plano, mas não há CLP, endereços ou parâmetros definidos. Não existe requisito técnico suficiente para implementá-lo nesta base.

O plano menciona SHT31 no circuito Wokwi e admite DHT22 na tabela. Se o avaliador exigir SHT31 especificamente, validar a substituição antes de apresentar uma simulação com DHT22.

## Entrega da equipe 1 proposta

Esquema de simulação; lista de componentes; firmware C++ versionado; diagrama dos estados; parâmetros documentados; mensagens MQTT combinadas; cenários de teste e evidências; contribuição ao memorial e à demonstração integrada. Tudo ainda pendente de implementação.

## Item 1 conforme novo documento recebido em 27/10/2026

O primeiro entregável inclui tanto circuito Wokwi quanto script SQL. O usuário pediu ajuda com o item inteiro; foi preparado o pacote [[Entrega do item 1]], sem redefinir unilateralmente a responsabilidade de manutenção do banco da equipe 2. A referência explícita do circuito é SHT31; DHT22 permanece apenas na fonte anterior. Ver [[Atualizacao dos entregaveis em 2026-10-27]].
