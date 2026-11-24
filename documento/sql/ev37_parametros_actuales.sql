-- 10_parametros.sql  (se ejecuta como postgres)
-- Parametros criticos de configuracion (equivalentes a DB_BLOCK_SIZE, SGA_TARGET, PGA_AGGREGATE_TARGET).

-- 1. Valores actuales
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN ('block_size', 'shared_buffers', 'work_mem', 'maintenance_work_mem',
               'effective_cache_size', 'random_page_cost', 'max_connections')
ORDER BY name;
