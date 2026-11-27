# Proyecto final – Diseño, seguridad y optimización de un sistema de gestión de empleados

**Bases de Datos Avanzadas** · Facultad de Ingeniería, UNAM · Grupo 3 · Equipo 08
**Profesor:** Mtro. Gerardo Gabriel Carrasco Zúñiga

| Integrante | No. de cuenta | GitHub |
|---|---|---|
| Rojas Chimal Karla Beatriz | 320048025 | [@KarlaRoChi](https://github.com/KarlaRoChi) |
| Calderón Gutiérrez Victor Emiliano | 423097331 | [@Delta2904](https://github.com/Delta2904) |

Sistema de gestión de empleados en **PostgreSQL 16 sobre Docker** (base y esquema `rrhh`), adaptado del enunciado
original en Oracle. Todas las cifras del reporte y de la presentación provienen de la ejecución real de los scripts.

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| [`documento/`](documento) | Reporte en LaTeX (`main.tex`), 43 evidencias en `img/`, código SQL de cada evidencia en `sql/` y el PDF entregable |
| [`presentacion/`](presentacion) | Presentación en PowerPoint (24 diapositivas con notas del orador) |
| [`Dockerpfinal/`](Dockerpfinal) | Contenedor: `docker-compose.yaml`, los 10 scripts SQL del proyecto, el mantenimiento programado (`mantenimiento/`), generador de evidencias, `validar.sh` y la transcripción completa de la ejecución |

### Entregables (nomenclatura `Proyectoxx_equipoxx_<nombre>`)

- `documento/Proyecto01_equipo08_CalderonGutierrezVictorEmiliano_RojasChimalKarlaBeatriz.pdf`
- `presentacion/Proyecto01_equipo08_CalderonGutierrezVictorEmiliano_RojasChimalKarlaBeatriz.pptx`

## Resumen

- **Diseño:** tabla `empleados` particionada por rango (5 particiones) sobre 5 tablespaces (datos, índices, particiones, auditoría e histórico), cada uno con tamaño asignado (dimensionado para 300,000 empleados) y alerta al 80 % de uso.
- **Seguridad multinivel:** tres roles y tres usuarios (`usr_admin`, `usr_analista_karla`, `usr_auditor_victor`); RBAC, DAC con `GRANT`/`REVOKE` y MAC con niveles de autorización, *Row Level Security* y una vista `security_barrier`. Ningún objeto pertenece al administrador (los de negocio son de `rol_propietario`, sin inicio de sesión; los de auditoría y afinación, de `postgres`), así que no puede desactivar la auditoría, borrar la bitácora ni cambiar los niveles MAC.
- **Auditoría:** vista y trigger que registran usuario, IP y salarios anterior/nuevo; bitácora inmutable por SQL mientras sus triggers estén activos (un superusuario podría desactivarlos; ver el reporte).
- **Carga masiva:** 60,000 registros con un bloque PL/pgSQL por lotes.
- **Rendimiento:** tres consultas complejas con `EXPLAIN`, advisor propio (vistas sobre `pg_stat_*`), recreación de índices y comparativo antes/después (reducción de costo de 95.4 %, 39.6 % y 57.7 %).
- **Almacenamiento y parámetros:** monitoreo de tablespaces, nueva partición, reubicación del histórico, procedimiento de mantenimiento programado (servicio `mantenimiento`, una vez al día), truncado y ajuste de `work_mem`, `maintenance_work_mem` y `random_page_cost`.

## Cómo reproducirlo

```bash
cd Dockerpfinal
docker compose up -d
python generar_evidencias.py   # ejecuta los 10 scripts y regenera documento/img y documento/sql
bash validar.sh                # 14 verificaciones del estado final
```

Para compilar el reporte:

```bash
cd documento
pdflatex main.tex && pdflatex main.tex
```

Detalles del contenedor (usuarios, volúmenes, puertos) en [`Dockerpfinal/README.md`](Dockerpfinal/README.md).
