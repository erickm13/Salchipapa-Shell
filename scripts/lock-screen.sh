#!/usr/bin/env bash
# Bloquea la pantalla con la de la shell (Super+BackSpace). Quickshell identifica cada instancia
# por la ruta con la que se lanzó: autostart.lua usa la ruta tal cual (~/.config/hypr, un enlace
# al repo), así que se prueba primero esa y luego la real (con readlink -f no encontraba ninguna).
set -uo pipefail

logical="${SALCHIPAPA_SHELL_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
resolved="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

for repo in "$logical" "$resolved"; do
    qs ipc --path "$repo/shell/shell.qml" call salchipapa-lock activate 2>/dev/null && exit 0
done
echo "lock-screen: no hay ninguna instancia de la shell en marcha" >&2
exit 1
