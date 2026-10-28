-- Valores para demonstracao; use parametros no backend, nao concatenacao de entrada externa.
SELECT data_medicao, data_recebimento, produto, lote_producao, lote_capsula,
 temperatura_c, umidade_pct, nivel_ruido, unidade_ruido, estado_maquina,
 desumidificador_comandado, origem_dados
FROM mixnutri.telemetria_sala01 WHERE sala_id='sala01'
ORDER BY data_recebimento;

-- Correspondencia temporal com 30 s anteriores, sem afirmar causa.
-- Nao mistura dados reais e simulados; compara produto e lote; usa somente relogio sincronizado.
SELECT p.evento_id,p.inicio,p.produto,p.lote_producao,p.origem_dados,
 max(t.umidade_pct) AS maior_ur_nos_30s_anteriores,count(t.id) AS amostras_validas
FROM mixnutri.paradas_maquina_sala01 p
LEFT JOIN mixnutri.telemetria_sala01 t
 ON t.sala_id=p.sala_id AND t.device_id=p.device_id
 AND t.origem_dados=p.origem_dados AND t.produto=p.produto AND t.lote_producao=p.lote_producao
 AND t.clima_valido AND t.data_medicao BETWEEN p.inicio-interval '30 seconds' AND p.inicio
 AND p.referencia_tempo='dispositivo_sincronizado'
GROUP BY p.id ORDER BY p.inicio;

SELECT sala_id,versao,ur_liga,ur_desliga,histerese_pp,limiar_operando,limiar_parado,unidade_ruido,
 alerta_persistencia_s,canal_dashboard,canal_email,canal_telegram,origem_parametros
FROM mixnutri.configuracao_alertas WHERE ativo;

-- Alertas com a parada associada, quando houver (linha do tempo do dashboard).
SELECT a.tipo,a.severidade,a.inicio,a.fim,a.valor_observado,a.limite,a.unidade,a.canais,a.status_envio,
 p.evento_id AS parada
FROM mixnutri.alertas_emitidos a
LEFT JOIN mixnutri.paradas_maquina_sala01 p ON p.id=a.parada_id
WHERE a.sala_id='sala01' ORDER BY a.inicio;
