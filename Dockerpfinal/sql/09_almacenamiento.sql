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
--;;
-- 3. Particiones: rango, filas y tamano de cada una
CREATE VIEW rrhh.v_particiones AS
SELECT c.relname                              AS particion,
       pg_get_expr(c.relpartbound, c.oid)     AS rango,
       s.n_live_tup                           AS filas,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano_total
FROM pg_inherits i
JOIN pg_class c        ON c.oid = i.inhrelid
JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE i.inhparent = 'rrhh.empleados'::regclass
ORDER BY c.relname;

SELECT * FROM rrhh.v_particiones;
--;;
-- 4. Ajuste dinamico: nueva particion 2027-2028 y reubicacion de los datos historicos
--    en su propio tablespace (ts_rrhh_hist), sin perder informacion
CREATE TABLE rrhh.p_2027_2028 (LIKE rrhh.empleados INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    TABLESPACE ts_rrhh_part;
ALTER TABLE rrhh.p_2027_2028 OWNER TO rol_propietario;   -- mismo dueno que el resto de las particiones
ALTER TABLE rrhh.empleados DETACH PARTITION rrhh.p_futuro;
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_2027_2028
    FOR VALUES FROM ('2027-01-01') TO ('2029-01-01');
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_futuro
    FOR VALUES FROM ('2029-01-01') TO (MAXVALUE);
ALTER TABLE rrhh.p_historico SET TABLESPACE ts_rrhh_hist;
ALTER INDEX rrhh.p_historico_pkey SET TABLESPACE ts_rrhh_hist;

SELECT * FROM rrhh.v_particiones;
SELECT * FROM rrhh.v_uso_tablespaces;
--;;
-- 5. Mantenimiento automatico: reconstruye los indices secundarios de las particiones cuyo
--    nombre inicia con p_prefijo y actualiza las estadisticas de todas las particiones
CREATE PROCEDURE rrhh.prc_mantenimiento(p_prefijo TEXT)
LANGUAGE plpgsql AS
$$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT c.relname FROM pg_class c
             WHERE c.relnamespace = 'rrhh'::regnamespace AND c.relkind = 'i'
               AND c.relname !~ '_pkey$' AND c.relname !~ '_key$'
               AND c.relname LIKE p_prefijo || '%'
    LOOP
        EXECUTE format('REINDEX INDEX rrhh.%I', r.relname);
        RAISE NOTICE 'Indice reconstruido: %', r.relname;
    END LOOP;
    FOR r IN SELECT c.relname FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
             WHERE i.inhparent = 'rrhh.empleados'::regclass
    LOOP
        EXECUTE format('ANALYZE rrhh.%I', r.relname);
        RAISE NOTICE 'Particion analizada: %', r.relname;
    END LOOP;
END;
$$;

CALL rrhh.prc_mantenimiento('p_2025');
--;;
-- 6. Truncado controlado: se cargan filas de prueba en la particion nueva y se vacia
--    solo esa particion (sin tocar el resto de la tabla ni disparar la bitacora por fila)
SET session_replication_role = replica;
INSERT INTO rrhh.empleados (emp_id, nombre, apellido, email, salario, fecha_ingreso, depto_id, rol_id, clasificacion_nivel)
SELECT 70000 + i, 'Temporal_' || i, 'Prueba', 'tmp.' || i || '@empresa-rrhh.com', 15000,
       DATE '2027-01-01' + (i % 700), 40, 4, 1
FROM generate_series(1, 1000) AS i;
SET session_replication_role = origin;
SELECT count(*) AS filas_antes FROM rrhh.p_2027_2028;
-- Una particion referenciada por una FK no se puede truncar directamente: se desprende,
-- se vacia y se vuelve a adjuntar con el mismo rango
ALTER TABLE rrhh.empleados DETACH PARTITION rrhh.p_2027_2028;
TRUNCATE rrhh.p_2027_2028;
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_2027_2028
    FOR VALUES FROM ('2027-01-01') TO ('2029-01-01');
SELECT count(*) AS filas_despues FROM rrhh.p_2027_2028;
SELECT count(*) AS total_empleados FROM rrhh.empleados;
