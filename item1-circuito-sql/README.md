# Item 1 — circuito e banco de dados

Circuito da sala piloto no Wokwi (ESP32, SHT31, som, relé e LED), um programa de diagnóstico para conferir as ligações e o script SQL do PostgreSQL.

| Pasta | Conteúdo |
| --- | --- |
| `circuito/` | `diagram.json`, `sketch.ino` (diagnóstico) e os chips customizados `sht31` e `som` |
| `banco/` | `01_schema.sql` (tabelas), `02_dados_demo.sql` (exemplos sintéticos), `03_consultas.sql` |
| `testes/` | Verificação do banco e testes em C dos chips |

O firmware completo fica em [`../item2-firmware`](../item2-firmware), e usa este mesmo circuito.

## Circuito no Wokwi

**Jeito rápido:** abra o [projeto pronto](https://wokwi.com/projects/479079864657061889) e clique em ▶.

**Montando do zero:**

1. Crie um [projeto ESP32 novo](https://wokwi.com/projects/new/esp32).
2. Pelo menu ▼ das abas → "New file…", crie `sht31.chip.c`, `sht31.chip.json`, `som.chip.c` e `som.chip.json`. Cole em cada um o conteúdo da pasta `circuito/`.
3. Substitua `sketch.ino` e `diagram.json` pelos desta pasta.

No monitor serial (115200), aparece a cada segundo uma linha como esta:

```text
uptime_ms=3000 clima=VALIDO T=25.00C UR=45.00% ruido_adc_rms=589.05 ruido_dbfs=-10.8 rele=OFF modo=MANUAL_DIAG
```

O que dá para testar:

- **Relé:** digite `1` e `0` no serial. O LED verde, ligado nos contatos do relé, acende e apaga.
- **Histerese:** digite `a` e mude a umidade no SHT31 (clique na peça). Em 60% o relé liga; em 53% continua ligado; em 49% desliga.
- **Som:** clique no chip `som`. Tom em 80% dá cerca de −11 dBFS; tom em 0% deixa só o ruído de fundo, perto de −50 dBFS.
- **Falha do sensor:** no SHT31, `crcFault = 1` ou `online = 0` faz a leitura falhar. Em AUTO, o relé desliga.

O SHT31 é um modelo parcial (I²C 0x44, medição com CRC) e o som é um gerador sintético. Servem para testar a lógica, não substituem os sensores reais.

## Pinagem

| Componente | Pino | Ligação no ESP32 DevKit V1 |
| --- | --- | --- |
| SHT31 | VCC / GND | 3V3 / GND |
| SHT31 | SDA / SCL | GPIO 21 / GPIO 22, com pull-up de 4,7 kΩ para 3V3 |
| Som | OUT | GPIO 34 (ADC) |
| Relé | VCC / GND | VIN / GND |
| Relé | IN | GPIO 26 — módulo `npn`: HIGH liga, LOW desliga |
| Relé | COM / NO | 3V3 → COM; NO → resistor de 330 Ω → LED verde → GND |

## Banco de dados

Use um banco **vazio** de teste. Os scripts criam o schema `mixnutri` e não foram feitos para rodar duas vezes no mesmo banco.

```sh
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO -f banco/01_schema.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO -f banco/02_dados_demo.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO -f banco/03_consultas.sql
psql -X -v ON_ERROR_STOP=1 -d SEU_BANCO -f testes/04_validacao_banco.sql
```

| Tabela | Uma linha por… |
| --- | --- |
| `configuracao_alertas` | Versão da configuração: limites de umidade e histerese, limiares de ruído e canais de alerta. Só uma fica ativa por sala |
| `telemetria_sala01` | Leitura, sempre com produto e lote, qualidade da medição, ruído com unidade, estado da máquina, modo e relé |
| `paradas_maquina_sala01` | Parada, com início, fim, duração, fonte (som ou Modbus) e motivo do fim |
| `alertas_emitidos` | Alerta gerado: tipo, severidade, valor e limite, canais e situação do envio |

As regras do banco recusam umidade fora de 0–100%, mensagem duplicada, lote vazio, dB SPL sem calibração e histerese invertida. O `04_validacao_banco.sql` testa essas regras e desfaz tudo no final.

## Testes dos chips

```sh
clang -std=c11 -Wall -Wextra -Werror -I testes testes/test_models.c -o /tmp/modelos && /tmp/modelos
```

## Wokwi CLI (opcional)

`circuito/wokwi.toml`, `circuito/platformio.ini` e `circuito/testes-wokwi/item1.test.yaml` servem para rodar a simulação pelo terminal com o [wokwi-cli](https://github.com/wokwi/wokwi-cli). É preciso ter um token do Wokwi e compilar com `pio run`. Esse caminho ainda não foi testado.
