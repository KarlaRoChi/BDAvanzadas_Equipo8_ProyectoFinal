-- 09_almacenamiento.sql  (se ejecuta como postgres)
-- Monitoreo de tablespaces, ajuste dinamico de particiones y mantenimiento automatico.
-- PostgreSQL no tiene AUTOEXTEND: los archivos de un tablespace crecen mientras haya
-- espacio en el volumen; el crecimiento se controla con las vistas de uso y con nuevas particiones.

-- 1. Uso de espacio por tablespace frente a su tamano asignado (rrhh.capacidad_tablespaces,
--    definido en 01_instancia_roles.sql); equivalente a DBA_DATA_FILES / DBA_FREE_SPACE
--    con alerta por umbral
CREATE VIEW rrhh.v_uso_tablespaces AS
SELECT t.spcname                                                AS tablespace,
       COALESCE(NULLIF(pg_tablespace_location(t.oid), ''), '(directorio de datos)') AS ruta,
       pg_size_pretty(pg_tablespace_size(t.oid))                AS usado,
       c.asignado_mb || ' MB'                                   AS asignado,
       ROUND(100.0 * pg_tablespace_size(t.oid) / (c.asignado_mb * 1024.0 * 1024), 1) AS pct_uso,
       CASE WHEN c.asignado_mb IS NULL THEN '-'
            WHEN pg_tablespace_size(t.oid) >= c.asignado_mb * 1024.0 * 1024 * c.umbral_pct / 100
                 THEN 'ALERTA' ELSE 'OK' END                    AS estado,
       (SELECT count(*) FROM pg_class r WHERE r.reltablespace = t.oid AND r.relkind IN ('r', 'i')) AS objetos
FROM pg_tablespace t
LEFT JOIN rrhh.capacidad_tablespaces c ON c.tablespace = t.spcname
ORDER BY pg_tablespace_size(t.oid) DESC;

SELECT * FROM rrhh.v_uso_tablespaces;
