-- 3. Bitacora inmutable: ni siquiera el administrador puede modificarla o vaciarla
CREATE FUNCTION rrhh.fn_bitacora_inmutable() RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
    RAISE EXCEPTION 'La bitacora de auditoria es inmutable (% bloqueado)', TG_OP;
END;
$$;

CREATE TRIGGER trg_bitacora_inmutable
BEFORE UPDATE OR DELETE ON rrhh.audit_log_empleados
FOR EACH ROW EXECUTE FUNCTION rrhh.fn_bitacora_inmutable();

CREATE TRIGGER trg_bitacora_no_truncate
BEFORE TRUNCATE ON rrhh.audit_log_empleados
FOR EACH STATEMENT EXECUTE FUNCTION rrhh.fn_bitacora_inmutable();

SELECT tgname AS trigger, tgrelid::regclass AS tabla,
       CASE WHEN tgenabled = 'O' THEN 'ACTIVO' ELSE tgenabled::text END AS estado
FROM pg_trigger
WHERE NOT tgisinternal AND tgrelid::regclass::text LIKE 'rrhh.%'
ORDER BY tgrelid::regclass::text, tgname;
