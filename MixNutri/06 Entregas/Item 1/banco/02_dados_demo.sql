-- SOMENTE dados sinteticos. Aplicar depois de 01_schema.sql em banco de estudo.
-- Os valores imitam o formato publicado pelo firmware do item 2 (ruido em dBFS),
-- mas foram gerados por este script, nao coletados do ESP32.
BEGIN;
INSERT INTO mixnutri.configuracao_alertas
 (sala_id,versao,ativo,ur_liga,ur_desliga,limiar_operando,limiar_parado,unidade_ruido,
  confirmar_operando_ms,confirmar_parado_ms,alerta_persistencia_s,canal_dashboard,canal_email,
  origem_parametros,observacao)
VALUES ('sala01',1,true,55,50,-25,-35,'dBFS',3000,5000,10,true,true,'proposta_didatica',
  'Exemplo didatico: liga 55% UR, desliga 50% UR; som em dBFS relativo ao ADC, nao dB SPL.');
INSERT INTO mixnutri.telemetria_sala01
 (device_id,boot_id,seq,uptime_ms,data_medicao,data_recebimento,origem_dados,produto,lote_producao,lote_capsula,lote_po,
  temperatura_c,umidade_pct,clima_valido,nivel_ruido,unidade_ruido,fonte_estado,estado_maquina,modo,desumidificador_comandado,configuracao_id)
SELECT 'esp32-demo','boot-demo',n,n*5000,
 timestamptz '2026-10-27 12:00:00+00'+n*interval '5 seconds',
 timestamptz '2026-10-27 12:00:00+00'+n*interval '5 seconds',
 'simulacao','PRODUTO_DEMO','LOTE_DEMO','CAPSULA_DEMO','PO_DEMO',
 25,CASE WHEN n<3 THEN 45 WHEN n<7 THEN 60 ELSE 48 END,true,
 CASE WHEN n<5 THEN -10.8 ELSE -48.5 END,'dBFS','sintetico',
 CASE WHEN n<5 THEN 'OPERANDO' ELSE 'PARADO' END,'AUTO',(n>=3 AND n<7),id
FROM mixnutri.configuracao_alertas CROSS JOIN generate_series(0,9) n
WHERE sala_id='sala01' AND versao=1;
INSERT INTO mixnutri.paradas_maquina_sala01
 (device_id,evento_id,origem_dados,produto,lote_producao,lote_capsula,fonte_estado,inicio,fim,referencia_tempo,observacao)
VALUES ('esp32-demo','parada-demo-1','simulacao','PRODUTO_DEMO','LOTE_DEMO','CAPSULA_DEMO','sintetico',
 '2026-10-27 12:00:25+00',NULL,'dispositivo_sincronizado','Cenario sintetico; nenhuma causa de parada foi comprovada.');
-- Alertas como o backend geraria: UR acima do limite e coincidencia temporal com a parada.
INSERT INTO mixnutri.alertas_emitidos
 (configuracao_id,tipo,severidade,origem_dados,inicio,fim,valor_observado,limite,unidade,mensagem,canais,
  status_envio,enviado_em,telemetria_id)
SELECT c.id,'UR_ALTA','aviso','simulacao',t.data_medicao,t.data_medicao+interval '20 seconds',60,55,'%UR',
 'UR 60% acima de 55% por mais de 10 s (dados sinteticos)',ARRAY['dashboard','email'],
 'enviado',t.data_medicao+interval '11 seconds',t.id
FROM mixnutri.configuracao_alertas c JOIN mixnutri.telemetria_sala01 t ON t.seq=3
WHERE c.sala_id='sala01' AND c.versao=1;
INSERT INTO mixnutri.alertas_emitidos
 (configuracao_id,tipo,severidade,origem_dados,inicio,valor_observado,limite,unidade,mensagem,canais,parada_id)
SELECT c.id,'UR_ALTA_E_PARADA','critico','simulacao',p.inicio,60,55,'%UR',
 'Parada inferida com UR acima do limite nos 30 s anteriores. Correlacao temporal, nao causa.',
 ARRAY['dashboard','email'],p.id
FROM mixnutri.configuracao_alertas c CROSS JOIN mixnutri.paradas_maquina_sala01 p
WHERE c.sala_id='sala01' AND c.versao=1 AND p.evento_id='parada-demo-1';
COMMIT;
