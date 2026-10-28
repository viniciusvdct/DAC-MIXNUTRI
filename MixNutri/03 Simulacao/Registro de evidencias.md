---
projeto: MixNutri
equipe: 1
tipo: registro
status: com_evidencias
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Registro de evidências

Nenhuma evidência de circuito, firmware ou integração foi produzida na sessão inicial. A criação e verificação da base de notas não é teste do protótipo.

| ID do teste | Data | Versão e configuração | Arquivo da evidência | Resultado observado | Conclusão |
| --- | --- | --- | --- | --- | --- |

Criar uma nota por execução com [[Modelo de teste]]. Guardar logs, capturas e medições em uma pasta de evidências quando existirem. Não criar links para arquivos ainda inexistentes. Associar cada execução a [[Matriz de testes]].

Para som: registrar se a entrada foi sintética ou áudio. Para ambiente: indicar sensor/modelo e se o valor foi injetado. Para rede: registrar o caminho entre simulador e broker. Para reinício: registrar como foi provocado e quais parâmetros foram recuperados.

## Execuções do item 1 em 27/10/2026

Ver [[Validacao do item 1]] para procedimentos e limites de cada resultado. Foram executados testes do diagnóstico Wokwi, dos modelos em C e dos scripts PostgreSQL. O primeiro erro de polaridade do relé foi corrigido; as evidências finais estão separadas do histórico.

| Grupo | Data | Versão e ambiente | Evidência | Conclusão |
| --- | --- | --- | --- | --- |
| I1-W01 a I1-W05 | 27/10/2026 | Diagnóstico corrigido, Wokwi web, entradas sintéticas | Nota [[Validacao do item 1]], logs/capturas do pacote | Ver comportamentos e limites descritos |
| I1-C01 | 27/10/2026 | Fontes dos chips e adaptador C local | Saída dos testes no pacote | Comportamentos exercitados passaram |
| I1-S01 a I1-S04 | 27/10/2026 | PostgreSQL 18 temporário e isolado | Log PostgreSQL no pacote | Schema, exemplos, consultas e restrições exercitados passaram |

Essas execuções não são validação do firmware completo nem integração com backend/dashboard.

## Execuções de 27/10/2026 (segunda sessão)

| Grupo | Versão e ambiente | Evidência | Conclusão |
| --- | --- | --- | --- |
| I1-V2-W01 a W03 | Item 1 v2, Wokwi web, arquivos conferidos por SHA-256 | `Item 1/evidencias/wokwi-serial-revalidacao-v2.txt` | Clima, relé e caminho do som com ruído demonstrados |
| I1-V2-C01, S01 | Testes C; PostgreSQL 18.4 temporário | `Item 1/evidencias/modelos-validacao.txt`, `postgresql-validacao.txt` | Aprovados |
| I2-N01 | Lógica do firmware, clang++ com ASan/UBSan | `Item 2/evidencias/testes-logica-nativos.txt` | 15 grupos OK |
| I2-W01 a W15 | Firmware do item 2, Wokwi web, MQTT `broker.hivemq.com` | `Item 2/evidencias/mqtt-recebido-execucao-final.log`, `wokwi-serial-execucao-final.txt` | Ver [[Validacao do item 2]]; Modbus real não testado |

Som sintético; rede pelo gateway público do Wokwi; reinício provocado por `ESP.restart()` (comando `r`), com recuperação da fila, da configuração v2 e do contexto.
