#!/usr/bin/env bash
# Aplica un esquema de color propio (sin caelestia): escribe el estado que leen la shell
# (colors.json) y Hyprland (colors.conf, formato `$clave = hex`).
#
# Uso:
#   apply-colors.sh scheme <nombre> [flavour]   -> de shell/themes/schemes.json (temas de caelestia guardados)
#   apply-colors.sh file <palette.json>         -> un JSON { "role": "hex", ... } (p.ej. salida de matugen)
#
# Tras escribir el estado, la shell se recolorea sola (FileView). Para el glow de ventanas
# se recarga Hyprland.
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$HOME/proyects/Salchipapa-Shell}"
schemes="$repo/shell/themes/schemes.json"
state="$HOME/.local/state/salchipapa-shell"
mkdir -p "$state"

mode="${1:-}"
arg="${2:-}"
flavour="${3:-}"

case "$mode" in
    scheme)
        if [ -n "$flavour" ]; then
            pal=$(jq -c --arg n "$arg" --arg f "$flavour" '.[$n][$f]' "$schemes")
        else
            # por defecto: el flavour con el background más oscuro (modo oscuro)
            pal=$(jq -c --arg n "$arg" '.[$n] | to_entries | min_by(.value.background // "ffffff") | .value' "$schemes")
        fi
        ;;
    file)
        pal=$(jq -c '.' "$arg")
        ;;
    *)
        echo "uso: apply-colors.sh scheme <nombre> [flavour] | file <palette.json>" >&2
        exit 1
        ;;
esac

if [ -z "$pal" ] || [ "$pal" = "null" ]; then
    echo "paleta no encontrada: $mode $arg" >&2
    exit 1
fi

# Estado para la shell (mismo formato que leía: { "colours": { role: hex } })
echo "{\"colours\": $pal}" | jq '.' >"$state/colors.json"

# Estado para Hyprland/Lua ($clave = hex)
echo "$pal" | jq -r 'to_entries[] | "$\(.key) = \(.value)"' >"$state/colors.conf"

# Recargar Hyprland para el glow (si hay sesión)
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
