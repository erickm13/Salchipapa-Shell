#!/usr/bin/env bash
# Scratchpad estilo caelestia: apps en un workspace especial.
#   scratch.sh <nombre-special> <regex-clase> <comando a lanzar...>
# Si ya hay una ventana de esa app -> alterna su workspace especial.
# Si no -> la lanza (una windowrule la manda a ese special) y lo muestra.
#
# OJO: con la config de Hyprland en Lua, `hyprctl dispatch` usa sintaxis Lua
# (hl.dsp.*), no la clásica. Las consultas (clients -j) sí siguen igual.
set -euo pipefail

name="$1"
class="$2"
shift 2

count=$(hyprctl clients -j | jq --arg c "$class" '[.[] | select((.class // "") | test($c; "i"))] | length')

if [ "${count:-0}" -eq 0 ]; then
    # Lanzar la app (la windowrule la envía a special:$name)
    setsid -f sh -c "$*" >/dev/null 2>&1 || true
fi

# Mostrar/ocultar el workspace especial (sintaxis Lua)
hyprctl dispatch "hl.dsp.workspace.toggle_special('$name')"
