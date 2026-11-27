-- Aplicável também a um banco existente com o schema e os papéis do item 3.
BEGIN;

CREATE TABLE IF NOT EXISTS mixnutri.inspecoes_capsulas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  envio_id uuid NOT NULL UNIQUE,
  sala_id text NOT NULL CHECK (btrim(sala_id) <> ''),
  maquina text NOT NULL CHECK (btrim(maquina) <> ''),
  produto text NOT NULL CHECK (btrim(produto) <> ''),
  lote_producao text NOT NULL CHECK (btrim(lote_producao) <> ''),
  inicio timestamptz NOT NULL,
  fim timestamptz NOT NULL,
  ponto_inspecao text NOT NULL CHECK (btrim(ponto_inspecao) <> ''),
  total_inspecionado integer NOT NULL CHECK (total_inspecionado >= 0),
  quantidade_quebrada integer NOT NULL CHECK (quantidade_quebrada BETWEEN 0 AND total_inspecionado),
  origem_dados text NOT NULL CHECK (origem_dados IN ('simulacao', 'real')),
  lote_capsula text,
  observacoes text,
  enviado_em timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (isfinite(inicio) AND isfinite(fim) AND fim > inicio)
);

CREATE INDEX IF NOT EXISTS telemetria_por_contexto_instante_valido
  ON mixnutri.telemetria_sala01
     (sala_id, produto, lote_producao, origem_dados, (coalesce(data_medicao, data_recebimento)))
  WHERE clima_valido;

CREATE OR REPLACE FUNCTION integracao.gravar_inspecao(p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE
  v_campo record;
  v_texto text;
  v_numero numeric;
  v_dados mixnutri.inspecoes_capsulas;
  v_gravada mixnutri.inspecoes_capsulas;
  v_iso constant text := '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:\d{2})$';
BEGIN
  IF jsonb_typeof(p) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Envie os dados da inspeção em um objeto JSON.';
  END IF;

  BEGIN
    v_dados.envio_id := (p->>'envio_id')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Identificador de envio inválido.';
  END;
  IF v_dados.envio_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Identificador de envio obrigatório.';
  END IF;

  FOR v_campo IN
    SELECT * FROM (VALUES
      ('sala_id', 'a sala', true), ('maquina', 'a máquina', true), ('produto', 'o produto', true),
      ('lote_producao', 'o lote de produção', true), ('ponto_inspecao', 'o ponto de inspeção', true),
      ('lote_capsula', 'o lote das cápsulas', false), ('observacoes', 'as observações', false)
    ) AS campos(chave, rotulo, obrigatorio)
  LOOP
    IF coalesce(jsonb_typeof(p->v_campo.chave), 'null') NOT IN ('string', 'null') THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = format('Preencha %s com texto.', v_campo.rotulo);
    END IF;
    v_texto := nullif(regexp_replace(p->>v_campo.chave, '^[[:space:]]+|[[:space:]]+$', '', 'g'), '');
    IF v_campo.obrigatorio AND v_texto IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = format('Informe %s.', v_campo.rotulo);
    END IF;
    p := jsonb_set(p, ARRAY[v_campo.chave], coalesce(to_jsonb(v_texto), 'null'::jsonb));
  END LOOP;

  v_dados.origem_dados := p->>'origem_dados';
  IF v_dados.origem_dados IS NULL OR v_dados.origem_dados NOT IN ('simulacao', 'real') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Selecione origem real ou simulada.';
  END IF;

  FOR v_campo IN
    SELECT * FROM (VALUES
      ('inicio', 'o início'), ('fim', 'o fim')
    ) AS campos(chave, rotulo)
  LOOP
    BEGIN
      v_texto := p->>v_campo.chave;
      IF v_texto IS NULL OR v_texto !~ v_iso THEN
        RAISE invalid_datetime_format;
      END IF;
      PERFORM v_texto::timestamptz;
    EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_time_zone_displacement_value THEN
      RAISE EXCEPTION USING ERRCODE = '22023',
        MESSAGE = format('Informe %s da produção com data, hora e fuso horário válidos.', v_campo.rotulo);
    END;
  END LOOP;

  FOR v_campo IN
    SELECT * FROM (VALUES
      ('total_inspecionado', 'O total inspecionado'), ('quantidade_quebrada', 'A quantidade quebrada')
    ) AS campos(chave, rotulo)
  LOOP
    v_texto := format('%s deve ser um inteiro entre 0 e 2147483647.', v_campo.rotulo);
    IF jsonb_typeof(p->v_campo.chave) IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = v_texto;
    END IF;
    v_numero := (p->>v_campo.chave)::numeric;
    IF v_numero < 0 OR v_numero > 2147483647 OR v_numero <> trunc(v_numero) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = v_texto;
    END IF;
    p := jsonb_set(p, ARRAY[v_campo.chave], to_jsonb(v_numero::integer));
  END LOOP;

  SELECT * INTO v_dados FROM jsonb_populate_record(NULL::mixnutri.inspecoes_capsulas, p - 'id' - 'enviado_em');
  IF v_dados.fim <= v_dados.inicio THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'O fim da produção deve ser posterior ao início.';
  END IF;
  IF v_dados.quantidade_quebrada > v_dados.total_inspecionado THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A quantidade quebrada deve ser menor ou igual ao total inspecionado.';
  END IF;

  INSERT INTO mixnutri.inspecoes_capsulas (
    envio_id, sala_id, maquina, produto, lote_producao, inicio, fim, ponto_inspecao,
    total_inspecionado, quantidade_quebrada, origem_dados, lote_capsula, observacoes
  ) VALUES (
    v_dados.envio_id, v_dados.sala_id, v_dados.maquina, v_dados.produto, v_dados.lote_producao,
    v_dados.inicio, v_dados.fim, v_dados.ponto_inspecao, v_dados.total_inspecionado,
    v_dados.quantidade_quebrada, v_dados.origem_dados, v_dados.lote_capsula, v_dados.observacoes
  )
  ON CONFLICT (envio_id) DO NOTHING
  RETURNING * INTO v_gravada;

  IF FOUND THEN
    RETURN jsonb_build_object('id', v_gravada.id, 'status', 'gravada');
  END IF;

  SELECT * INTO STRICT v_gravada FROM mixnutri.inspecoes_capsulas WHERE envio_id = v_dados.envio_id;
  v_dados.id := v_gravada.id;
  v_dados.enviado_em := v_gravada.enviado_em;
  IF v_dados IS DISTINCT FROM v_gravada THEN
    RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'Este identificador já foi usado em uma inspeção com outros dados.';
  END IF;
  RETURN jsonb_build_object('id', v_gravada.id, 'status', 'duplicada');
END;
$$;

CREATE OR REPLACE VIEW mixnutri.v_inspecoes_capsulas AS
SELECT i.*, 100.0 * i.quantidade_quebrada / nullif(i.total_inspecionado, 0) AS indice_quebra_pct,
       ambiente.temperatura_media_c, ambiente.temperatura_min_c, ambiente.temperatura_max_c,
       ambiente.temperatura_leituras, ambiente.umidade_media_pct, ambiente.umidade_min_pct,
       ambiente.umidade_max_pct, ambiente.umidade_leituras
FROM mixnutri.inspecoes_capsulas i
CROSS JOIN LATERAL (
  SELECT avg(t.temperatura_c) AS temperatura_media_c,
         min(t.temperatura_c) AS temperatura_min_c,
         max(t.temperatura_c) AS temperatura_max_c,
         count(t.temperatura_c) AS temperatura_leituras,
         avg(t.umidade_pct) AS umidade_media_pct,
         min(t.umidade_pct) AS umidade_min_pct,
         max(t.umidade_pct) AS umidade_max_pct,
         count(t.umidade_pct) AS umidade_leituras
  FROM mixnutri.telemetria_sala01 t
  WHERE t.sala_id = i.sala_id AND t.produto = i.produto
    AND t.lote_producao = i.lote_producao AND t.origem_dados = i.origem_dados
    AND t.clima_valido
    AND coalesce(t.data_medicao, t.data_recebimento) >= i.inicio
    AND coalesce(t.data_medicao, t.data_recebimento) < i.fim
) ambiente;

REVOKE ALL ON FUNCTION integracao.gravar_inspecao(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION integracao.gravar_inspecao(jsonb) TO nodered_ingestao;
GRANT SELECT ON mixnutri.inspecoes_capsulas, mixnutri.v_inspecoes_capsulas TO grafana_leitura;

COMMIT;
