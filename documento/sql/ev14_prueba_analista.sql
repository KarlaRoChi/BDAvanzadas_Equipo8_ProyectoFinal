-- usr_analista_karla
SELECT current_user, session_user, rrhh.nivel_usuario() AS nivel_mac;

-- usr_analista_karla
SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM v_resumen_empleados;

-- usr_analista_karla
SELECT emp_id, nombre_completo, nombre_depto, nombre_rol, salario, clasificacion_nivel
FROM v_resumen_empleados ORDER BY emp_id LIMIT 3;

-- usr_analista_karla
SELECT * FROM departamentos;

-- usr_analista_karla
SELECT * FROM empleados LIMIT 1;

-- usr_analista_karla
DELETE FROM empleados WHERE emp_id = 1;

-- usr_analista_karla
SELECT * FROM audit_log_empleados;

-- usr_analista_karla
CREATE TABLE intruso (id int);
