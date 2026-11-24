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
