-- 08_indices.sql  (se ejecuta como postgres)
-- Creacion y recreacion de indices, y evaluacion del impacto en el costo de ejecucion.

-- 1. Indices recomendados por el advisor (se crean en cada particion, en ts_rrhh_idx)
CREATE INDEX idx_emp_fecha_depto   ON rrhh.empleados (fecha_ingreso, depto_id) TABLESPACE ts_rrhh_idx;
CREATE INDEX idx_emp_depto_salario ON rrhh.empleados (depto_id, salario)       TABLESPACE ts_rrhh_idx;
CREATE INDEX idx_emp_salario       ON rrhh.empleados (salario) INCLUDE (depto_id, rol_id) TABLESPACE ts_rrhh_idx;
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
