---
projeto: MixNutri
equipe: 1
tipo: plano
status: proposto
criado: 2026-10-26
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Plano de execução da equipe 1

Objetivo: desenvolver e demonstrar uma sala piloto simulada com ESP32, leitura de temperatura e umidade, controle local de um desumidificador representado por relé/LED, detecção de máquina operando/parada e comunicação com o sistema das equipes 2 e 3.

O usuário solicitou este plano em 26/10/2026. O plano é uma proposta de execução: simulador, componentes, parâmetros e divisão Modbus ainda não foram aprovados. Nenhum circuito ou firmware foi implementado nesta etapa.

## Escopo e resultado esperado

A equipe 1 entrega o circuito e o firmware, incluindo histerese, detecção sonora, AUTO/MANUAL, persistência de configuração e MQTT. O detalhamento do MVP também cita cliente Modbus TCP; sua distribuição com a equipe 2 deve ser resolvida no início, sem excluir o requisito por suposição.

Ao final, deve ser possível variar a umidade, observar o acionamento e desligamento com histerese, simular funcionamento e parada, visualizar eventos no backend/dashboard e demonstrar que a perda de rede não bloqueia o controle local.

O desafio de investigar quebras continua dependendo de dados de produção, lote e ambiente por semanas. A demonstração de software não valida a causa das quebras, a faixa ideal de umidade ou um microfone real. Ver [[Dados para investigar as quebras]] e [[Limites da simulacao]].

## Base proposta para começar

Usar Wokwi como candidato, ESP32, DHT22, relé, LED com resistor e potenciômetro para injetar nível de ruído normalizado. Essa proposta se apoia nas verificações de documentação registradas em [[Escolha do simulador]] e [[Referencias tecnicas]]. Não constitui escolha feita pelo usuário.

Antes da montagem, confirmar se DHT22 e entrada sonora sintética são aceitos para a demonstração. O DHT22 não testa o driver SHT31. O potenciômetro permite verificar a lógica de estados, mas não adquire áudio e não mede dB SPL. Se forem exigidos sensor e áudio específicos, incluir implementação de modelos/drivers ou uma etapa física compatível e revisar a estimativa.

## Etapas e critérios para avançar

Estimativa inicial da IA: **23 a 36 horas de trabalho técnico**, em ambiente já disponível, para a versão com clima simulado e nível sonoro sintético. É uma estimativa de esforço, não um prazo combinado. Não inclui espera por respostas, compra, aprendizado extenso de ferramentas, modelo customizado SHT31/microfone, implementação Modbus adicional ou validação industrial. Essas atividades exigirão nova estimativa se integrarem o escopo final.

| Etapa | Esforço estimado | Trabalho | Entrega e critério para avançar |
| --- | --- | --- | --- |
| 1. Definir a demonstração | 1–2 h | Escolher ambiente, placa, sensor e origem do estado; resolver responsabilidades | Decisões registradas; componentes e fonte Modbus/som definidos |
| 2. Montar circuito mínimo | 2–3 h | ESP32, clima, relé e LED; documentar pinagem e alimentação | Leitura aparece no serial; contatos e LED respondem ao comando correto |
| 3. Implementar controle local | 3–5 h | Validar leitura, aplicar histerese e definir falhas | T01–T04, T12, T16 e teste de dado vencido ambiental documentados |
| 4. Implementar detecção de parada | 3–5 h | Estados, limiares, confirmação temporal e eventos | T05–T07; uma parada confirmada gera um evento; entrada inválida vira DESCONHECIDO |
| 5. Adicionar modos e persistência | 4–6 h | AUTO/MANUAL, configuração validada, validade de comandos e recuperação após reinício | Configuração persiste; comando antigo não religa a carga; T10, T11, T14, T17 conforme política acordada |
| 6. Conectar MQTT | 4–6 h | Publicação, recebimento, confirmação e reconexão sem bloquear | T08, T09, T15 e T19; backend recebe valores e unidades corretos |
| 7. Integrar e testar o cenário | 4–6 h | Unir nó, backend e dashboard com equipes 2 e 3 | T13 e T20; T18 se Modbus no escopo acordado; evidências da cadeia completa |
| 8. Preparar a entrega | 2–3 h | Consolidar arquivos, memorial da equipe 1 e demonstração | Pacote reproduzível, testes com conclusão e limitações explícitas |

Os detalhes dos testes estão em [[Matriz de testes]]. Todos permanecem não executados até existir registro de execução. Quando um teste depender de uma funcionalidade posterior, concluir a verificação correspondente nessa etapa e registrar a dependência.

## Sequência de implementação do firmware

1. Definir a saída inicial do relé antes da conexão à rede.
2. Ler clima e distinguir inicialização, leitura válida, falha e dado vencido.
3. Implementar histerese com dois limites configuráveis e logs de mudança de saída.
4. Implementar estado da máquina independentemente do controle de umidade.
5. Adicionar AUTO/MANUAL e regras de prioridade, expiração e falha.
6. Validar e persistir configuração; testar reinício.
7. Adicionar Wi-Fi/MQTT com tentativas limitadas no tempo, preservando o ciclo local.
8. Integrar configuração remota, confirmações e identificação de mensagens.

Organizar o código por responsabilidades: leitura de clima, aquisição de nível, classificação, controle, configuração/persistência e comunicação. A troca do sensor ou da origem do nível não deve exigir reescrever as regras de controle.

Para a primeira demonstração, os valores 55% para ligar e 50% para desligar podem servir como proposta didática. O primeiro aparece como exemplo no MVP; nenhum deles é um limite industrial validado. Ver [[Parametros propostos]] e [[Controle de umidade]].

## Trabalho com as outras equipes

| Momento | Alinhamento necessário | Resultado esperado |
| --- | --- | --- |
| Etapa 1 | Equipe 2: quem implementa o cliente Modbus e onde | Responsável, fonte de estado, mapa simulado e escopo explícitos |
| Etapas 1–2 | Equipe 2: acesso ao broker a partir do simulador | Host, porta, autenticação e caminho de rede testável |
| Antes da etapa 6 | Equipes 2 e 3: mensagens e comandos | Versão acordada de [[Contrato MQTT proposto]] |
| Antes da etapa 7 | Equipe 3: unidades, qualidade, modos e alertas | Tela não confunde nível sintético com dB SPL nem comando com retorno físico |
| Etapa 8 | Todas: memorial e apresentação | Mesmas versões, cenário e limitações na entrega |

A equipe 1 pode desenvolver regras locais e usar logs seriais enquanto o backend estiver em preparação. Mensagens de exemplo podem auxiliar as equipes 2 e 3, mas um emissor externo ao ESP32 não comprova integração do firmware. O cenário final deve usar mensagens emitidas pelo nó em execução.

Na opção Wokwi, resolver o acesso ao broker local antes de depender dessa conexão. As condições verificadas para gateway público/privado estão em [[Escolha do simulador]]. Não é necessário publicar os documentos ou dados da empresa para testar a comunicação.

## Primeira sessão de trabalho proposta

Reservar um bloco inicial de 2 a 3 horas, ajustável à disponibilidade do grupo:

- [ ] Confirmar simulador e placa; registrar o que for decidido.
- [ ] Definir se a primeira versão usará DHT22 e nível sonoro sintético.
- [ ] Especificar entradas, saídas e o comportamento esperado do relé na partida.
- [ ] Montar apenas ESP32, sensor de clima, relé e LED.
- [ ] Executar leitura ambiental e um comando simples para verificar GPIO e contatos.
- [ ] Salvar esquema, código, versões e observações da execução.

Resultado esperado desse primeiro bloco: circuito mínimo observável, ainda sem declarar MQTT, áudio ou controle completo como entregues. Se a escolha do ambiente exigir instalação ou modelo especial, usar o bloco para resolver isso e revisar o restante.

## Roteiro da demonstração final

| Passo | Ação | Evidência observável |
| --- | --- | --- |
| 1 | Iniciar e exibir configuração, versão e origem dos dados | Serial e painel identificam a simulação |
| 2 | Manter UR abaixo do limiar e nível de operação confirmado | Relé OFF e máquina OPERANDO |
| 3 | Elevar UR acima do limiar de ligar | Comando local ON e atualização publicada |
| 4 | Fazer queda breve do nível e recuperar | Nenhum evento falso de parada |
| 5 | Manter nível abaixo do limiar pelo tempo definido | PARADO e um evento no histórico |
| 6 | Reduzir UR até o limiar de desligar | OFF com histerese respeitada |
| 7 | Perder a conexão MQTT e variar UR | Controle local continua; reconexão recupera publicação |
| 8 | Aplicar configuração válida, reiniciar e verificar | Parâmetros recuperados sem repetir comando manual obsoleto |

Passos adicionais de MANUAL, sensor inválido, dado vencido e Modbus devem estar demonstrados ou cobertos por evidências dos testes correspondentes. O cenário UR alta seguido de parada é um estímulo de teste, sem conclusão causal sobre a fábrica.

## Organização da entrega da equipe 1

Preparar, após implementação, um pacote com esquema/pinagem, componentes e versões, código-fonte do firmware, instruções para executar, configuração de exemplo sem segredos, contrato de mensagens, registros de teste, evidências e contribuição ao memorial. Esses artefatos ainda não existem como implementação nesta sessão.

O pacote deve permitir a outro integrante repetir a demonstração. Guardar limitações de modelos e diferenças para o hardware físico. Registrar cada trabalho relevante em [[Registro de sessoes]] e cada execução em [[Registro de evidencias]].

## Relação com o cronograma do programa

O relatório prevê fim do desenvolvimento em 06/11/2026, validação de 09 a 27/11 e entrega/apresentação de 30/11 a 11/12. São datas documentais, sem consulta de atualização no OpenProject. Ver [[Cronograma e entregas]].

Proposta de organização: concluir a versão demonstrável e a primeira integração na janela de desenvolvimento, reservar a janela de validação para corrigir falhas e produzir evidências, e consolidar memorial/apresentação na janela final. A viabilidade depende da disponibilidade do grupo e das decisões da etapa 1; não há novos compromissos de data firmados por este plano.

## Prioridades se o esforço disponível for menor

Priorizar circuito reproduzível, histerese local, qualidade dos dados, classificação temporal, AUTO/MANUAL, persistência e MQTT integrado. Registrar o que faltar em relação aos requisitos, sem declarar o MVP completo por reduzir a demonstração.

Deixar expansões para várias salas, estética adicional do painel e bônus de selagem para depois da entrega principal, salvo nova orientação. SHT31 específico, áudio real e Modbus não podem ser descartados unilateralmente se forem exigidos: negociar o recorte e documentar a decisão.

## Próxima ação

Definir o ambiente da etapa 1 e então iniciar o circuito mínimo da etapa 2. O plano detalha o caminho; sua criação não representa aprovação das escolhas técnicas nem execução das etapas.

## Execução iniciada em 27/10/2026

O usuário solicitou ajuda para entregar o item 1 do novo documento. Foi preparado circuito Wokwi com SHT31 parcial, som sintético e diagnóstico, além de SQL executado em banco isolado. Ver [[Progresso em 2026-10-27]], [[Entrega do item 1]] e [[Validacao do item 1]]. As frases desta nota sobre inexistência de implementação descrevem a situação em 26/10; o avanço atual não inclui o firmware completo nem integração. As estimativas anteriores não são medições de tempo gasto nesta sessão.
