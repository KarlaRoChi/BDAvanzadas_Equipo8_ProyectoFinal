-- Query 2: JOIN multitabla y agregacion
EXPLAIN
SELECT d.nombre_depto, r.nombre_rol, COUNT(e.emp_id) AS total_personal, SUM(e.salario) AS gasto_nomina
FROM rrhh.empleados e
JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
JOIN rrhh.roles r ON e.rol_id = r.rol_id
WHERE e.salario > 92000
GROUP BY d.nombre_depto, r.nombre_rol;
