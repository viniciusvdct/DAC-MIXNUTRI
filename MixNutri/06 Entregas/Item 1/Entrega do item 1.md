---
projeto: MixNutri
equipe: 1
tipo: entrega
status: implementado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Entrega do item 1

[Pacote ZIP do item 1, versão 2](../MixNutri_Item1_v2_2026-10-27.zip). Inclui circuito, SQL, documentação, evidências e arquivos para o Wokwi CLI. O [pacote da versão 1](../MixNutri_Item1_2026-10-27.zip) fica como histórico. O histórico anterior à correção do relé fica somente no cofre.

**Versão 2 (27/10/2026):** som sintético com ruído de fundo e simulação de sensor desconectado; diagnóstico com nível em dBFS; SQL com tabela `alertas_emitidos`, canais e persistência de alerta na configuração, `histerese_pp` calculada, `motivo_fim` nas paradas e dBFS coerente; `wokwi.toml`, `platformio.ini` e cenário de teste para o Wokwi CLI. O mesmo circuito roda o firmware completo do [[Entrega do item 2|item 2]].

**Projeto no Wokwi (versão 2, salvo em 27/10/2026):** [MixNutri - Item 1 (circuito e diagnostico)](https://wokwi.com/projects/479079864657061889). Público, na conta Wokwi do usuário. Os 6 arquivos foram conferidos por SHA-256 contra os desta pasta, e o projeto salvo foi executado depois de salvar.

## O que foi preparado

Primeira versão do item “Circuito eletrônico e modelagem de dados”, solicitado pelo usuário em 27/10/2026 e definido no bloco 25 de [[Transcricao integral dos entregaveis]]. O pacote reúne circuito Wokwi, modelos customizados, programa de diagnóstico, SQL e evidências de verificação. A aceitação acadêmica do uso de modelos parciais continua a confirmar.

| Parte | Arquivos | Papel |
| --- | --- | --- |
| Circuito | [diagram.json](circuito/diagram.json) | ESP32, SHT31, som, relé, resistores e LED |
| Diagnóstico | [sketch.ino](circuito/sketch.ino) | Ler clima/ADC e testar relé; histerese didática opcional |
| Modelo de clima | [sht31.chip.c](circuito/sht31.chip.c), [definição](circuito/sht31.chip.json) | I²C 0x44, medição, CRC, reset/status parciais |
| Sinal sonoro | [som.chip.c](circuito/som.chip.c), [definição](circuito/som.chip.json) | Tom de 200 Hz com amplitude ajustável, ruído de fundo e opção de desconectar |
| Banco | [01_schema.sql](banco/01_schema.sql) | Telemetria, paradas, configuração de alertas e alertas emitidos, com restrições e índices |
| Demonstração SQL | [02_dados_demo.sql](banco/02_dados_demo.sql), [03_consultas.sql](banco/03_consultas.sql) | Dados sintéticos e consultas de verificação |
| Verificação | [[Validacao do item 1]] | Procedimentos, resultados e limites |
| Hardware e modelo de dados | [[Pinagem e componentes do item 1]], [[Modelo de dados do item 1]] | Explicação para revisão e apresentação |
| Wokwi CLI / VS Code | [wokwi.toml](circuito/wokwi.toml), [platformio.ini](circuito/platformio.ini), [item1.test.yaml](circuito/testes-wokwi/item1.test.yaml) | Execução local e teste automático; não executados, ver [[Wokwi CLI e VS Code]] |

O programa de diagnóstico não implementa MQTT, cliente Modbus, NVS, retenção offline ou classificação OPERANDO/PARADO. Essas funções estão no firmware do [[Entrega do item 2|item 2]]. O circuito e o SQL foram testados separadamente; não existe coleta automática ESP32 → PostgreSQL nesta entrega.

## Onde simular

**Circuito e ESP32:** [Wokwi, projeto novo ESP32](https://wokwi.com/projects/new/esp32). O documento já indica esse ambiente. Foram usados chips customizados, recurso documentado na [Chips API](https://docs.wokwi.com/chips-api/getting-started), para representar as partes ausentes da lista nativa. O SHT31 parcial preserva o caminho I²C exigido, mas não equivale à validação de um sensor físico.

**Modelagem de dados:** PostgreSQL local ou ambiente isolado de estudo. SQL foi executado em uma instância PostgreSQL 18 temporária, separada dos bancos existentes, encerrada ao terminar a verificação. Wokwi não executa PostgreSQL.

Em 27/10/2026 o projeto foi salvo como público na conta do usuário, a pedido dele: https://wokwi.com/projects/479079864657061889. O plano grátis do Wokwi não permite projeto "Unlisted". Os arquivos locais continuam sendo a referência reproduzível.

## Reproduzir o circuito no Wokwi

1. Criar um projeto ESP32 pelo link acima.
2. Em “Add a new part”, escolher “Custom Chip”, nome `sht31`, linguagem C. Repetir para `som`.
3. Substituir os dois arquivos gerados de cada chip pelos arquivos homônimos da pasta `circuito`.
4. Substituir `sketch.ino` e `diagram.json` pelas versões deste pacote. Não é necessária biblioteca externa para o programa de diagnóstico.
5. Iniciar a simulação; no serial a 115200 baud, conferir clima válido, 25 °C e aproximadamente 45% UR iniciais.
6. Enviar `1` e `0` pelo serial para testar o LED ligado aos contatos COM/NO. O módulo `npn` usado tem **ON = HIGH e OFF = LOW**, verificado visualmente.
7. Enviar `a` para habilitar a histerese didática de 55/50% UR. Clicar no SHT31 e variar UR: 60 → 53 → 49 → 53. O esperado é ON → ON → OFF → OFF.
8. No chip `som`, variar o tom: 80% dá RMS ≈ 589 (−10,8 dBFS); 0% com ruído de fundo de 5% dá RMS ≈ 7 (≈ −50 dBFS); ruído 0% ou `online = 0` dão 0 (−66,2 dBFS, piso do cálculo). dBFS é relativo ao ADC, não dB SPL.
9. No SHT31, `crcFault = 1` ou `online = 0` injeta falha; o diagnóstico em AUTO desliga a saída e indica falha. Restaurar antes de continuar.

O sensor é lido a cada cerca de 2 s; há quantização dos valores. Não interpretar milésimos próximos do limiar como precisão industrial. Para enquadrar o circuito, usar “Zoom, grid, and more” → “Fit”. A implementação representa somente carga demonstrativa de baixa tensão.

## Reproduzir o SQL

Os scripts criam quatro tabelas: as três pedidas no item (telemetria, paradas e configuração de alertas) e `alertas_emitidos`, para o registro de alertas citado na Figura 1. Em um **banco de estudo vazio escolhido pelo executor**, substituir `SEU_BANCO_DE_TESTE` no exemplo. Os scripts criam o schema `mixnutri`; não devem ser aplicados repetidamente em um schema já existente como se fossem migrações.

```sh
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO_DE_TESTE -f banco/01_schema.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO_DE_TESTE -f banco/02_dados_demo.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO_DE_TESTE -f banco/03_consultas.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO_DE_TESTE -f testes/04_validacao_banco.sql
```

Executar a partir da pasta do pacote, com autenticação normal do ambiente. Não há credenciais nos arquivos. Os dados demo são gerados pelo SQL, não foram coletados do firmware. As alterações dos testes de rejeição são revertidas por ROLLBACK.

## O que apresentar

Diagrama/pinagem; leitura de clima; variação do sinal de som em dBFS; LED respondendo pelo relé; as quatro tabelas com produto/lote e qualidade/origem; execução dos scripts; logs e limitações. Se houver tempo, mostrar o mesmo circuito rodando o firmware do item 2. Usar [[Validacao do item 1]] para informar exatamente o que foi executado.

Para fechar a entrega acadêmica, confirmar a aceitação dos modelos customizados e revisar o pacote com o grupo/orientação. Se exigirem MAX9814/INMP441 fiel ou áudio físico, essa validação adicional permanece pendente.
