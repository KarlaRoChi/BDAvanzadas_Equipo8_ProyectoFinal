-- mantenimiento_programado.sql  (lo ejecuta el servicio "mantenimiento" de docker-compose)
-- Ejecucion automatica y periodica de rrhh.prc_mantenimiento (REINDEX + ANALYZE),
-- con registro de cada corrida en una bitacora propia.
-- Variable de psql: prefijo (indices a reconstruir; 'p_' = todas las particiones).

-- 1. Bitacora de corridas, en el tablespace de auditoria (se crea la primera vez)
CREATE TABLE IF NOT EXISTS rrhh.log_mantenimiento (
    id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY USING INDEX TABLESPACE ts_rrhh_audit,
    inicio   TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    fin      TIMESTAMPTZ,
    prefijo  TEXT        NOT NULL,
    estado   TEXT        NOT NULL
) TABLESPACE ts_rrhh_audit;
GRANT SELECT ON rrhh.log_mantenimiento TO rol_admin, rol_auditor;

-- 2. Corrida: se registra el inicio, se ejecuta el procedimiento y se registra el fin
INSERT INTO rrhh.log_mantenimiento (prefijo, estado)
VALUES (:'prefijo', 'EN CURSO')
RETURNING id AS log_id \gset

CALL rrhh.prc_mantenimiento(:'prefijo');

UPDATE rrhh.log_mantenimiento
SET fin = clock_timestamp(), estado = 'OK'
WHERE id = :log_id;

-- 3. Ultimas corridas
SELECT id, inicio, fin - inicio AS duracion, prefijo, estado
FROM rrhh.log_mantenimiento
ORDER BY id DESC
LIMIT 5;
