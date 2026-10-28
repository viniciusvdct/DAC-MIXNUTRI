CREATE TABLE IF NOT EXISTS telemetria_sala01 (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sala_id TEXT NOT NULL DEFAULT 'sala01',
  instante TIMESTAMPTZ NOT NULL,
  umidade_pct NUMERIC(5,2) NOT NULL CHECK (umidade_pct BETWEEN 0 AND 100),
  temperatura_c NUMERIC(6,2),
  ruido_db NUMERIC(6,2),
  estado_maquina TEXT CHECK (estado_maquina IN ('OPERANDO','PARADO','DESCONHECIDO')),
  desumidificador BOOLEAN,
  modo TEXT CHECK (modo IN ('AUTO','MANUAL')),
  origem TEXT NOT NULL DEFAULT 'esp32',
  codigo_falha INTEGER,
  payload_original JSONB
);
CREATE INDEX IF NOT EXISTS idx_telemetria_sala01_instante ON telemetria_sala01 (instante DESC);

CREATE TABLE IF NOT EXISTS paradas_maquina_sala01 (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  inicio TIMESTAMPTZ NOT NULL,
  fim TIMESTAMPTZ,
  origem TEXT NOT NULL CHECK (origem IN ('modbus','s7comm','acustico','manual','simulador')),
  codigo_falha INTEGER,
  ruido_db NUMERIC(6,2),
  correlacao_umidade_pct NUMERIC(5,2),
  detalhes JSONB,
  CHECK (fim IS NULL OR fim >= inicio)
);
CREATE INDEX IF NOT EXISTS idx_paradas_sala01_inicio ON paradas_maquina_sala01 (inicio DESC);

CREATE TABLE IF NOT EXISTS configuracao_alertas (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  umidade_max_pct NUMERIC(5,2) NOT NULL DEFAULT 55 CHECK (umidade_max_pct BETWEEN 0 AND 100),
  histerese_pct NUMERIC(5,2) NOT NULL DEFAULT 5 CHECK (histerese_pct BETWEEN 0 AND 100),
  ruido_operacional_db NUMERIC(6,2) NOT NULL DEFAULT 60,
  parada_segundos INTEGER NOT NULL DEFAULT 15 CHECK (parada_segundos >= 0),
  alerta_umidade BOOLEAN NOT NULL DEFAULT TRUE,
  alerta_parada BOOLEAN NOT NULL DEFAULT TRUE,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO configuracao_alertas (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS alertas_sala01 (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  instante TIMESTAMPTZ NOT NULL DEFAULT now(),
  tipo TEXT NOT NULL CHECK (tipo IN ('UMIDADE_ALTA','MAQUINA_PARADA','FALHA_INTEGRACAO')),
  severidade TEXT NOT NULL DEFAULT 'warning' CHECK (severidade IN ('info','warning','critical')),
  mensagem TEXT NOT NULL,
  resolvido BOOLEAN NOT NULL DEFAULT FALSE,
  origem TEXT NOT NULL DEFAULT 'node-red',
  detalhes JSONB
);
CREATE INDEX IF NOT EXISTS idx_alertas_sala01_instante ON alertas_sala01 (instante DESC);

DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafana_reader') THEN
    CREATE ROLE grafana_reader LOGIN PASSWORD 'replace-me';
  END IF;
END $$;
GRANT CONNECT ON DATABASE iotmixnutri TO grafana_reader;
GRANT USAGE ON SCHEMA public TO grafana_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana_reader;
