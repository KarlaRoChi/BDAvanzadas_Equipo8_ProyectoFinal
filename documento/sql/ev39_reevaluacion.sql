-- 3. Reevaluacion de las 3 consultas con los parametros ajustados
SELECT rrhh.registrar_etapa('4_parametros');
SELECT consulta,
       MAX(costo)     FILTER (WHERE etapa = '3_indice_recreado') AS costo_idx,
       MAX(costo)     FILTER (WHERE etapa = '4_parametros')      AS costo_params,
       MAX(tiempo_ms) FILTER (WHERE etapa = '3_indice_recreado') AS ms_idx,
       MAX(tiempo_ms) FILTER (WHERE etapa = '4_parametros')      AS ms_params
FROM rrhh.tuning_resultados
GROUP BY consulta ORDER BY consulta;
