-- usr_admin
SELECT current_user, rrhh.nivel_usuario() AS nivel_mac;

-- usr_admin
UPDATE empleados SET salario = salario * 1.10 WHERE emp_id = 100;

-- usr_admin
INSERT INTO empleados
VALUES (60001, 'Prueba', 'Insercion', 'prueba@empresa-rrhh.com', 25000, '2026-03-20', 10, 3, 1);

-- usr_admin
DELETE FROM empleados WHERE emp_id = 60001;

-- usr_admin
CREATE TABLE prueba_admin (id int);
DROP TABLE prueba_admin;

-- usr_admin
UPDATE audit_log_empleados SET salario_nuevo = 1;

-- usr_admin
SELECT hist_id, emp_id, salario, vigente_desde, motivo FROM historial_salarios;
