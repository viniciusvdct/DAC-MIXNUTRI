#!/bin/sh
# Ativa o login dos papeis criados em 02_integracao.sql com as senhas de teste do .env.
# Executado uma vez pelo entrypoint do PostgreSQL, apenas com o volume de dados vazio.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v senha_nodered="$PG_NODERED_SENHA" -v senha_grafana="$PG_GRAFANA_SENHA" <<'SQL'
ALTER ROLE nodered_ingestao LOGIN PASSWORD :'senha_nodered';
ALTER ROLE grafana_leitura LOGIN PASSWORD :'senha_grafana';
SQL
