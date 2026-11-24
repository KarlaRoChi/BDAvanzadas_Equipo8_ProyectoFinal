-- Query 3: subconsulta sobre el promedio salarial del departamento
EXPLAIN
SELECT e.emp_id, e.nombre, e.salario
FROM rrhh.empleados e
WHERE e.depto_id = 10
  AND e.salario > (SELECT AVG(e2.salario) * 1.7 FROM rrhh.empleados e2 WHERE e2.depto_id = 10);
