#!/usr/bin/env bash
# Fondos animados de Wallpaper Engine (Workshop de Steam) con linux-wallpaperengine.
#   animated-wallpaper.sh list                    -> JSON [{id, title, type, preview}] (con caché)
#   animated-wallpaper.sh set <id> [colors|nocolors] -> lo pone en todos los monitores activos
#   animated-wallpaper.sh stop                    -> lo quita y vuelve el fondo estático de la shell
#   animated-wallpaper.sh restore                 -> al iniciar sesión, vuelve a poner el último
#   animated-wallpaper.sh watch                   -> (interno) pausa el motor de cada monitor tapado
# Estado: ~/.local/state/salchipapa-shell/animated (el id, o vacío; con id la shell oculta su fondo).
# Un motor por monitor, a WALLPAPER_FPS (60 por defecto). El vigilante pausa (SIGSTOP) el de cada
# monitor cuyo escritorio (o especial abierto) tiene una ventana en mosaico o a pantalla completa;
# las flotantes no cuentan. Se compara por nombre: en Hyprland 0.57 los especiales no tienen id.
# Pausado se queda el último fotograma: no se nota y no gasta GPU.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
workshop="${WALLPAPER_ENGINE_DIR:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"
state="$HOME/.local/state/salchipapa-shell"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/animated-wallpapers.json"
log=/tmp/animated-wallpaper.log
watchpid="$state/animated-watch.pid"
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

engine_pids() {
    pgrep -x linux-wallpaper || true # el nombre del proceso se corta a 15 letras
}

# PID del motor que dibuja en el monitor $1
engine_for() {
    local p
    for p in $(engine_pids); do
        tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q -- " --screen-root $1 " && echo "$p"
    done
}

stop_watch() {
    local w
    w=$(cat "$watchpid" 2>/dev/null) || return 0
    # El vigilante es líder de su grupo (setsid): se cierra con su socat
    [ -n "$w" ] && kill -- "-$w" 2>/dev/null
    rm -f "$watchpid"
    return 0
}

# Cierra solo los procesos de linux-wallpaperengine (por PID exacto)
stop_engine() {
    stop_watch
    local pids
    pids=$(engine_pids)
    [ -n "$pids" ] || pids=$(pgrep -f '^(prime-run )?linux-wallpaperengine( |$)' || true)
    [ -n "$pids" ] || return 0
    kill -CONT $pids 2>/dev/null # uno pausado no atiende SIGTERM
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

# Pausa o reanuda el motor de cada monitor según si su escritorio está tapado
update_pause() {
    local mons clients m covered p
    mons=$(hyprctl monitors -j) || return 0
    clients=$(hyprctl clients -j) || return 0
    while read -r m covered; do
        for p in $(engine_for "$m"); do
            if [ "$covered" = true ]; then kill -STOP "$p"; else kill -CONT "$p"; fi 2>/dev/null || true
        done
    done < <(jq -rn --argjson m "$mons" --argjson c "$clients" '
        $m[] | . as $mon
        | [$c[] | select(
            (.mapped // true) and ((.hidden // false) | not)
            and (.workspace.name == $mon.activeWorkspace.name
                 or (($mon.specialWorkspace.name // "") != "" and .workspace.name == $mon.specialWorkspace.name))
            and (((.floating // false) | not) or ((.fullscreen // 0) | . != 0 and . != false))
          )] | length > 0
        | "\($mon.name) \(.)"')
}

watch() {
    local events="${XDG_RUNTIME_DIR:-/tmp}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
    command -v socat >/dev/null && [ -S "$events" ] || exit 0
    printf '%s' "$$" >"$watchpid"
    update_pause
    socat -U - "UNIX-CONNECT:$events" 2>/dev/null | while IFS= read -r ev; do
        case "${ev%%>>*}" in
        openwindow | closewindow | movewindow | movewindowv2 | workspace | workspacev2 | focusedmon | \
            focusedmonv2 | fullscreen | changefloatingmode | activespecial | activespecialv2 | minimized | \
            monitoradded | monitoraddedv2 | monitorremoved | monitorremovedv2)
            [ -n "$(engine_pids)" ] || exit 0
            update_pause
            ;;
        esac
    done
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
    args+=(linux-wallpaperengine --fps "${WALLPAPER_FPS:-60}" --silent --no-audio-processing --fullscreen-pause-only-active --scaling fill)
    if [ "$bg" != "$id" ]; then
        while IFS= read -r p; do
            args+=(--set-property "$p")
        done < <(jq -r '.preset // {} | to_entries[] | select(.value != null) | "\(.key)=\(.value)"' "$pj")
    fi
    # Un motor por monitor, para poder pausar cada pantalla por separado
    for m in $(hyprctl monitors -j | jq -r '.[].name'); do
        setsid -f "${args[@]}" --screen-root "$m" --bg "$bg" >>"$log" 2>&1
    done
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
    setsid -f "$(readlink -f "$0")" watch >>"$log" 2>&1
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
watch)
    watch
    ;;
restore)
    [ -s "$state/animated" ] || exit 0
    sleep 2 # que los monitores estén listos
    start "$(cat "$state/animated")" || : >"$state/animated"
    ;;
*)
    echo "uso: animated-wallpaper.sh list | set <id> [colors|nocolors] | stop | restore | watch" >&2
    exit 1
    ;;
esac
