"""Ejecuta TODO el Proyecto Final contra el contenedor bd-lab-final y renderiza la salida
REAL de cada paso como imagen estilo terminal en ../documento/img.
Tambien guarda en ../documento/sql el codigo SQL mostrado en cada evidencia, para que
main.tex lo incluya con \\lstinputlisting.

Uso (Docker corriendo; BORRA los volumenes del proyecto con `docker compose down -v` al empezar):
    python generar_evidencias.py
Requiere: pip install pillow
"""
import os
import re
import subprocess
import sys
import time

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.normpath(os.path.join(HERE, "..", "documento"))
OUT = os.path.join(DOC, "img")
SQLOUT = os.path.join(DOC, "sql")
C = "bd-lab-final"
DB = "rrhh"
PS = "PS D:\\PROYECTOS LATEX y otros\\BDA\\Dockerpfinal> "

PASSWORDS = {
    "postgres": None,                      # socket Unix (trust), como "/ as sysdba"
    "usr_admin": "AdminSecure2026#",
    "usr_analista_karla": "KarlaAnalyst2026#",
    "usr_auditor_victor": "VictorAudit2026#",
}
ADMIN, KARLA, VICTOR = "usr_admin", "usr_analista_karla", "usr_auditor_victor"

WHITE, GREY, YELLOW, RED = "#e6e6e6", "#cccccc", "#e5e510", "#f48771"
MAXCOLS = 190

lines = []      # cada linea: lista de (texto, color)
marks = []      # (nombre, indice_inicio)
codes = {}      # nombre -> codigo SQL mostrado en el documento
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
TAG = re.compile(r"\$[A-Za-z_]*\$")


def run(args, cwd=None, stdin=None):
    p = subprocess.run(args, cwd=cwd, input=stdin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    txt = p.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    txt = ANSI.sub("", txt)
    return re.sub(r"(?m)^(psql:)?<stdin>:\d+: ", "", txt)


def emit_out(txt):
    rows = txt.split("\n")
    while rows and rows[-1] == "":
        rows.pop()
    for r in rows:
        bad = r.startswith(("ERROR", "FATAL", "psql: error"))
        lines.append([(r, RED if bad else GREY)])


def mark(name):
    marks.append((name, len(lines)))
    codes[name] = ""


def dedup(txt):
    """docker compose imprime el progreso sin TTY con lineas repetidas: se dejan unicas."""
    seen, out = set(), []
    for r in txt.split("\n"):
        if r not in seen:
            seen.add(r)
            out.append(r)
    return "\n".join(out)


def ps(display, args, cwd=HERE):
    lines.append([(PS, WHITE), (display, YELLOW)])
    txt = run(args, cwd=cwd)
    if args[:2] == ["docker", "compose"]:
        txt = dedup(txt)
    emit_out(txt)


# ---------------------------------------------------------------- psql
def base(user):
    a = ["docker", "exec", "-i"]
    if PASSWORDS[user]:
        a += ["-e", f"PGPASSWORD={PASSWORDS[user]}"]
    a += [C, "psql", "-X", "-U", user, "-d", DB]
    if PASSWORDS[user]:
        a += ["-h", "localhost"]
    return a


def psql_start(user):
    host = "-h localhost " if PASSWORDS[user] else ""
    lines.append([(PS, WHITE), (f"docker exec -it {C} psql {host}-U {user} -d {DB}", YELLOW)])
    ver = run(["docker", "exec", C, "psql", "-U", "postgres", "-d", DB, "-tA", "-c", "SHOW server_version;"]).strip()
    lines.append([(f"psql ({ver})", GREY)])
    lines.append([('Type "help" for help.', GREY)])
    lines.append([("", GREY)])


def prompt(user, kind):
    sym = "#" if user == "postgres" else ">"
    return {"main": f"{DB}={sym} ", "cont": f"{DB}-{sym} ", "dollar": f"{DB}${sym} "}[kind]


def split_statements(text):
    """Divide un script en sentencias (respeta $$...$$, comentarios y meta-comandos)."""
    stmts, cur, pend, tag = [], [], [], None
    for raw in text.split("\n"):
        ln = raw.rstrip()
        s = ln.strip()
        if not cur and tag is None:
            if s == "":
                continue
            if s.startswith("--"):
                pend.append(ln)
                continue
            if s.startswith("\\"):
                stmts.append((pend, [ln]))
                pend = []
                continue
        cur.append(ln)
        for t in TAG.findall(ln):
            tag = t if tag is None else (None if tag == t else tag)
        code = re.sub(r"\s--.*$", "", ln).rstrip()
        if tag is None and code.endswith(";"):
            stmts.append((pend, cur))
            cur, pend = [], []
    if cur:
        stmts.append((pend, cur))
    return stmts


def exec_block(user, text):
    stmts = split_statements(text)
    script = ""
    for i, (_, body) in enumerate(stmts):
        script += f"\\echo @@MARK {i}\n" + "\n".join(body) + "\n"
    out = run(base(user), stdin=script.encode("utf-8"))
    parts = re.split(r"(?m)^@@MARK (\d+)\n?", out)
    results = {int(parts[k]): parts[k + 1] for k in range(1, len(parts) - 1, 2)}
    for i, (comments, body) in enumerate(stmts):
        for c in comments:
            lines.append([(prompt(user, "main"), WHITE), (c, WHITE)])
        in_tag = None
        for j, ln in enumerate(body):
            kind = "main" if j == 0 else ("dollar" if in_tag else "cont")
            lines.append([(prompt(user, kind), WHITE), (ln, WHITE)])
            for t in TAG.findall(ln):
                in_tag = t if in_tag is None else (None if in_tag == t else in_tag)
        emit_out(results.get(i, ""))


def run_file(fname, user, names):
    """Ejecuta sql/<fname> bloque por bloque (separados por '--;;'). Un nombre None
    anexa el bloque a la evidencia anterior."""
    text = open(os.path.join(HERE, "sql", fname), encoding="utf-8").read()
    blocks = re.split(r"(?m)^--;;[ \t]*\n?", text)
    assert len(blocks) == len(names), f"{fname}: {len(blocks)} bloques y {len(names)} nombres"
    last = None
    for k, (blk, nm) in enumerate(zip(blocks, names)):
        if nm:
            mark(nm)
            last = nm
            if k == 0:
                psql_start(user)
        codes[last] += blk.strip("\n") + "\n\n"
        exec_block(user, blk)


def session(user, name, statements):
    """Sesion interactiva de un usuario: ejecuta cada sentencia y muestra su resultado."""
    host = "-h localhost " if PASSWORDS[user] else ""
    lines.append([(PS, WHITE), (f"docker exec -it {C} psql {host}-U {user} -d {DB}", YELLOW)])
    for stmt in statements:
        stmt = stmt.strip("\n")
        for j, ln in enumerate(stmt.split("\n")):
            lines.append([(prompt(user, "main" if j == 0 else "cont"), WHITE), (ln, WHITE)])
        emit_out(run(base(user), stdin=(stmt + "\n").encode("utf-8")))
        codes[name] += f"-- {user}\n{stmt}\n\n"
    lines.append([(prompt(user, "main"), WHITE), ("\\q", WHITE)])


def quit_psql(user):
    lines.append([(prompt(user, "main"), WHITE), ("\\q", WHITE)])


# ---------------------------------------------------------------- render
def render(name, seg):
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 16)
    cw = font.getlength("M")
    lh, pad = 22, 16
    rows = []
    for ln in seg:
        rem, out = MAXCOLS, []
        for txt, col in ln:
            txt = txt[:rem]
            out.append((txt, col))
            rem -= len(txt)
        rows.append(out)
    longest = max((sum(len(t) for t, _ in r) for r in rows), default=0)
    width = int(max(900, pad * 2 + cw * longest + 8))
    h = pad * 2 + lh * max(len(rows), 1)
    img = Image.new("RGB", (width, h), "#1e1e1e")
    d = ImageDraw.Draw(img)
    y = pad
    for ln in rows:
        x = pad
        for txt, col in ln:
            d.text((x, y), txt, font=font, fill=col)
            x += cw * len(txt)
        y += lh
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    print("OK", name, f"{len(seg)} lineas")


def esperar_healthy():
    for _ in range(60):
        if run(["docker", "inspect", "-f", "{{.State.Health.Status}}", C]).strip() == "healthy":
            return
        time.sleep(2)
    raise SystemExit("El contenedor no llego a healthy")


# ---------------------------------------------------------------- flujo
def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("ev") and f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    run(["docker", "compose", "down", "-v"], cwd=HERE)        # estado limpio (no se muestra)

    # 1. Entorno
    mark("ev01_entorno")
    ps("docker compose up -d", ["docker", "compose", "up", "-d"])
    esperar_healthy()
    ps("docker ps", ["docker", "ps"])
    ps(f"docker exec {C} ls -l /var/lib/postgresql/tablespaces",
       ["docker", "exec", C, "ls", "-l", "/var/lib/postgresql/tablespaces"])
    ps(f"docker exec {C} pg_isready -U postgres -d {DB}", ["docker", "exec", C, "pg_isready", "-U", "postgres", "-d", DB])

    # 2. Tablespaces, roles y usuarios
    run_file("01_instancia_roles.sql", "postgres", ["ev02_tablespaces", "ev03_roles_usuarios", "ev04_esquema_acceso"])
    quit_psql("postgres")

    # 3. Esquema (usr_admin es el propietario del esquema rrhh)
    run_file("02_esquema.sql", ADMIN,
             ["ev05_catalogos", "ev06_empleados_particiones", "ev07_historial_ubicacion", None, "ev08_mac_vista"])
    quit_psql(ADMIN)

    # 4-6. Auditoria, seguridad y carga masiva
    run_file("03_auditoria.sql", "postgres", ["ev09_trigger_auditoria", "ev10_bitacora_inmutable"])
    run_file("04_seguridad.sql", "postgres", ["ev11_rbac_dac", "ev12_mac_rls"])
    run_file("05_carga_masiva.sql", "postgres", ["ev13_carga_masiva", None])
    quit_psql("postgres")

    # 7. Pruebas de acceso por rol
    mark("ev14_prueba_analista")
    lines.append([(PS, WHITE), (f"docker exec -it -e PGPASSWORD=ClaveIncorrecta {C} psql -h localhost -U {KARLA} -d {DB}", YELLOW)])
    emit_out(run(["docker", "exec", "-i", "-e", "PGPASSWORD=ClaveIncorrecta", C, "psql", "-X", "-h", "localhost",
                  "-U", KARLA, "-d", DB, "-c", "SELECT 1;"]))
    session(KARLA, "ev14_prueba_analista", [
        "SELECT current_user, session_user, rrhh.nivel_usuario() AS nivel_mac;",
        "SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM v_resumen_empleados;",
        "SELECT emp_id, nombre_completo, nombre_depto, nombre_rol, salario, clasificacion_nivel\n"
        "FROM v_resumen_empleados ORDER BY emp_id LIMIT 3;",
        "SELECT * FROM departamentos;",
        "-- Intento de fuga por error: con security_barrier el filtro MAC se aplica primero\n"
        "SELECT count(*) AS visibles FROM v_resumen_empleados\n"
        "WHERE 1 / (CASE WHEN clasificacion_nivel = 3 THEN 0 ELSE 1 END) = 1;",
        "SELECT * FROM empleados LIMIT 1;",
        "DELETE FROM empleados WHERE emp_id = 1;",
        "SELECT * FROM audit_log_empleados;",
        "CREATE TABLE intruso (id int);",
    ])

    mark("ev15_prueba_admin")
    session(ADMIN, "ev15_prueba_admin", [
        "SELECT current_user, rrhh.nivel_usuario() AS nivel_mac;",
        "UPDATE empleados SET salario = salario * 1.10 WHERE emp_id = 100;",
        "INSERT INTO empleados\n"
        "VALUES (60001, 'Prueba', 'Insercion', 'prueba@empresa-rrhh.com', 25000, '2026-03-20', 10, 3, 1);",
        "DELETE FROM empleados WHERE emp_id = 60001;",
        "CREATE TABLE prueba_admin (id int);\nDROP TABLE prueba_admin;",
        "UPDATE audit_log_empleados SET salario_nuevo = 1;",
        "-- Separacion de funciones: el admin no es dueno de los objetos\n"
        "ALTER TABLE empleados DISABLE TRIGGER trg_audit_empleados;",
        "DROP TABLE audit_log_empleados;",
        "TRUNCATE empleados CASCADE;",
        "UPDATE autorizaciones SET nivel = 3 WHERE usuario = 'usr_analista_karla';",
        "SELECT hist_id, emp_id, salario, vigente_desde, motivo FROM historial_salarios;",
    ])

    mark("ev16_prueba_auditor")
    session(VICTOR, "ev16_prueba_auditor", [
        "SELECT audit_id, accion, emp_id, usuario_bd, salario_anterior, salario_nuevo, ip_origen\n"
        "FROM audit_log_empleados ORDER BY audit_id;",
        "SELECT usuario_bd, accion, count(*) AS eventos FROM audit_log_empleados\n"
        "GROUP BY usuario_bd, accion ORDER BY 1, 2;",
        "SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM v_resumen_empleados;",
        "UPDATE audit_log_empleados SET salario_nuevo = 1;",
        "DELETE FROM empleados WHERE emp_id = 1;",
    ])

    mark("ev17_dac_mac_inmutable")
    session(ADMIN, "ev17_dac_mac_inmutable", ["GRANT SELECT ON empleados TO usr_analista_karla;"])
    session(KARLA, "ev17_dac_mac_inmutable",
            ["SELECT count(*) AS visibles, max(clasificacion_nivel) AS nivel_max FROM empleados;"])
    session(ADMIN, "ev17_dac_mac_inmutable", ["REVOKE SELECT ON empleados FROM usr_analista_karla;"])
    session(KARLA, "ev17_dac_mac_inmutable", ["SELECT count(*) FROM empleados;"])
    session("postgres", "ev17_dac_mac_inmutable",
            ["TRUNCATE rrhh.audit_log_empleados;", "DELETE FROM rrhh.audit_log_empleados;"])

    # 8. Rendimiento
    run_file("06_rendimiento_base.sql", "postgres",
             ["ev18_consultas_tuning", "ev19_funciones_plan", "ev20_medicion_base",
              "ev21_plan_q1_antes", "ev22_plan_q2_antes", "ev23_plan_q3_antes"])
    run_file("07_advisor.sql", "postgres", ["ev24_advisor_vistas", "ev25_advisor_hallazgos"])
    run_file("08_indices.sql", "postgres",
             ["ev26_crear_indices", "ev27_recrear_indice", "ev28_plan_q1_despues", "ev29_plan_q2_despues",
              "ev30_plan_q3_despues", "ev31_comparativo"])

    # 9. Almacenamiento
    run_file("09_almacenamiento.sql", "postgres",
             ["ev32_uso_tablespaces", "ev33_particiones", "ev34_ajuste_dinamico", "ev35_mantenimiento", "ev36_truncado"])

    # 10. Parametros y verificacion del advisor
    run_file("10_parametros.sql", "postgres",
             ["ev37_parametros_actuales", "ev38_alter_system", "ev39_reevaluacion", "ev40_aplicar_recomendacion", "ev41_verificacion_advisor"])
    quit_psql("postgres")

    # 11. Cierre
    mark("ev42_cierre")
    ps(f"docker stop {C}", ["docker", "stop", C])
    ps(f"docker ps -a --filter name={C}", ["docker", "ps", "-a", "--filter", f"name={C}"])

    marks.append(("__fin__", len(lines)))
    for (name, a), (_, b) in zip(marks, marks[1:]):
        render(name, lines[a:b])

    os.makedirs(SQLOUT, exist_ok=True)
    for f in os.listdir(SQLOUT):
        os.remove(os.path.join(SQLOUT, f))
    for name, code in codes.items():
        if name in ("ev01_entorno", "ev42_cierre"):
            continue
        with open(os.path.join(SQLOUT, name + ".sql"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(code.strip("\n") + "\n")

    with open(os.path.join(HERE, "transcripcion.txt"), "w", encoding="utf-8") as f:
        for ln in lines:
            f.write("".join(t for t, _ in ln) + "\n")


if __name__ == "__main__":
    sys.exit(main())
