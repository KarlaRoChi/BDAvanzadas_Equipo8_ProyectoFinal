-- 4. Mantenimiento automatico: reconstruye los indices secundarios de las particiones cuyo
--    nombre inicia con p_prefijo y actualiza las estadisticas de todas las particiones.
--    El servicio "mantenimiento" de docker-compose lo ejecuta una vez al dia.
CREATE PROCEDURE rrhh.prc_mantenimiento(p_prefijo TEXT)
LANGUAGE plpgsql AS
$$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT c.relname FROM pg_class c
             WHERE c.relnamespace = 'rrhh'::regnamespace AND c.relkind = 'i'
               AND c.relname !~ '_pkey$' AND c.relname !~ '_key$'
               AND c.relname LIKE p_prefijo || '%'
    LOOP
        EXECUTE format('REINDEX INDEX rrhh.%I', r.relname);
        RAISE NOTICE 'Indice reconstruido: %', r.relname;
    END LOOP;
    FOR r IN SELECT c.relname FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
             WHERE i.inhparent = 'rrhh.empleados'::regclass
    LOOP
        EXECUTE format('ANALYZE rrhh.%I', r.relname);
        RAISE NOTICE 'Particion analizada: %', r.relname;
    END LOOP;
END;
$$;

CALL rrhh.prc_mantenimiento('p_2025');
