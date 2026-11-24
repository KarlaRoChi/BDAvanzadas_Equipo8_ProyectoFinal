# Docker - Proyecto Final (Diseño, Seguridad y Optimización de un Sistema de Gestión de Empleados, PostgreSQL 16)

**Trabajo conjunto de** Rojas Chimal Karla Beatriz (320048025) y Calderón Gutiérrez Victor Emiliano (423097331) — Grupo 3, Equipo 8.

Entorno equivalente al de P1-P4 (imagen `postgres:16`, red y volúmenes declarativos).
Documento del proyecto: `../documento/main.tex`.

| Elemento | Valor |
|---|---|
| Contenedor | `bd-lab-final` (más `bd-lab-final-init`, que corre una vez y termina) |
| Superusuario / contraseña | `postgres` / `Admin12345` (socket Unix en `trust`, como `/ as sysdba`) |
| BD de trabajo | `rrhh` (esquema `rrhh`) |
| Usuarios del proyecto | `usr_admin`, `usr_analista_karla`, `usr_auditor_victor` (contraseñas en `sql/01_instancia_roles.sql`) |
| Volúmenes | `bd_datos_final`, `bd_tablespace_final` (`/var/lib/postgresql/tablespaces/{data,idx,part,audit,hist}`) |
| Extensión | `pg_stat_statements` precargada (`shared_preload_libraries`) |
| Autenticación | `initdb/01-hba-scram.sh` pone el loopback TCP en `scram-sha-256` (solo al crear el volumen) |
| Puerto | `5432` (detener antes el contenedor de otra práctica) |

A diferencia de P3, **no hay pasos manuales**: el servicio `init-tablespaces` crea los cinco directorios
de los tablespaces y los asigna a `postgres` antes de arrancar la base.

## Uso

```bash
docker compose up -d
docker exec -it bd-lab-final psql          # PGUSER=postgres y PGDATABASE=rrhh ya vienen definidos
```

Los scripts de `sql/` se montan en `/sql` y se ejecutan en orden. El proyecto completo desde cero:

```bash
docker exec -i bd-lab-final psql -X -U postgres -d rrhh -f /sql/01_instancia_roles.sql
docker exec -i -e PGPASSWORD='AdminSecure2026#' bd-lab-final psql -X -h localhost -U usr_admin -d rrhh -f /sql/02_esquema.sql
for f in 03_auditoria 04_seguridad 05_carga_masiva 06_rendimiento_base 07_advisor 08_indices 09_almacenamiento 10_parametros; do
  docker exec -i bd-lab-final psql -X -U postgres -d rrhh -f /sql/$f.sql
done
```

| Script | Contenido | Se ejecuta como |
|---|---|---|
| `01_instancia_roles.sql` | 5 tablespaces, roles RBAC, 3 usuarios, esquema `rrhh` | `postgres` |
| `02_esquema.sql` | Catálogos, `empleados` particionada por rango, historial, nivel MAC, vista | `usr_admin` |
| `03_auditoria.sql` | Bitácora, trigger de auditoría, bitácora inmutable | `postgres` |
| `04_seguridad.sql` | GRANT (DAC/RBAC), niveles MAC y políticas RLS | `postgres` |
| `05_carga_masiva.sql` | 60,000 registros con bloque `DO` por lotes de 5,000 | `postgres` |
| `06_rendimiento_base.sql` | 3 consultas complejas, medición de costo y plan (antes) | `postgres` |
| `07_advisor.sql` | Hallazgos y recomendaciones (análogo a `DBA_ADVISOR_*`) | `postgres` |
| `08_indices.sql` | Creación y recreación de índices, comparativo de costos | `postgres` |
| `09_almacenamiento.sql` | Uso de tablespaces, nueva partición, mantenimiento, truncado | `postgres` |
| `10_parametros.sql` | Ajuste de parámetros, aplicación de recomendaciones | `postgres` |

- Comprobar el estado final: `bash validar.sh`
- Regenerar las capturas de `../documento/img` y el código de `../documento/sql`:
  `python generar_evidencias.py` (requiere `pip install pillow`;
  **ejecuta `docker compose down -v` al empezar**, así que borra los datos del proyecto).
- Al terminar (sin borrar volúmenes): `docker stop bd-lab-final`.

## Diferencias con Oracle

| Oracle (enunciado) | PostgreSQL (adaptación) |
|---|---|
| `CREATE TABLESPACE ... DATAFILE ... AUTOEXTEND` | `CREATE TABLESPACE ... LOCATION` (no hay datafiles ni `AUTOEXTEND`: crecen mientras haya espacio en el volumen) |
| `PARTITION BY RANGE ... VALUES LESS THAN` | `PARTITION BY RANGE` + `PARTITION OF ... FOR VALUES FROM ... TO` |
| MAC con Oracle Label Security | Nivel por usuario (`autorizaciones`) + `ROW LEVEL SECURITY` y vista filtrada |
| Roles `CONNECT`, `RESOURCE`, `DBA` | Roles propios con `GRANT` explícitos (mínimo privilegio) |
| `DBMS_RANDOM`, `FORALL` | `random()`, `INSERT ... SELECT generate_series` por lotes |
| `EXPLAIN PLAN` + `DBMS_XPLAN` | `EXPLAIN` / `EXPLAIN (ANALYZE, BUFFERS)` |
| `DB_BLOCK_SIZE`, `SGA_TARGET`, `PGA_AGGREGATE_TARGET` | `block_size` (fijo), `shared_buffers`, `work_mem`, `effective_cache_size` |
| `DBA_ADVISOR_FINDINGS` / `DBA_ADVISOR_RECOMMENDATIONS` | Vistas propias sobre `pg_stat_user_tables`, `pg_stat_user_indexes` y `pg_stat_statements` |
| `ALTER INDEX ... REBUILD` | `REINDEX INDEX` |
