---
projeto: MixNutri
equipe: 1
tipo: plano
status: nao_executado
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Matriz de testes

**Plano de validação; todos os testes estão NÃO EXECUTADOS.** Valores remetem a [[Parametros propostos]], ainda não aprovados. Teste planejado não é evidência.

| ID | Estímulo e condição | Resultado esperado proposto | Status |
| --- | --- | --- | --- |
| T01 | Partir sem leitura válida | Saída inicial OFF; clima inicializando; máquina DESCONHECIDO | Não executado |
| T02 | Em AUTO: UR 49 → 56 | Solicitar ON em 55 ou acima | Não executado |
| T03 | Já ON, UR 53; depois 49 | Manter ON na banda e solicitar OFF em 50 ou abaixo | Não executado |
| T04 | Já OFF, oscilar UR 51–54 | Permanecer OFF, sem alternância | Não executado |
| T05 | Nível 0,8 contínuo por 3 s | Confirmar OPERANDO uma vez | Não executado |
| T06 | Já OPERANDO, nível 0,2 por 2 s e voltar | Não confirmar parada; reiniciar temporizador | Não executado |
| T07 | Já OPERANDO, nível 0,2 por 5 s | Confirmar PARADO; gerar uma transição | Não executado |
| T08 | Derrubar MQTT com Wi-Fi disponível | Controle local continua; falha publicada após retorno | Não executado |
| T09 | Wi-Fi indisponível desde a partida | Inicialização e controle não ficam bloqueados | Não executado |
| T10 | Aplicar configuração inválida, ex. desliga >= liga | Rejeitar, confirmar erro, preservar configuração anterior | Não executado |
| T11 | Aplicar configuração válida e reiniciar | Recuperar parâmetros e versão; não reaplicar manual antigo | Não executado |
| T12 | Falha de sensor/UR inválida | Marcar qualidade, alarme e política de saída definida | Não executado |
| T13 | Executar cenário integrado UR alta e depois parada | Mesmos dados no nó/backend/tela; origem sintética visível | Não executado |
| T14 | MANUAL com comando válido e depois retorno a AUTO | Saída segue semântica acordada e retorna à histerese | Não executado |
| T15 | Mensagem duplicada/antiga ou comando vencido | Não aplicar comando indevido nem duplicar evento | Não executado |
| T16 | Verificar GPIO, contatos NO/NC e LED | Comando lógico corresponde à carga demonstrativa | Não executado |
| T17 | Ativar tempo mínimo e pedir mudança antes do prazo | Respeitar regra e publicar solicitação versus comando | Não executado |
| T18 | Modbus: OPERANDO, PARADO e timeout | Estados e qualidade coerentes; timeout não vira parada | Não executado |
| T19 | Relógio não sincronizado e posterior sincronização | Não inventar horário; preservar uptime e origem temporal | Não executado |
| T20 | Clima/estado vencido com último valor plausível | Marcar dado vencido em vez de confirmar valor atual | Não executado |

T18 depende da divisão Modbus a combinar. Para cada teste, registrar procedimento, valores exatos, versão, tempo medido, resultado real e evidência. Uma captura de tela isolada não comprova comportamento temporal ou resistência a falhas.

Usar [[Modelo de teste]] e atualizar [[Registro de evidencias]] quando houver execução.

## Execuções específicas do diagnóstico do item 1 em 27/10/2026

A declaração inicial “todos não executados” descreve a situação de criação da matriz. Houve posteriormente testes específicos do circuito/diagnóstico, registrados com IDs I1 em [[Validacao do item 1]]. Os testes gerais acima ainda devem ser aplicados ao firmware completo quando implementado. Não promover resultados do diagnóstico a aprovação de MQTT, Modbus, persistência ou integração.
