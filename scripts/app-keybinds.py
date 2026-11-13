#!/usr/bin/env python3
"""Atajos de otras apps para el glosario de la isla (Super+/): app-keybinds.py <app> -> JSON
[{section, keys: [str], desc}] (el formato de BindsContent.qml).

Leídos de la config real (en vivo):
  terminal la chuleta `keys --json` de Salchipapa.Dots (fish): comandos, abreviaturas, fzf, git, lazygit
  herdr    ~/.config/herdr/config.toml ([keys] y [[keys.command]] con su description) + los por defecto
           que no cambiaste (`herdr --default-config`)
  foot     los defaults documentados en /etc/xdg/foot/foot.ini + tus cambios en ~/.config/foot/foot.ini
  zellij   ~/.config/zellij/config.kdl (o `zellij setup --dump-config` si no define keybinds)
  ghostty  `ghostty +list-keybinds` (los efectivos: defaults + tu config)
Escritos a mano (no guardan sus atajos por defecto en ningún archivo legible):
  yazi     los por defecto + los de ~/.config/yazi/keymap.toml si existe
  firefox  los más útiles + Surfingkeys si está instalada (sus atajos por defecto, sacados del .xpi
           instalado: cada mapkey("tecla", "#<grupo>Descripción") de content.js) y tu
           configuración de Advanced mode (sección "Mis atajos"; map/unmap aplicados), leída de su
           IndexedDB
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
# Acciones de herdr en español (las que no estén aquí se leen tal cual, "swap_pane_left" -> "Swap pane left")
HERDR = {
    "prefix": "Prefijo (tecla líder)", "help": "Ver todos los atajos", "settings": "Ajustes",
    "detach": "Salir sin cerrar nada (sigue en segundo plano)", "reload_config": "Recargar la configuración",
    "open_notification_target": "Ir a la notificación (el agente que te necesita)",
    "workspace_picker": "Elegir workspace", "goto": "Navegador de sesiones",
    "new_workspace": "Workspace nuevo", "new_worktree": "Workspace nuevo en un git worktree",
    "rename_workspace": "Renombrar workspace", "close_workspace": "Cerrar workspace",
    "previous_workspace": "Workspace anterior", "next_workspace": "Workspace siguiente",
    "new_tab": "Pestaña nueva", "rename_tab": "Renombrar pestaña", "previous_tab": "Pestaña anterior",
    "next_tab": "Pestaña siguiente", "move_tab_previous": "Mover la pestaña a la izquierda",
    "move_tab_next": "Mover la pestaña a la derecha", "switch_tab": "Ir a la pestaña 1…9",
    "close_tab": "Cerrar pestaña", "rename_pane": "Renombrar panel",
    "edit_scrollback": "Historial del panel en el editor (nvim)", "clear_pane": "Limpiar el panel",
    "focus_pane_left": "Panel de la izquierda", "focus_pane_right": "Panel de la derecha",
    "focus_pane_down": "Panel de abajo", "focus_pane_up": "Panel de arriba",
    "cycle_pane_next": "Panel siguiente", "cycle_pane_previous": "Panel anterior",
    "last_pane": "Volver al último panel", "split_vertical": "Panel nuevo a la derecha",
    "split_horizontal": "Panel nuevo abajo", "close_pane": "Cerrar panel",
    "zoom": "Ampliar el panel (otra vez para volver)", "resize_mode": "Modo redimensionar (flechas, Esc sale)",
    "resize_pane_left": "Agrandar el panel a la izquierda", "resize_pane_right": "Agrandar el panel a la derecha",
    "resize_pane_down": "Agrandar el panel hacia abajo", "resize_pane_up": "Agrandar el panel hacia arriba",
    "swap_pane_left": "Intercambiar con el panel de la izquierda", "swap_pane_right": "Intercambiar con el panel de la derecha",
    "swap_pane_down": "Intercambiar con el panel de abajo", "swap_pane_up": "Intercambiar con el panel de arriba",
    "toggle_sidebar": "Mostrar u ocultar la barra lateral",
    "copy_mode": "Modo copia: recorrer el historial del panel con el teclado",
}
# Solo para el modo navegar / ventanas de herdr: no son atajos globales
HERDR_SKIP = {"remote_image_paste", "navigate_workspace_up", "navigate_workspace_down", "navigate_pane_left",
              "navigate_pane_down", "navigate_pane_up", "navigate_pane_right"}


def herdr_defaults():
    """{acción: [teclas]} por defecto, de `herdr --default-config` (las líneas comentadas de [keys])"""
    try:
        text = subprocess.run(["herdr", "--default-config"], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    out, in_keys = {}, False
    for line in text.splitlines():
        t = line.strip()
        if t.startswith("[") or t.startswith("# ["):
            in_keys = t.lstrip("# ") == "[keys]"
            continue
        m = re.match(r'#\s*([a-z_]+)\s*=\s*"([^"]*)"', t)
        # Solo atajos ("prefix+w", "ctrl+v"): fuera quedan los ejemplos de [[keys.command]] (type = "popup"…)
        if in_keys and m and "+" in m.group(2):
            out[m.group(1)] = [m.group(2)]
    return out


def herdr():
    path = os.path.join(CONF, "herdr", "config.toml")
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    mine, commands, block = {}, [], None  # block: "keys", "command" u otra tabla
    for line in lines:
        t = line.split(" #")[0].strip() if not line.strip().startswith("#") else ""
        if t.startswith("[[keys.command]]"):
            block = "command"
            commands.append({})
            continue
        if t.startswith("["):
            block = "keys" if t == "[keys]" else None
            continue
        m = re.match(r"([\w-]+)\s*=\s*(.+)$", t)
        if not m:
            continue
        name, value = m.group(1), m.group(2)
        if block == "keys":
            mine[name] = re.findall(r'"([^"]+)"', value)
        elif block == "command":
            q = re.match(r'\s*["\']{1,3}(.*?)["\']{1,3}\s*$', value)
            commands[-1][name] = q.group(1) if q else value
    prefix_key = (mine.get("prefix") or herdr_defaults().get("prefix") or ["ctrl+b"])[0]
    prefix = combo(prefix_key)

    def caps(k):
        if k.startswith("prefix+"):
            return prefix + ["·"] + combo(k[len("prefix+"):]), True
        return combo(k), False

    out = [row("herdr · Prefijo", prefix, HERDR["prefix"])]
    # Los tuyos (config.toml) primero; los por defecto que no cambiaste, después
    for name, keys in mine.items():
        if name == "prefix" or name in HERDR_SKIP:
            continue
        for k in keys:
            c, pre = caps(k)
            out.append(row("herdr · Con el prefijo" if pre else "herdr · Mis atajos", c, HERDR.get(name, humanize(name))))
    for cmd in commands:
        if "key" not in cmd:
            continue
        c, pre = caps(cmd["key"])
        desc = cmd.get("description") or cmd.get("command", "")
        out.append(row("herdr · Mis comandos", c, desc))
    for name, keys in herdr_defaults().items():
        if name == "prefix" or name in mine or name in HERDR_SKIP:
            continue
        for k in keys:
            if ".." in k:  # prefix+1..9
                k = k.replace("1..9", "1…9")
            c, _ = caps(k)
            out.append(row("herdr · Por defecto", c, HERDR.get(name, humanize(name))))
    order = {"herdr · Prefijo": 0, "herdr · Mis atajos": 1, "herdr · Con el prefijo": 2, "herdr · Mis comandos": 3}
    out.sort(key=lambda r: order.get(r["section"], 4))
    return out


# ---------------------------------------------------------------- terminal
# La chuleta `keys` de Salchipapa.Dots (fish): comandos propios, abreviaturas, fzf, git y lazygit.
# Nvim y herdr tienen su propia pestaña, así que esas secciones se saltan.
def keycaps(k):
    """'Ctrl+T' -> ['Ctrl', 'T']; con espacios o '/' ('ff [texto]', 'Ctrl+R / ↑') va en una sola tecla"""
    if " " in k or "/" in k or "+" not in k:
        return [k]
    return combo(k)


def terminal():
    try:
        res = subprocess.run(["fish", "-c", "keys --json"], capture_output=True, text=True, timeout=10)
        data = json.loads(res.stdout or "[]")
    except (OSError, subprocess.SubprocessError, ValueError):
        return []
    out = []
    for r in data:
        if r.get("section") in ("Nvim", "Herdr"):
            continue
        item = row("Terminal · " + r["section"], keycaps(r["key"]), r["desc"])
        if r["section"] == "Abreviaturas":  # la expansión es un comando: sin mayúscula ("git status")
            item["desc"] = r["desc"].strip()
        out.append(item)
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
    """'<Ctrl-Alt-i>' -> ['Ctrl', 'Alt', 'i'];  ';ql' -> [';ql'];  '<<' -> ['<<'];  'g<Ctrl-x>' -> ['g', 'Ctrl', 'x']"""
    caps, buf = [], ""
    for tok in re.findall(r"<(?:[A-Za-z]+-)*[^<>\s-]+>|.", k):
        if len(tok) > 2 and tok[0] == "<" and tok[-1] == ">":
            if buf:
                caps.append(buf)
                buf = ""
            parts = tok[1:-1].split("-")
            key = parts.pop()
            caps += [cap(p) for p in parts] + [NAMES.get(key.lower(), key) if len(key) > 1 else key]
        else:
            buf += tok
    if buf:
        caps.append(buf)
    return caps


def sk_storage(prof):
    """Ajustes guardados de Surfingkeys (IndexedDB de la extensión): {clave: valor} con los valores que
    se saben leer (texto y booleanos). Las claves van con cada letra +1 y los valores en snappy +
    structured clone."""
    import shutil
    import sqlite3
    import tempfile
    try:
        prefs = open(os.path.join(prof, "prefs.js"), encoding="utf-8").read()
        m = re.search(r'\\"' + re.escape(SURFINGKEYS_ID) + r'\\":\\"([0-9a-f-]+)\\"', prefs)
        uuid = m.group(1)
    except (OSError, AttributeError):
        return {}
    base = os.path.join(prof, "storage", "default", f"moz-extension+++{uuid}^userContextId=4294967295", "idb")
    dbs = [f for f in os.listdir(base) if f.endswith(".sqlite")] if os.path.isdir(base) else []
    if not dbs:
        return {}

    def snappy(b):
        i = n = shift = 0
        while True:
            c = b[i]; i += 1; n |= (c & 0x7F) << shift; shift += 7
            if c < 0x80:
                break
        out = bytearray()
        while i < len(b):
            t = b[i]; i += 1; k = t & 3
            if k == 0:
                ln = t >> 2
                if ln >= 60:
                    nb = ln - 59; ln = int.from_bytes(b[i:i + nb], "little"); i += nb
                ln += 1; out += b[i:i + ln]; i += ln
            else:
                if k == 1:
                    ln = ((t >> 2) & 7) + 4; off = ((t >> 5) << 8) | b[i]; i += 1
                elif k == 2:
                    ln = (t >> 2) + 1; off = int.from_bytes(b[i:i + 2], "little"); i += 2
                else:
                    ln = (t >> 2) + 1; off = int.from_bytes(b[i:i + 4], "little"); i += 4
                for _ in range(ln):
                    out.append(out[-off])
        return bytes(out)

    def value(raw):
        # Cabecera (8 bytes) + par (dato uint32, etiqueta uint32)
        data = int.from_bytes(raw[8:12], "little")
        tag = int.from_bytes(raw[12:16], "little")
        if tag == 0xFFFF0002:  # booleano
            return bool(data)
        if tag == 0xFFFF0004:  # texto: longitud + bit de latin1
            n, latin1 = data & 0x7FFFFFFF, data & 0x80000000
            body = raw[16:]
            return body[:n].decode("latin-1") if latin1 else body[:2 * n].decode("utf-16-le", "replace")
        return None

    res = {}
    with tempfile.TemporaryDirectory() as tmp:
        # Copia (con su -wal): la base está abierta por Firefox
        for f in os.listdir(base):
            if f.startswith(dbs[0]):
                shutil.copy(os.path.join(base, f), tmp)
        try:
            db = sqlite3.connect(os.path.join(tmp, dbs[0]))
            for key, data in db.execute("select key, data from object_data"):
                name = "".join(chr(c - 1) for c in key[1:])
                try:
                    res[name] = value(snappy(bytes(data)))
                except (IndexError, ValueError):
                    pass
            db.close()
        except sqlite3.Error:
            pass
    return res


SK_MODES = {"mapkey": "", "map": "", "vmapkey": "visual", "imapkey": "inserción", "cmap": "omnibar"}


def sk_unescape(s):
    return s.encode("latin-1", "backslashreplace").decode("unicode_escape")


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
        # Nombres (minificados) de las funciones de la API: const{…map:p,mapkey:m,…vmapkey:y,…}=o
        fn = {}
        m = re.search(r"const\{([^}]*mapkey:[^}]*)\}=\w+", js)
        if m:
            for name, var in re.findall(r"(\w+):([\w$]+)", m.group(1)):
                if name in SK_MODES:
                    fn[var] = name
        found = []  # (tecla, grupo, descripción, modo)
        # mapkey/vmapkey/imapkey("k","#Ndesc",…)
        for var, key, group, desc in re.findall(r'(?<![\w$.])([\w$]{1,3})\("((?:[^"\\]|\\.){1,16})",\s*"#(\d+)((?:[^"\\]|\\.)+)"', js):
            found.append((key, group, desc, SK_MODES.get(fn.get(var, "mapkey"), "")))
        # map("g0",":feedkeys 99E",0,"#3Go to the first tab")
        for key, group, desc in re.findall(r'\("((?:[^"\\]|\\.){1,16})","[^"]*",0,"#(\d+)((?:[^"\\]|\\.)+)"', js):
            found.append((key, group, desc, ""))
        # Desplazarse y modos: mappings.add("j",{annotation:"Scroll down",feature_group:2,…})
        # (los del grupo 9 son del modo visual: w, b, f, n… no deben pisar a los normales)
        for key, desc, group in re.findall(r'mappings\.add\("((?:[^"\\]|\\.){1,16})",\{annotation:"((?:[^"\\]|\\.)+)",feature_group:(\d+)', js):
            found.append((key, group, desc, "visual" if group == "9" else ""))
        # Buscadores: addSearchAlias("g","google",url,"s",…) crea "og" y "sg"
        for alias, engine, prefix in re.findall(r'\("([a-z])","([a-z]+)","https?://[^"]+","([a-z])"', js):
            name = {"duckduckgo": "DuckDuckGo", "github": "GitHub", "youtube": "YouTube"}.get(engine, engine.capitalize())
            found.append(("o" + alias, "8", f"Buscar en {name} (abre el omnibar)", ""))
            found.append((prefix + alias, "6", f"Buscar el texto seleccionado en {name}", ""))

        rows = {}  # (tecla, modo) -> (grupo, descripción): la última definición gana, como en Surfingkeys
        order = []
        for key, group, desc, mode in found:
            k = (sk_unescape(key), mode)
            if k not in rows:
                order.append(k)
            rows[k] = (int(group), sk_unescape(desc))

        # Tu configuración (Advanced mode): mapkey/vmapkey/imapkey nuevos, map("nueva","vieja"), unmap
        st = sk_storage(prof)
        mine = set()
        snippet = st.get("snippets") if st.get("showAdvanced") else None
        if isinstance(snippet, str):
            code = re.sub(r"//[^\n]*", "", snippet)
            q = r"""(["'`])((?:\\.|(?!\1).)*)\1"""
            for call in re.finditer(r"api\.(mapkey|vmapkey|imapkey|map|unmap)\(", code):
                kind = call.group(1)
                after = code[call.end():call.end() + 400]
                if kind in ("map", "unmap"):  # sus argumentos no llevan ")"
                    after = after[:after.find(")")]
                strs = [m.group(2) for m in re.finditer(q, after)][:2]
                if kind in ("mapkey", "vmapkey", "imapkey") and len(strs) >= 2:
                    mode = SK_MODES[kind]
                    g = re.match(r"#(\d+)", strs[1])
                    desc = re.sub(r"^#\d+", "", strs[1])
                    k = (strs[0], mode)
                    if k not in rows:
                        order.append(k)
                    rows[k] = (int(g.group(1)) if g else 14, desc)
                    mine.add(k)
                elif kind == "map" and len(strs) >= 2:
                    new, old = (strs[0], ""), (strs[1], "")
                    if old in rows:
                        if new not in rows:
                            order.append(new)
                        g, d = rows[old]
                        rows[new] = (g, f"{d} (como {strs[1]})")
                        mine.add(new)
                elif kind == "unmap" and strs:
                    rows.pop((strs[0], ""), None)

        out = []
        for k in order:
            if k not in rows:
                continue
            g, desc = rows[k]
            key, mode = k
            name = "Mis atajos" if k in mine else (SK_GROUPS[g] if g < len(SK_GROUPS) else f"Grupo {g}")
            if mode:
                desc += f" (modo {mode})"
            out.append((0 if k in mine else 1, g, row("Surfingkeys · " + name, sk_caps(key), desc)))
        out.sort(key=lambda x: (x[0], x[1]))
        return [r for _, _, r in out]
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
    "terminal": terminal, "herdr": herdr, "foot": foot, "zellij": zellij, "ghostty": ghostty, "yazi": yazi,
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
