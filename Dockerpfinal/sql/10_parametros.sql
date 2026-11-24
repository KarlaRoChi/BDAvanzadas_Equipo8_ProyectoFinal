-- 10_parametros.sql  (se ejecuta como postgres)
-- Parametros criticos de configuracion (equivalentes a DB_BLOCK_SIZE, SGA_TARGET, PGA_AGGREGATE_TARGET).

-- 1. Valores actuales
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN ('block_size', 'shared_buffers', 'work_mem', 'maintenance_work_mem',
               'effective_cache_size', 'random_page_cost', 'max_connections')
ORDER BY name;
--;;
-- 2. Ajustes segun las recomendaciones del advisor (se aplican sin reiniciar).
--    block_size es fijo al compilar el motor (como DB_BLOCK_SIZE): no se cambia en caliente.
ALTER SYSTEM SET work_mem = '32MB';               -- ordenamientos y HASH JOIN sin desbordar a disco
ALTER SYSTEM SET maintenance_work_mem = '256MB';  -- REINDEX / CREATE INDEX / VACUUM mas rapidos
ALTER SYSTEM SET random_page_cost = 1.1;          -- almacenamiento SSD: el acceso por indice es mas barato
SELECT pg_reload_conf();
SELECT pg_sleep(1);
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN ('work_mem', 'maintenance_work_mem', 'random_page_cost')
ORDER BY name;
--;;
-- 3. Reevaluacion de las 3 consultas con los parametros ajustados
SELECT rrhh.registrar_etapa('4_parametros');
SELECT consulta,
       MAX(costo)     FILTER (WHERE etapa = '3_indice_recreado') AS costo_idx,
       MAX(costo)     FILTER (WHERE etapa = '4_parametros')      AS costo_params,
       MAX(tiempo_ms) FILTER (WHERE etapa = '3_indice_recreado') AS ms_idx,
       MAX(tiempo_ms) FILTER (WHERE etapa = '4_parametros')      AS ms_params
FROM rrhh.tuning_resultados
GROUP BY consulta ORDER BY consulta;
--;;
-- 4. Aplicacion de la recomendacion INDICE SIN USO: idx_emp_email no lo usa ninguna de las
--    consultas de la carga de trabajo y solo agrega costo de escritura y 3 MB de espacio
DROP INDEX rrhh.idx_emp_email;
--;;
-- 5. Verificacion: se reinician las estadisticas, se repite la carga de trabajo y se revisa
--    si el advisor sigue reportando lecturas secuenciales
SELECT pg_stat_reset();
SELECT rrhh.ejecutar_carga(20);
SELECT pg_sleep(2);
SELECT s.relname AS particion, s.seq_scan, s.seq_tup_read, s.idx_scan
FROM pg_stat_user_tables s
WHERE s.schemaname = 'rrhh' AND s.relname LIKE 'p\_%'
ORDER BY s.relname;
SELECT * FROM rrhh.v_advisor_hallazgos ORDER BY filas_leidas DESC, objeto;
