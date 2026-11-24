-- 06_rendimiento_base.sql  (se ejecuta como postgres)
-- Infraestructura de medicion: consultas a analizar, funciones que leen el plan de
-- ejecucion (EXPLAIN en formato JSON) y tabla donde se guarda cada etapa de la afinacion.

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT pg_stat_statements_reset();

-- 1. Las 3 consultas complejas a evaluar
CREATE TABLE rrhh.consultas_tuning (
    consulta    TEXT PRIMARY KEY,
    descripcion TEXT NOT NULL,
    sentencia   TEXT NOT NULL
) TABLESPACE ts_rrhh_data;

INSERT INTO rrhh.consultas_tuning VALUES
('Q1', 'Rango de fechas con poda de particiones',
 $q$SELECT depto_id, ROUND(AVG(salario),2) AS salario_prom, COUNT(*) AS total
    FROM rrhh.empleados
    WHERE fecha_ingreso BETWEEN DATE '2023-06-01' AND DATE '2023-06-30'
    GROUP BY depto_id$q$),
('Q2', 'Masa salarial con JOIN a catalogos',
 $q$SELECT d.nombre_depto, r.nombre_rol, COUNT(e.emp_id) AS total_personal, SUM(e.salario) AS gasto_nomina
    FROM rrhh.empleados e
    JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
    JOIN rrhh.roles r ON e.rol_id = r.rol_id
    WHERE e.salario > 92000
    GROUP BY d.nombre_depto, r.nombre_rol$q$),
('Q3', 'Salarios atipicos del depto 10 (subconsulta)',
 $q$SELECT e.emp_id, e.nombre, e.salario
    FROM rrhh.empleados e
    WHERE e.depto_id = 10
      AND e.salario > (SELECT AVG(e2.salario) * 1.7 FROM rrhh.empleados e2 WHERE e2.depto_id = 10)$q$);
