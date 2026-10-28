#!/bin/sh
set -eu
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set ON_ERROR_STOP=1 --set=grafana_pass="$GRAFANA_DB_PASSWORD" <<'SQL'
SELECT format('ALTER ROLE grafana_reader WITH PASSWORD %L', :'grafana_pass') \gexec
SQL
