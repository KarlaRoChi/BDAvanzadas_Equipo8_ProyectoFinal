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
