#!/bin/sh
# Programador del mantenimiento automatico (servicio "mantenimiento" de docker-compose).
# Cada MANT_INTERVALO_SEG segundos ejecuta mantenimiento_programado.sql, que llama a
# rrhh.prc_mantenimiento(MANT_PREFIJO): REINDEX de los indices de las particiones y ANALYZE.
#
# Uso:
#   (automatico)  docker compose up -d            -> corre al arrancar y luego cada intervalo
#   (manual)      docker exec bd-lab-final-mant sh /mant/mantenimiento.sh --una-vez
#
# Conexion: PGHOST, PGUSER, PGPASSWORD y PGDATABASE vienen del docker-compose.

INTERVALO="${MANT_INTERVALO_SEG:-86400}"
PREFIJO="${MANT_PREFIJO:-p_}"
SQL=/mant/mantenimiento_programado.sql

corrida() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mantenimiento con prefijo '$PREFIJO'"
    # El procedimiento lo crea sql/09_almacenamiento.sql; antes de eso no hay nada que mantener
    if [ "$(psql -X -tA -c "SELECT to_regprocedure('rrhh.prc_mantenimiento(text)') IS NOT NULL;")" != "t" ]; then
        echo "  rrhh.prc_mantenimiento aun no existe (faltan los scripts 01-09); se omite."
        return 0
    fi
    if psql -X -v ON_ERROR_STOP=1 -v prefijo="$PREFIJO" -f "$SQL"; then
        echo "  Mantenimiento terminado: OK"
    else
        echo "  Mantenimiento con ERROR"
        psql -X -q -c "UPDATE rrhh.log_mantenimiento SET fin = clock_timestamp(), estado = 'ERROR' WHERE estado = 'EN CURSO';" || true
        return 1
    fi
}

if [ "$1" = "--una-vez" ]; then
    corrida
    exit $?
fi

echo "Mantenimiento automatico activo: cada $INTERVALO s"
while true; do
    corrida || true
    sleep "$INTERVALO"
done
