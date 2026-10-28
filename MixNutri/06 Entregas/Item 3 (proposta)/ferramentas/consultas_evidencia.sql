-- Consultas de evidencia apos reproduzir o log do item 2 (e o cenario de BOOT) na proposta do item 3.
-- Executar com o papel somente leitura grafana_leitura (ver README). Nao altera dados.
\pset footer off
\echo '== 1. Mensagens recebidas pelo Node-RED, por topico (registro bruto) =='
SELECT split_part(topico, '/', 3) AS canal, count(*) AS mensagens,
       count(*) FILTER (WHERE resultado LIKE 'erro%') AS com_erro
FROM integracao.mensagens_mqtt GROUP BY 1 ORDER BY 1;

\echo '== 2. Resultado da gravacao de cada mensagem =='
SELECT regexp_replace(resultado, 'boot [a-z0-9]+: ', 'boot: ') AS resultado, count(*) AS mensagens
FROM integracao.mensagens_mqtt GROUP BY 1 ORDER BY 2 DESC, 1;

\echo '== 3. Falhas (restricao violada, JSON invalido) =='
SELECT id, topico, resultado, left(payload_texto, 80) AS inicio_do_texto
FROM integracao.mensagens_mqtt WHERE resultado LIKE 'erro%' ORDER BY id;

\echo '== 4. Telemetria por boot =='
SELECT device_id, boot_id, count(*) AS leituras, min(seq) AS seq_min, max(seq) AS seq_max,
       count(*) FILTER (WHERE data_medicao IS NULL) AS sem_relogio,
       count(*) FILTER (WHERE NOT clima_valido) AS clima_invalido,
       min(data_medicao) AS primeira_medicao, max(data_medicao) AS ultima_medicao
FROM mixnutri.telemetria_sala01 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '== 5. Telemetria por produto/lote, fonte, unidade e versao de configuracao =='
SELECT t.produto, t.lote_producao, t.fonte_estado, t.unidade_ruido, c.versao AS config_versao,
       count(*) AS leituras, min(t.nivel_ruido) AS ruido_min_dbfs, max(t.nivel_ruido) AS ruido_max_dbfs,
       min(t.umidade_pct) AS ur_min, max(t.umidade_pct) AS ur_max,
       count(*) FILTER (WHERE t.desumidificador_comandado) AS rele_ligado
FROM mixnutri.telemetria_sala01 t LEFT JOIN mixnutri.configuracao_alertas c ON c.id = t.configuracao_id
GROUP BY 1, 2, 3, 4, 5 ORDER BY 5 NULLS FIRST, 1, 3;

\echo '== 6. Configuracoes (v1 semeada; demais vindas de CONFIG_APLICADA) =='
SELECT versao, ativo, ur_liga, ur_desliga, histerese_pp, limiar_operando, limiar_parado, unidade_ruido,
       confirmar_operando_ms, confirmar_parado_ms, alerta_persistencia_s, origem_parametros
FROM mixnutri.configuracao_alertas ORDER BY versao;

\echo '== 7. Paradas =='
SELECT device_id, evento_id, fonte_estado, inicio, fim, round(duracao_s, 3) AS duracao_s, motivo_fim,
       referencia_tempo, produto, lote_producao, observacao
FROM mixnutri.paradas_maquina_sala01 ORDER BY inicio;

\echo '== 8. Alertas emitidos =='
SELECT tipo, severidade, inicio, fim, valor_observado, limite, unidade, canais, status_envio,
       parada_id IS NOT NULL AS tem_parada, telemetria_id IS NOT NULL AS tem_telemetria, mensagem
FROM mixnutri.alertas_emitidos ORDER BY inicio, tipo;

\echo '== 9. Itens abertos (paradas e alertas sem fim) =='
SELECT 'parada' AS item, count(*) FROM mixnutri.paradas_maquina_sala01 WHERE fim IS NULL
UNION ALL
SELECT 'alerta ' || tipo, count(*) FROM mixnutri.alertas_emitidos WHERE fim IS NULL GROUP BY tipo;
