#!/usr/bin/env bash
# Fondos animados de Wallpaper Engine (Workshop de Steam) con linux-wallpaperengine.
#   animated-wallpaper.sh list                    -> JSON [{id, title, type, preview}] (con caché)
#   animated-wallpaper.sh set <id> [colors|nocolors] -> lo pone en todos los monitores activos
#   animated-wallpaper.sh stop                    -> lo quita y vuelve el fondo estático de la shell
#   animated-wallpaper.sh restore                 -> al iniciar sesión, vuelve a poner el último
# Estado: ~/.local/state/salchipapa-shell/animated (el id, o vacío; con id la shell oculta su fondo).
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
workshop="${WALLPAPER_ENGINE_DIR:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"
state="$HOME/.local/state/salchipapa-shell"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/animated-wallpapers.json"
log=/tmp/animated-wallpaper.log
mkdir -p "$state" "$(dirname "$cache")"

list() {
    [ -d "$workshop" ] || {
        echo "[]"
        return
    }
    # La caché vale mientras no cambie la carpeta de la Workshop (suscribirse/borrar la toca)
    if [ -s "$cache" ] && [ "$cache" -nt "$workshop" ]; then
        cat "$cache"
        return
    fi
    local d
    for d in "$workshop"/*/; do
        [ -f "$d/project.json" ] || continue
        jq -c --arg id "$(basename "$d")" --arg dir "${d%/}" '{
            id: $id,
            title: (.title // $id),
            type: ((.type // "unknown") | ascii_downcase),
            preview: ($dir + "/" + (.preview // "preview.jpg"))
        }' "$d/project.json" 2>/dev/null || true
    done | jq -s 'sort_by(.title | ascii_downcase)' >"$cache"
    cat "$cache"
}

# Cierra solo los procesos de linux-wallpaperengine (por PID exacto)
stop_engine() {
    local pids
    pids=$(pgrep -x linux-wallpaper || true) # el nombre del proceso se corta a 15 letras
    [ -n "$pids" ] || pids=$(pgrep -f '^(prime-run )?linux-wallpaperengine( |$)' || true)
    [ -n "$pids" ] || return 0
    kill $pids 2>/dev/null
    # A veces se cuelga al cerrar (escribe "Stopping" y no sale) y el fondo viejo sigue debajo
    # del nuevo: si en 2 s no ha salido, SIGKILL
    local i p
    for i in $(seq 20); do
        for p in $pids; do kill -0 "$p" 2>/dev/null && break; p=; done
        [ -z "$p" ] && return 0
        sleep 0.1
    done
    kill -9 $pids 2>/dev/null
    return 0
}

start() {
    local id="$1" args=() m p bg="$1"
    local pj="$workshop/$id/project.json"
    # Preset: project.json sin "type", con "dependency" (el fondo base) y "preset" (sus ajustes).
    # linux-wallpaperengine no los entiende ("Project type missing"): se lanza el fondo base y se
    # le pasan los valores del preset como propiedades.
    if [ -f "$pj" ] && [ -z "$(jq -r '.type // empty' "$pj")" ]; then
        bg=$(jq -r '.dependency // empty' "$pj")
        [ -n "$bg" ] && [ -d "$workshop/$bg" ] || {
            notify-send -u critical -i dialog-error "Fondo animado" "El preset $id necesita el fondo $bg: suscríbete a él en la Workshop" 2>/dev/null || true
            echo "preset $id: falta el fondo base $bg" >&2
            return 1
        }
    fi
    stop_engine
    sleep 0.3
    # prime-run: lo renderiza la NVIDIA (si existe) y no carga la iGPU
    command -v prime-run >/dev/null && args+=(prime-run)
    args+=(linux-wallpaperengine --fps 165 --silent --no-audio-processing --fullscreen-pause-only-active --scaling fill)
    if [ "$bg" != "$id" ]; then
        while IFS= read -r p; do
            args+=(--set-property "$p")
        done < <(jq -r '.preset // {} | to_entries[] | select(.value != null) | "\(.key)=\(.value)"' "$pj")
    fi
    for m in $(hyprctl monitors -j | jq -r '.[].name'); do
        args+=(--screen-root "$m" --bg "$bg")
    done
    setsid -f "${args[@]}" >>"$log" 2>&1
    # Si muere al arrancar (p. ej. falta una librería tras actualizar ffmpeg), no dejar la shell
    # sin fondo: el estado solo se escribe si sigue vivo
    sleep 2
    if ! pgrep -x linux-wallpaper >/dev/null && ! pgrep -f '^(prime-run )?linux-wallpaperengine( |$)' >/dev/null; then
        local err
        err=$(tail -n 3 "$log" | tr '\n' ' ')
        notify-send -u critical -i dialog-error "Fondo animado" "linux-wallpaperengine no arrancó: $err" 2>/dev/null || true
        echo "linux-wallpaperengine no arrancó: $err" >&2
        return 1
    fi
}

cmd="${1:-}"
case "$cmd" in
list)
    list
    ;;
set)
    id="${2:?falta el id}"
    colors="${3:-colors}"
    [ -d "$workshop/$id" ] || {
        echo "no existe $workshop/$id" >&2
        exit 1
    }
    start "$id" || exit 1
    printf '%s' "$id" >"$state/animated"
    if [ "$colors" = "colors" ]; then
        preview="$workshop/$id/$(jq -r '.preview // "preview.jpg"' "$workshop/$id/project.json")"
        [ -f "$preview" ] && "$repo/scripts/wallpaper.sh" --colors-only "$preview"
    fi
    ;;
stop)
    stop_engine
    : >"$state/animated" # vacío (no borrado): así la shell ve el cambio y vuelve a su fondo
    ;;
restore)
    [ -s "$state/animated" ] || exit 0
    sleep 2 # que los monitores estén listos
    start "$(cat "$state/animated")" || : >"$state/animated"
    ;;
*)
    echo "uso: animated-wallpaper.sh list | set <id> [colors|nocolors] | stop | restore" >&2
    exit 1
    ;;
esac
