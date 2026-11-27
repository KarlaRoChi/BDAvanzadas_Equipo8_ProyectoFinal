-- 4. Ajuste dinamico: nueva particion 2027-2028 y reubicacion de los datos historicos
--    en su propio tablespace (ts_rrhh_hist), sin perder informacion
CREATE TABLE rrhh.p_2027_2028 (LIKE rrhh.empleados INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    TABLESPACE ts_rrhh_part;
ALTER TABLE rrhh.p_2027_2028 OWNER TO rol_propietario;   -- mismo dueno que el resto de las particiones
ALTER TABLE rrhh.empleados DETACH PARTITION rrhh.p_futuro;
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_2027_2028
    FOR VALUES FROM ('2027-01-01') TO ('2029-01-01');
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_futuro
    FOR VALUES FROM ('2029-01-01') TO (MAXVALUE);
ALTER TABLE rrhh.p_historico SET TABLESPACE ts_rrhh_hist;
ALTER INDEX rrhh.p_historico_pkey SET TABLESPACE ts_rrhh_hist;

SELECT * FROM rrhh.v_particiones;
SELECT * FROM rrhh.v_uso_tablespaces;
