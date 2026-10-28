-- Testes das funcoes integracao.* em casos que o log real nao cobre. Tudo dentro de uma
-- transacao desfeita no final (ROLLBACK): nao deixa dados. Executar como administrador do banco.
\set ON_ERROR_STOP on
BEGIN;
-- Isola os testes de alertas abertos pela reproducao do log.
UPDATE mixnutri.alertas_emitidos SET fim = greatest(inicio, now()) WHERE fim IS NULL;

CREATE FUNCTION pg_temp.tel(p_boot text, p_seq int, p_t text, p_ur numeric, p_dbfs numeric DEFAULT -11)
RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('schema_version', 2, 'device_id', 'teste-funcoes', 'sala_id', 'sala01',
    'boot_id', p_boot, 'seq', p_seq, 'uptime_ms', 5000 * (p_seq + 1), 'timestamp_utc', p_t, 'clock_synced', true,
    'origem_dados', 'simulacao', 'produto', 'PRODUTO_TESTE', 'lote_producao', 'LOTE_TESTE_01',
    'temperatura_c', 25, 'umidade_pct', p_ur, 'clima_valido', true, 'nivel_ruido', p_dbfs,
    'unidade_ruido', 'dBFS', 'fonte_estado', 'sintetico', 'estado_maquina', 'OPERANDO', 'modo', 'AUTO',
    'desumidificador_comandado', false, 'config_version', 1)
$$;

CREATE FUNCTION pg_temp.evt(p_tipo text, p_boot text, p_seq int, p_t text, p_extra jsonb DEFAULT '{}')
RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('schema_version', 2, 'device_id', 'teste-funcoes', 'sala_id', 'sala01',
    'boot_id', p_boot, 'seq', p_seq, 'uptime_ms', 60000 + p_seq, 'timestamp_utc', p_t, 'clock_synced', true,
    'origem_dados', 'simulacao', 'tipo', p_tipo, 'produto', 'PRODUTO_TESTE', 'lote_producao', 'LOTE_TESTE_01',
    'fonte_estado', 'sintetico') || p_extra
$$;

DO $$
DECLARE
  r text;
  topo_t constant text := 'mixnutri/sala01/telemetria';
  topo_e constant text := 'mixnutri/sala01/eventos';
  p mixnutri.paradas_maquina_sala01;
BEGIN
  -- T1: telemetria repetida (mesmo device/boot/seq) e descartada.
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 0, '2026-10-27T10:00:00Z', 50));
  ASSERT r = 'telemetria_gravada', 'T1a ' || r;
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 0, '2026-10-27T10:00:00Z', 50));
  ASSERT r = 'duplicada', 'T1b ' || r;
  RAISE NOTICE 'T1 ok: telemetria duplicada descartada';

  -- T2: UR_ALTA so abre apos 60 s continuos >= 55 %UR (config v1) e fecha abaixo do limite.
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 1, '2026-10-27T10:01:00Z', 60));
  ASSERT r = 'telemetria_gravada', 'T2a ' || r;
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 2, '2026-10-27T10:01:30Z', 61));
  ASSERT r = 'telemetria_gravada', 'T2b ' || r;
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 3, '2026-10-27T10:02:00Z', 62));
  ASSERT r LIKE '%UR_ALTA aberto', 'T2c ' || r;
  ASSERT (SELECT inicio FROM mixnutri.alertas_emitidos WHERE tipo = 'UR_ALTA' AND fim IS NULL)
         = '2026-10-27T10:01:00Z', 'T2d inicio do alerta';
  r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 4, '2026-10-27T10:02:30Z', 50));
  ASSERT r LIKE '%UR_ALTA fechado', 'T2e ' || r;
  RAISE NOTICE 'T2 ok: UR_ALTA com persistencia de 60 s abre e fecha';

  -- T3: valor fora das restricoes do schema (dBFS positivo) e rejeitado pelo banco.
  BEGIN
    r := integracao.gravar_telemetria(topo_t, pg_temp.tel('t1', 5, '2026-10-27T10:03:00Z', 50, 3));
    RAISE EXCEPTION 'T3 deveria falhar';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'T3 ok: dBFS positivo rejeitado (check_violation)';
  END;

  -- T4: segunda PARADA_INICIO com outra parada aberta na mesma fonte e rejeitada sem erro.
  r := integracao.gravar_parada_inicio(topo_e, pg_temp.evt('PARADA_INICIO', 't1', 10, '2026-10-27T10:05:00Z',
         '{"evento_id":"tf-t1-1","inicio_utc":"2026-10-27T10:04:55Z"}'));
  ASSERT r LIKE 'parada_aberta%', 'T4a ' || r;
  r := integracao.gravar_parada_inicio(topo_e, pg_temp.evt('PARADA_INICIO', 't1', 11, '2026-10-27T10:06:00Z',
         '{"evento_id":"tf-t1-2","inicio_utc":"2026-10-27T10:05:55Z"}'));
  ASSERT r = 'rejeitada: outra parada aberta para a mesma fonte', 'T4b ' || r;
  RAISE NOTICE 'T4 ok: parada simultanea na mesma fonte rejeitada';

  -- T5: BOOT fecha a parada aberta; PARADA_FIM atrasada (fila da Flash) corrige o fim.
  r := integracao.gravar_boot(topo_e, pg_temp.evt('BOOT', 't2', 0, '2026-10-27T10:07:00Z'));
  ASSERT r = 'boot t2: 1 parada(s) fechada(s) por reinicio', 'T5a ' || r;
  SELECT * INTO p FROM mixnutri.paradas_maquina_sala01 WHERE evento_id = 'tf-t1-1';
  ASSERT p.motivo_fim = 'reinicio_dispositivo' AND p.fim = '2026-10-27T10:07:00Z', 'T5b';
  ASSERT (SELECT fim FROM mixnutri.alertas_emitidos WHERE parada_id = p.id AND tipo = 'PARADA_MAQUINA')
         = '2026-10-27T10:07:00Z', 'T5c alerta fechado no BOOT';
  r := integracao.gravar_parada_fim(topo_e, pg_temp.evt('PARADA_FIM', 't1', 12, '2026-10-27T10:06:10Z',
         '{"evento_id":"tf-t1-1","inicio_utc":"2026-10-27T10:04:55Z","fim_utc":"2026-10-27T10:06:05Z","motivo_fim":"retorno_operacao"}'));
  ASSERT r = 'parada_fim_corrigido_pelo_dispositivo', 'T5d ' || r;
  SELECT * INTO p FROM mixnutri.paradas_maquina_sala01 WHERE evento_id = 'tf-t1-1';
  ASSERT p.motivo_fim = 'retorno_operacao' AND p.fim = '2026-10-27T10:06:05Z', 'T5e';
  RAISE NOTICE 'T5 ok: BOOT fecha parada; PARADA_FIM atrasada corrige o fim';

  -- T6: PARADA_INICIO atrasada de um boot anterior ao ultimo BOOT e gravada ja encerrada.
  r := integracao.gravar_parada_inicio(topo_e, pg_temp.evt('PARADA_INICIO', 't1', 13, '2026-10-27T10:06:30Z',
         '{"evento_id":"tf-t1-3","inicio_utc":"2026-10-27T10:06:25Z"}'));
  ASSERT r = 'parada_gravada_ja_encerrada_por_reinicio', 'T6a ' || r;
  SELECT * INTO p FROM mixnutri.paradas_maquina_sala01 WHERE evento_id = 'tf-t1-3';
  ASSERT p.motivo_fim = 'reinicio_dispositivo' AND p.fim = '2026-10-27T10:07:00Z', 'T6b';
  RAISE NOTICE 'T6 ok: PARADA_INICIO de boot antigo gravada encerrada';

  -- T7: PARADA_FIM sem PARADA_INICIO recebida e gravada completa.
  r := integracao.gravar_parada_fim(topo_e, pg_temp.evt('PARADA_FIM', 't2', 1, '2026-10-27T10:09:00Z',
         '{"evento_id":"tf-t2-1","inicio_utc":"2026-10-27T10:08:00Z","fim_utc":"2026-10-27T10:08:50Z"}'));
  ASSERT r = 'parada_gravada_sem_inicio', 'T7 ' || r;
  RAISE NOTICE 'T7 ok: PARADA_FIM sem inicio gravada';

  -- T8: CONFIG_APLICADA de uma versao ja registrada nao cria outra linha nem muda a ativa.
  r := integracao.gravar_config_aplicada(topo_e, pg_temp.evt('CONFIG_APLICADA', 't2', 2, '2026-10-27T10:10:00Z',
         '{"config_version":1,"ur_liga":55,"ur_desliga":50,"limiar_operando_dbfs":-25,"limiar_parado_dbfs":-35}'));
  ASSERT r = 'configuracao v1 ja registrada', 'T8 ' || r;
  RAISE NOTICE 'T8 ok: versao de configuracao repetida ignorada';
END $$;
ROLLBACK;
