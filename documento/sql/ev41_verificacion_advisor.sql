-- 5. Verificacion: se reinician las estadisticas, se repite la carga de trabajo y se revisa
--    si el advisor sigue reportando lecturas secuenciales
SELECT pg_stat_reset();
SELECT rrhh.ejecutar_carga(20);
SELECT pg_sleep(2);
SELECT s.relname AS particion, s.seq_scan, s.seq_tup_read, s.idx_scan
FROM pg_stat_user_tables s
WHERE s.schemaname = 'rrhh' AND s.relname LIKE 'p\_%'
ORDER BY s.relname;
SELECT * FROM rrhh.v_advisor_hallazgos ORDER BY filas_leidas DESC, objeto;
