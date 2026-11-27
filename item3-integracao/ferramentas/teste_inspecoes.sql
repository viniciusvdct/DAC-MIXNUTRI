-- Execute com o papel de administração depois da migração 04. Os dados do teste são revertidos.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL plpgsql.check_asserts TO on;

INSERT INTO mixnutri.telemetria_sala01 (
  sala_id, device_id, boot_id, seq, uptime_ms, data_medicao, data_recebimento, origem_dados, produto,
  lote_producao, temperatura_c, umidade_pct, clima_valido, fonte_estado, estado_maquina, modo,
  desumidificador_comandado
)
SELECT sala, 'sensor-teste-inspecoes', 'teste-inspecoes', seq, 100, medicao, recebimento, origem, produto,
       lote, temperatura, umidade, temperatura IS NOT NULL, 'audio', 'OPERANDO', 'AUTO', false
  FROM (VALUES
  (1, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:00:00Z'::timestamptz, '2026-10-27T13:00:00Z'::timestamptz, 22, 50),
  (2, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:05:00Z', '2026-10-27T13:00:00Z', 27, 65),
  (3, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', NULL, '2026-10-27T12:06:00Z', 24, 55),
  (4, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:10:00Z', '2026-10-27T13:00:00Z', 30, 70),
  (5, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:19:59Z', '2026-10-27T13:00:00Z', 32, 73),
  (6, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:20:00Z', '2026-10-27T13:00:00Z', 90, 90),
  (7, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T11:59:59Z', '2026-10-27T12:01:00Z', 90, 90),
  (8, 'sala-teste', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:04:00Z', '2026-10-27T13:00:00Z', NULL, NULL),
  (9, 'sala-teste', 'real',      'P-TESTE', 'L-TESTE', '2026-10-27T12:04:00Z', '2026-10-27T13:00:00Z', 90, 90),
  (10, 'sala-teste', 'simulacao', 'P-TESTE', 'OUTRO',  '2026-10-27T12:04:00Z', '2026-10-27T13:00:00Z', 90, 90),
  (11, 'sala-teste', 'simulacao', 'OUTRO',   'L-TESTE', '2026-10-27T12:04:00Z', '2026-10-27T13:00:00Z', 90, 90),
  (12, 'outra-sala', 'simulacao', 'P-TESTE', 'L-TESTE', '2026-10-27T12:04:00Z', '2026-10-27T13:00:00Z', 90, 90)
  ) AS dados(seq, sala, origem, produto, lote, medicao, recebimento, temperatura, umidade);

DO $$
DECLARE
  a jsonb := '{
    "envio_id":"00000000-0000-4000-8000-000000000001", "sala_id":"sala-teste", "maquina":"Encapsuladora",
    "produto":"P-TESTE", "lote_producao":"L-TESTE", "ponto_inspecao":"Saída",
    "inicio":"2026-10-27T08:00:00-04:00", "fim":"2026-10-27T08:10:00-04:00",
    "origem_dados":"simulacao", "total_inspecionado":200, "quantidade_quebrada":4
  }';
  b jsonb := a || '{
    "envio_id":"00000000-0000-4000-8000-000000000002", "inicio":"2026-10-27T12:10:00Z",
    "fim":"2026-10-27T12:20:00Z", "total_inspecionado":300, "quantidade_quebrada":3
  }';
  sem_dados jsonb := a || '{
    "envio_id":"00000000-0000-4000-8000-000000000003", "lote_producao":"SEM-DADOS",
    "total_inspecionado":0, "quantidade_quebrada":0
  }';
  sem_quebras jsonb := sem_dados || '{
    "envio_id":"00000000-0000-4000-8000-000000000004", "total_inspecionado":25,
    "lote_capsula":" LC-INDUSTRIAL ", "observacoes":"Amostra de teste"
  }';
  nova_amostra jsonb := a || '{"envio_id":"00000000-0000-4000-8000-000000000005"}';
  resultado_a jsonb;
  resultado_b jsonb;
  resultado jsonb;
  ambiente mixnutri.v_inspecoes_capsulas;
  caso record;
BEGIN
  SET LOCAL ROLE nodered_ingestao;
  resultado_a := integracao.gravar_inspecao(a);
  resultado_b := integracao.gravar_inspecao(b);
  ASSERT resultado_a->>'status' = 'gravada' AND resultado_b->>'status' = 'gravada', 'gravação pelo papel do Admin';
  resultado := integracao.gravar_inspecao(a || '{"inicio":"2026-10-27T12:00Z", "produto":" P-TESTE ","enviado_em":"1970-01-01"}');
  ASSERT resultado->>'status' = 'duplicada' AND resultado->'id' = resultado_a->'id', 'reenvio idempotente';
  ASSERT integracao.gravar_inspecao(b)->>'status' = 'duplicada', 'reenvio da segunda inspeção';
  BEGIN
    PERFORM integracao.gravar_inspecao(a || '{"quantidade_quebrada":5}');
    RAISE EXCEPTION 'A reutilização do identificador com outros dados deveria falhar.';
  EXCEPTION WHEN unique_violation THEN
    ASSERT SQLERRM LIKE 'Este identificador%', 'conflito de envio com mensagem própria';
  END;

  FOR caso IN SELECT * FROM (VALUES
    ('{"total_inspecionado":-1}'::jsonb, 'O total inspecionado'),
    ('{"total_inspecionado":2147483648}'::jsonb, 'O total inspecionado'),
    ('{"quantidade_quebrada":1.7}'::jsonb, 'A quantidade quebrada'),
    ('{"quantidade_quebrada":"1"}'::jsonb, 'A quantidade quebrada'),
    ('{"quantidade_quebrada":201}'::jsonb, 'A quantidade quebrada deve ser menor'),
    ('{"fim":"2026-10-27T08:00:00-04:00"}'::jsonb, 'O fim da produção'),
    ('{"fim":"2026-10-27T07:00:00-04:00"}'::jsonb, 'O fim da produção'),
    ('{"inicio":"2026-02-31T08:00:00-04:00"}'::jsonb, 'Informe o início'),
    ('{"inicio":"2026-10-27T08:00:00"}'::jsonb, 'Informe o início'),
    ('{"fim":"2026-10-27T08:00:00+33:00"}'::jsonb, 'Informe o fim'),
    ('{"origem_dados":"especulacao"}'::jsonb, 'Selecione origem'),
    ('{"ponto_inspecao":"\t  "}'::jsonb, 'Informe o ponto'),
    ('{"envio_id":"invalido"}'::jsonb, 'Identificador de envio inválido')
  ) AS casos(valor, prefixo)
  LOOP
    BEGIN
      PERFORM integracao.gravar_inspecao(a || caso.valor);
      RAISE EXCEPTION 'Deveria rejeitar %.', caso.valor;
    EXCEPTION WHEN invalid_parameter_value THEN
      ASSERT SQLERRM LIKE caso.prefixo || '%', SQLERRM;
    END;
  END LOOP;
  RESET ROLE;

  ASSERT NOT has_table_privilege('nodered_ingestao', 'mixnutri.inspecoes_capsulas', 'INSERT'), 'Admin usa a função';
  ASSERT NOT has_table_privilege('grafana_leitura', 'mixnutri.inspecoes_capsulas', 'INSERT'), 'papel Grafana de leitura';
  ASSERT NOT has_function_privilege('grafana_leitura', 'integracao.gravar_inspecao(jsonb)', 'EXECUTE'), 'Grafana não grava via função';
  SET LOCAL ROLE grafana_leitura;
  ASSERT (SELECT count(*) = 2 AND sum(total_inspecionado) = 500 AND sum(quantidade_quebrada) = 7
                 AND 100.0 * sum(quantidade_quebrada) / nullif(sum(total_inspecionado), 0) = 1.4
          FROM mixnutri.v_inspecoes_capsulas WHERE sala_id = 'sala-teste' AND lote_producao = 'L-TESTE'),
    '4 de 200 e 3 de 300 totalizam 7 de 500, ou 1,4%, depois dos reenvios';
  SELECT * INTO STRICT ambiente FROM mixnutri.v_inspecoes_capsulas WHERE id = (resultado_a->>'id')::bigint;
  ASSERT ambiente.indice_quebra_pct = 2 AND ambiente.inicio = '2026-10-27T12:00:00Z' AND ambiente.enviado_em > ambiente.fim,
    'índice individual, conversão de fuso e horário do envio';
  ASSERT ambiente.temperatura_leituras = 3 AND ambiente.temperatura_min_c = 22 AND ambiente.temperatura_max_c = 27
    AND round(ambiente.temperatura_media_c, 2) = 24.33 AND ambiente.umidade_leituras = 3
    AND ambiente.umidade_min_pct = 50 AND ambiente.umidade_max_pct = 65 AND round(ambiente.umidade_media_pct, 2) = 56.67,
    'contexto, clima válido, relógio da medição com fallback e início inclusivo e fim exclusivo';
  SELECT * INTO STRICT ambiente FROM mixnutri.v_inspecoes_capsulas WHERE id = (resultado_b->>'id')::bigint;
  ASSERT ambiente.indice_quebra_pct = 1 AND ambiente.temperatura_leituras = 2 AND ambiente.umidade_leituras = 2
    AND ambiente.temperatura_media_c = 31 AND ambiente.umidade_media_pct = 71.5, 'segundo intervalo e índice individual';
  RESET ROLE;

  resultado := integracao.gravar_inspecao(sem_dados);
  SELECT * INTO STRICT ambiente FROM mixnutri.v_inspecoes_capsulas WHERE id = (resultado->>'id')::bigint;
  ASSERT ambiente.indice_quebra_pct IS NULL AND ambiente.temperatura_leituras = 0 AND ambiente.umidade_leituras = 0
    AND ambiente.temperatura_media_c IS NULL AND ambiente.umidade_media_pct IS NULL, 'total zero e nenhuma telemetria';
  resultado := integracao.gravar_inspecao(sem_quebras);
  SELECT * INTO STRICT ambiente FROM mixnutri.v_inspecoes_capsulas WHERE id = (resultado->>'id')::bigint;
  ASSERT ambiente.indice_quebra_pct = 0 AND ambiente.lote_capsula = 'LC-INDUSTRIAL'
    AND ambiente.observacoes = 'Amostra de teste' AND ambiente.temperatura_leituras = 0, 'zero quebras e campos opcionais';
  resultado := integracao.gravar_inspecao(nova_amostra);
  ASSERT resultado->>'status' = 'gravada' AND resultado->'id' <> resultado_a->'id', 'segunda inspeção legítima com dados idênticos';
  RAISE NOTICE 'Inspeções: gravadas 2%% e 1%%, total ponderado 1,4%%, reenvios, dados inválidos, contexto ambiental, casos sem dados e permissões conferidos.';
END;
$$;

ROLLBACK;
