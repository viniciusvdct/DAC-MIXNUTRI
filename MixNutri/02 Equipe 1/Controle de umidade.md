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

# Controle de umidade

Fonte do requisito: [[Extracao do plano MVP]], blocos 31 e 40–44. O exemplo documental cita 55% UR. Não informa faixa industrial validada.

## Histerese proposta

Para a demonstração, definir dois limiares distintos: `ur_liga` e `ur_desliga`, com `0 <= ur_desliga < ur_liga <= 100`. Se a interface tiver “UR máxima” e “histerese”, propor `ur_liga = UR_max` e `ur_desliga = UR_max - histerese`; confirmar a semântica com as equipes.

```text
AUTO e leitura válida:
    se UR >= ur_liga: solicitar ON
    senão se UR <= ur_desliga: solicitar OFF
    senão: manter solicitação anterior
```

Proposta de demonstração: liga em 55% UR, desliga em 50% UR, banda de 5 pontos percentuais. Na partida, a solicitação inicial é OFF até uma leitura válida. Com 53% UR, manter OFF se antes estava OFF e manter ON se antes estava ON.

## Prioridades propostas

1. Validar leitura e configuração antes de decidir.
2. Em falha de clima, publicar alarme e aplicar política de falha definida. Para a bancada, propõe-se OFF; não foi definida a política industrial.
3. AUTO executa histerese. MANUAL aceita intenção ON/OFF vigente, sujeito às proteções definidas.
4. Aplicar eventual tempo mínimo ligado/desligado, separando solicitação e comando final.
5. Publicar alterações reais do comando e o motivo.

Um equipamento com compressor pode exigir proteção contra ciclos curtos. Não há tempo mínimo fornecido no desafio; a implementação industrial dependerá das especificações do equipamento. Na bancada, um valor acelerado pode ser usado para testar a regra e deve ser rotulado como didático.

## Rede e máquina

Perder MQTT não deve travar a histerese local. O comportamento após expirar um comando MANUAL ainda deve ser decidido: proposta de retorno a AUTO após validade definida. Estado PARADO da encapsuladora não é uma condição de desligamento do desumidificador no requisito atual.

Ver [[Parametros propostos]] e [[Matriz de testes]].
