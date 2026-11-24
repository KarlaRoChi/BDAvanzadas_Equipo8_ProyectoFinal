-- usr_auditor_victor
SELECT audit_id, accion, emp_id, usuario_bd, salario_anterior, salario_nuevo, ip_origen
FROM audit_log_empleados ORDER BY audit_id;

-- usr_auditor_victor
SELECT usuario_bd, accion, count(*) AS eventos FROM audit_log_empleados
GROUP BY usuario_bd, accion ORDER BY 1, 2;

-- usr_auditor_victor
SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM v_resumen_empleados;

-- usr_auditor_victor
UPDATE audit_log_empleados SET salario_nuevo = 1;

-- usr_auditor_victor
DELETE FROM empleados WHERE emp_id = 1;
