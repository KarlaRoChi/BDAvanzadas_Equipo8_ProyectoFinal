-- Query 1 despues de los indices
EXPLAIN
SELECT depto_id, ROUND(AVG(salario),2) AS salario_prom, COUNT(*) AS total
FROM rrhh.empleados
WHERE fecha_ingreso BETWEEN DATE '2023-06-01' AND DATE '2023-06-30'
GROUP BY depto_id;
