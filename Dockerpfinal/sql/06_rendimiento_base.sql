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
--;;
-- 2. Lectura del plan: costo del optimizador (EXPLAIN) y tiempo real (EXPLAIN ANALYZE)
CREATE FUNCTION rrhh.costo_plan(q TEXT) RETURNS NUMERIC
LANGUAGE plpgsql AS
$$
DECLARE j JSON;
BEGIN
    EXECUTE 'EXPLAIN (FORMAT JSON) ' || q INTO j;
    RETURN (j -> 0 -> 'Plan' ->> 'Total Cost')::NUMERIC;
END;
$$;

CREATE FUNCTION rrhh.tiempo_plan(q TEXT) RETURNS NUMERIC
LANGUAGE plpgsql AS
$$
DECLARE j JSON;
BEGIN
    EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || q INTO j;
    RETURN (j -> 0 ->> 'Execution Time')::NUMERIC;
END;
$$;

-- 3. Resultados por etapa de afinacion
CREATE TABLE rrhh.tuning_resultados (
    etapa     TEXT NOT NULL,
    consulta  TEXT NOT NULL REFERENCES rrhh.consultas_tuning (consulta),
    costo     NUMERIC NOT NULL,
    tiempo_ms NUMERIC NOT NULL,
    PRIMARY KEY (etapa, consulta)
) TABLESPACE ts_rrhh_data;

CREATE FUNCTION rrhh.registrar_etapa(p_etapa TEXT) RETURNS VOID
LANGUAGE plpgsql AS
$$
DECLARE
    c    RECORD;
    v_ms NUMERIC;
BEGIN
    FOR c IN SELECT consulta, sentencia FROM rrhh.consultas_tuning ORDER BY consulta LOOP
        -- tiempo real = mejor de 5 ejecuciones (reduce el ruido de una sola medicion)
        SELECT MIN(rrhh.tiempo_plan(c.sentencia)) INTO v_ms FROM generate_series(1, 5);
        INSERT INTO rrhh.tuning_resultados
        VALUES (p_etapa, c.consulta, rrhh.costo_plan(c.sentencia), v_ms);
    END LOOP;
END;
$$;

-- 4. Carga de trabajo reproducible: cada consulta se ejecuta p_veces veces
CREATE FUNCTION rrhh.ejecutar_carga(p_veces INTEGER) RETURNS VOID
LANGUAGE plpgsql AS
$$
DECLARE c RECORD;
BEGIN
    FOR c IN SELECT sentencia FROM rrhh.consultas_tuning ORDER BY consulta LOOP
        FOR i IN 1..p_veces LOOP
            EXECUTE c.sentencia;
        END LOOP;
    END LOOP;
END;
$$;
--;;
-- 5. Estadisticas actualizadas y medicion de la etapa base (sin indices secundarios)
VACUUM ANALYZE rrhh.empleados;
SELECT rrhh.registrar_etapa('1_sin_indices');
SELECT etapa, consulta, costo, tiempo_ms FROM rrhh.tuning_resultados ORDER BY consulta;
--;;
-- Query 1: filtro por rango de fechas (poda de particiones)
EXPLAIN
SELECT depto_id, ROUND(AVG(salario),2) AS salario_prom, COUNT(*) AS total
FROM rrhh.empleados
WHERE fecha_ingreso BETWEEN DATE '2023-06-01' AND DATE '2023-06-30'
GROUP BY depto_id;
--;;
-- Query 2: JOIN multitabla y agregacion
EXPLAIN
SELECT d.nombre_depto, r.nombre_rol, COUNT(e.emp_id) AS total_personal, SUM(e.salario) AS gasto_nomina
FROM rrhh.empleados e
JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
JOIN rrhh.roles r ON e.rol_id = r.rol_id
WHERE e.salario > 92000
GROUP BY d.nombre_depto, r.nombre_rol;
--;;
-- Query 3: subconsulta sobre el promedio salarial del departamento
EXPLAIN
SELECT e.emp_id, e.nombre, e.salario
FROM rrhh.empleados e
WHERE e.depto_id = 10
  AND e.salario > (SELECT AVG(e2.salario) * 1.7 FROM rrhh.empleados e2 WHERE e2.depto_id = 10);
