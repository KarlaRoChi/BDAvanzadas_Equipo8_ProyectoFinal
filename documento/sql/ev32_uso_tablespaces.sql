-- 09_almacenamiento.sql  (se ejecuta como postgres)
-- Monitoreo de tablespaces, ajuste dinamico de particiones y mantenimiento automatico.
-- PostgreSQL no tiene AUTOEXTEND: los archivos de un tablespace crecen mientras haya
-- espacio en el volumen; el crecimiento se controla con las vistas de uso y con nuevas particiones.

-- 1. Tamano asignado a cada tablespace (equivalente a DATAFILE ... SIZE / MAXSIZE de Oracle).
--    Dimensionado para 300,000 empleados (5 veces la carga actual); ver el calculo en el reporte.
CREATE TABLE rrhh.capacidad_tablespaces (
    tablespace     NAME     PRIMARY KEY,
    asignado_mb    INTEGER  NOT NULL CHECK (asignado_mb > 0),
    umbral_pct     SMALLINT NOT NULL DEFAULT 80 CHECK (umbral_pct BETWEEN 1 AND 100),
    criterio       TEXT     NOT NULL
) TABLESPACE ts_rrhh_data;

INSERT INTO rrhh.capacidad_tablespaces (tablespace, asignado_mb, criterio) VALUES
    ('ts_rrhh_data',   32, 'Catalogos, historial, niveles MAC y afinacion (hoy ~100 kB)'),
    ('ts_rrhh_part',  128, '300,000 x ~120 B/fila = ~35 MB; holgura x3.5'),
    ('ts_rrhh_idx',   128, '300,000 x ~175 B/fila (PK + indices) = ~51 MB; holgura x2.5'),
    ('ts_rrhh_audit', 256, '1,000,000 eventos x ~120 B = ~115 MB; holgura x2'),
    ('ts_rrhh_hist',   64, 'Hoy ~3 MB (filas antes de 2021); holgura para archivar ~20 anios');

-- 2. Uso de espacio por tablespace frente a su tamano asignado
--    (equivalente a DBA_DATA_FILES / DBA_FREE_SPACE con alerta por umbral)
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
