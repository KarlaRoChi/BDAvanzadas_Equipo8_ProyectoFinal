-- 2. Tabla de empleados particionada por rango de fecha de ingreso
--    clasificacion_nivel se usa para MAC (1 Publico, 2 Confidencial, 3 Secreto)
CREATE TABLE rrhh.empleados (
    emp_id              INTEGER       NOT NULL,
    nombre              VARCHAR(50)   NOT NULL,
    apellido            VARCHAR(50)   NOT NULL,
    email               VARCHAR(100),
    salario             NUMERIC(10,2) NOT NULL CHECK (salario > 0),
    fecha_ingreso       DATE          NOT NULL,
    depto_id            SMALLINT      NOT NULL REFERENCES rrhh.departamentos (depto_id),
    rol_id              SMALLINT      NOT NULL REFERENCES rrhh.roles (rol_id),
    clasificacion_nivel SMALLINT      NOT NULL DEFAULT 1 CHECK (clasificacion_nivel BETWEEN 1 AND 3),
    CONSTRAINT pk_empleados PRIMARY KEY (emp_id, fecha_ingreso)
        USING INDEX TABLESPACE ts_rrhh_idx
) PARTITION BY RANGE (fecha_ingreso);

CREATE TABLE rrhh.p_historico  PARTITION OF rrhh.empleados
    FOR VALUES FROM (MINVALUE)     TO ('2021-01-01') TABLESPACE ts_rrhh_part;
CREATE TABLE rrhh.p_2021_2022  PARTITION OF rrhh.empleados
    FOR VALUES FROM ('2021-01-01') TO ('2023-01-01') TABLESPACE ts_rrhh_part;
CREATE TABLE rrhh.p_2023_2024  PARTITION OF rrhh.empleados
    FOR VALUES FROM ('2023-01-01') TO ('2025-01-01') TABLESPACE ts_rrhh_part;
CREATE TABLE rrhh.p_2025_2026  PARTITION OF rrhh.empleados
    FOR VALUES FROM ('2025-01-01') TO ('2027-01-01') TABLESPACE ts_rrhh_part;
CREATE TABLE rrhh.p_futuro     PARTITION OF rrhh.empleados
    FOR VALUES FROM ('2027-01-01') TO (MAXVALUE)     TABLESPACE ts_rrhh_part;
