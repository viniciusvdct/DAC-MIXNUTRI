---
projeto: MixNutri
equipe: 1
tipo: sessao
status: concluido
criado: 2026-10-28
atualizado: 2026-10-28
tags:
  - mixnutri
  - equipe1
---

# 28/10/2026 — publicação no GitHub

## Contexto e pedido

O usuário pediu para subir tudo para [viniciusvdct/DAC-MIXNUTRI](https://github.com/viniciusvdct/DAC-MIXNUTRI) e compartilhar com as outras equipes. O repositório é público e tinha só o README de apresentação.

## Decisões

Decididas pelo usuário depois de a IA apontar os riscos:
- os documentos do desafio, suas transcrições e os contatos ficam fora do repositório público;
- a entrega recebida da outra equipe entra em pasta identificada.

Decisão da IA, por segurança: nunca publicar senhas. O `.env.exemplo` do item 3 foi trocado por marcadores e o `.env` ficou só no Mac. Detalhes em [[Documentacao do repositorio]].

## Trabalho realizado

- Varredura de senhas literais e de dados pessoais (e-mails, telefones, nomes da coordenação) em todos os arquivos de texto. Apareceram só nos arquivos excluídos e no `.env`/`.env.exemplo` do item 3.
- Os 16 arquivos da outra equipe foram movidos para `90 Fontes/Entrega recebida - etapas 3 e 4`, com LEIA-ME, e os links foram ajustados na nota de compatibilidade e nas pendências.
- README do repositório atualizado mantendo a apresentação anterior, mais `.gitignore`.
- Commit e push a partir de um clone fora do iCloud.

## Testes e evidências

Antes do push: verificação de que nenhum arquivo do commit contém as senhas do `.env`, nem os e-mails ou nomes da coordenação. Depois do push: listagem dos arquivos no GitHub.

## Pendências e próximo passo

Compartilhar o link com as equipes 2 e 3. Para publicar atualizações futuras, repetir a cópia com as mesmas exclusões, ou manter um clone local fora do iCloud.

## Notas alteradas

[[Documentacao do repositorio]], [[Compatibilidade com a entrega das etapas 3 e 4]], [[Pendencias e perguntas]], [[Registro de sessoes]], `06 Entregas/Item 3 (proposta)/README.md` e `.env.exemplo`.
