---
projeto: MixNutri
equipe: 1
tipo: proposta
status: proposto
criado: 2026-10-26
atualizado: 2026-10-26
tags:
  - mixnutri
  - equipe1
---

# Parâmetros propostos

**Todos os valores abaixo são propostas didáticas, sem aprovação do usuário ou validação pela empresa.** 55% UR aparece como exemplo no plano, não como especificação da sala.

| Parâmetro | Proposta inicial | Unidade ou significado |
| --- | --- | --- |
| ur_liga | 55 | % UR |
| ur_desliga | 50 | % UR |
| banda_histerese | 5 | Pontos percentuais |
| leitura_clima | 2000 | ms, revisar conforme sensor escolhido |
| telemetria | 5000 | ms |
| leitura_nivel_sintetico | 200 | ms, não é taxa de áudio |
| nivel_operando | 0,60 | Normalizado 0–1 |
| nivel_parado | 0,40 | Normalizado 0–1 |
| confirmar_operando | 3000 | ms contínuos acima do limiar |
| confirmar_parado | 5000 | ms contínuos abaixo do limiar |
| modo_inicial | AUTO | Proposta para a bancada |
| saida_inicial | OFF | Antes de leitura válida |
| estado_maquina_inicial | DESCONHECIDO | Sem evidência suficiente |
| sensor_invalido | Alarme e OFF | Proposta de bancada, política real pendente |
| tempo_minimo_atuador | A definir | Depende do equipamento e do cenário |
| validade_comando_manual | A definir | TTL ou timeout explícito |
| sensor_stale | A definir | Idade máxima por fonte |
| broker e credenciais | A definir | Fornecidos/confirmados com equipe 2 |
| QoS, retenção e biblioteca MQTT | A definir | Conforme capacidades dos dois lados |

Validações mínimas propostas: UR finita entre 0 e 100; desligamento abaixo de ligamento; nível normalizado entre 0 e 1; limiar de parada abaixo do de operação; tempos positivos com limites razoáveis; versão de configuração conhecida. Rejeitar o conjunto inválido sem alterar parcialmente a configuração anterior.

Não preencher valores faltantes com supostos padrões industriais. Registrar alterações em [[Decisoes]] e na sessão correspondente.
