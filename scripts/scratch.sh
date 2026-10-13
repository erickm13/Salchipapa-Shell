#!/usr/bin/env bash
# Scratchpad estilo caelestia: apps en un workspace especial.
#   scratch.sh <nombre-special> <regex-clase> <comando a lanzar...>
# Si ya hay una ventana de esa app -> alterna su workspace especial.
# Si no -> la lanza (una windowrule la manda a ese special) y lo muestra.
set -euo pipefail

name="$1"
class="$2"
shift 2

count=$(hyprctl clients -j | jq --arg c "$class" '[.[] | select((.class // "") | test($c; "i"))] | length')

if [ "${count:-0}" -gt 0 ]; then
    hyprctl dispatch togglespecialworkspace "$name"
else
    hyprctl dispatch exec "$*"
    hyprctl dispatch togglespecialworkspace "$name"
fi
