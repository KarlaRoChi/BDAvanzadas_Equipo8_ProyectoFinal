#!/bin/bash
# Validacion del estado final del Proyecto Final (despues de ejecutar sql/01 ... sql/10).
# Uso: bash validar.sh   (con el contenedor activo: docker compose up -d)
set -e

CONTAINER=bd-lab-final
DB=rrhh

psql_su() {   # superusuario por socket Unix
  docker exec -i $CONTAINER psql -X -U postgres -d $DB -tA -c "$1"
}
psql_as() {   # usuario, contrasena, sentencia (por TCP: exige contrasena)
  docker exec -i -e PGPASSWORD="$2" $CONTAINER psql -X -h localhost -U "$1" -d $DB -tA -c "$3"
}
denegado() {  # la sentencia debe fallar
  if psql_as "$1" "$2" "$3" >/dev/null 2>&1; then
    echo "ERROR: se esperaba rechazo para $1: $3"; exit 1
  fi
}

echo "1. Contenedor activo y base abierta..."
docker ps --filter "name=$CONTAINER" --filter "status=running" | grep $CONTAINER
[ "$(psql_su "SELECT CASE WHEN pg_is_in_recovery() THEN 'RECOVERY' ELSE 'OPEN' END;")" = "OPEN" ]

echo "2. Cinco tablespaces del proyecto..."
[ "$(psql_su "SELECT count(*) FROM pg_tablespace WHERE spcname LIKE 'ts_rrhh_%';")" = "5" ]

echo "3. Tabla empleados particionada (>= 5 particiones) y >= 50,000 registros..."
[ "$(psql_su "SELECT count(*) >= 5 FROM pg_inherits WHERE inhparent='rrhh.empleados'::regclass;")" = "t" ]
[ "$(psql_su "SELECT count(*) >= 50000 FROM rrhh.empleados;")" = "t" ]

echo "4. Usuarios y roles (RBAC)..."
[ "$(psql_su "SELECT count(*) FROM pg_roles WHERE rolname IN ('rol_admin','rol_analista','rol_auditor','usr_admin','usr_analista_karla','usr_auditor_victor');")" = "6" ]

echo "5. Triggers de auditoria y de bitacora inmutable..."
[ "$(psql_su "SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_audit_empleados','trg_bitacora_inmutable','trg_bitacora_no_truncate') AND tgrelid IN ('rrhh.empleados'::regclass,'rrhh.audit_log_empleados'::regclass);")" = "3" ]

echo "6. Analista: ve solo hasta nivel MAC 2 y no puede borrar ni leer la bitacora..."
[ "$(psql_as usr_analista_karla 'KarlaAnalyst2026#' "SELECT max(clasificacion_nivel) FROM rrhh.v_resumen_empleados;")" = "2" ]
denegado usr_analista_karla 'KarlaAnalyst2026#' "DELETE FROM rrhh.empleados WHERE emp_id = 1;"
denegado usr_analista_karla 'KarlaAnalyst2026#' "SELECT * FROM rrhh.audit_log_empleados;"

echo "7. Auditor: ve nivel 3, lee la bitacora y no puede modificarla..."
[ "$(psql_as usr_auditor_victor 'VictorAudit2026#' "SELECT max(clasificacion_nivel) FROM rrhh.v_resumen_empleados;")" = "3" ]
psql_as usr_auditor_victor 'VictorAudit2026#' "SELECT count(*) FROM rrhh.audit_log_empleados;" >/dev/null
denegado usr_auditor_victor 'VictorAudit2026#' "UPDATE rrhh.audit_log_empleados SET salario_nuevo = 1;"

echo "8. Bitacora inmutable incluso para el superusuario..."
if psql_su "DELETE FROM rrhh.audit_log_empleados;" >/dev/null 2>&1; then
  echo "ERROR: la bitacora se pudo borrar"; exit 1
fi

echo "9. Autenticacion: contrasena incorrecta debe FALLAR..."
denegado usr_admin 'ClaveIncorrecta' "SELECT 1;"

echo "10. Etapas de afinacion registradas (4 etapas x 3 consultas)..."
[ "$(psql_su "SELECT count(*) FROM rrhh.tuning_resultados;")" = "12" ]
[ "$(psql_su "SELECT (SELECT costo FROM rrhh.tuning_resultados WHERE etapa='3_indice_recreado' AND consulta='Q1') < (SELECT costo FROM rrhh.tuning_resultados WHERE etapa='1_sin_indices' AND consulta='Q1');")" = "t" ]

echo "11. Parametros ajustados y pg_stat_statements precargada..."
[ "$(psql_su "SHOW work_mem;")" = "32MB" ]
psql_su "SHOW shared_preload_libraries;" | grep -q pg_stat_statements

echo "12. Datos historicos reubicados en ts_rrhh_hist..."
[ "$(psql_su "SELECT t.spcname FROM pg_class c JOIN pg_tablespace t ON t.oid=c.reltablespace WHERE c.oid='rrhh.p_historico'::regclass;")" = "ts_rrhh_hist" ]

echo "Validacion finalizada correctamente."
