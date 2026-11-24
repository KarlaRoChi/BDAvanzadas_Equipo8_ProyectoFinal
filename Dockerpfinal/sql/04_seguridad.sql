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
--;;
-- 2. MAC: nivel de autorizacion de cada usuario (1 Publico, 2 Confidencial, 3 Secreto)
INSERT INTO rrhh.autorizaciones (usuario, nivel) VALUES
    ('usr_admin', 3), ('usr_analista_karla', 2), ('usr_auditor_victor', 3);

-- 3. MAC a nivel de fila (RLS): aunque un usuario reciba acceso a la tabla (DAC),
--    solo ve las filas cuya clasificacion no excede su autorizacion
ALTER TABLE rrhh.empleados ENABLE ROW LEVEL SECURITY;
ALTER TABLE rrhh.empleados FORCE ROW LEVEL SECURITY;

CREATE POLICY pol_mac_lectura ON rrhh.empleados FOR SELECT
    USING (clasificacion_nivel <= rrhh.nivel_usuario());
CREATE POLICY pol_admin_escritura ON rrhh.empleados FOR ALL TO rol_admin
    USING (true) WITH CHECK (true);

-- 4. Resumen de privilegios efectivos por rol sobre los objetos del esquema
SELECT grantee, table_name, string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema = 'rrhh' AND grantee IN ('rol_admin', 'rol_analista', 'rol_auditor')
  AND table_name IN ('v_resumen_empleados', 'departamentos', 'audit_log_empleados', 'empleados')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
