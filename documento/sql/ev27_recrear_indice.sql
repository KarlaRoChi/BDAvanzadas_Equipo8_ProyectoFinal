-- 3. Recrear un indice: idx_emp_fecha_depto no incluye salario, asi que Q1 aun debe leer la
--    tabla. Se reemplaza por un indice de cobertura (INCLUDE) que permite Index Only Scan.
DROP INDEX rrhh.idx_emp_fecha_depto;
CREATE INDEX idx_emp_fecha_cobertura ON rrhh.empleados (fecha_ingreso)
    INCLUDE (depto_id, salario) TABLESPACE ts_rrhh_idx;
VACUUM ANALYZE rrhh.empleados;
SELECT rrhh.registrar_etapa('3_indice_recreado');
