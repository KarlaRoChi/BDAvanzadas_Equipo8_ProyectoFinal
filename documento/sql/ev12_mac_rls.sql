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
