#!/bin/bash
# Se ejecuta una sola vez, al inicializar el volumen de datos (docker-entrypoint-initdb.d).
# La imagen oficial deja las conexiones TCP de loopback en "trust"; se exige contrasena
# (scram-sha-256) para que las pruebas de seguridad (conexion con -h localhost como
# usr_admin, usr_analista_karla y usr_auditor_victor) validen realmente la autenticacion.
# El socket Unix permanece en "trust" (analogo a "/ as sysdba").
set -e
sed -i -E 's#^(host\s+all\s+all\s+(127\.0\.0\.1/32|::1/128)\s+)trust#\1scram-sha-256#' "$PGDATA/pg_hba.conf"
