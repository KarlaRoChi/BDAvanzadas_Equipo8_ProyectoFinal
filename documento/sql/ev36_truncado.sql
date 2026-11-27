-- 6. Truncado controlado: se cargan filas de prueba en la particion nueva y se vacia
--    solo esa particion (sin tocar el resto de la tabla ni disparar la bitacora por fila)
SET session_replication_role = replica;
INSERT INTO rrhh.empleados (emp_id, nombre, apellido, email, salario, fecha_ingreso, depto_id, rol_id, clasificacion_nivel)
SELECT 70000 + i, 'Temporal_' || i, 'Prueba', 'tmp.' || i || '@empresa-rrhh.com', 15000,
       DATE '2027-01-01' + (i % 700), 40, 4, 1
FROM generate_series(1, 1000) AS i;
SET session_replication_role = origin;
SELECT count(*) AS filas_antes FROM rrhh.p_2027_2028;
-- Una particion referenciada por una FK no se puede truncar directamente: se desprende,
-- se vacia y se vuelve a adjuntar con el mismo rango
ALTER TABLE rrhh.empleados DETACH PARTITION rrhh.p_2027_2028;
TRUNCATE rrhh.p_2027_2028;
ALTER TABLE rrhh.empleados ATTACH PARTITION rrhh.p_2027_2028
    FOR VALUES FROM ('2027-01-01') TO ('2029-01-01');
SELECT count(*) AS filas_despues FROM rrhh.p_2027_2028;
SELECT count(*) AS total_empleados FROM rrhh.empleados;
