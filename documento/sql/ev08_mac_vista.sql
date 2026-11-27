-- 5. Nivel de autorizacion (MAC) de cada usuario y funcion que lo consulta
CREATE TABLE rrhh.autorizaciones (
    usuario NAME PRIMARY KEY,
    nivel   SMALLINT NOT NULL CHECK (nivel BETWEEN 1 AND 3)
) TABLESPACE ts_rrhh_data;

CREATE FUNCTION rrhh.nivel_usuario() RETURNS SMALLINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = rrhh, pg_temp AS
$$ SELECT COALESCE((SELECT nivel FROM rrhh.autorizaciones WHERE usuario = session_user), 0) $$;

-- 6. Vista de negocio: oculta lo que excede la autorizacion MAC del usuario.
--    security_barrier obliga a aplicar primero el filtro MAC: sin ella, un filtro del
--    usuario (p. ej. una division entre cero o un cast) se evaluaria antes y sus
--    mensajes de error revelarian datos de filas ocultas.
CREATE VIEW rrhh.v_resumen_empleados WITH (security_barrier = true) AS
SELECT e.emp_id,
       e.nombre || ' ' || e.apellido AS nombre_completo,
       e.email,
       d.nombre_depto,
       r.nombre_rol,
       e.fecha_ingreso,
       e.salario,
       e.clasificacion_nivel
FROM rrhh.empleados e
JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
JOIN rrhh.roles r         ON e.rol_id   = r.rol_id
WHERE e.clasificacion_nivel <= rrhh.nivel_usuario();
