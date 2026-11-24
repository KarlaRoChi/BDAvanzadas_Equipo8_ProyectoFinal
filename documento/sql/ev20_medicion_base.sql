-- 5. Estadisticas actualizadas y medicion de la etapa base (sin indices secundarios)
VACUUM ANALYZE rrhh.empleados;
SELECT rrhh.registrar_etapa('1_sin_indices');
SELECT etapa, consulta, costo, tiempo_ms FROM rrhh.tuning_resultados ORDER BY consulta;
