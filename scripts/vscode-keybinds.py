#!/usr/bin/env python3
"""Atajos de VS Code para el glosario de la isla (Super+/, pestaña VS Code).

Imprime JSON [{section, keys: [str], desc}] (el mismo formato que BindsContent.qml saca de
lua/keybinds.lua) con:
  - "Mis atajos": ~/.config/Code/User/keybindings.json (los "-comando" salen como desactivados)
  - una sección por extensión instalada con atajos (título del comando, traducido con su
    package.nls.json), sin los que su "when" descarta con los ajustes actuales
  - "VS Code · …": una selección de los atajos por defecto de Linux (VS Code no los guarda en
    ningún archivo legible)
Las teclas que la extensión de Vim captura en el editor se marcan "(Vim en el editor)".
Se omite la extensión de Vim: sus 75 atajos son las teclas que captura, no comandos. En su lugar
salen "Vim · …": los mapeos propios (vim.*ModeKeyBindings* de settings.json) y una selección de los
comandos que entiende VSCodeVim (los extras como surround solo si están activados).
"""

import glob
import json
import os
import re
import sys

USER = os.path.expanduser(os.environ.get("VSCODE_USER_DIR", "~/.config/Code/User"))
EXTS = os.path.expanduser(os.environ.get("VSCODE_EXTENSIONS_DIR", "~/.vscode/extensions"))

# Atajos por defecto de VS Code en Linux (los más útiles)
DEFAULTS = [
    ("General", [
        ("ctrl+shift+p", "Paleta de comandos"),
        ("ctrl+p", "Abrir archivo por nombre (Quick Open)"),
        ("ctrl+,", "Ajustes"),
        ("ctrl+k ctrl+s", "Atajos de teclado"),
        ("ctrl+shift+n", "Nueva ventana"),
        ("ctrl+k ctrl+t", "Cambiar tema de color"),
        ("ctrl+=", "Acercar (zoom +)"),
        ("ctrl+-", "Alejar (zoom −)"),
        ("ctrl+k z", "Modo zen"),
    ]),
    ("Archivos y pestañas", [
        ("ctrl+n", "Archivo nuevo"),
        ("ctrl+o", "Abrir archivo"),
        ("ctrl+s", "Guardar"),
        ("ctrl+shift+s", "Guardar como"),
        ("ctrl+k s", "Guardar todo"),
        ("ctrl+w", "Cerrar pestaña"),
        ("ctrl+k ctrl+w", "Cerrar todas las pestañas"),
        ("ctrl+shift+t", "Reabrir la pestaña cerrada"),
        ("ctrl+tab", "Cambiar entre pestañas abiertas"),
        ("ctrl+pageup", "Pestaña anterior"),
        ("ctrl+pagedown", "Pestaña siguiente"),
        ("ctrl+\\", "Dividir el editor"),
        ("ctrl+1", "Enfocar el primer grupo de editores"),
        ("ctrl+2", "Enfocar el segundo grupo de editores"),
    ]),
    ("Edición", [
        ("ctrl+shift+k", "Borrar línea"),
        ("alt+up", "Mover línea arriba"),
        ("alt+down", "Mover línea abajo"),
        ("ctrl+shift+alt+up", "Duplicar línea arriba"),
        ("ctrl+shift+alt+down", "Duplicar línea abajo"),
        ("ctrl+enter", "Insertar línea debajo"),
        ("ctrl+shift+enter", "Insertar línea encima"),
        ("ctrl+/", "Comentar/descomentar línea"),
        ("ctrl+shift+a", "Comentario de bloque"),
        ("ctrl+shift+i", "Formatear documento"),
        ("ctrl+k ctrl+f", "Formatear selección"),
        ("ctrl+]", "Aumentar sangría"),
        ("ctrl+[", "Reducir sangría"),
        ("ctrl+shift+[", "Plegar bloque"),
        ("ctrl+shift+]", "Desplegar bloque"),
        ("ctrl+z", "Deshacer"),
        ("ctrl+shift+z", "Rehacer"),
    ]),
    ("Multicursor y selección", [
        ("shift+alt+up", "Cursor extra arriba"),
        ("shift+alt+down", "Cursor extra abajo"),
        ("alt+click", "Añadir cursor donde haces clic"),
        ("ctrl+d", "Seleccionar la siguiente coincidencia"),
        ("ctrl+shift+l", "Seleccionar todas las coincidencias"),
        ("ctrl+l", "Seleccionar línea"),
        ("shift+alt+right", "Ampliar selección"),
        ("shift+alt+left", "Reducir selección"),
    ]),
    ("Código", [
        ("ctrl+space", "Sugerencias"),
        ("ctrl+shift+space", "Ayuda de parámetros"),
        ("ctrl+.", "Arreglo rápido (Quick Fix)"),
        ("f2", "Renombrar símbolo"),
        ("f12", "Ir a la definición"),
        ("ctrl+shift+f10", "Ver la definición en línea (Peek)"),
        ("shift+f12", "Ver referencias"),
        ("ctrl+k ctrl+i", "Mostrar información (hover)"),
        ("ctrl+shift+o", "Ir a un símbolo del archivo"),
        ("ctrl+t", "Ir a un símbolo del proyecto"),
        ("ctrl+g", "Ir a la línea"),
        ("ctrl+alt+-", "Volver atrás"),
        ("ctrl+shift+-", "Ir adelante"),
        ("f8", "Siguiente error o aviso"),
        ("shift+f8", "Error o aviso anterior"),
    ]),
    ("Buscar", [
        ("ctrl+f", "Buscar en el archivo"),
        ("ctrl+h", "Reemplazar en el archivo"),
        ("ctrl+shift+f", "Buscar en el proyecto"),
        ("ctrl+shift+h", "Reemplazar en el proyecto"),
    ]),
    ("Paneles", [
        ("ctrl+b", "Mostrar/ocultar la barra lateral"),
        ("ctrl+shift+e", "Explorador"),
        ("ctrl+shift+g", "Control de código (Git)"),
        ("ctrl+shift+d", "Ejecutar y depurar"),
        ("ctrl+shift+x", "Extensiones"),
        ("ctrl+j", "Mostrar/ocultar el panel inferior"),
        ("ctrl+shift+m", "Problemas"),
        ("ctrl+shift+u", "Salida (Output)"),
        ("ctrl+shift+v", "Vista previa de Markdown"),
        ("ctrl+k v", "Vista previa de Markdown al lado"),
    ]),
    ("Terminal", [
        ("ctrl+`", "Mostrar/ocultar la terminal"),
        ("ctrl+shift+`", "Terminal nueva"),
        ("ctrl+shift+5", "Dividir la terminal"),
    ]),
    ("Depurar", [
        ("f5", "Iniciar/continuar la depuración"),
        ("ctrl+f5", "Ejecutar sin depurar"),
        ("shift+f5", "Detener la depuración"),
        ("f9", "Poner/quitar punto de interrupción"),
        ("f10", "Paso por encima"),
        ("f11", "Paso a paso (entrar)"),
        ("shift+f11", "Salir de la función"),
    ]),
]

# Comandos de Vim que entiende VSCodeVim: (teclas tal cual, descripción[, ajuste que lo activa])
VIM = [
    ("Modos", [
        ("i", "Insertar antes del cursor"),
        ("a", "Insertar después del cursor"),
        ("I", "Insertar al principio de la línea"),
        ("A", "Insertar al final de la línea"),
        ("o", "Línea nueva debajo"),
        ("O", "Línea nueva encima"),
        ("v", "Modo visual"),
        ("V", "Modo visual por líneas"),
        ("Ctrl+V", "Modo visual por bloques"),
        ("Esc", "Volver al modo normal"),
        (":", "Línea de comandos"),
    ]),
    ("Moverse", [
        ("h j k l", "Izquierda, abajo, arriba, derecha"),
        ("w", "Palabra siguiente"),
        ("b", "Palabra anterior"),
        ("e", "Final de la palabra"),
        ("0", "Principio de la línea"),
        ("^", "Primer carácter de la línea"),
        ("$", "Final de la línea"),
        ("gg", "Principio del archivo"),
        ("G", "Final del archivo"),
        ("{n}G", "Ir a la línea n"),
        ("f{c}", "Saltar al carácter c en la línea"),
        ("t{c}", "Saltar hasta antes del carácter c"),
        ("%", "Ir al paréntesis o llave pareja"),
        ("Ctrl+D", "Media pantalla abajo"),
        ("Ctrl+U", "Media pantalla arriba"),
        ("zz", "Centrar la línea en pantalla"),
        ("Ctrl+O", "Volver a la posición anterior"),
        ("Ctrl+I", "Ir a la posición siguiente"),
    ]),
    ("Editar", [
        ("x", "Borrar carácter"),
        ("dd", "Borrar (cortar) línea"),
        ("D", "Borrar hasta el final de la línea"),
        ("dw", "Borrar palabra"),
        ("cc", "Cambiar línea"),
        ("cw", "Cambiar palabra"),
        ("r{c}", "Reemplazar el carácter por c"),
        ("yy", "Copiar línea"),
        ("yw", "Copiar palabra"),
        ("p", "Pegar después"),
        ("P", "Pegar antes"),
        ("\"+y", "Copiar al portapapeles del sistema"),
        ("\"+p", "Pegar del portapapeles del sistema"),
        ("u", "Deshacer"),
        ("Ctrl+R", "Rehacer"),
        (".", "Repetir el último cambio"),
        (">>", "Aumentar sangría"),
        ("<<", "Reducir sangría"),
        ("J", "Unir con la línea de abajo"),
        ("~", "Cambiar mayúsculas/minúsculas"),
    ]),
    ("Objetos de texto", [
        ("ciw", "Cambiar la palabra entera"),
        ("diw", "Borrar la palabra entera"),
        ("ci\"", "Cambiar dentro de comillas"),
        ("ci(", "Cambiar dentro de paréntesis"),
        ("ci{", "Cambiar dentro de llaves"),
        ("dit", "Borrar dentro de la etiqueta HTML"),
        ("da(", "Borrar paréntesis y su contenido"),
        ("vip", "Seleccionar el párrafo"),
    ]),
    ("Buscar y reemplazar", [
        ("/texto", "Buscar hacia delante"),
        ("?texto", "Buscar hacia atrás"),
        ("n", "Siguiente resultado"),
        ("N", "Resultado anterior"),
        ("*", "Buscar la palabra bajo el cursor"),
        (":%s/a/b/g", "Reemplazar a por b en todo el archivo"),
    ]),
    ("Archivos y ventanas", [
        (":w", "Guardar"),
        (":q", "Cerrar"),
        (":wq", "Guardar y cerrar"),
        (":e archivo", "Abrir archivo"),
        ("gt", "Pestaña siguiente"),
        ("gT", "Pestaña anterior"),
        (":vsp", "Dividir en vertical"),
        ("Ctrl+W h/l", "Cambiar de panel dividido"),
    ]),
    ("Extras de VSCodeVim", [
        ("gd", "Ir a la definición"),
        ("gh", "Mostrar información (hover)"),
        ("gb", "Cursor extra en la siguiente coincidencia"),
        ("gcc", "Comentar/descomentar línea"),
        ("gc{movimiento}", "Comentar el movimiento (gcip, gc2j…)"),
        ("gC", "Comentario de bloque"),
        ("ysiw)", "Rodear la palabra con ( )", "vim.surround"),
        ("cs\"'", "Cambiar las comillas \" por '", "vim.surround"),
        ("ds(", "Quitar los paréntesis de alrededor", "vim.surround"),
        ("S)", "Rodear la selección (visual) con ( )", "vim.surround"),
    ]),
]

KEY_NAMES = {
    "ctrl": "Ctrl", "shift": "Shift", "alt": "Alt", "meta": "Super", "cmd": "Super", "win": "Super",
    "escape": "Esc", "enter": "Enter", "space": "Space", "tab": "Tab", "backspace": "⌫",
    "delete": "Supr", "insert": "Insert", "home": "Inicio", "end": "Fin",
    "pageup": "PgUp", "pagedown": "PgDn", "up": "↑", "down": "↓", "left": "←", "right": "→",
    "click": "Click", "oem_3": "`",
}


def lenient_json(text):
    """JSON con comentarios y comas finales, como los que escribe VS Code."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
        else:
            out.append(c)
            i += 1
    return json.loads(re.sub(r",(\s*[\]}])", r"\1", "".join(out)))


def load(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return lenient_json(f.read())
    except (OSError, ValueError):
        return default


def key_caps(key):
    """'ctrl+k ctrl+s' -> ['Ctrl', 'K', '·', 'Ctrl', 'S']"""
    caps = []
    for n, chord in enumerate(key.lower().split()):
        if n:
            caps.append("·")
        for part in re.split(r"\+(?!$)", chord):
            caps.append(KEY_NAMES.get(part, part.upper() if len(part) <= 3 else part.capitalize()))
    return caps


def norm_key(key):
    return " ".join("+".join(sorted(c.split("+")[:-1]) + [c.split("+")[-1]]) for c in key.lower().split())


settings = load(os.path.join(USER, "settings.json"), {})

extensions = []  # (pkg, dir) de la versión más nueva de cada extensión
seen = set()
for d in sorted(glob.glob(os.path.join(EXTS, "*", "")), reverse=True):
    pkg = load(os.path.join(d, "package.json"), None)
    if not isinstance(pkg, dict) or "publisher" not in pkg:
        continue
    ext_id = f"{pkg['publisher']}.{pkg.get('name', '')}".lower()
    if ext_id in seen:
        continue
    seen.add(ext_id)
    extensions.append((pkg, d))

# Defaults de los ajustes de las extensiones (para evaluar "config.x" en los "when")
config_defaults = {}
for pkg, _ in extensions:
    confs = pkg.get("contributes", {}).get("configuration", [])
    for conf in confs if isinstance(confs, list) else [confs]:
        for name, prop in (conf.get("properties") or {}).items():
            if "default" in prop:
                config_defaults[name] = prop["default"]


def setting(name):
    return settings.get(name, config_defaults.get(name))


def nls(pkg_dir, text):
    if not isinstance(text, str) or not text.startswith("%"):
        return text
    table = load(os.path.join(pkg_dir, "package.nls.json"), {})
    v = table.get(text.strip("%"), text)
    return v.get("message", text) if isinstance(v, dict) else v


titles = {}  # comando -> "Categoría: título"
for pkg, d in extensions:
    for c in pkg.get("contributes", {}).get("commands", []) or []:
        if not isinstance(c, dict) or "command" not in c:
            continue
        title = nls(d, c.get("title", ""))
        cat = nls(d, c.get("category", ""))
        titles[c["command"]] = f"{cat}: {title}" if cat and not title.startswith(cat) else title


def when_ok(when):
    """Descarta los atajos que un "config.x" del when anula con los ajustes actuales."""
    if not when:
        return True
    for clause in when.split("||"):
        ok = True
        for neg, name in re.findall(r"(!?)config\.([\w.]+)(?!\s*[=!]=)", clause):
            if bool(setting(name)) == bool(neg):
                ok = False
        if ok:
            return True
    return False


CONTEXTS = [
    (r"editorLangId == '?(\w+)'?", lambda m: f"en {m.group(1).capitalize()}"),
    (r"terminalFocus", lambda m: "en la terminal"),
    (r"focusedView == '?javaProjectExplorer'?", lambda m: "en Java Projects"),
    (r"explorerViewletFocus", lambda m: "en el explorador"),
    (r"inQuickOpen", lambda m: "en Quick Open"),
    (r"claudeVSCodePanel", lambda m: "en el panel de Claude"),
]


def context(when):
    for pat, fmt in CONTEXTS:
        m = re.search(pat, when or "")
        if m and not re.search(r"!\s*" + pat, when):
            return fmt(m)
    return ""


def humanize(cmd):
    """workbench.action.terminal.sendSequence -> Terminal: send sequence"""
    parts = [p for p in cmd.split(".") if p not in ("workbench", "action", "editor", "vscode")]
    if not parts:
        return cmd
    words = re.sub(r"([a-z])([A-Z])", r"\1 \2", parts[-1]).lower()
    return (parts[0].capitalize() + ": " if len(parts) > 1 else "") + words


def describe(b):
    cmd = b.get("command", "")
    if cmd == "workbench.action.terminal.sendSequence":
        text = (b.get("args") or {}).get("text", "")
        seq = text.replace("\x1b", "Esc ").replace("\r", "Enter").replace("\n", "Enter").strip()
        desc = f"Enviar {seq} a la terminal"
        if text == "\x1b\r":
            desc += " (salto de línea en Claude Code)"
        return desc
    return titles.get(cmd) or humanize(cmd)


vim_keys = set()
vim_pkg = next((p for p, _ in extensions if p.get("name") == "vim" and p.get("publisher", "").lower() == "vscodevim"), None)
if vim_pkg:
    handle = {**(config_defaults.get("vim.handleKeys") or {}), **(settings.get("vim.handleKeys") or {})}
    use_ctrl = setting("vim.useCtrlKeys")
    for b in vim_pkg.get("contributes", {}).get("keybindings", []):
        key, when = b.get("key", ""), b.get("when", "")
        if "editorTextFocus" not in when or "vim.mode != 'Insert'" in when and "use<" not in when:
            continue
        m = re.search(r"vim\.use<([^>]+)>", when)
        if m:
            if not use_ctrl or handle.get(f"<{m.group(1)}>") is False:
                continue
        elif not key.startswith("ctrl+"):
            continue
        vim_keys.add(norm_key(key))

out = []


def add(section, key, desc, check_vim=True):
    if check_vim and norm_key(key) in vim_keys:
        desc += " (Vim en el editor)"
    out.append({"section": section, "keys": key_caps(key), "desc": desc[:1].upper() + desc[1:]})


for b in load(os.path.join(USER, "keybindings.json"), []):
    if not isinstance(b, dict) or not b.get("key") or not b.get("command"):
        continue
    if b["command"].startswith("-"):
        add("Mis atajos", b["key"], "Desactivado: " + describe({**b, "command": b["command"][1:]}), False)
        continue
    desc = describe(b)
    ctx = context(b.get("when", ""))
    if ctx and ctx.split()[-1] not in desc:  # "Enviar … a la terminal" ya dice dónde
        desc += f" ({ctx})"
    add("Mis atajos", b["key"], desc, False)

def vim_caps(keys):
    """"Ctrl+W h/l" -> ['Ctrl', 'W', 'h/l'];  "gg" -> ['gg'] (sin pasar a mayúsculas: en Vim importa)"""
    caps = []
    for part in keys.split(" "):
        if part.startswith("Ctrl+"):
            caps += ["Ctrl", part[5:]]
        else:
            caps.append(part)
    return caps


def vim_sections():
    rows = []
    # Mapeos propios: vim.normalModeKeyBindings(NonRecursive), insertMode…, visualMode…
    for name, value in settings.items():
        m = re.match(r"vim\.(normal|insert|visual|operatorPending)ModeKeyBindings(NonRecursive)?$", name)
        if not m or not isinstance(value, list):
            continue
        mode = {"normal": "normal", "insert": "insertar", "visual": "visual", "operatorPending": "operador"}[m.group(1)]
        for b in value:
            before = "".join(b.get("before", []))
            if b.get("after"):
                desc = "→ " + "".join(b["after"])
            elif b.get("commands"):
                desc = ", ".join(titles.get(c.get("command", c) if isinstance(c, dict) else c) or humanize(c.get("command", c) if isinstance(c, dict) else c) for c in b["commands"])
            else:
                continue
            rows.append({"section": "Vim · Mis mapeos", "keys": [before], "desc": f"{desc[:1].upper()}{desc[1:]} (modo {mode})"})
    for section, binds in VIM:
        for b in binds:
            keys, desc = b[0], b[1]
            if len(b) > 2 and not setting(b[2]):
                continue
            rows.append({"section": "Vim · " + section, "keys": vim_caps(keys), "desc": desc})
    return rows


for pkg, d in sorted(extensions, key=lambda e: nls(e[1], e[0].get("displayName", e[0].get("name", ""))).lower()):
    if pkg is vim_pkg:
        continue
    kbs = pkg.get("contributes", {}).get("keybindings", [])
    kbs = kbs if isinstance(kbs, list) else [kbs]
    name = nls(d, pkg.get("displayName") or pkg.get("name"))
    seen_rows = set()
    for b in kbs:
        key = b.get("linux") or b.get("key")
        cmd = b.get("command", "")
        if not key or cmd not in titles or not when_ok(b.get("when")):
            continue
        desc = titles[cmd]
        # Sin el prefijo "Categoría:" si coincide con el nombre de la extensión
        if ": " in desc and desc.split(": ", 1)[0].lower() in name.lower():
            desc = desc.split(": ", 1)[1]
        ctx = context(b.get("when", ""))
        if ctx:
            desc += f" ({ctx})"
        if (norm_key(key), desc) in seen_rows:
            continue
        seen_rows.add((norm_key(key), desc))
        # Vim solo le quita la tecla si el atajo es del editor de texto
        add(name, key, desc, check_vim=ctx == "" and "editorTextFocus" in (b.get("when") or ""))

if vim_pkg:
    out += vim_sections()

for section, binds in DEFAULTS:
    for key, desc in binds:
        add("VS Code · " + section, key, desc)

json.dump(out, sys.stdout, ensure_ascii=False)
