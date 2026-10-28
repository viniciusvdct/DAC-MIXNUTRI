---
projeto: MixNutri
equipe: 1
tipo: referencia
status: documentado
criado: 2026-10-27
atualizado: 2026-10-27
tags:
  - mixnutri
  - equipe1
---

# Documentação do repositório

Repositório confirmado pelo usuário: [viniciusvdct/DAC-MIXNUTRI](https://github.com/viniciusvdct/DAC-MIXNUTRI).

Em 27/10/2026, o usuário pediu About e README com linguagem simples e humana, centrados na equipe 1 e com apresentação breve das outras equipes e da comunicação entre elas. Os dois textos foram atualizados no GitHub e conferidos após a escrita.

## Textos

- [README publicado](https://github.com/viniciusvdct/DAC-MIXNUTRI/blob/main/README.md) e [cópia local](README.md).
- [Texto do About](ABOUT.txt), aplicado à descrição do repositório.
- [Commit do README](https://github.com/viniciusvdct/DAC-MIXNUTRI/commit/99264158977ce8e39620e14c969fe1d66a22f228).

O README apresenta a equipe 1 como responsável por circuito e firmware do ESP32; explica a histerese e a detecção sonora em termos simples; descreve a troca de dados/comandos MQTT com as equipes 2 e 3; separa o circuito de diagnóstico testado da integração ainda a validar. A figura Mermaid mostra o caminho até o banco/painéis e o retorno de configurações.

Somente o README e a descrição About foram alterados no repositório. Código, anexos, contatos e notas internas não foram enviados. A conferência ficou registrada em `publicacao.json`.

## Atualização futura

Manter o README coerente com os testes efetivamente executados. Os arquivos locais do item 2 incluem implementação de funções de firmware, mas não foram compilados nem testados nesta sessão de documentação. Sua existência não comprova integração ou validação industrial.

## Publicação do projeto em 28/10/2026

O usuário pediu para subir tudo ao repositório, que é **público**, para compartilhar com as outras equipes. Antes de publicar, a IA apontou três pontos, e o usuário decidiu:

- **Documentos do desafio** (PDF/DOCX originais, transcrições, extrações, figura) e a nota com e-mails e telefones da coordenação (`Pessoas e acompanhamento`): **ficaram de fora**. O PDF declara distribuição restrita ao SENAI-MS, à UCDB e à empresa. Também ficaram fora o catálogo, o índice e os manifestos dessas fontes.
- **Entrega recebida da outra equipe** (etapas 3 e 4): **incluída**, em `90 Fontes/Entrega recebida - etapas 3 e 4`, com LEIA-ME de autoria e SHA-256. O `_env` dela nunca foi copiado.
- **Senhas:** o `.env` do item 3 não é publicado. O `.env.exemplo` passou a conter só marcadores `TROCAR_*`, e as senhas de teste geradas ficaram apenas no `.env` local.

Também ficam fora: `.obsidian/`, os ZIPs (o conteúdo já está nas pastas), `.DS_Store` e saídas de compilação. O README foi atualizado com a situação de cada item, os links do Wokwi, o caminho para as outras equipes e o mapa das pastas. A publicação foi feita a partir de um clone fora do iCloud, para não colocar `.git` dentro do cofre sincronizado.

Commit da publicação: [cbbc755](https://github.com/viniciusvdct/DAC-MIXNUTRI/commit/cbbc755224b68fa41735574744a19ffa6758c1fb). 142 arquivos no repositório depois do push.
