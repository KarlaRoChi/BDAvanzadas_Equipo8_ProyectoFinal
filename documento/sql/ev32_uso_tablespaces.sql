-- 09_almacenamiento.sql  (se ejecuta como postgres)
-- Monitoreo de tablespaces, ajuste dinamico de particiones y mantenimiento automatico.
-- PostgreSQL no tiene AUTOEXTEND: los archivos de un tablespace crecen mientras haya
-- espacio en el volumen; el crecimiento se controla con las vistas de uso y con nuevas particiones.

-- 1. Uso de espacio por tablespace (equivalente a DBA_DATA_FILES / DBA_FREE_SPACE)
CREATE VIEW rrhh.v_uso_tablespaces AS
SELECT t.spcname                                                AS tablespace,
       COALESCE(NULLIF(pg_tablespace_location(t.oid), ''), '(directorio de datos)') AS ruta,
       pg_size_pretty(pg_tablespace_size(t.oid))                AS usado,
       (SELECT count(*) FROM pg_class c WHERE c.reltablespace = t.oid AND c.relkind IN ('r', 'i')) AS objetos
FROM pg_tablespace t
ORDER BY pg_tablespace_size(t.oid) DESC;

SELECT * FROM rrhh.v_uso_tablespaces;
