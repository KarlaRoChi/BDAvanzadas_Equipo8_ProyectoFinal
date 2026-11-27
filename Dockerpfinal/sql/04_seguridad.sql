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
--;;
-- 3. MAC: nivel de autorizacion de cada usuario (1 Publico, 2 Confidencial, 3 Secreto)
INSERT INTO rrhh.autorizaciones (usuario, nivel) VALUES
    ('usr_admin', 3), ('usr_analista_karla', 2), ('usr_auditor_victor', 3);

-- 4. MAC a nivel de fila (RLS): aunque un usuario reciba acceso a la tabla (DAC),
--    solo ve las filas cuya clasificacion no excede su autorizacion
ALTER TABLE rrhh.empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE rrhh.empleados FORCE ROW LEVEL SECURITY;

CREATE POLICY pol_mac_lectura ON rrhh.empleados FOR SELECT
    USING (clasificacion_nivel <= rrhh.nivel_usuario());
CREATE POLICY pol_admin_escritura ON rrhh.empleados FOR ALL TO rol_admin
    USING (true) WITH CHECK (true);

-- 5. Resumen de privilegios efectivos por rol sobre los objetos del esquema
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'rrhh' AND grantee IN ('rol_admin', 'rol_analista', 'rol_auditor')
  AND table_name IN ('v_resumen_empleados', 'departamentos', 'audit_log_empleados',
                     'empleados', 'autorizaciones')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;

-- 6. Propietario de cada objeto: ya ninguno pertenece a usr_admin
SELECT c.relname AS objeto, pg_get_userbyid(c.relowner) AS propietario
FROM pg_class c
WHERE c.relnamespace = 'rrhh'::regnamespace AND c.relkind IN ('r', 'p', 'v')
  AND c.relname NOT LIKE 'p\_%'
ORDER BY c.relname;
