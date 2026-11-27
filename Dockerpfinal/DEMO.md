# Guía de la demo – Proyecto final (Equipo 08)

Comandos para la exposición, en el orden en que se presentan. Todos se ejecutan desde una terminal
(PowerShell o Git Bash) en la carpeta `Dockerpfinal`. Esta guía amplía la sección
"Guía de demostración en clase" del reporte.

## 0. Antes de empezar

```powershell
cd "C:\PROYECTOS LATEX y otros\BDA\BDAvanzadas_Equipo8_ProyectoFinal\Dockerpfinal"
docker compose start          # o "docker compose up -d" si los contenedores no existen
docker ps                     # bd-lab-final (healthy) y bd-lab-final-mant deben estar "Up"
bash validar.sh               # opcional: 14 verificaciones, debe terminar en "Validacion finalizada correctamente."
```

> En Git Bash, ejecuta antes `export MSYS_NO_PATHCONV=1`. Si no, las rutas como `/mant/...` se
> convierten en rutas de Windows y los comandos fallan. En PowerShell no hace falta.

### Usuarios y contraseñas

| Usuario | Contraseña | Rol | Nivel MAC |
|---|---|---|---|
| `postgres` | `Admin12345` | Superusuario (entra por socket sin contraseña) | — |
| `usr_admin` | `AdminSecure2026#` | `rol_admin` | 3 |
| `usr_analista_karla` | `KarlaAnalyst2026#` | `rol_analista` | 2 |
| `usr_auditor_victor` | `VictorAudit2026#` | `rol_auditor` | 3 |

Los tres usuarios del proyecto se conectan por TCP (`-h localhost`), así que **psql pide la contraseña**.
Ya tienen `search_path = rrhh`, por eso no hace falta escribir `rrhh.` en sus consultas.
Para salir de psql: `\q`.

---

## 1. Analista: MAC, RLS y `security_barrier`

```powershell
docker exec -it bd-lab-final psql -h localhost -U usr_analista_karla -d rrhh
```

```sql
-- Solo ve los niveles 1 y 2: 40,000 de 60,000 empleados
SELECT count(*) FROM v_resumen_empleados;
SELECT clasificacion_nivel, count(*) FROM v_resumen_empleados GROUP BY 1 ORDER BY 1;

-- No tiene acceso directo a la tabla ni a la bitácora (permission denied)
SELECT * FROM empleados LIMIT 5;
SELECT * FROM audit_log_empleados;

-- Tampoco puede borrar (permission denied)
DELETE FROM empleados WHERE emp_id = 1;

-- security_barrier: este filtro dividiría entre cero si llegara a evaluar una fila de nivel 3.
-- Devuelve las mismas 40,000 filas sin error, así que no se filtran filas ocultas por mensajes de error.
SELECT count(*) FROM v_resumen_empleados
WHERE 1/(CASE WHEN clasificacion_nivel = 3 THEN 0 ELSE 1 END) = 1;
```

## 2. Administrador: operación auditada y separación de funciones

```powershell
docker exec -it bd-lab-final psql -h localhost -U usr_admin -d rrhh
```

```sql
-- Cambio de salario: el trigger lo registra en la bitácora (genera un evento nuevo)
SELECT emp_id, nombre, salario FROM empleados WHERE emp_id = 100;
UPDATE empleados SET salario = salario * 1.10 WHERE emp_id = 100;
SELECT emp_id, nombre, salario FROM empleados WHERE emp_id = 100;

-- El mismo trigger alimenta el historial de salarios
SELECT * FROM historial_salarios WHERE emp_id = 100 ORDER BY hist_id;

-- No puede alterar la bitácora (permission denied)
UPDATE audit_log_empleados SET salario_nuevo = 0;

-- No puede apagar la auditoría: no es dueño de la tabla (must be owner)
ALTER TABLE empleados DISABLE TRIGGER trg_audit_empleados;

-- No puede subirse ni bajarle el nivel MAC a nadie (permission denied)
UPDATE autorizaciones SET nivel = 3;
```

## 3. Auditor: quién, qué, cuándo y desde dónde

```powershell
docker exec -it bd-lab-final psql -h localhost -U usr_auditor_victor -d rrhh
```

```sql
-- Bitácora: los 3 eventos del documento más el UPDATE que se acaba de hacer en la demo
SELECT audit_id, accion, emp_id, usuario_bd, fecha_operacion,
       salario_anterior, salario_nuevo, ip_origen
FROM audit_log_empleados ORDER BY audit_id;

-- Con nivel 3 ve los 60,000 empleados
SELECT count(*) FROM v_resumen_empleados;

-- Puede leer, pero no modificar la bitácora (permission denied)
UPDATE audit_log_empleados SET salario_nuevo = 1;
```

## 4. Superusuario: bitácora inmutable, advisor, rendimiento y almacenamiento

```powershell
docker exec -it bd-lab-final psql -U postgres -d rrhh
```

```sql
-- Ni postgres puede borrar ni cambiar la bitácora: la bloquean sus triggers
DELETE FROM rrhh.audit_log_empleados;
TRUNCATE rrhh.audit_log_empleados;

-- Advisor propio (equivalente a DBA_ADVISOR_FINDINGS / DBA_ADVISOR_RECOMMENDATIONS)
SELECT * FROM rrhh.v_advisor_hallazgos;
SELECT * FROM rrhh.v_advisor_recomendaciones;

-- Comparativo antes/después de la afinación (4 etapas x 3 consultas)
SELECT etapa, consulta, costo, tiempo_ms
FROM rrhh.tuning_resultados ORDER BY consulta, etapa;

-- Plan de Q1: Index Only Scan sobre la partición p_2023_2024 (costo 432.81 -> 19.98)
EXPLAIN
SELECT depto_id, ROUND(AVG(salario),2) AS salario_prom, COUNT(*) AS total
FROM rrhh.empleados
WHERE fecha_ingreso BETWEEN DATE '2023-06-01' AND DATE '2023-06-30'
GROUP BY depto_id;

-- Plan de Q2 (JOIN con catálogos)
EXPLAIN
SELECT d.nombre_depto, r.nombre_rol, COUNT(e.emp_id) AS total_personal, SUM(e.salario) AS gasto_nomina
FROM rrhh.empleados e
JOIN rrhh.departamentos d ON e.depto_id = d.depto_id
JOIN rrhh.roles r ON e.rol_id = r.rol_id
WHERE e.salario > 92000
GROUP BY d.nombre_depto, r.nombre_rol;

-- Plan de Q3 (subconsulta)
EXPLAIN
SELECT e.emp_id, e.nombre, e.salario
FROM rrhh.empleados e
WHERE e.depto_id = 10
  AND e.salario > (SELECT AVG(e2.salario) * 1.7 FROM rrhh.empleados e2 WHERE e2.depto_id = 10);

-- Almacenamiento: uso de cada tablespace frente a su tamaño asignado (alerta al 80 %)
SELECT * FROM rrhh.v_uso_tablespaces;
SELECT * FROM rrhh.v_particiones;

-- Mantenimiento manual de las particiones 2025-2026 (REINDEX + ANALYZE)
CALL rrhh.prc_mantenimiento('p_2025');

-- Parámetros ajustados
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW random_page_cost;
SHOW block_size;
```

### Cambio de rol sin reconectar (desde `postgres`)

```sql
SET ROLE rol_analista;
SELECT * FROM rrhh.audit_log_empleados;   -- permission denied
RESET ROLE;

SET ROLE rol_auditor;
SELECT count(*) FROM rrhh.audit_log_empleados;   -- sí puede leerla
RESET ROLE;
```

> `SET ROLE` cambia los **privilegios** (RBAC/DAC), pero el nivel MAC se calcula con el usuario de
> sesión (`session_user`). Para mostrar el MAC hay que reconectarse con cada usuario (secciones 1 y 3).

## 5. Mantenimiento automático

```powershell
docker exec bd-lab-final-mant sh /mant/mantenimiento.sh --una-vez
docker logs bd-lab-final-mant
docker exec -it bd-lab-final psql -c "SELECT * FROM rrhh.log_mantenimiento ORDER BY id;"
```

El servicio `mantenimiento` corre `rrhh.prc_mantenimiento('p_')` al arrancar y después una vez al día
(`MANT_INTERVALO_SEG=86400`). `--una-vez` fuerza una corrida inmediata y cada corrida queda en
`rrhh.log_mantenimiento` con su inicio, fin y estado.

## 6. Al terminar

```powershell
docker compose stop
```

`stop` apaga los contenedores sin borrar los volúmenes, así que los datos (y la bitácora) se conservan.
**No usar `docker compose down -v`**: borra la base. Para volver a crearla desde cero, ver el
[README de Dockerpfinal](README.md).

---

## Qué hace `validar.sh`

`validar.sh` es una prueba automática del estado final del proyecto. Se corre con los contenedores
levantados (`bash validar.sh`) y revisa 14 puntos. Se detiene en el primer punto que falla
(`set -e`) y, si todo está bien, termina con `Validacion finalizada correctamente.`

Usa dos formas de conexión:

- `psql_su`: entra como `postgres` por el socket interno del contenedor, para revisar el catálogo.
- `psql_as`: entra como un usuario del proyecto por TCP (`-h localhost`), con su contraseña, para
  probar los permisos tal como los tendría ese usuario.

La función `denegado` ejecuta una sentencia que **debe fallar**. Si la base la acepta, la validación
marca error, porque significaría que un permiso quedó abierto.

| # | Qué comprueba |
|---|---|
| 1 | El contenedor `bd-lab-final` está corriendo y la base está abierta (no en recuperación). |
| 2 | Existen los 5 tablespaces `ts_rrhh_*`. |
| 3 | `empleados` está particionada (al menos 5 particiones) y tiene al menos 50,000 registros. |
| 4 | Existen los 3 roles y los 3 usuarios del proyecto (RBAC). |
| 5 | Existen el trigger de auditoría y los 2 triggers que hacen inmutable la bitácora. |
| 6 | La analista ve como máximo el nivel MAC 2, y no puede borrar empleados ni leer la bitácora. |
| 7 | El auditor ve el nivel 3, puede leer la bitácora y no puede modificarla. |
| 8 | Ni siquiera `postgres` puede borrar o modificar la bitácora. Para probarlo aunque esté vacía, inserta un evento de prueba y lo intenta borrar y modificar dentro de una transacción con `ROLLBACK`, así que no deja rastro. |
| 8b | Separación de funciones: el administrador no puede desactivar el trigger de auditoría, borrar la bitácora, truncar `empleados` ni cambiar los niveles MAC; además, no es dueño de ningún objeto del esquema. Cada intento va dentro de `BEGIN ... ROLLBACK`. |
| 8c | La vista MAC es `security_barrier`: el filtro con división entre cero devuelve 40,000 filas sin error. |
| 9 | Una contraseña incorrecta es rechazada (autenticación `scram-sha-256`). |
| 10 | Están registradas las 4 etapas × 3 consultas de la afinación, y el costo de Q1 bajó respecto a la etapa sin índices. |
| 11 | `work_mem` quedó en 32 MB y `pg_stat_statements` está precargada. |
| 12 | La partición histórica `p_historico` se movió al tablespace `ts_rrhh_hist`. |
| 13 | Los 5 tablespaces tienen tamaño asignado y ninguno está en `ALERTA` (80 % de uso). |
| 14 | El contenedor de mantenimiento programado `bd-lab-final-mant` está corriendo. |

`validar.sh` no cambia los datos: solo consulta, y los intentos de escritura se rechazan o se deshacen
con `ROLLBACK`. Por eso se puede correr antes de la demo sin alterar la bitácora.
