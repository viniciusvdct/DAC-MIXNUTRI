# MixNutri Item 1

Versão 2 para revisão acadêmica, preparada e testada em 27/10/2026. Mudanças da v2: som com ruído de fundo e nível em dBFS; SQL com quatro tabelas (inclui `alertas_emitidos`); arquivos para o Wokwi CLI.

- Projeto no Wokwi: https://wokwi.com/projects/479079864657061889
- [Instruções completas](Entrega%20do%20item%201.md)
- [Pinagem e componentes](Pinagem%20e%20componentes%20do%20item%201.md)
- [Modelo SQL](Modelo%20de%20dados%20do%20item%201.md)
- [Validação e limites](Validacao%20do%20item%201.md)

O circuito usa modelos parciais/sintéticos. São seis arquivos na pasta circuito: criar os chips customizados sht31 e som no Wokwi e copiar os arquivos homônimos, sketch.ino e diagram.json. ON=HIGH no relé npn. A pasta banco contém schema, exemplos e consultas. `wokwi.toml`, `platformio.ini` e `testes-wokwi/` servem para o Wokwi CLI / VS Code e não foram executados. Não há integração automática entre o programa diagnóstico e o banco.

O código de diagnóstico não é o firmware completo do item 2. A aceitação dos modelos, a calibração acústica e a validação industrial continuam pendentes. As notas preservam links de contexto para o cofre Obsidian; os arquivos e procedimentos principais estão contidos neste pacote.
