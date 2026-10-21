#!/usr/bin/env bash
# Reinicia la shell (Super+Shift+R): útil cuando la recarga en caliente falla ("X is not a type")
# o el cliente HTTP de Qt se atasca. Cierra solo la instancia de esta shell (qs kill --path) y la
# vuelve a lanzar a través de Hyprland, con la misma ruta que autostart.lua (~/.config/hypr, sin
# resolver el enlace): Quickshell identifica las instancias por esa ruta y lock-screen.sh la busca así.
set -uo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
config="$repo/shell/shell.qml"

qs kill --path "$config" >/dev/null 2>&1
# Esperar a que se cierre del todo antes de lanzar la nueva
for _ in $(seq 20); do
    qs list --path "$config" 2>/dev/null | grep -q "Process ID" || break
    sleep 0.1
done
hyprctl dispatch "hl.dsp.exec_cmd(\"qs -p $config\")" >/dev/null
