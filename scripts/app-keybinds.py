#!/usr/bin/env python3
"""Atajos de otras apps para el glosario de la isla (Super+/): app-keybinds.py <app> -> JSON
[{section, keys: [str], desc}] (el formato de BindsContent.qml).

Leídos de la config real (en vivo):
  herdr    ~/.config/herdr/config.toml [keys] (la descripción sale de tus comentarios)
  foot     los defaults documentados en /etc/xdg/foot/foot.ini + tus cambios en ~/.config/foot/foot.ini
  zellij   ~/.config/zellij/config.kdl (o `zellij setup --dump-config` si no define keybinds)
  ghostty  `ghostty +list-keybinds` (los efectivos: defaults + tu config)
Escritos a mano (no guardan sus atajos por defecto en ningún archivo legible):
  yazi     los por defecto + los de ~/.config/yazi/keymap.toml si existe
  firefox  los más útiles + Surfingkeys si está instalada (sus atajos por defecto, sacados del .xpi
           instalado: cada mapkey("tecla", "#<grupo>Descripción") de content.js)
  obsidian los por defecto + los de <bóveda>/.obsidian/hotkeys.json
"""

import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
CONF = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))

NAMES = {
    "ctrl": "Ctrl", "control": "Ctrl", "shift": "Shift", "alt": "Alt", "mod1": "Alt", "super": "Super",
    "mod4": "Super", "meta": "Super", "logo": "Super", "esc": "Esc", "escape": "Esc", "enter": "Enter",
    "return": "Enter", "space": "Space", "tab": "Tab", "backspace": "⌫", "delete": "Supr", "del": "Supr",
    "insert": "Insert", "home": "Inicio", "end": "Fin", "pageup": "PgUp", "page_up": "PgUp", "prior": "PgUp",
    "pagedown": "PgDn", "page_down": "PgDn", "next": "PgDn", "up": "↑", "down": "↓", "left": "←", "right": "→",
    "minus": "-", "plus": "+", "equal": "=", "comma": ",", "period": ".", "slash": "/", "backslash": "\\",
    "bracket_left": "[", "bracket_right": "]", "bracketleft": "[", "bracketright": "]", "grave": "`",
    "kp_add": "Num +", "kp_subtract": "Num −", "kp_0": "Num 0", "kp_enter": "Num Enter",
}


def cap(k):
    low = k.lower()
    if low in NAMES:
        return NAMES[low]
    if re.fullmatch(r"f\d{1,2}", low):
        return low.upper()
    return k.upper() if len(k) == 1 else k


def combo(s, sep="+"):
    """'ctrl+shift+c' -> ['Ctrl', 'Shift', 'C'] ('+' suelto al final es la tecla +)"""
    parts = re.split(r"\+(?!$)", s) if sep == "+" else s.split(sep)
    return [cap(p) for p in parts if p != ""]


def row(section, keys, desc):
    desc = desc.strip()
    return {"section": section, "keys": keys, "desc": desc[:1].upper() + desc[1:]}


def humanize(action):
    return re.sub(r"[_-]+", " ", re.sub(r"([a-z])([A-Z])", r"\1 \2", action)).strip().capitalize()


# ---------------------------------------------------------------- herdr
HERDR = {
    "previous_tab": "Pestaña anterior", "next_tab": "Pestaña siguiente", "new_tab": "Pestaña nueva",
    "move_tab_previous": "Mover la pestaña a la izquierda", "move_tab_next": "Mover la pestaña a la derecha",
    "focus_pane_left": "Panel de la izquierda", "focus_pane_right": "Panel de la derecha",
    "focus_pane_down": "Panel de abajo", "focus_pane_up": "Panel de arriba",
    "split_vertical": "Panel nuevo a la derecha", "split_horizontal": "Panel nuevo abajo",
    "close_pane": "Cerrar panel", "close_tab": "Cerrar pestaña", "prefix": "Prefijo (tecla líder)",
}


def herdr():
    path = os.path.join(CONF, "herdr", "config.toml")
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    out, in_keys, comment, prefix = [], False, "", ["Ctrl", "G"]
    entries = []
    for line in lines:
        t = line.strip()
        if t.startswith("["):
            in_keys = t == "[keys]"
            comment = ""
            continue
        if not in_keys:
            continue
        if t.startswith("#"):
            comment = t.lstrip("# ").strip()
            continue
        m = re.match(r"([\w-]+)\s*=\s*(.+)$", t)
        if not m:
            comment = ""
            continue
        name, value = m.group(1), m.group(2)
        keys = re.findall(r'"([^"]+)"', value)
        if name == "prefix" and keys:
            prefix = combo(keys[0])
        entries.append((name, keys, comment))
        comment = ""
    for name, keys, comment in entries:
        desc = HERDR.get(name)
        # Sin traducción: el comentario del usuario encima ("Nuevo panel abajo: Alt d (…)")
        if desc is None:
            c = comment.split(":")[0].strip() if comment else ""
            desc = c if c and len(c) < 60 else humanize(name)
        for k in keys:
            if k.startswith("prefix+"):
                caps = prefix + ["·"] + combo(k[len("prefix+"):])
                section = "herdr · Con el prefijo"
            else:
                caps = combo(k)
                section = "herdr · Mis atajos" if name != "prefix" else "herdr · Prefijo"
            out.append(row(section, caps, desc))
    out.sort(key=lambda r: ({"herdr · Prefijo": 0, "herdr · Mis atajos": 1}.get(r["section"], 2)))
    return out


# ---------------------------------------------------------------- foot
FOOT = {
    "scrollback-up-page": "Subir una página", "scrollback-up-half-page": "Subir media página",
    "scrollback-up-line": "Subir una línea", "scrollback-down-page": "Bajar una página",
    "scrollback-down-half-page": "Bajar media página", "scrollback-down-line": "Bajar una línea",
    "scrollback-home": "Ir al principio del historial", "scrollback-end": "Ir al final del historial",
    "clipboard-copy": "Copiar", "clipboard-paste": "Pegar", "primary-paste": "Pegar la selección primaria",
    "search-start": "Buscar en el historial", "font-increase": "Agrandar la letra",
    "font-decrease": "Achicar la letra", "font-reset": "Tamaño de letra normal",
    "spawn-terminal": "Terminal nueva en la misma carpeta", "show-urls-launch": "Abrir un enlace (modo URL)",
    "show-urls-copy": "Copiar un enlace (modo URL)", "show-urls-persistent": "Modo URL persistente",
    "prompt-prev": "Prompt anterior", "prompt-next": "Prompt siguiente",
    "unicode-input": "Escribir un carácter Unicode", "noop": "Nada",
    "cancel": "Cancelar la búsqueda", "commit": "Aceptar la búsqueda", "find-prev": "Resultado anterior",
    "find-next": "Resultado siguiente", "cursor-left": "Cursor a la izquierda", "cursor-right": "Cursor a la derecha",
    "extend-to-word-boundary": "Ampliar la selección una palabra", "extend-to-next-whitespace": "Ampliar hasta el siguiente espacio",
    "clipboard-paste": "Pegar", "delete-prev-word": "Borrar la palabra anterior", "delete-next-word": "Borrar la palabra siguiente",
    "toggle-url-visible": "Mostrar/ocultar las URL", "pipe-scrollback": "Pasar el historial a un comando",
    "pipe-visible": "Pasar lo visible a un comando", "pipe-selected": "Pasar la selección a un comando",
    "pipe-command-output": "Pasar la salida del último comando", "fullscreen": "Pantalla completa",
    "maximize": "Maximizar", "minimize": "Minimizar",
}


def ini_bindings(path, commented):
    """{sección: {acción: valor}} de las secciones *-bindings (comentadas = defaults)."""
    res, section = {}, None
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return res
    for line in lines:
        t = line.strip()
        m = re.match(r"^#?\s*\[([\w-]+)\]", t)
        if m:
            section = m.group(1) if m.group(1).endswith("-bindings") else None
            continue
        if not section:
            continue
        if commented:
            m = re.match(r"^#\s*([\w-]+)\s*=\s*(.+)$", t)
        else:
            m = re.match(r"^([\w-]+)\s*=\s*(.+)$", t)
        if m:
            res.setdefault(section, {})[m.group(1)] = m.group(2).strip()
    return res


def foot():
    defaults = ini_bindings("/etc/xdg/foot/foot.ini", True)
    mine = ini_bindings(os.path.join(CONF, "foot", "foot.ini"), False)
    out = []
    titles = {"key-bindings": "foot · General", "search-bindings": "foot · Buscando (Ctrl+Shift+R)",
              "url-bindings": "foot · Modo URL", "text-bindings": None, "mouse-bindings": None}
    for section in ("key-bindings", "search-bindings", "url-bindings"):
        acts = dict(defaults.get(section, {}))
        acts.update(mine.get(section, {}))
        for action, value in acts.items():
            if value == "none" or action.startswith(("pipe-", "regex-")):
                continue
            mod = action in mine.get(section, {})
            # Varios combos separados por espacio; "[cmd] combo" en los pipe-* (ya filtrados)
            for c in (x for x in value.split() if not x.startswith("[")):
                caps = combo(c)
                desc = FOOT.get(action, humanize(action))
                if mod:
                    desc += " (cambiado por ti)"
                out.append(row(titles[section], caps, desc))
    if "search-start" in mine.get("key-bindings", {}):
        for r in out:
            if r["section"].startswith("foot · Buscando"):
                r["section"] = "foot · Buscando"
    return out


# ---------------------------------------------------------------- zellij
ZELLIJ = {
    "NewPane": "Panel nuevo", "NewTab": "Pestaña nueva", "CloseFocus": "Cerrar panel", "CloseTab": "Cerrar pestaña",
    "MoveFocus": "Mover el foco", "MoveFocusOrTab": "Mover el foco (o de pestaña)", "MovePane": "Mover el panel",
    "MovePaneBackwards": "Mover el panel hacia atrás", "GoToTab": "Ir a la pestaña", "GoToNextTab": "Pestaña siguiente",
    "GoToPreviousTab": "Pestaña anterior", "ToggleTab": "Volver a la última pestaña", "MoveTab": "Mover la pestaña",
    "ToggleFocusFullscreen": "Panel a pantalla completa", "ToggleFloatingPanes": "Mostrar/ocultar paneles flotantes",
    "TogglePaneEmbedOrFloating": "Panel flotante ↔ fijo", "TogglePaneFrames": "Mostrar/ocultar bordes de paneles",
    "ToggleActiveSyncTab": "Escribir en todos los paneles a la vez", "Resize": "Redimensionar",
    "ScrollUp": "Subir", "ScrollDown": "Bajar", "PageScrollUp": "Subir una página", "PageScrollDown": "Bajar una página",
    "HalfPageScrollUp": "Subir media página", "HalfPageScrollDown": "Bajar media página", "ScrollToBottom": "Ir al final",
    "Search": "Buscar", "SearchToggleOption": "Opción de búsqueda", "EditScrollback": "Abrir el historial en el editor",
    "Detach": "Desconectarse (la sesión sigue)", "Quit": "Salir de zellij", "NextSwapLayout": "Siguiente distribución",
    "PreviousSwapLayout": "Distribución anterior", "BreakPane": "Sacar el panel a una pestaña nueva",
    "BreakPaneRight": "Sacar el panel a la pestaña de la derecha", "BreakPaneLeft": "Sacar el panel a la pestaña de la izquierda",
    "SwitchFocus": "Cambiar de panel", "UndoRenameTab": "Deshacer el renombrado", "UndoRenamePane": "Deshacer el renombrado",
    "PaneNameInput": "Renombrar panel", "TabNameInput": "Renombrar pestaña",
}
ZMODES = {"locked": "bloqueado", "normal": "normal", "pane": "panel", "tab": "pestaña", "resize": "tamaño",
          "move": "mover", "scroll": "scroll", "search": "búsqueda", "entersearch": "escribir búsqueda",
          "session": "sesión", "renametab": "renombrar pestaña", "renamepane": "renombrar panel", "tmux": "tmux",
          "prompt": "prompt"}


def zmode(m):
    return ZMODES.get(m.lower(), m.lower())


DIRS = {"left": "←", "right": "→", "up": "↑", "down": "↓", "Increase": "más grande", "Decrease": "más pequeño"}


def zellij_desc(actions):
    parts = []
    mode = None
    for a in re.findall(r"(\w+)((?:\s+(?:\"[^\"]*\"|-?\d+))*)\s*;", actions):
        name, args = a[0], re.findall(r"\"([^\"]*)\"|(-?\d+)", a[1])
        args = [x or y for x, y in args]
        if name == "SwitchToMode":
            mode = args[0] if args else None
            continue
        d = ZELLIJ.get(name, humanize(name))
        if name == "GoToTab" and args:
            d = f"Ir a la pestaña {args[0]}"
        elif name in ("NewPane", "MoveFocus", "MovePane", "MoveFocusOrTab", "Resize", "MoveTab", "SearchToggleOption", "Search") and args:
            d += " " + " ".join(DIRS.get(x, x) for x in args)
        elif name in ("PaneNameInput", "TabNameInput"):
            d = ZELLIJ[name]
        parts.append(d)
    if not parts and mode:
        return f"Modo {zmode(mode)}"
    desc = ", ".join(dict.fromkeys(parts))
    if mode and mode.lower() not in ("locked", "normal"):
        desc += f" (y pasa a modo {zmode(mode)})"
    return desc


def zellij():
    path = os.path.join(CONF, "zellij", "config.kdl")
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        text = ""
    if not re.search(r"^\s*keybinds\b", text, re.M):
        try:
            text = subprocess.run(["zellij", "setup", "--dump-config"], capture_output=True, text=True, timeout=10).stdout
        except (OSError, subprocess.SubprocessError):
            return []
    # Bloque keybinds { … } (sin comentarios //)
    text = re.sub(r"//[^\n]*", "", text)
    m = re.search(r"^\s*keybinds\b[^{]*\{", text, re.M)
    if not m:
        return []
    out, depth, i, block = [], 1, m.end(), None
    while i < len(text) and depth > 0:
        rest = text[i:]
        b = re.match(r"\s*bind((?:\s+\"[^\"]+\")+)\s*\{([^{}]*)\}", rest)
        if b and depth == 2:
            keys = re.findall(r"\"([^\"]+)\"", b.group(1))
            desc = zellij_desc(b.group(2))
            for k in keys:
                # Las letras sueltas tal cual: en zellij "c" y "C" son teclas distintas
                caps = combo(k, " ") if " " in k else [k if len(k) == 1 else cap(k)]
                out.append(row("zellij · " + block, caps, desc))
            i += b.end()
            continue
        hdr = re.match(r"\s*([a-z_]+)((?:\s+\"[^\"]+\")*)\s*\{", rest)
        if hdr and depth == 1:
            name, args = hdr.group(1), re.findall(r"\"([^\"]+)\"", hdr.group(2))
            if name == "shared_except":
                block = "Cambiar de modo" if "locked" in args else "Siempre"
            elif name == "shared_among":
                block = "Modos " + ", ".join(zmode(a) for a in args)
            elif name == "shared":
                block = "Siempre"
            else:
                block = "Modo " + zmode(name)
            depth += 1
            i += hdr.end()
            continue
        c = text[i]
        depth += 1 if c == "{" else -1 if c == "}" else 0
        i += 1
    # Primero lo que vale siempre y el modo normal/bloqueado
    order = lambda r: (0 if re.search(r"Siempre|Cambiar de modo", r["section"]) else 1 if re.search(r"Modo (bloqueado|normal)$", r["section"]) else 2)
    out.sort(key=order)
    return out


# ---------------------------------------------------------------- ghostty
GHOSTTY = {
    "copy_to_clipboard": "Copiar", "paste_from_clipboard": "Pegar", "paste_from_selection": "Pegar la selección",
    "reload_config": "Recargar la configuración", "open_config": "Abrir la configuración",
    "new_tab": "Pestaña nueva", "new_window": "Ventana nueva", "close_surface": "Cerrar panel/pestaña",
    "close_tab": "Cerrar pestaña", "close_window": "Cerrar ventana", "previous_tab": "Pestaña anterior",
    "next_tab": "Pestaña siguiente", "last_tab": "Última pestaña", "new_split": "Dividir",
    "goto_split": "Ir al panel", "resize_split": "Redimensionar el panel", "equalize_splits": "Igualar paneles",
    "toggle_split_zoom": "Ampliar/reducir el panel", "increase_font_size": "Agrandar la letra",
    "decrease_font_size": "Achicar la letra", "reset_font_size": "Tamaño de letra normal",
    "scroll_page_up": "Subir una página", "scroll_page_down": "Bajar una página", "scroll_to_top": "Ir al principio",
    "scroll_to_bottom": "Ir al final", "jump_to_prompt": "Saltar al prompt", "select_all": "Seleccionar todo",
    "start_search": "Buscar", "end_search": "Terminar la búsqueda", "toggle_fullscreen": "Pantalla completa",
    "toggle_command_palette": "Paleta de comandos", "inspector": "Inspector", "quit": "Salir de ghostty",
    "write_screen_file": "Guardar la pantalla en un archivo", "adjust_selection": "Ajustar la selección",
    "text": "Escribir texto",
}
GDIRS = {"left": "←", "right": "→", "up": "↑", "down": "↓", "top": "↑", "bottom": "↓", "previous": "anterior",
         "next": "siguiente", "auto": "automático", "toggle": ""}


def ghostty():
    try:
        lines = subprocess.run(["ghostty", "+list-keybinds"], capture_output=True, text=True, timeout=10).stdout.splitlines()
    except (OSError, subprocess.SubprocessError):
        return []
    try:
        mine = open(os.path.join(CONF, "ghostty", "config"), encoding="utf-8").read()
    except OSError:
        mine = ""
    out = []
    for line in lines:
        m = re.match(r"keybind\s*=\s*(.+?)=([a-z_]+)(?::(.*))?$", line.strip())
        if not m:
            continue
        trigger, action, arg = m.group(1), m.group(2), (m.group(3) or "").replace("\\\\", "\\")
        if trigger in ("copy", "paste"):  # teclas físicas de copiar/pegar
            continue
        caps = []
        for n, part in enumerate(trigger.split(">")):
            if n:
                caps.append("·")
            caps += combo(part)
        desc = GHOSTTY.get(action, humanize(action))
        if action == "goto_tab":
            desc = f"Ir a la pestaña {arg}"
        elif action == "text":
            desc = "Enviar " + ("Esc" if arg in ("\\x1b", "\\e") else arg)
        elif arg and action not in ("copy_to_clipboard",):
            extra = " ".join(GDIRS.get(a, a) for a in re.split(r"[:,]", arg) if a)
            desc += f" {extra}".rstrip() if extra and not extra.replace(" ", "").lstrip("-").isdigit() else ""
        section = "ghostty · Mis atajos" if re.search(r"^keybind\s*=\s*" + re.escape(trigger) + r"=", mine, re.M) else "ghostty · Por defecto"
        if ">" in trigger and section.endswith("Mis atajos"):
            section = "ghostty · Mis atajos (con " + " ".join(combo(trigger.split(">")[0])) + ")"
        out.append(row(section, caps, desc))
    out.sort(key=lambda r: 0 if "Mis atajos" in r["section"] and "(con" not in r["section"] else 1 if "(con" in r["section"] else 2)
    return out


# ---------------------------------------------------------------- yazi (defaults, escritos a mano)
YAZI = [
    ("Moverse", [("k ↑", "Arriba"), ("j ↓", "Abajo"), ("h ←", "Carpeta de arriba"), ("l →", "Entrar en la carpeta"),
                 ("gg", "Al principio"), ("G", "Al final"), ("Ctrl+U", "Media página arriba"), ("Ctrl+D", "Media página abajo"),
                 ("gh", "Ir a la carpeta personal"), ("gc", "Ir a ~/.config"), ("gd", "Ir a Descargas"),
                 ("g Space", "Ir a una carpeta (escribiéndola)"), ("z", "Saltar con fzf"), ("Z", "Saltar con zoxide")]),
    ("Archivos", [("Enter", "Abrir"), ("o", "Abrir"), ("O", "Abrir con…"), ("y", "Copiar"), ("x", "Cortar"),
                  ("p", "Pegar"), ("P", "Pegar sobrescribiendo"), ("d", "Mandar a la papelera"), ("D", "Borrar para siempre"),
                  ("a", "Crear archivo (termina en / para carpeta)"), ("r", "Renombrar"), ("Y", "Cancelar copiar/cortar"),
                  (".", "Mostrar/ocultar ocultos"), ("Tab", "Información del archivo")]),
    ("Seleccionar", [("Space", "Marcar/desmarcar"), ("v", "Modo visual"), ("V", "Modo visual (quitar)"),
                     ("Ctrl+A", "Marcar todo"), ("Ctrl+R", "Invertir la selección"), ("Esc", "Salir del modo/selección")]),
    ("Copiar rutas", [("cc", "Copiar la ruta"), ("cd", "Copiar la carpeta"), ("cf", "Copiar el nombre"),
                      ("cn", "Copiar el nombre sin extensión")]),
    ("Buscar y filtrar", [("/", "Buscar"), ("?", "Buscar hacia atrás"), ("n", "Siguiente"), ("N", "Anterior"),
                          ("f", "Filtrar"), ("s", "Buscar por nombre (fd)"), ("S", "Buscar por contenido (rg)"),
                          (",m", "Ordenar por fecha"), (",n", "Ordenar por nombre"), (",s", "Ordenar por tamaño")]),
    ("Pestañas y otros", [("t", "Pestaña nueva"), ("1–9", "Ir a la pestaña"), ("[", "Pestaña anterior"),
                          ("]", "Pestaña siguiente"), ("Ctrl+C", "Cerrar pestaña"), (";", "Ejecutar un comando"),
                          (":", "Ejecutar un comando (bloqueante)"), ("w", "Tareas"), ("~", "Ayuda"), ("q", "Salir")]),
]


def yazi_caps(k):
    caps = []
    for part in k.split(" "):
        if "+" in part and len(part) > 1:
            caps += combo(part)
        else:
            caps.append(NAMES.get(part.lower(), part) if len(part) > 1 and part.lower() in NAMES else part)
    return caps


def yazi():
    out = []
    # Los propios, si los hay (prepend_keymap / keymap de [mgr]/[manager])
    path = os.path.join(CONF, "yazi", "keymap.toml")
    try:
        import tomllib
        with open(path, "rb") as f:
            km = tomllib.load(f)
        for layer in ("mgr", "manager"):
            sect = km.get(layer, {})
            for key in ("prepend_keymap", "keymap", "append_keymap"):
                for b in sect.get(key, []):
                    on = b.get("on")
                    on = on if isinstance(on, list) else [on]
                    out.append(row("yazi · Mis atajos", [yazi_caps(x)[0] if len(yazi_caps(x)) == 1 else " ".join(yazi_caps(x)) for x in on],
                                   b.get("desc") or str(b.get("run"))))
    except (OSError, ValueError, ImportError):
        pass
    for section, binds in YAZI:
        for k, d in binds:
            out.append(row("yazi · " + section, yazi_caps(k), d))
    return out


# ---------------------------------------------------------------- firefox (escritos a mano)
FIREFOX = [
    ("Pestañas", [("ctrl+t", "Pestaña nueva"), ("ctrl+w", "Cerrar pestaña"), ("ctrl+shift+t", "Reabrir la pestaña cerrada"),
                  ("ctrl+tab", "Pestaña siguiente"), ("ctrl+shift+tab", "Pestaña anterior"), ("alt+1", "Ir a la pestaña 1 (…8)"),
                  ("alt+9", "Ir a la última pestaña"), ("ctrl+shift+pageup", "Mover la pestaña a la izquierda"),
                  ("ctrl+shift+pagedown", "Mover la pestaña a la derecha"), ("ctrl+m", "Silenciar la pestaña")]),
    ("Ventanas", [("ctrl+n", "Ventana nueva"), ("ctrl+shift+p", "Ventana privada"), ("ctrl+shift+w", "Cerrar ventana"),
                  ("f11", "Pantalla completa")]),
    ("Navegar", [("ctrl+l", "Ir a la barra de direcciones"), ("ctrl+k", "Buscar en la web"), ("alt+←", "Atrás"),
                 ("alt+→", "Adelante"), ("f5", "Recargar"), ("ctrl+shift+r", "Recargar sin caché"), ("alt+home", "Página de inicio"),
                 ("ctrl+enter", "Completar .com en la barra de direcciones")]),
    ("Página", [("ctrl+f", "Buscar en la página"), ("ctrl+g", "Siguiente resultado"), ("/", "Búsqueda rápida"),
                ("ctrl+plus", "Acercar"), ("ctrl+minus", "Alejar"), ("ctrl+0", "Zoom normal"), ("f9", "Vista de lectura"),
                ("ctrl+p", "Imprimir"), ("ctrl+s", "Guardar la página"), ("ctrl+u", "Ver el código fuente")]),
    ("Marcadores e historial", [("ctrl+d", "Guardar en marcadores"), ("ctrl+shift+o", "Biblioteca de marcadores"),
                                ("ctrl+b", "Barra lateral de marcadores"), ("ctrl+h", "Historial en la barra lateral"),
                                ("ctrl+shift+h", "Biblioteca del historial"), ("ctrl+shift+delete", "Borrar el historial reciente"),
                                ("ctrl+j", "Descargas")]),
    ("Herramientas", [("f12", "Herramientas de desarrollo"), ("ctrl+shift+k", "Consola web"), ("ctrl+shift+i", "Inspector"),
                      ("ctrl+shift+m", "Diseño adaptable (móvil)"), ("ctrl+shift+a", "Complementos")]),
]

# ---------------------------------------------------------------- Surfingkeys (extensión de Firefox)
SURFINGKEYS_ID = "{a8332c60-5b6d-41ee-bfc8-e9bb331d34ad}"
SK_GROUPS = ["Ayuda", "Clic en enlaces", "Desplazarse", "Pestañas", "Navegar por la página", "Sesiones",
             "Buscar la selección con", "Portapapeles", "Omnibar", "Modo visual", "Marcas (como Vim)", "Ajustes",
             "URLs del navegador", "Proxy", "Otros", "Modo inserción", "Modo lurk", "Pistas por regiones"]


def firefox_profiles():
    import configparser
    out = []
    for base in (os.path.join(CONF, "mozilla", "firefox"), os.path.join(HOME, ".mozilla", "firefox")):
        ini = configparser.ConfigParser()
        if not ini.read(os.path.join(base, "profiles.ini")):
            continue
        for sec in ini.sections():
            path = ini[sec].get("Path")
            if path:
                full = path if ini[sec].get("IsRelative", "1") == "0" else os.path.join(base, path)
                if os.path.isdir(full):
                    out.append(full)
    return out


def sk_caps(k):
    """'<Ctrl-Alt-i>' -> ['Ctrl', 'Alt', 'i'];  ';ql' -> [';ql'];  'g<Ctrl-x>' -> ['g', 'Ctrl', 'x']"""
    caps = []
    for tok in re.findall(r"<[^>]+>|[^<]+", k):
        if tok.startswith("<") and len(tok) > 2:
            parts = tok[1:-1].split("-")
            key = parts.pop() or "-"
            caps += [cap(p) for p in parts] + [NAMES.get(key.lower(), key) if len(key) > 1 else key]
        else:
            caps.append(tok)
    return caps


def surfingkeys():
    import zipfile
    for prof in firefox_profiles():
        try:
            addons = json.load(open(os.path.join(prof, "extensions.json"), encoding="utf-8")).get("addons", [])
        except (OSError, ValueError):
            continue
        sk = next((a for a in addons if a.get("id") == SURFINGKEYS_ID and a.get("active")), None)
        if not sk or not sk.get("path"):
            continue
        try:
            with zipfile.ZipFile(sk["path"]) as z:
                js = z.read("content.js").decode("utf-8", "replace")
        except (OSError, KeyError, zipfile.BadZipFile):
            continue
        out, seen = [], set()
        found = re.findall(r'\("((?:[^"\\]|\\.){1,16})",\s*"#(\d+)((?:[^"\\]|\\.)+)"', js)
        # Los de desplazarse y cambiar de modo: mappings.add("j",{annotation:"Scroll down",feature_group:2,…})
        found += [(k, g, d) for k, d, g in re.findall(
            r'mappings\.add\("((?:[^"\\]|\\.){1,16})",\{annotation:"((?:[^"\\]|\\.)+)",feature_group:(\d+)', js)]
        for key, group, desc in found:
            key = key.encode().decode("unicode_escape")
            desc = desc.encode().decode("unicode_escape")
            g = int(group)
            if (key, desc) in seen:
                continue
            seen.add((key, desc))
            name = SK_GROUPS[g] if g < len(SK_GROUPS) else f"Grupo {g}"
            out.append((g, row("Surfingkeys · " + name, sk_caps(key), desc)))
        out.sort(key=lambda x: x[0])
        return [r for _, r in out]
    return []


# ---------------------------------------------------------------- obsidian (escritos a mano)
OBSIDIAN = [
    ("General", [("ctrl+p", "Paleta de comandos"), ("ctrl+o", "Abrir nota (quick switcher)"), ("ctrl+n", "Nota nueva"),
                 ("ctrl+,", "Ajustes"), ("ctrl+shift+f", "Buscar en la bóveda"), ("ctrl+f", "Buscar en la nota"),
                 ("ctrl+h", "Reemplazar en la nota"), ("ctrl+g", "Vista de grafo"), ("ctrl+e", "Editar/leer (vista previa)")]),
    ("Pestañas y paneles", [("ctrl+w", "Cerrar pestaña"), ("ctrl+shift+t", "Reabrir la pestaña cerrada"),
                            ("ctrl+tab", "Pestaña siguiente"), ("alt+←", "Atrás"), ("alt+→", "Adelante"),
                            ("ctrl+click", "Abrir el enlace en pestaña nueva")]),
    ("Editar", [("ctrl+b", "Negrita"), ("ctrl+i", "Cursiva"), ("ctrl+k", "Insertar enlace"), ("ctrl+l", "Casilla de verificación"),
                ("ctrl+]", "Aumentar sangría"), ("ctrl+[", "Reducir sangría"), ("ctrl+/", "Comentar"),
                ("ctrl+d", "Borrar el párrafo"), ("[[", "Enlazar otra nota"), ("ctrl+z", "Deshacer"), ("ctrl+shift+z", "Rehacer")]),
]


def curated(app, groups):
    return [row(f"{app} · {s}", combo(k), d) for s, binds in groups for k, d in binds]


def obsidian():
    out = []
    # Atajos propios de la bóveda (hotkeys.json): {comando: [{modifiers, key}]}
    vault = os.environ.get("OBSIDIAN_VAULT", os.path.join(CONF, "obsidian"))
    try:
        hk = json.load(open(os.path.join(vault, ".obsidian", "hotkeys.json"), encoding="utf-8"))
        for cmd, binds in hk.items():
            for b in binds or []:
                mods = [{"Mod": "Ctrl", "Ctrl": "Ctrl", "Meta": "Super", "Alt": "Alt", "Shift": "Shift"}.get(x, x) for x in b.get("modifiers", [])]
                out.append(row("Obsidian · Mis atajos", mods + [cap(b.get("key", ""))], humanize(cmd.split(":")[-1])))
    except (OSError, ValueError):
        pass
    return out + curated("Obsidian", OBSIDIAN)


APPS = {
    "herdr": herdr, "foot": foot, "zellij": zellij, "ghostty": ghostty, "yazi": yazi,
    "firefox": lambda: curated("Firefox", FIREFOX) + surfingkeys(), "obsidian": obsidian,
}

if __name__ == "__main__":
    app = sys.argv[1] if len(sys.argv) > 1 else ""
    if app not in APPS:
        print("uso: app-keybinds.py " + "|".join(APPS), file=sys.stderr)
        sys.exit(1)
    try:
        rows = APPS[app]()
    except Exception as e:  # nunca romper el glosario
        print(f"app-keybinds {app}: {e}", file=sys.stderr)
        rows = []
    json.dump(rows, sys.stdout, ensure_ascii=False)
