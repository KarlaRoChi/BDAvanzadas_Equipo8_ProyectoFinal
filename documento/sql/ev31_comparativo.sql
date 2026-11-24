-- 4. Comparativo del costo del optimizador y del tiempo real por etapa
SELECT consulta,
       MAX(costo)     FILTER (WHERE etapa = '1_sin_indices')     AS costo_antes,
       MAX(costo)     FILTER (WHERE etapa = '2_con_indices')     AS costo_con_idx,
       MAX(costo)     FILTER (WHERE etapa = '3_indice_recreado') AS costo_final,
       MAX(tiempo_ms) FILTER (WHERE etapa = '1_sin_indices')     AS ms_antes,
       MAX(tiempo_ms) FILTER (WHERE etapa = '3_indice_recreado') AS ms_despues
FROM rrhh.tuning_resultados
GROUP BY consulta ORDER BY consulta;
