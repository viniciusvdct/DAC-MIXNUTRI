---
projeto: MixNutri
equipe: 1
tipo: referencia
status: proposto
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Wokwi CLI e VS Code

Pergunta do usuário em 27/10/2026: existe uma forma melhor de integrar com o Wokwi, como o [wokwi-cli](https://github.com/wokwi/wokwi-cli)? Esta nota registra o que a documentação oficial informa e o que foi preparado. **Nada aqui foi executado**, porque falta o token da conta do usuário e não há toolchain ESP32 nesta máquina.

## Opções

| Caminho | Para quê | Custo e requisitos | Situação no projeto |
| --- | --- | --- | --- |
| Wokwi web | Entregar e demonstrar; compila no servidor | Grátis; salvar e compartilhar exige login | Usado nos testes dos itens 1 e 2 |
| Wokwi for VS Code | Desenvolver localmente com PlatformIO e depurar | Extensão; usa `wokwi.toml` e o firmware compilado | Arquivos prontos |
| Wokwi CLI | Rodar sem interface, com cenários de teste automáticos e CI | Token em `WOKWI_CLI_TOKEN`; plano grátis com 50 min de simulação a cada 30 dias e sessões de até 5 min | Arquivos e cenários prontos, não executados |
| `wokwi-cli mcp` | Servidor MCP experimental: um agente de IA roda e lê simulações direto | Mesmo token | Opção para as próximas sessões com IA |

**Recomendação:** manter o Wokwi web para a entrega (link do projeto para o professor) e usar o Wokwi CLI para regressão. Os cenários dos itens 1 e 2 repetem os testes manuais em segundos, sem clicar em controles. O servidor MCP ajuda nas próximas sessões, mas é experimental; não depender dele para a entrega.

## Passo a passo (a fazer pelo usuário)

1. Instalar o CLI: `curl -L https://wokwi.com/ci/install.sh | sh`
2. Gerar o token no [painel de CI do Wokwi](https://wokwi.com/dashboard/ci) e exportar `WOKWI_CLI_TOKEN` no shell. Não colocar o token em arquivo do cofre.
3. Instalar o PlatformIO (`pip install platformio`) e, na pasta `firmware` do item 2 (ou `circuito` do item 1), rodar `pio run`.
4. Compilar os chips: `wokwi-cli chip compile sht31.chip.c -o sht31.chip.wasm` e o mesmo para `som`.
5. Conferir o diagrama com `wokwi-cli lint`.
6. Rodar o cenário: `wokwi-cli --scenario testes/wokwi/item2.test.yaml --timeout 120000 --serial-log-file serial.txt`
7. Opcional, para a IA: `claude mcp add wokwi --env WOKWI_CLI_TOKEN=$WOKWI_CLI_TOKEN -- wokwi-cli mcp`, executado pelo próprio usuário.

Arquivos: `wokwi.toml` e `platformio.ini` em [[Entrega do item 1]] (`circuito/`) e [[Entrega do item 2]] (`firmware/`); cenários em `circuito/testes-wokwi/item1.test.yaml` e `firmware/testes/wokwi/item2.test.yaml`.

## Cuidados

- O passo `set-control` dos cenários está documentado para peças nativas. Para controles de chips customizados, o suporte precisa ser confirmado na primeira execução.
- O PlatformIO oficial usa Arduino-ESP32 2.x; o Wokwi web usa a versão dele. O firmware só foi compilado no Wokwi web.
- Rede: no Wokwi, o ESP32 alcança a internet pelo gateway público. Broker local (Mosquitto da equipe 2) exige o gateway privado (`host.wokwi.internal`), que no Wokwi web é recurso pago. O VS Code traz o gateway embutido; a documentação consultada não informa preço para esse caso. Até decidir, o broker público serve apenas para demonstração com dados sintéticos.
- Wokwi web sem `partitions.csv` não tem partição para LittleFS. O item 2 inclui a tabela.

Fontes: [README do wokwi-cli](https://github.com/wokwi/wokwi-cli), [uso do CLI](https://docs.wokwi.com/wokwi-ci/cli-usage), [cenários de automação](https://docs.wokwi.com/wokwi-ci/automation-scenarios), [configuração do projeto](https://docs.wokwi.com/vscode/project-config), [Wi-Fi do ESP32](https://docs.wokwi.com/guides/esp32-wifi), [limites do CI](https://docs.wokwi.com/wokwi-ci/getting-started), consultadas em 27/10/2026.
