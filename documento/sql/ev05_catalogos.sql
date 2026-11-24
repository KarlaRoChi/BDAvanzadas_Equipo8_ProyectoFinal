-- 02_esquema.sql  (se ejecuta como usr_admin)
-- Esquema relacional: roles, departamentos, empleados (particionada por rango) e historial.

-- 1. Catalogos
CREATE TABLE rrhh.roles (
    rol_id       SMALLINT PRIMARY KEY USING INDEX TABLESPACE ts_rrhh_idx,
    nombre_rol   VARCHAR(50) NOT NULL UNIQUE USING INDEX TABLESPACE ts_rrhh_idx,
    nivel_acceso VARCHAR(20) NOT NULL DEFAULT 'CONFIDENCIAL',
    descripcion  VARCHAR(200)
) TABLESPACE ts_rrhh_data;

CREATE TABLE rrhh.departamentos (
    depto_id                SMALLINT PRIMARY KEY USING INDEX TABLESPACE ts_rrhh_idx,
    nombre_depto            VARCHAR(60) NOT NULL UNIQUE USING INDEX TABLESPACE ts_rrhh_idx,
    presupuesto_anual       NUMERIC(14,2) CHECK (presupuesto_anual >= 0),
    clasificacion_seguridad VARCHAR(20) DEFAULT 'RESTRINGIDO'
) TABLESPACE ts_rrhh_data;
