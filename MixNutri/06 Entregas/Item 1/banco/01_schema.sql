-- Item 1: modelo proposto para uma sala piloto. Executar em banco de estudo.
-- Nao contem dados reais, senhas, DROP ou comandos sobre outros schemas.
-- Versao 2 (27/10/2026): dBFS coerente, canais de alerta na configuracao e tabela de alertas emitidos.
BEGIN;
CREATE SCHEMA mixnutri;

CREATE TABLE mixnutri.configuracao_alertas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sala_id text NOT NULL DEFAULT 'sala01' CHECK (btrim(sala_id) <> ''),
  versao integer NOT NULL CHECK (versao > 0),
  ativo boolean NOT NULL DEFAULT false,
  -- Controle local (histerese). No Admin: UR max = ur_liga; histerese = ur_liga - ur_desliga.
  ur_liga numeric(5,2) NOT NULL CHECK (ur_liga BETWEEN 0 AND 100),
  ur_desliga numeric(5,2) NOT NULL CHECK (ur_desliga BETWEEN 0 AND 100),
  histerese_pp numeric(5,2) GENERATED ALWAYS AS (ur_liga - ur_desliga) STORED,
  temperatura_min_c numeric(6,2),
  temperatura_max_c numeric(6,2),
  -- Deteccao de parada por som: limiares na unidade declarada.
  limiar_operando numeric(10,3) NOT NULL,
  limiar_parado numeric(10,3) NOT NULL,
  unidade_ruido text NOT NULL CHECK (unidade_ruido IN ('normalizado_0_1','adc_rms','dBFS','dB_SPL')),
  calibracao_ruido_ref text,
  confirmar_operando_ms integer NOT NULL CHECK (confirmar_operando_ms > 0),
  confirmar_parado_ms integer NOT NULL CHECK (confirmar_parado_ms > 0),
  -- Alertas: NULL em alerta_ur_max significa usar ur_liga. Destinatarios (e-mail, chat) ficam
  -- fora do banco, nas credenciais do backend, para nao gravar dados pessoais aqui.
  alerta_ur_max numeric(5,2) CHECK (alerta_ur_max IS NULL OR alerta_ur_max BETWEEN 0 AND 100),
  alerta_persistencia_s integer NOT NULL DEFAULT 60 CHECK (alerta_persistencia_s BETWEEN 0 AND 86400),
  alertar_parada boolean NOT NULL DEFAULT true,
  canal_dashboard boolean NOT NULL DEFAULT true,
  canal_email boolean NOT NULL DEFAULT false,
  canal_telegram boolean NOT NULL DEFAULT false,
  origem_parametros text NOT NULL CHECK (origem_parametros IN ('proposta_didatica','validado_empresa')),
  criado_em timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  observacao text,
  UNIQUE (sala_id, versao), UNIQUE (sala_id, id),
  CHECK (ur_desliga < ur_liga),
  CHECK (limiar_parado >= -200 AND limiar_operando <= 4095 AND limiar_parado < limiar_operando),
  CHECK (unidade_ruido <> 'normalizado_0_1' OR (limiar_parado >= 0 AND limiar_operando <= 1)),
  CHECK (unidade_ruido <> 'adc_rms' OR limiar_parado >= 0),
  CHECK (unidade_ruido <> 'dBFS' OR limiar_operando <= 0),
  CHECK (unidade_ruido <> 'dB_SPL' OR (calibracao_ruido_ref IS NOT NULL AND btrim(calibracao_ruido_ref) <> '')),
  CHECK (canal_dashboard OR canal_email OR canal_telegram),
  CHECK ((temperatura_min_c IS NULL AND temperatura_max_c IS NULL) OR
    (temperatura_min_c IS NOT NULL AND temperatura_max_c IS NOT NULL AND
     temperatura_min_c >= -40 AND temperatura_max_c <= 125 AND temperatura_min_c < temperatura_max_c))
);
CREATE UNIQUE INDEX uma_configuracao_ativa_por_sala
  ON mixnutri.configuracao_alertas(sala_id) WHERE ativo;

CREATE TABLE mixnutri.telemetria_sala01 (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sala_id text NOT NULL DEFAULT 'sala01' CHECK (btrim(sala_id) <> ''),
  device_id text NOT NULL CHECK (btrim(device_id) <> ''),
  boot_id text NOT NULL CHECK (btrim(boot_id) <> ''),
  seq bigint NOT NULL CHECK (seq >= 0),
  uptime_ms bigint NOT NULL CHECK (uptime_ms >= 0),
  data_medicao timestamptz,
  data_recebimento timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  origem_dados text NOT NULL CHECK (origem_dados IN ('simulacao','real')),
  produto text NOT NULL CHECK (btrim(produto) <> ''),
  lote_producao text NOT NULL CHECK (btrim(lote_producao) <> ''),
  lote_capsula text CHECK (lote_capsula IS NULL OR btrim(lote_capsula) <> ''),
  lote_po text CHECK (lote_po IS NULL OR btrim(lote_po) <> ''),
  temperatura_c numeric(6,2) CHECK (temperatura_c BETWEEN -40 AND 125),
  umidade_pct numeric(5,2) CHECK (umidade_pct BETWEEN 0 AND 100),
  clima_valido boolean NOT NULL,
  nivel_ruido numeric(10,3) CHECK (nivel_ruido BETWEEN -200 AND 4095),
  unidade_ruido text CHECK (unidade_ruido IN ('normalizado_0_1','adc_rms','dBFS','dB_SPL')),
  calibracao_ruido_ref text,
  fonte_estado text NOT NULL CHECK (fonte_estado IN ('sintetico','audio','modbus','indisponivel')),
  estado_maquina text NOT NULL CHECK (estado_maquina IN ('DESCONHECIDO','OPERANDO','PARADO')),
  modo text NOT NULL CHECK (modo IN ('AUTO','MANUAL')),
  desumidificador_comandado boolean NOT NULL,
  configuracao_id bigint,
  UNIQUE (sala_id, device_id, boot_id, seq),
  FOREIGN KEY (sala_id, configuracao_id) REFERENCES mixnutri.configuracao_alertas(sala_id, id),
  CHECK ((clima_valido AND temperatura_c IS NOT NULL AND umidade_pct IS NOT NULL) OR
         (NOT clima_valido AND temperatura_c IS NULL AND umidade_pct IS NULL)),
  CHECK ((nivel_ruido IS NULL AND unidade_ruido IS NULL) OR (nivel_ruido IS NOT NULL AND unidade_ruido IS NOT NULL)),
  CHECK (unidade_ruido <> 'normalizado_0_1' OR nivel_ruido BETWEEN 0 AND 1),
  CHECK (unidade_ruido <> 'adc_rms' OR nivel_ruido >= 0),
  CHECK (unidade_ruido <> 'dBFS' OR nivel_ruido <= 0),
  CHECK (unidade_ruido <> 'dB_SPL' OR (calibracao_ruido_ref IS NOT NULL AND btrim(calibracao_ruido_ref) <> '')),
  CHECK (fonte_estado <> 'indisponivel' OR estado_maquina = 'DESCONHECIDO'),
  CHECK (fonte_estado <> 'sintetico' OR origem_dados = 'simulacao')
);
CREATE INDEX telemetria_por_sala_tempo ON mixnutri.telemetria_sala01(sala_id, data_recebimento DESC);
CREATE INDEX telemetria_por_produto_lote ON mixnutri.telemetria_sala01(produto, lote_producao, data_recebimento);

CREATE TABLE mixnutri.paradas_maquina_sala01 (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sala_id text NOT NULL DEFAULT 'sala01' CHECK (btrim(sala_id) <> ''),
  device_id text NOT NULL CHECK (btrim(device_id) <> ''),
  evento_id text NOT NULL CHECK (btrim(evento_id) <> ''),
  origem_dados text NOT NULL CHECK (origem_dados IN ('simulacao','real')),
  produto text NOT NULL CHECK (btrim(produto) <> ''),
  lote_producao text NOT NULL CHECK (btrim(lote_producao) <> ''),
  lote_capsula text CHECK (lote_capsula IS NULL OR btrim(lote_capsula) <> ''),
  fonte_estado text NOT NULL CHECK (fonte_estado IN ('sintetico','audio','modbus')),
  inicio timestamptz NOT NULL,
  fim timestamptz,
  motivo_fim text CHECK (motivo_fim IS NULL OR
    motivo_fim IN ('retorno_operacao','fonte_indisponivel','reinicio_dispositivo','encerramento_manual')),
  referencia_tempo text NOT NULL CHECK (referencia_tempo IN ('dispositivo_sincronizado','recebimento_backend')),
  duracao_s numeric GENERATED ALWAYS AS (extract(epoch FROM (fim - inicio))) STORED,
  codigo_falha integer,
  observacao text,
  UNIQUE (sala_id, device_id, evento_id),
  CHECK (fim IS NULL OR fim >= inicio),
  CHECK (fim IS NOT NULL OR motivo_fim IS NULL),
  CHECK (fonte_estado = 'modbus' OR codigo_falha IS NULL),
  CHECK (fonte_estado <> 'sintetico' OR origem_dados = 'simulacao')
);
CREATE INDEX paradas_por_sala_tempo ON mixnutri.paradas_maquina_sala01(sala_id, inicio DESC);
CREATE UNIQUE INDEX uma_parada_aberta_por_fonte
  ON mixnutri.paradas_maquina_sala01(sala_id, device_id, fonte_estado) WHERE fim IS NULL;

-- Registro dos alertas gerados pelo backend (Figura 1: "telemetria · paradas · alertas").
CREATE TABLE mixnutri.alertas_emitidos (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sala_id text NOT NULL DEFAULT 'sala01' CHECK (btrim(sala_id) <> ''),
  configuracao_id bigint,
  tipo text NOT NULL CHECK (tipo IN ('UR_ALTA','TEMPERATURA_FORA','PARADA_MAQUINA','UR_ALTA_E_PARADA',
                                     'SENSOR_FALHA','DISPOSITIVO_OFFLINE')),
  severidade text NOT NULL CHECK (severidade IN ('info','aviso','critico')),
  origem_dados text NOT NULL CHECK (origem_dados IN ('simulacao','real')),
  inicio timestamptz NOT NULL,
  fim timestamptz,
  valor_observado numeric(10,3),
  limite numeric(10,3),
  unidade text,
  mensagem text NOT NULL CHECK (btrim(mensagem) <> ''),
  canais text[] NOT NULL DEFAULT ARRAY['dashboard']::text[],
  status_envio text NOT NULL DEFAULT 'pendente'
    CHECK (status_envio IN ('pendente','enviado','falha_envio','somente_dashboard')),
  enviado_em timestamptz,
  reconhecido_em timestamptz,
  telemetria_id bigint REFERENCES mixnutri.telemetria_sala01(id),
  parada_id bigint REFERENCES mixnutri.paradas_maquina_sala01(id),
  criado_em timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sala_id, configuracao_id) REFERENCES mixnutri.configuracao_alertas(sala_id, id),
  CHECK (cardinality(canais) > 0 AND canais <@ ARRAY['dashboard','email','telegram']::text[]),
  CHECK (fim IS NULL OR fim >= inicio),
  CHECK ((valor_observado IS NULL AND limite IS NULL) OR unidade IS NOT NULL),
  CHECK (status_envio <> 'enviado' OR enviado_em IS NOT NULL),
  CHECK (tipo NOT IN ('PARADA_MAQUINA','UR_ALTA_E_PARADA') OR parada_id IS NOT NULL)
);
CREATE INDEX alertas_por_sala_tempo ON mixnutri.alertas_emitidos(sala_id, inicio DESC);
CREATE UNIQUE INDEX um_alerta_aberto_por_tipo
  ON mixnutri.alertas_emitidos(sala_id, tipo) WHERE fim IS NULL;

COMMENT ON TABLE mixnutri.telemetria_sala01 IS
  'Telemetria com produto/lote por leitura. Comando de rele nao comprova funcionamento fisico. Nao mede taxa de quebra.';
COMMENT ON TABLE mixnutri.paradas_maquina_sala01 IS
  'Paradas observadas ou inferidas; nao atribui causalidade ambiental. Guardar referencia temporal e origem.';
COMMENT ON TABLE mixnutri.configuracao_alertas IS
  'Configuracoes versionadas de controle e alerta. Valores didaticos nao representam limites industriais validados.';
COMMENT ON TABLE mixnutri.alertas_emitidos IS
  'Alertas gerados pelo backend. Coincidencia UR alta e parada e correlacao temporal, nao prova de causa.';
COMMENT ON COLUMN mixnutri.telemetria_sala01.nivel_ruido IS
  'dBFS = 20*log10(RMS_ADC/2048): nivel relativo ao ADC, sem calibracao acustica. Nao e dB SPL.';
COMMIT;
