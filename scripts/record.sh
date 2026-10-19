#!/usr/bin/env bash
# Grabación de pantalla con gpu-screen-recorder (como `caelestia record`).
#   record.sh screen [sound|nosound]  -> graba el monitor enfocado; si ya graba, la para
#   record.sh region [sound|nosound]  -> elige la zona con slurp; si ya graba, la para
#   record.sh stop | pause            -> parar (guarda) | pausar/reanudar
# Vídeos en ~/Videos/Recordings. Estado (lo lee la isla para el indicador):
# ~/.local/state/salchipapa-shell/recording -> {"pid", "start", "file", "paused"}; vacío = sin grabar.
#
# Se llama a /usr/bin/gpu-screen-recorder directamente (sin prime-run: graba en la GPU del monitor)
# y con la salida a un log: si hereda una tubería que se cierra, muere con SIGPIPE.
set -euo pipefail

state_dir="$HOME/.local/state/salchipapa-shell"
state="$state_dir/recording"
dir="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
log=/tmp/salchipapa-record.log
audio="default_output|default_input" # sonido del sistema + micrófono
mkdir -p "$state_dir" "$dir"

running_pid() {
    local pid
    pid=$(jq -r '.pid // empty' "$state" 2>/dev/null || true)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid"
    return 0
}

stop() {
    local pid file act
    pid=$(running_pid)
    file=$(jq -r '.file // empty' "$state" 2>/dev/null || true)
    : >"$state"
    [ -n "$pid" ] || exit 0
    # SIGINT: gpu-screen-recorder cierra el archivo bien antes de salir
    kill -INT "$pid"
    for _ in $(seq 100); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    [ -s "$file" ] || {
        notify-send -u critical -i dialog-error "Grabación" "No se guardó el vídeo (ver $log)"
        exit 1
    }
    # Clic en la notificación = ver el vídeo; acciones para abrir la carpeta o borrarlo
    (
        act=$(notify-send -i media-record -A default=Ver -A open=Carpeta -A delete=Borrar \
            "Grabación guardada" "$(basename "$file")" || true)
        case "$act" in
        default) xdg-open "$file" ;;
        open) xdg-open "$dir" ;;
        delete) rm -f "$file" ;;
        esac
    ) >/dev/null 2>&1 &
}

start() {
    local mode="$1" sound="$2" args=() monitors region fps file pid
    monitors=$(hyprctl monitors -j)
    if [ "$mode" = "region" ]; then
        region=$(slurp -f '%wx%h+%x+%y') || exit 0 # Esc en slurp = cancelar
        # FPS: el mayor de los monitores que toca la región
        fps=$(jq -r --arg r "$region" '
            ($r | capture("(?<w>\\d+)x(?<h>\\d+)\\+(?<x>-?\\d+)\\+(?<y>-?\\d+)") | map_values(tonumber)) as $g |
            [.[] | select(.x < $g.x + $g.w and .x + .width > $g.x and .y < $g.y + $g.h and .y + .height > $g.y) |
             .refreshRate | round] | max // 60' <<<"$monitors")
        args+=(-w region -region "$region" -f "$fps")
    else
        args+=(-w "$(jq -r '.[] | select(.focused) | .name' <<<"$monitors")")
        args+=(-f "$(jq -r '.[] | select(.focused) | .refreshRate | round' <<<"$monitors")")
    fi
    [ "$sound" = "sound" ] && args+=(-a "$audio")
    file="$dir/recording_$(date +%Y%m%d_%H-%M-%S).mp4"

    : >"$log"
    setsid /usr/bin/gpu-screen-recorder "${args[@]}" -o "$file" >>"$log" 2>&1 &
    pid=$!
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        notify-send -u critical -i dialog-error "Grabación" "gpu-screen-recorder no arrancó: $(tail -n 2 "$log" | tr '\n' ' ')"
        exit 1
    fi
    jq -n --argjson pid "$pid" --argjson start "$(date +%s)" --arg file "$file" \
        '{pid: $pid, start: $start, file: $file, paused: false}' >"$state"
}

case "${1:-screen}" in
screen | region)
    if [ -n "$(running_pid)" ]; then
        stop
    else
        start "$1" "${2:-sound}"
    fi
    ;;
stop)
    stop
    ;;
pause)
    pid=$(running_pid)
    [ -n "$pid" ] || exit 0
    kill -USR2 "$pid"
    jq '.paused = (.paused | not)' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
    ;;
*)
    echo "uso: record.sh screen|region [sound|nosound] | stop | pause" >&2
    exit 1
    ;;
esac
