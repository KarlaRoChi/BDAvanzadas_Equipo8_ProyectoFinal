-- 3. Particiones: rango, filas y tamano de cada una
CREATE VIEW rrhh.v_particiones AS
SELECT c.relname                              AS particion,
       pg_get_expr(c.relpartbound, c.oid)     AS rango,
       s.n_live_tup                           AS filas,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano_total
FROM pg_inherits i
JOIN pg_class c        ON c.oid = i.inhrelid
JOIN pg_stat_user_tables s ON s.relid = c.oid
WHERE i.inhparent = 'rrhh.empleados'::regclass
ORDER BY c.relname;

SELECT * FROM rrhh.v_particiones;
