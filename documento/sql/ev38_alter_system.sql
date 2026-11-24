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
