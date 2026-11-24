-- usr_admin
GRANT SELECT ON empleados TO usr_analista_karla;

-- usr_analista_karla
SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM empleados;

-- usr_admin
REVOKE SELECT ON empleados FROM usr_analista_karla;

-- usr_analista_karla
SELECT count(*) FROM empleados;

-- postgres
TRUNCATE rrhh.audit_log_empleados;

-- postgres
DELETE FROM rrhh.audit_log_empleados;
