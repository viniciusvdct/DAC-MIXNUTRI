-- Item 3: PROPOSTA da equipe 1 para a equipe 2 avaliar (nao e a entrega da equipe 2).
-- Ingestao MQTT -> PostgreSQL sobre o schema v2 do item 1, sem altera-lo. O fluxo do Node-RED
-- escolhe a funcao pelo topico/tipo; cada mensagem e gravada numa unica transacao.
-- Dados sinteticos. Limites e regras de alerta sao didaticos, nao validados pela empresa.
-- Alerta de UR alta, parada ou coincidencia nao prova causa de quebra de capsula.
BEGIN;

CREATE SCHEMA integracao;
COMMENT ON SCHEMA integracao IS 'Proposta do item 3 (equipe 1): registro bruto MQTT e funcoes de gravacao.';

-- Toda mensagem recebida, para auditoria e deduplicacao por (topico, device_id, boot_id, seq).
-- Mensagens sem essa chave (Admin, disponibilidade) nunca colidem, pois NULL e distinto.
CREATE TABLE integracao.mensagens_mqtt (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  topico text NOT NULL,
  recebido_em timestamptz NOT NULL DEFAULT clock_timestamp(),
  payload jsonb,
  payload_texto text,  -- so quando a mensagem nao foi gravada (JSON invalido ou erro)
  device_id text,
  boot_id text,
  seq bigint,
  tipo text,
  resultado text NOT NULL DEFAULT 'registrada',
  CHECK (payload IS NOT NULL OR payload_texto IS NOT NULL),
  UNIQUE (topico, device_id, boot_id, seq)
);
CREATE INDEX mensagens_por_dispositivo_tipo ON integracao.mensagens_mqtt (device_id, tipo, id DESC);

-- Versao 1 = configPadrao() do firmware do item 2. Novas versoes entram pelo evento CONFIG_APLICADA.
INSERT INTO mixnutri.configuracao_alertas
  (sala_id, versao, ativo, ur_liga, ur_desliga, limiar_operando, limiar_parado, unidade_ruido,
   confirmar_operando_ms, confirmar_parado_ms, origem_parametros, observacao)
VALUES ('sala01', 1, true, 55, 50, -25, -35, 'dBFS', 3000, 5000, 'proposta_didatica',
  'Espelho de configPadrao() do firmware do item 2. Valores didaticos, nao validados pela empresa.');

-- ---------------------------------------------------------------------------------------
-- Auxiliares (uso interno das funcoes de gravacao)
-- ---------------------------------------------------------------------------------------

-- Grava a mensagem bruta; devolve NULL quando ja foi recebida.
CREATE FUNCTION integracao.registrar(p_topico text, p jsonb) RETURNS bigint
LANGUAGE sql SET search_path = pg_catalog, pg_temp AS $$
  INSERT INTO integracao.mensagens_mqtt (topico, payload, device_id, boot_id, seq, tipo)
  VALUES (p_topico, p, p->>'device_id', p->>'boot_id', (p->>'seq')::bigint, p->>'tipo')
  ON CONFLICT (topico, device_id, boot_id, seq) DO NOTHING
  RETURNING id
$$;

CREATE FUNCTION integracao.concluir(p_msg bigint, p_resultado text) RETURNS text
LANGUAGE sql SET search_path = pg_catalog, pg_temp AS $$
  UPDATE integracao.mensagens_mqtt SET resultado = p_resultado WHERE id = p_msg RETURNING p_resultado
$$;

-- Sala pelo payload ou, na falta (Last Will), pelo topico mixnutri/<sala>/...
CREATE FUNCTION integracao.sala(p_topico text, p jsonb) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT coalesce(nullif(p->>'sala_id', ''), split_part(p_topico, '/', 2))
$$;

-- Horario do dispositivo quando o relogio esta sincronizado. Sem relogio: recebimento menos o
-- tempo decorrido no dispositivo (uptime). Mensagens atrasadas na fila ficam com erro maior.
CREATE FUNCTION integracao.horario(p jsonb, p_campo text, p_uptime text, p_recebido timestamptz)
RETURNS timestamptz LANGUAGE sql STABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT CASE
    WHEN (p->>'clock_synced')::boolean AND p->>p_campo IS NOT NULL THEN (p->>p_campo)::timestamptz
    ELSE p_recebido - make_interval(secs => greatest(0, (p->>'uptime_ms')::bigint
                                      - coalesce((p->>p_uptime)::bigint, (p->>'uptime_ms')::bigint)) / 1000.0)
  END
$$;

CREATE FUNCTION integracao.referencia(p jsonb, p_campo text) RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = pg_catalog, pg_temp AS $$
  SELECT CASE WHEN (p->>'clock_synced')::boolean AND p->>p_campo IS NOT NULL
              THEN 'dispositivo_sincronizado' ELSE 'recebimento_backend' END
$$;

-- Abre um alerta se nao houver outro aberto do mesmo tipo na sala; devolve o id ou NULL.
-- Canais vem da configuracao ativa. Envio por e-mail/Telegram fica fora desta proposta.
CREATE FUNCTION integracao.abrir_alerta(p_sala text, p_tipo text, p_severidade text, p_origem text,
  p_inicio timestamptz, p_valor numeric, p_limite numeric, p_unidade text, p_mensagem text,
  p_telemetria bigint, p_parada bigint, p_configuracao bigint DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  c mixnutri.configuracao_alertas;
  v_canais text[];
  v_id bigint;
BEGIN
  SELECT * INTO c FROM mixnutri.configuracao_alertas WHERE sala_id = p_sala AND ativo;
  v_canais := array_remove(ARRAY[
    CASE WHEN coalesce(c.canal_dashboard, true) THEN 'dashboard' END,
    CASE WHEN c.canal_email THEN 'email' END,
    CASE WHEN c.canal_telegram THEN 'telegram' END], NULL);
  INSERT INTO mixnutri.alertas_emitidos (sala_id, configuracao_id, tipo, severidade, origem_dados, inicio,
    valor_observado, limite, unidade, mensagem, canais, status_envio, telemetria_id, parada_id)
  VALUES (p_sala, coalesce(p_configuracao, c.id), p_tipo, p_severidade, p_origem, p_inicio, p_valor, p_limite,
    p_unidade, p_mensagem, v_canais,
    CASE WHEN v_canais = ARRAY['dashboard'] THEN 'somente_dashboard' ELSE 'pendente' END,
    p_telemetria, p_parada)
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE FUNCTION integracao.fechar_alertas(p_sala text, p_tipos text[], p_fim timestamptz) RETURNS integer
LANGUAGE sql SET search_path = pg_catalog, pg_temp AS $$
  WITH f AS (
    UPDATE mixnutri.alertas_emitidos SET fim = p_fim
     WHERE sala_id = p_sala AND tipo = ANY (p_tipos) AND fim IS NULL AND inicio <= p_fim
    RETURNING 1)
  SELECT count(*)::integer FROM f
$$;

-- ---------------------------------------------------------------------------------------
-- Funcoes chamadas pelo Node-RED: (topico, payload jsonb) -> texto com o resultado
-- ---------------------------------------------------------------------------------------

CREATE FUNCTION integracao.gravar_telemetria(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  t mixnutri.telemetria_sala01;
  c mixnutri.configuracao_alertas;
  v_t timestamptz;
  v_lim numeric;
  v_ok timestamptz;
  v_ini timestamptz;
  v_res text := 'telemetria_gravada';
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  SELECT * INTO c FROM mixnutri.configuracao_alertas
   WHERE sala_id = integracao.sala(p_topico, p) AND versao = (p->>'config_version')::integer;

  -- Campos extras (estado_som, estado_modbus, motivo_rele, fila_flash, ruido_adc_rms...) ficam
  -- apenas em integracao.mensagens_mqtt.payload: o schema do item 1 nao tem colunas para eles.
  INSERT INTO mixnutri.telemetria_sala01 (sala_id, device_id, boot_id, seq, uptime_ms, data_medicao,
    data_recebimento, origem_dados, produto, lote_producao, lote_capsula, lote_po, temperatura_c, umidade_pct,
    clima_valido, nivel_ruido, unidade_ruido, fonte_estado, estado_maquina, modo, desumidificador_comandado,
    configuracao_id)
  SELECT integracao.sala(p_topico, p), x.device_id, x.boot_id, x.seq, x.uptime_ms,
         CASE WHEN x.clock_synced THEN x.timestamp_utc END, v_rec,
         x.origem_dados, x.produto, x.lote_producao, x.lote_capsula, x.lote_po, x.temperatura_c, x.umidade_pct,
         x.clima_valido, x.nivel_ruido, x.unidade_ruido, x.fonte_estado, x.estado_maquina, x.modo,
         x.desumidificador_comandado, c.id
    FROM jsonb_to_record(p) AS x(device_id text, boot_id text, seq bigint, uptime_ms bigint,
         timestamp_utc timestamptz, clock_synced boolean, origem_dados text, produto text, lote_producao text,
         lote_capsula text, lote_po text, temperatura_c numeric, umidade_pct numeric, clima_valido boolean,
         nivel_ruido numeric, unidade_ruido text, fonte_estado text, estado_maquina text, modo text,
         desumidificador_comandado boolean)
  ON CONFLICT (sala_id, device_id, boot_id, seq) DO NOTHING
  RETURNING * INTO t;
  IF t.id IS NULL THEN RETURN integracao.concluir(v_msg, 'telemetria_ja_gravada'); END IF;

  -- UR_ALTA: leituras validas e continuas >= limite por alerta_persistencia_s (limite = alerta_ur_max
  -- ou ur_liga da versao de configuracao informada na leitura). Leitura invalida interrompe a sequencia.
  v_t := coalesce(t.data_medicao, t.data_recebimento);
  IF c.id IS NOT NULL AND t.clima_valido THEN
    v_lim := coalesce(c.alerta_ur_max, c.ur_liga);
    IF t.umidade_pct >= v_lim THEN
      SELECT max(coalesce(data_medicao, data_recebimento)) INTO v_ok
        FROM mixnutri.telemetria_sala01
       WHERE sala_id = t.sala_id AND device_id = t.device_id
         AND coalesce(data_medicao, data_recebimento) <= v_t
         AND (NOT clima_valido OR umidade_pct < v_lim);
      SELECT min(coalesce(data_medicao, data_recebimento)) INTO v_ini
        FROM mixnutri.telemetria_sala01
       WHERE sala_id = t.sala_id AND device_id = t.device_id
         AND coalesce(data_medicao, data_recebimento) > coalesce(v_ok, '-infinity')
         AND coalesce(data_medicao, data_recebimento) <= v_t;
      IF v_t - v_ini >= make_interval(secs => c.alerta_persistencia_s)
         AND integracao.abrir_alerta(t.sala_id, 'UR_ALTA', 'aviso', t.origem_dados, v_ini, t.umidade_pct, v_lim,
               '%UR', format('UR >= %s %%UR por pelo menos %s s (limite didatico, nao industrial)',
                             v_lim, c.alerta_persistencia_s), t.id, NULL, c.id) IS NOT NULL THEN
        v_res := v_res || '; alerta UR_ALTA aberto';
      END IF;
    ELSIF integracao.fechar_alertas(t.sala_id, ARRAY['UR_ALTA'], v_t) > 0 THEN
      v_res := v_res || '; alerta UR_ALTA fechado';
    END IF;
  END IF;
  RETURN integracao.concluir(v_msg, v_res);
END $$;

CREATE FUNCTION integracao.gravar_parada_inicio(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  v_sala text := integracao.sala(p_topico, p);
  v_ini timestamptz;
  v_boot_msg bigint;
  v_boot_id text;
  v_boot_t timestamptz;
  v_antigo boolean := false;
  v_par mixnutri.paradas_maquina_sala01;
  c mixnutri.configuracao_alertas;
  v_res text;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  v_ini := integracao.horario(p, 'inicio_utc', 'inicio_uptime_ms', v_rec);

  -- PARADA_INICIO atrasada (fila da Flash) de um boot que ja foi substituido por outro BOOT:
  -- grava a parada encerrada por reinicio, para nao deixa-la aberta para sempre.
  SELECT m.id, m.boot_id, integracao.horario(m.payload, 'timestamp_utc', 'uptime_ms', m.recebido_em)
    INTO v_boot_msg, v_boot_id, v_boot_t
    FROM integracao.mensagens_mqtt m
   WHERE m.topico = p_topico AND m.device_id = p->>'device_id' AND m.tipo = 'BOOT'
   ORDER BY m.id DESC LIMIT 1;
  IF v_boot_id IS DISTINCT FROM p->>'boot_id' AND v_boot_id IS NOT NULL THEN
    v_antigo := EXISTS (SELECT 1 FROM integracao.mensagens_mqtt m
                         WHERE m.device_id = p->>'device_id' AND m.boot_id = p->>'boot_id' AND m.id < v_boot_msg);
  END IF;

  INSERT INTO mixnutri.paradas_maquina_sala01 (sala_id, device_id, evento_id, origem_dados, produto,
    lote_producao, lote_capsula, fonte_estado, inicio, fim, motivo_fim, referencia_tempo, codigo_falha, observacao)
  VALUES (v_sala, p->>'device_id', p->>'evento_id', p->>'origem_dados', p->>'produto', p->>'lote_producao',
    p->>'lote_capsula', p->>'fonte_estado', v_ini,
    CASE WHEN v_antigo THEN greatest(v_boot_t, v_ini) END,
    CASE WHEN v_antigo THEN 'reinicio_dispositivo' END,
    integracao.referencia(p, 'inicio_utc'), (p->>'codigo_falha')::integer,
    CASE WHEN v_antigo THEN format('PARADA_INICIO recebida apos o BOOT %s; encerrada pelo backend', v_boot_id) END)
  ON CONFLICT DO NOTHING
  RETURNING * INTO v_par;

  IF v_par.id IS NULL THEN
    IF EXISTS (SELECT 1 FROM mixnutri.paradas_maquina_sala01
                WHERE sala_id = v_sala AND device_id = p->>'device_id' AND evento_id = p->>'evento_id') THEN
      RETURN integracao.concluir(v_msg, 'parada_ja_registrada');
    END IF;
    -- Indice uma_parada_aberta_por_fonte: outra parada desta fonte continua aberta (FIM perdido?).
    RETURN integracao.concluir(v_msg, 'rejeitada: outra parada aberta para a mesma fonte');
  END IF;
  IF v_par.fim IS NOT NULL THEN
    RETURN integracao.concluir(v_msg, 'parada_gravada_ja_encerrada_por_reinicio');
  END IF;

  v_res := 'parada_aberta';
  SELECT * INTO c FROM mixnutri.configuracao_alertas WHERE sala_id = v_sala AND ativo;
  IF coalesce(c.alertar_parada, true) THEN
    IF integracao.abrir_alerta(v_sala, 'PARADA_MAQUINA', 'aviso', v_par.origem_dados, v_par.inicio, NULL, NULL,
         NULL, format('Parada inferida pela fonte %s; nao mede quebra de capsula', v_par.fonte_estado),
         NULL, v_par.id) IS NOT NULL THEN
      v_res := v_res || '; alerta PARADA_MAQUINA aberto';
    END IF;
    IF EXISTS (SELECT 1 FROM mixnutri.alertas_emitidos WHERE sala_id = v_sala AND tipo = 'UR_ALTA' AND fim IS NULL)
       AND integracao.abrir_alerta(v_sala, 'UR_ALTA_E_PARADA', 'aviso', v_par.origem_dados, v_par.inicio, NULL,
             NULL, NULL, 'UR alta e parada ao mesmo tempo: coincidencia temporal, nao prova de causa',
             NULL, v_par.id) IS NOT NULL THEN
      v_res := v_res || '; alerta UR_ALTA_E_PARADA aberto';
    END IF;
  END IF;
  RETURN integracao.concluir(v_msg, v_res);
END $$;

CREATE FUNCTION integracao.gravar_parada_fim(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  v_sala text := integracao.sala(p_topico, p);
  v_ini timestamptz;
  v_fim timestamptz;
  v_motivo text := coalesce(p->>'motivo_fim', 'retorno_operacao');
  v_par mixnutri.paradas_maquina_sala01;
  v_res text;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  v_ini := integracao.horario(p, 'inicio_utc', 'inicio_uptime_ms', v_rec);
  v_fim := integracao.horario(p, 'fim_utc', 'fim_uptime_ms', v_rec);

  SELECT * INTO v_par FROM mixnutri.paradas_maquina_sala01
   WHERE sala_id = v_sala AND device_id = p->>'device_id' AND evento_id = p->>'evento_id'
   FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO mixnutri.paradas_maquina_sala01 (sala_id, device_id, evento_id, origem_dados, produto,
      lote_producao, lote_capsula, fonte_estado, inicio, fim, motivo_fim, referencia_tempo, codigo_falha, observacao)
    VALUES (v_sala, p->>'device_id', p->>'evento_id', p->>'origem_dados', p->>'produto', p->>'lote_producao',
      p->>'lote_capsula', p->>'fonte_estado', v_ini, greatest(v_fim, v_ini), v_motivo,
      integracao.referencia(p, 'inicio_utc'), (p->>'codigo_falha')::integer,
      'PARADA_INICIO nao recebida; registrada pela PARADA_FIM')
    RETURNING * INTO v_par;
    v_res := 'parada_gravada_sem_inicio';
  ELSIF v_par.fim IS NULL OR v_par.motivo_fim = 'reinicio_dispositivo' THEN
    -- O fim informado pelo dispositivo prevalece sobre o fechamento estimado no BOOT.
    v_res := CASE WHEN v_par.fim IS NULL THEN 'parada_fechada' ELSE 'parada_fim_corrigido_pelo_dispositivo' END;
    UPDATE mixnutri.paradas_maquina_sala01
       SET fim = greatest(v_fim, inicio), motivo_fim = v_motivo,
           observacao = CASE WHEN fim IS NULL THEN observacao
                             ELSE concat_ws('; ', observacao, 'fim corrigido pela PARADA_FIM do dispositivo') END
     WHERE id = v_par.id
    RETURNING * INTO v_par;
  ELSE
    RETURN integracao.concluir(v_msg, 'parada_ja_encerrada');
  END IF;

  UPDATE mixnutri.alertas_emitidos SET fim = greatest(v_par.fim, inicio) WHERE parada_id = v_par.id;
  RETURN integracao.concluir(v_msg, v_res);
END $$;

CREATE FUNCTION integracao.gravar_boot(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  v_sala text := integracao.sala(p_topico, p);
  v_t timestamptz;
  v_n integer;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  v_t := integracao.horario(p, 'timestamp_utc', 'uptime_ms', v_rec);

  -- Contrato v2: ao receber BOOT, fechar paradas abertas do dispositivo com reinicio_dispositivo.
  -- O fim real e desconhecido; usa-se o horario do BOOT.
  WITH f AS (
    UPDATE mixnutri.paradas_maquina_sala01
       SET fim = greatest(v_t, inicio), motivo_fim = 'reinicio_dispositivo',
           observacao = concat_ws('; ', observacao,
             format('encerrada pelo backend ao receber BOOT %s; fim = horario do BOOT, nao o fim real', p->>'boot_id'))
     WHERE sala_id = v_sala AND device_id = p->>'device_id' AND fim IS NULL AND inicio <= v_t
    RETURNING id, fim),
  a AS (
    UPDATE mixnutri.alertas_emitidos al SET fim = greatest(f.fim, al.inicio)
      FROM f WHERE al.parada_id = f.id AND al.fim IS NULL
    RETURNING 1)
  SELECT count(*) INTO v_n FROM f;
  RETURN integracao.concluir(v_msg, format('boot %s: %s parada(s) fechada(s) por reinicio', p->>'boot_id', v_n));
END $$;

CREATE FUNCTION integracao.gravar_sensor(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  v_sala text := integracao.sala(p_topico, p);
  v_t timestamptz;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  v_t := integracao.horario(p, 'timestamp_utc', 'uptime_ms', v_rec);
  IF p->>'tipo' = 'SENSOR_FALHA' THEN
    RETURN integracao.concluir(v_msg, CASE WHEN integracao.abrir_alerta(v_sala, 'SENSOR_FALHA', 'critico',
      p->>'origem_dados', v_t, NULL, NULL, NULL,
      format('Falha de leitura do sensor %s informada pelo dispositivo', coalesce(p->>'sensor', '?')), NULL, NULL)
      IS NOT NULL THEN 'alerta SENSOR_FALHA aberto' ELSE 'alerta SENSOR_FALHA ja estava aberto' END);
  ELSIF p->>'tipo' = 'SENSOR_OK' THEN
    RETURN integracao.concluir(v_msg, format('%s alerta(s) SENSOR_FALHA fechado(s)',
      integracao.fechar_alertas(v_sala, ARRAY['SENSOR_FALHA'], v_t)));
  END IF;
  RAISE EXCEPTION 'gravar_sensor: tipo inesperado %', p->>'tipo';
END $$;

CREATE FUNCTION integracao.gravar_config_aplicada(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_sala text := integracao.sala(p_topico, p);
  v_ver integer := (p->>'config_version')::integer;
  b mixnutri.configuracao_alertas;
  v_id bigint;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  IF EXISTS (SELECT 1 FROM mixnutri.configuracao_alertas WHERE sala_id = v_sala AND versao = v_ver) THEN
    RETURN integracao.concluir(v_msg, format('configuracao v%s ja registrada', v_ver));
  END IF;
  SELECT * INTO b FROM mixnutri.configuracao_alertas
   WHERE sala_id = v_sala AND versao < v_ver ORDER BY versao DESC LIMIT 1;
  IF b.id IS NULL THEN
    RETURN integracao.concluir(v_msg, 'rejeitada: sem versao anterior para copiar tempos e alertas');
  END IF;

  -- O evento traz UR e limiares; tempos de confirmacao e regras de alerta sao copiados da versao anterior.
  INSERT INTO mixnutri.configuracao_alertas (sala_id, versao, ativo, ur_liga, ur_desliga, temperatura_min_c,
    temperatura_max_c, limiar_operando, limiar_parado, unidade_ruido, confirmar_operando_ms, confirmar_parado_ms,
    alerta_ur_max, alerta_persistencia_s, alertar_parada, canal_dashboard, canal_email, canal_telegram,
    origem_parametros, observacao)
  VALUES (v_sala, v_ver, false, (p->>'ur_liga')::numeric, (p->>'ur_desliga')::numeric, b.temperatura_min_c,
    b.temperatura_max_c, (p->>'limiar_operando_dbfs')::numeric, (p->>'limiar_parado_dbfs')::numeric, 'dBFS',
    b.confirmar_operando_ms, b.confirmar_parado_ms, b.alerta_ur_max, b.alerta_persistencia_s, b.alertar_parada,
    b.canal_dashboard, b.canal_email, b.canal_telegram, 'proposta_didatica',
    format('Registrada a partir de CONFIG_APLICADA (%s, boot %s, seq %s, modbus_habilitado=%s). Tempos de '
           'confirmacao e alertas copiados da versao %s: o evento nao os informa.',
           p->>'device_id', p->>'boot_id', p->>'seq', p->>'modbus_habilitado', b.versao))
  RETURNING id INTO v_id;

  IF v_ver > coalesce((SELECT max(versao) FROM mixnutri.configuracao_alertas WHERE sala_id = v_sala AND ativo), 0) THEN
    UPDATE mixnutri.configuracao_alertas SET ativo = false WHERE sala_id = v_sala AND ativo;
    UPDATE mixnutri.configuracao_alertas SET ativo = true WHERE id = v_id;
    RETURN integracao.concluir(v_msg, format('configuracao v%s registrada e ativa', v_ver));
  END IF;
  RETURN integracao.concluir(v_msg, format('configuracao v%s registrada (mais antiga que a ativa)', v_ver));
END $$;

CREATE FUNCTION integracao.gravar_disponibilidade(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_msg bigint;
  v_rec timestamptz;
  v_sala text := integracao.sala(p_topico, p);
  v_origem text;
BEGIN
  v_msg := integracao.registrar(p_topico, p);
  IF v_msg IS NULL THEN RETURN 'duplicada'; END IF;
  SELECT recebido_em INTO v_rec FROM integracao.mensagens_mqtt WHERE id = v_msg;
  IF p->>'estado' = 'offline' THEN
    -- O Last Will nao traz device_id nem origem_dados: usa a ultima origem vista na sala.
    SELECT m.payload->>'origem_dados' INTO v_origem FROM integracao.mensagens_mqtt m
     WHERE m.topico LIKE 'mixnutri/' || v_sala || '/%' AND m.payload ? 'origem_dados'
     ORDER BY m.id DESC LIMIT 1;
    RETURN integracao.concluir(v_msg, CASE WHEN integracao.abrir_alerta(v_sala, 'DISPOSITIVO_OFFLINE', 'aviso',
      coalesce(v_origem, 'simulacao'), v_rec, NULL, NULL, NULL,
      'Dispositivo offline (Last Will do broker); horario = recebimento no backend', NULL, NULL) IS NOT NULL
      THEN 'alerta DISPOSITIVO_OFFLINE aberto' ELSE 'alerta DISPOSITIVO_OFFLINE ja estava aberto' END);
  ELSIF p->>'estado' = 'online' THEN
    RETURN integracao.concluir(v_msg, format('%s alerta(s) DISPOSITIVO_OFFLINE fechado(s)',
      integracao.fechar_alertas(v_sala, ARRAY['DISPOSITIVO_OFFLINE'], v_rec)));
  END IF;
  RETURN integracao.concluir(v_msg, 'estado de disponibilidade desconhecido');
END $$;

-- Comandos, configuracao e contexto do Admin, confirmacoes e eventos sem tabela propria
-- (RELE, MODO, ESTADO_MAQUINA...) ficam apenas no registro bruto.
CREATE FUNCTION integracao.registrar_somente(p_topico text, p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
BEGIN
  RETURN CASE WHEN integracao.registrar(p_topico, p) IS NULL THEN 'duplicada' ELSE 'registrada' END;
END $$;

-- Chamado pelo ramo de erro do fluxo: guarda o texto original e o motivo da rejeicao.
CREATE FUNCTION integracao.registrar_falha(p_topico text, p_texto text, p_erro text) RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  INSERT INTO integracao.mensagens_mqtt (topico, payload_texto, resultado)
  VALUES (p_topico, coalesce(p_texto, ''), 'erro: ' || left(coalesce(p_erro, '?'), 300))
  RETURNING 'falha_registrada'
$$;

-- ---------------------------------------------------------------------------------------
-- Apoio ao Admin (item 4) e a leitura Modbus no Node-RED
-- ---------------------------------------------------------------------------------------

-- Versao seguinte para o Admin publicar: o firmware recusa versao igual ou menor que a aplicada.
-- Considera as versoes registradas e as ja publicadas no topico (ainda sem CONFIG_APLICADA).
CREATE FUNCTION integracao.proxima_versao_config(p_sala text) RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT greatest(
    (SELECT coalesce(max(versao), 0) FROM mixnutri.configuracao_alertas WHERE sala_id = p_sala),
    (SELECT coalesce(max(floor((payload->>'versao')::numeric)), 0)::bigint FROM integracao.mensagens_mqtt
      WHERE topico = 'mixnutri/' || p_sala || '/configuracao' AND jsonb_typeof(payload->'versao') = 'number')
  ) + 1
$$;

-- Estado resumido para abrir o painel Admin; depois ele se atualiza pelas mensagens MQTT.
-- O contexto vem da ultima telemetria do ESP32 (produto/lote em vigor no dispositivo).
CREATE FUNCTION integracao.estado_admin(p_sala text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
  SELECT jsonb_build_object(
    'proxima_versao', integracao.proxima_versao_config(p_sala),
    'configuracao', (SELECT jsonb_build_object('versao', versao, 'ur_max', ur_liga, 'histerese', histerese_pp,
        'limiar_db', limiar_operando, 'banda_db', limiar_operando - limiar_parado, 'unidade_ruido', unidade_ruido)
      FROM mixnutri.configuracao_alertas WHERE sala_id = p_sala AND ativo),
    'contexto', coalesce((SELECT jsonb_build_object('produto', produto, 'lote_producao', lote_producao,
        'lote_capsula', lote_capsula, 'lote_po', lote_po)
      FROM mixnutri.telemetria_sala01 WHERE sala_id = p_sala ORDER BY id DESC LIMIT 1),
      jsonb_build_object('produto', 'NAO_INFORMADO', 'lote_producao', 'NAO_INFORMADO')),
    'disponibilidade', (SELECT payload FROM integracao.mensagens_mqtt
      WHERE topico = 'mixnutri/' || p_sala || '/disponibilidade' AND payload IS NOT NULL ORDER BY id DESC LIMIT 1),
    'ultima_confirmacao', (SELECT payload FROM integracao.mensagens_mqtt
      WHERE topico = 'mixnutri/' || p_sala || '/confirmacoes' AND payload IS NOT NULL ORDER BY id DESC LIMIT 1))
$$;

-- ---------------------------------------------------------------------------------------
-- Papeis: o Node-RED so executa as funcoes; o Grafana so le. Senhas em 03_senhas.sh (.env).
-- ---------------------------------------------------------------------------------------
CREATE ROLE nodered_ingestao NOLOGIN;
CREATE ROLE grafana_leitura NOLOGIN;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA integracao FROM PUBLIC;
GRANT USAGE ON SCHEMA integracao TO nodered_ingestao;
GRANT EXECUTE ON FUNCTION
  integracao.gravar_telemetria(text, jsonb), integracao.gravar_parada_inicio(text, jsonb),
  integracao.gravar_parada_fim(text, jsonb), integracao.gravar_boot(text, jsonb),
  integracao.gravar_sensor(text, jsonb), integracao.gravar_config_aplicada(text, jsonb),
  integracao.gravar_disponibilidade(text, jsonb), integracao.registrar_somente(text, jsonb),
  integracao.registrar_falha(text, text, text), integracao.proxima_versao_config(text),
  integracao.estado_admin(text)
  TO nodered_ingestao;
GRANT USAGE ON SCHEMA mixnutri, integracao TO grafana_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA mixnutri, integracao TO grafana_leitura;

COMMIT;
