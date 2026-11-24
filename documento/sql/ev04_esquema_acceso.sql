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
