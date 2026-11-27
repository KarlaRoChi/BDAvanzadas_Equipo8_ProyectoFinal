-- 04_seguridad.sql  (se ejecuta como postgres)
-- Modelos RBAC + DAC + MAC sobre el esquema rrhh.

-- 1. Separacion de funciones: usr_admin construyo el esquema en 02_esquema.sql; al
--    cerrar el diseno, la propiedad pasa a rol_propietario. Un dueno puede desactivar
--    triggers, borrar tablas o quitar el RLS, asi que el administrador no debe serlo.
REASSIGN OWNED BY usr_admin TO rol_propietario;

-- 2. RBAC: privilegios minimos agrupados en roles
--    Administrador: DML sobre los datos; solo lectura en la bitacora y en los niveles MAC.
--    No recibe TRUNCATE (vaciaria tablas sin disparar la auditoria por fila) ni TRIGGER.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA rrhh TO rol_admin;
REVOKE INSERT, UPDATE, DELETE ON rrhh.audit_log_empleados, rrhh.autorizaciones FROM rol_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rrhh TO rol_admin;
--    DAC: el administrador puede delegar la lectura de empleados (GRANT ... WITH GRANT OPTION)
GRANT SELECT ON rrhh.empleados TO rol_admin WITH GRANT OPTION;
--    Analista: solo lectura sobre la vista de negocio y el catalogo de departamentos
GRANT USAGE ON SCHEMA rrhh TO rol_analista;
GRANT SELECT ON rrhh.v_resumen_empleados, rrhh.departamentos TO rol_analista;
--    Auditor: lectura exclusiva de la bitacora y de la vista de negocio
GRANT USAGE ON SCHEMA rrhh TO rol_auditor;
GRANT SELECT ON rrhh.audit_log_empleados, rrhh.v_resumen_empleados TO rol_auditor;
