-- 01_instancia_roles.sql  (se ejecuta como postgres sobre la BD rrhh)
-- Tablespaces, roles (RBAC), usuarios del equipo y esquema del sistema.
-- Las lineas "--;;" solo delimitan el bloque que generar_evidencias.py captura como una imagen.

-- 1. Tablespaces: un directorio dedicado por tipo de carga
--    (los directorios los crea y asigna a postgres el servicio init-tablespaces)
CREATE TABLESPACE ts_rrhh_data  LOCATION '/var/lib/postgresql/tablespaces/data';
CREATE TABLESPACE ts_rrhh_idx   LOCATION '/var/lib/postgresql/tablespaces/idx';
CREATE TABLESPACE ts_rrhh_part  LOCATION '/var/lib/postgresql/tablespaces/part';
CREATE TABLESPACE ts_rrhh_audit LOCATION '/var/lib/postgresql/tablespaces/audit';
CREATE TABLESPACE ts_rrhh_hist  LOCATION '/var/lib/postgresql/tablespaces/hist';
\db+
--;;
-- 2. Roles personalizados (RBAC): privilegios agrupados, sin inicio de sesion
CREATE ROLE rol_admin    NOLOGIN;
CREATE ROLE rol_analista NOLOGIN;
CREATE ROLE rol_auditor  NOLOGIN;

-- 3. Usuarios del equipo (ficticios) y asignacion de rol
CREATE USER usr_admin          LOGIN PASSWORD 'AdminSecure2026#';
CREATE USER usr_analista_karla LOGIN PASSWORD 'KarlaAnalyst2026#';
CREATE USER usr_auditor_victor LOGIN PASSWORD 'VictorAudit2026#';
GRANT rol_admin    TO usr_admin;
GRANT rol_analista TO usr_analista_karla;
GRANT rol_auditor  TO usr_auditor_victor;
--;;
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

-- 5. Esquema del sistema, propiedad del rol administrador
CREATE SCHEMA rrhh AUTHORIZATION rol_admin;
\du
