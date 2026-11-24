-- 07_advisor.sql  (se ejecuta como postgres)
-- Equivalente a DBA_ADVISOR_FINDINGS y DBA_ADVISOR_RECOMMENDATIONS de Oracle, construido
-- sobre las vistas de estadisticas de PostgreSQL (el motor no incluye un advisor automatico).

-- 1. Hallazgos: particiones leidas secuencialmente con frecuencia, e indices sin uso
CREATE VIEW rrhh.v_advisor_hallazgos AS
SELECT 'LECTURAS SECUENCIALES'::TEXT AS hallazgo,
       s.relname::TEXT               AS objeto,
       s.seq_scan                    AS veces,
       s.seq_tup_read                AS filas_leidas
FROM pg_stat_user_tables s
WHERE s.schemaname = 'rrhh' AND s.relname LIKE 'p\_%'
  AND s.seq_tup_read > 0 AND s.seq_scan > 2 * COALESCE(s.idx_scan, 0)
UNION ALL
SELECT 'INDICE SIN USO', i.indexrelname::TEXT, i.idx_scan, 0
FROM pg_stat_user_indexes i
JOIN pg_index x ON x.indexrelid = i.indexrelid
WHERE i.schemaname = 'rrhh' AND i.idx_scan = 0 AND NOT x.indisunique AND NOT x.indisprimary;

-- 2. Recomendaciones derivadas de los hallazgos
CREATE VIEW rrhh.v_advisor_recomendaciones AS
SELECT hallazgo,
       count(*)                 AS objetos_afectados,
       sum(filas_leidas)        AS filas_leidas_en_total,
       CASE hallazgo
            WHEN 'LECTURAS SECUENCIALES'
                 THEN 'CREATE INDEX sobre las columnas de filtro de las sentencias mas costosas'
            ELSE      'Evaluar DROP INDEX: cuesta escritura y espacio sin beneficio de lectura'
       END                      AS recomendacion
FROM rrhh.v_advisor_hallazgos
GROUP BY hallazgo;

-- 3. Sentencias mas costosas (de donde se toman las columnas a indexar)
CREATE VIEW rrhh.v_advisor_sentencias AS
SELECT calls, ROUND(total_exec_time::NUMERIC, 2) AS total_ms,
       LEFT(REGEXP_REPLACE(query, '\s+', ' ', 'g'), 70) AS sentencia
FROM pg_stat_statements
WHERE query ILIKE '%rrhh.empleados%' AND query NOT ILIKE '%pg_stat%'
  AND query NOT ILIKE '%consultas_tuning%'
ORDER BY total_exec_time DESC;
