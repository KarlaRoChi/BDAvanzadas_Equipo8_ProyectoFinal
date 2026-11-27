-- 08_indices.sql  (se ejecuta como postgres)
-- Creacion y recreacion de indices, y evaluacion del impacto en el costo de ejecucion.

-- 1. Indices sobre las columnas de filtro que senalo el advisor (uno por consulta; se
--    crean en cada particion, en ts_rrhh_idx)
CREATE INDEX idx_emp_fecha_depto   ON rrhh.empleados (fecha_ingreso, depto_id) TABLESPACE ts_rrhh_idx;
CREATE INDEX idx_emp_depto_salario ON rrhh.empleados (depto_id, salario)       TABLESPACE ts_rrhh_idx;
CREATE INDEX idx_emp_salario       ON rrhh.empleados (salario) INCLUDE (depto_id, rol_id) TABLESPACE ts_rrhh_idx;
--    Indice de control: ninguna consulta de la carga filtra por email. Se crea a proposito
--    para comprobar que el advisor detecta indices sin uso (se elimina en 10_parametros.sql)
CREATE INDEX idx_emp_email         ON rrhh.empleados (email)                   TABLESPACE ts_rrhh_idx;
ANALYZE rrhh.empleados;
SELECT rrhh.registrar_etapa('2_con_indices');

-- 2. Tamano de cada indice (suma de sus particiones)
SELECT c.relname AS indice, COALESCE(t.spcname, 'pg_default') AS tablespace,
       pg_size_pretty((SELECT sum(pg_relation_size(pt.relid)) FROM pg_partition_tree(c.oid) pt)) AS tamano_total
FROM pg_class c
LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
WHERE c.relnamespace = 'rrhh'::regnamespace AND c.relkind = 'I'
ORDER BY c.relname;
--;;
-- 3. Recrear un indice: idx_emp_fecha_depto no incluye salario, asi que Q1 aun debe leer la
--    tabla. Se reemplaza por un indice de cobertura (INCLUDE) que permite Index Only Scan.
DROP INDEX rrhh.idx_emp_fecha_depto;
CREATE INDEX idx_emp_fecha_cobertura ON rrhh.empleados (fecha_ingreso)
    INCLUDE (depto_id, salario) TABLESPACE ts_rrhh_idx;
VACUUM ANALYZE rrhh.empleados;
SELECT rrhh.registrar_etapa('3_indice_recreado');
--;;
-- Query 1 despues de los indices
EXPLAIN
SELECT depto_id, ROUND(AVG(salario),2) AS salario_prom, COUNT(*) AS total
FROM rrhh.empleados
WHERE fecha_ingreso BETWEEN DATE '2023-06-01' AND DATE '2023-06-30'
GROUP BY depto_id;
--;;
-- Query 2 despues de los indices
EXPLAIN
SELECT d.nombre_depto, r.nombre_rol, COUNT(e.emp_id) AS total_personal, SUM(e.salario) AS gasto_nomina
FROM rrhh.empleados e
JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
JOIN rrhh.roles r ON e.rol_id = r.rol_id
WHERE e.salario > 92000
GROUP BY d.nombre_depto, r.nombre_rol;
--;;
-- Query 3 despues de los indices
EXPLAIN
SELECT e.emp_id, e.nombre, e.salario
FROM rrhh.empleados e
WHERE e.depto_id = 10
  AND e.salario > (SELECT AVG(e2.salario) * 1.7 FROM rrhh.empleados e2 WHERE e2.depto_id = 10);
--;;
-- 4. Comparativo del costo del optimizador y del tiempo real por etapa
SELECT consulta,
       MAX(costo)     FILTER (WHERE etapa = '1_sin_indices')     AS costo_antes,
       MAX(costo)     FILTER (WHERE etapa = '2_con_indices')     AS costo_con_idx,
       MAX(costo)     FILTER (WHERE etapa = '3_indice_recreado') AS costo_final,
       MAX(tiempo_ms) FILTER (WHERE etapa = '1_sin_indices')     AS ms_antes,
       MAX(tiempo_ms) FILTER (WHERE etapa = '3_indice_recreado') AS ms_despues
FROM rrhh.tuning_resultados
GROUP BY consulta ORDER BY consulta;
