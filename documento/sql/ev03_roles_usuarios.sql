-- 2. Roles personalizados (RBAC): privilegios agrupados, sin inicio de sesion.
--    rol_propietario es el dueno de los objetos y nadie inicia sesion con el ni es
--    miembro suyo (separacion de funciones): asi el administrador opera los datos,
--    pero no puede borrar la bitacora, desactivar triggers ni cambiar politicas.
CREATE ROLE rol_propietario NOLOGIN;
CREATE ROLE rol_admin    NOLOGIN;
CREATE ROLE rol_analista NOLOGIN;
CREATE ROLE rol_auditor  NOLOGIN;

-- 3. Usuarios del equipo (ficticios) y asignacion de rol
CREATE USER usr_admin          LOGIN PASSWORD 'AdminSecure2026#';
CREATE USER usr_analista_karla LOGIN PASSWORD 'KarlaAnalyst2026#';
CREATE USER usr_auditor_victor LOGIN PASSWORD 'VictorAudit2026#';
GRANT rol_admin    TO usr_admin;
GRANT rol_analista TO usr_analista_karla;
GRANT rol_auditor  TO usr_auditor_victor;
