-- 4. Acceso a la BD solo para los roles del proyecto; tablespaces solo para el admin
REVOKE ALL ON DATABASE rrhh FROM PUBLIC;
GRANT CONNECT ON DATABASE rrhh TO rol_admin, rol_analista, rol_auditor;
GRANT CREATE ON TABLESPACE ts_rrhh_data, ts_rrhh_idx, ts_rrhh_part,
                           ts_rrhh_audit, ts_rrhh_hist TO rol_admin;
ALTER ROLE usr_admin          SET default_tablespace = 'ts_rrhh_data';
ALTER ROLE usr_analista_karla SET default_tablespace = 'ts_rrhh_data';
ALTER ROLE usr_auditor_victor SET default_tablespace = 'ts_rrhh_data';
ALTER ROLE usr_admin          SET search_path = rrhh, public;
ALTER ROLE usr_analista_karla SET search_path = rrhh, public;
ALTER ROLE usr_auditor_victor SET search_path = rrhh, public;

-- 5. Esquema del sistema, propiedad de rol_propietario; el administrador puede
--    crear objetos en el (los construye en 02_esquema.sql) pero no es su dueno
CREATE SCHEMA rrhh AUTHORIZATION rol_propietario;
GRANT USAGE, CREATE ON SCHEMA rrhh TO rol_admin;
\du

-- 6. Tamano asignado a cada tablespace (equivalente a DATAFILE ... SIZE / MAXSIZE de Oracle).
--    CREATE TABLESPACE no admite tamano en PostgreSQL: se define aqui, dimensionado para
--    300,000 empleados (5 veces la carga del proyecto), y v_uso_tablespaces
--    (09_almacenamiento.sql) compara el uso real contra el y alerta al llegar al umbral.
CREATE TABLE rrhh.capacidad_tablespaces (
    tablespace     NAME     PRIMARY KEY,
    asignado_mb    INTEGER  NOT NULL CHECK (asignado_mb > 0),
    umbral_pct     SMALLINT NOT NULL DEFAULT 80 CHECK (umbral_pct BETWEEN 1 AND 100),
    criterio       TEXT     NOT NULL
) TABLESPACE ts_rrhh_data;

INSERT INTO rrhh.capacidad_tablespaces (tablespace, asignado_mb, criterio) VALUES
    ('ts_rrhh_data',   32, 'Catalogos, historial, niveles MAC y afinacion: menos de 1 MB'),
    ('ts_rrhh_part',  128, '300,000 empleados x 120 B por fila = 35 MB aprox.; holgura x3.5'),
    ('ts_rrhh_idx',   128, '300,000 x 115 B por fila (PK + 3 indices) = 33 MB aprox.; holgura x4'),
    ('ts_rrhh_audit', 256, '1,000,000 eventos x 120 B = 115 MB aprox.; holgura x2'),
    ('ts_rrhh_hist',   64, 'Particiones anteriores a 2021: 3 MB hoy, crece al archivar');

SELECT tablespace, asignado_mb || ' MB' AS asignado, umbral_pct || ' %' AS alerta, criterio
FROM rrhh.capacidad_tablespaces ORDER BY asignado_mb DESC, tablespace;
