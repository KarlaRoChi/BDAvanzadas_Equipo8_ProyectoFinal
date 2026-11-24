-- 05_carga_masiva.sql  (se ejecuta como postgres)
-- Carga masiva de 60,000 empleados simulados con un bloque anonimo PL/pgSQL
-- (equivalente al bloque PL/SQL de Oracle). Cumple el minimo de 50,000 registros.

-- 1. Catalogos base
INSERT INTO rrhh.roles (rol_id, nombre_rol, nivel_acceso, descripcion) VALUES
    (1, 'Director',     'SECRETO',      'Direccion General'),
    (2, 'Gerente',      'CONFIDENCIAL', 'Gerencia de Area'),
    (3, 'Especialista', 'CONFIDENCIAL', 'Operacion Tecnica'),
    (4, 'Asistente',    'PUBLICO',      'Soporte Administrativo');

INSERT INTO rrhh.departamentos (depto_id, nombre_depto, presupuesto_anual, clasificacion_seguridad) VALUES
    (10, 'Tecnologias de la Informacion', 5000000.00, 'SECRETO'),
    (20, 'Finanzas y Contabilidad',       3500000.00, 'CONFIDENCIAL'),
    (30, 'Recursos Humanos',              1500000.00, 'CONFIDENCIAL'),
    (40, 'Operaciones y Logistica',       4000000.00, 'RESTRINGIDO');

-- 2. Carga en lotes de 5,000 filas con confirmacion por lote (COMMIT dentro de DO).
--    La bitacora se omite durante la carga (session_replication_role = replica) para no
--    generar 60,000 eventos artificiales; las operaciones reales posteriores si se auditan.
SET session_replication_role = replica;
SELECT setseed(0.42);   -- salarios reproducibles

DO $$
DECLARE
    v_total CONSTANT integer := 60000;
    v_lote  CONSTANT integer := 5000;
    v_ini   integer;
BEGIN
    FOR v_ini IN 1..v_total BY v_lote LOOP
        INSERT INTO rrhh.empleados (emp_id, nombre, apellido, email, salario,
                                    fecha_ingreso, depto_id, rol_id, clasificacion_nivel)
        SELECT i,
               'Empleado_' || i,
               'Paterno_' || (i % 250),
               'usuario.' || i || '@empresa-rrhh.com',
               ROUND((12000 + random() * 83000)::numeric, 2),
               DATE '2018-01-01' + (i % 3000),
               (ARRAY[10, 20, 30, 40])[1 + i % 4],
               (ARRAY[1, 2, 3, 4])[1 + i % 4],
               1 + i % 3
        FROM generate_series(v_ini, v_ini + v_lote - 1) AS i;
        COMMIT;
        RAISE NOTICE 'Lote cargado: % - %', v_ini, v_ini + v_lote - 1;
    END LOOP;
    RAISE NOTICE 'Carga completada exitosamente: % registros insertados.', v_total;
END $$;

SET session_replication_role = origin;
ANALYZE rrhh.empleados;
SELECT tableoid::regclass AS particion, count(*) AS registros,
       min(fecha_ingreso) AS desde, max(fecha_ingreso) AS hasta
FROM rrhh.empleados
GROUP BY tableoid ORDER BY 1::text;
SELECT count(*) AS total_empleados FROM rrhh.empleados;
