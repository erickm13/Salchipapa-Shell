#!/usr/bin/env bash
# Capturas de pantalla para Hyprland (grim + slurp).
# Se usa desde un script para que Hyprland no intente expandir $(...) como variables suyas.
#
# Uso: screenshot.sh [region|screen|output]
#   region  -> seleccionar un área con el ratón
#   screen  -> toda la pantalla (todos los monitores)
#   output  -> solo el monitor activo
# En todos los casos: guarda en ~/Pictures/Screenshots y copia al portapapeles.
set -euo pipefail

mode="${1:-region}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
    region)
        geom="$(slurp)" || exit 0        # ESC/cancelar = salir sin error
        grim -g "$geom" "$file"
        ;;
    screen)
        grim "$file"
        ;;
    output)
        mon="$(hyprctl activeworkspace -j | jq -r '.monitor')"
        grim -o "$mon" "$file"
        ;;
    *)
        echo "modo desconocido: $mode (usa region|screen|output)" >&2
        exit 1
        ;;
esac

wl-copy -t image/png < "$file"

if command -v notify-send >/dev/null; then
    notify-send -i "$file" "Captura guardada" "$file"
fi
