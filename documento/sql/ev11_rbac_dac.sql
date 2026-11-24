-- 04_seguridad.sql  (se ejecuta como postgres)
-- Modelos RBAC + DAC + MAC sobre el esquema rrhh.

-- 1. RBAC: privilegios minimos agrupados en roles
--    Administrador: control total del esquema (menos la bitacora, que es de solo lectura)
GRANT USAGE, CREATE ON SCHEMA rrhh TO rol_admin;
GRANT ALL ON ALL TABLES IN SCHEMA rrhh TO rol_admin;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON rrhh.audit_log_empleados FROM rol_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA rrhh TO rol_admin;
--    Analista: solo lectura sobre la vista de negocio y el catalogo de departamentos
GRANT USAGE ON SCHEMA rrhh TO rol_analista;
GRANT SELECT ON rrhh.v_resumen_empleados, rrhh.departamentos TO rol_analista;
--    Auditor: lectura exclusiva de la bitacora y de la vista de negocio
GRANT USAGE ON SCHEMA rrhh TO rol_auditor;
GRANT SELECT ON rrhh.audit_log_empleados, rrhh.v_resumen_empleados TO rol_auditor;
