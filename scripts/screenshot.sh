#!/usr/bin/env bash
# Capturas estilo caelestia (grim + slurp + swappy).
# Se usa desde script para que Hyprland no expanda $(...) como variables suyas.
#
# Uso: screenshot.sh [region|screen|window]
#   region  -> seleccionar un área; se guarda, se copia y se abre en swappy para anotar
#   screen  -> monitor activo -> portapapeles + guardado + notificación
#   window  -> capturar la ventana bajo el cursor (x/y opcionales)
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
    window)
        window_error() {
            notify-send -u critical "No se pudo capturar la ventana" "$1" 2>/dev/null || true
            printf 'Error al capturar ventana: %s\n' "$1" >&2
            exit 1
        }

        if [[ $# -ge 5 ]]; then
            # La geometría la envía el preview, así se captura exactamente el área resaltada.
            geometry="$2,$3 ${4}x${5}"
        else
            # Modo manual: buscar la ventana bajo el cursor después de cerrar el selector.
            sleep 0.15
            cursor="$(hyprctl cursorpos -j)" || window_error "Hyprland no devolvió la posición del cursor"
            cursor_x="$(jq -r '.x' <<<"$cursor")"
            cursor_y="$(jq -r '.y' <<<"$cursor")"

            active="$(hyprctl -j activewindow)" || window_error "Hyprland no devolvió la ventana enfocada"
            geometry="$(jq -r --argjson x "$cursor_x" --argjson y "$cursor_y" '
                if (.at | type == "array" and length == 2) and
                   (.size | type == "array" and length == 2) and
                   .at[0] <= $x and .at[1] <= $y and
                   ($x < (.at[0] + .size[0])) and ($y < (.at[1] + .size[1])) then
                    (.at[0] | floor) as $left |
                    (.at[1] | floor) as $top |
                    ((.at[0] + .size[0] | ceil) - $left) as $width |
                    ((.at[1] + .size[1] | ceil) - $top) as $height |
                    "\($left),\($top) \($width)x\($height)"
                else empty end
            ' <<<"$active")" || window_error "No se pudo leer la geometría de la ventana enfocada"

            if [[ -z "$geometry" ]]; then
                clients="$(hyprctl -j clients)" || window_error "Hyprland no devolvió sus ventanas"
                geometry="$(jq -r --argjson x "$cursor_x" --argjson y "$cursor_y" '
                    [.[] | select(
                        (.mapped // true) == true and (.hidden // false) == false and
                        (.at | type == "array" and length == 2) and
                        (.size | type == "array" and length == 2) and
                        .at[0] <= $x and .at[1] <= $y and
                        ($x < (.at[0] + .size[0])) and ($y < (.at[1] + .size[1]))
                    )] | last | if . then
                        (.at[0] | floor) as $left |
                        (.at[1] | floor) as $top |
                        ((.at[0] + .size[0] | ceil) - $left) as $width |
                        ((.at[1] + .size[1] | ceil) - $top) as $height |
                        "\($left),\($top) \($width)x\($height)"
                    else empty end
                ' <<<"$clients")" || window_error "No se pudo leer la geometría de las ventanas"
            fi
        fi
        if [[ -z "$geometry" ]]; then
            notify-send "Captura cancelada" "No hay una ventana bajo el cursor" 2>/dev/null || true
            exit 0
        fi

        grim -g "$geometry" "$file" || window_error "grim rechazó la geometría: $geometry"
        wl-copy -t image/png < "$file" || window_error "No se pudo copiar la captura al portapapeles"
        # Misma vista previa y edición que las capturas de región.
        if command -v swappy >/dev/null; then
            swappy -f "$file"
        fi
        ;;
    *)
        echo "modo desconocido: $mode (usa region|screen|window)" >&2
        exit 1
        ;;
esac
