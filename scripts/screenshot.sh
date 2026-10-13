#!/usr/bin/env bash
# Capturas estilo caelestia (grim + slurp + swappy).
# Se usa desde script para que Hyprland no expanda $(...) como variables suyas.
#
# Uso: screenshot.sh [region|screen]
#   region  -> seleccionar un área; se guarda, se copia y se abre en swappy para anotar
#   screen  -> monitor activo -> portapapeles + guardado + notificación
set -euo pipefail

mode="${1:-region}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
    region)
        geom="$(slurp)" || exit 0            # ESC/cancelar = salir sin error
        grim -g "$geom" "$file"
        wl-copy -t image/png < "$file"       # copia el recorte al portapapeles
        # Abre el editor para anotar (como caelestia). En swappy: Ctrl+S guarda, Ctrl+C copia.
        if command -v swappy >/dev/null; then
            swappy -f "$file"
        fi
        ;;
    screen)
        mon="$(hyprctl activeworkspace -j | jq -r '.monitor')"
        grim -o "$mon" "$file"
        wl-copy -t image/png < "$file"
        if command -v notify-send >/dev/null; then
            notify-send -i "$file" "Captura guardada" "$file"
        fi
        ;;
    *)
        echo "modo desconocido: $mode (usa region|screen)" >&2
        exit 1
        ;;
esac
