-- 4. Carga de trabajo real: cada consulta se ejecuta 20 veces
SELECT rrhh.ejecutar_carga(20);
SELECT pg_sleep(2);

SELECT * FROM rrhh.v_advisor_hallazgos ORDER BY filas_leidas DESC, objeto;
SELECT * FROM rrhh.v_advisor_recomendaciones;
SELECT * FROM rrhh.v_advisor_sentencias LIMIT 3;
