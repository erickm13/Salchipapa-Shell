#!/usr/bin/env bash
# Aviso de descarga terminada: lo lanza services/Downloads.qml con los archivos nuevos de la
# carpeta de descargas que llegaron juntos. Uso: download-done.sh <archivo>...
# Espera a que terminen: que no quede su .part (Firefox) y que el tamaño no cambie en 2 s (lo que
# se guarda de golpe o lo escribe otra app). Descarta los que desaparecen (cancelada, movida) y los
# de fecha de más de 5 min: al descomprimir un zip los archivos conservan la suya.
# Uno: aviso con Abrir (también el clic) y Mostrar en carpeta. Varios: un solo aviso con los nombres
# y el total, que abre la carpeta. Se queda esperando la respuesta.
set -uo pipefail

sizes() {
    local f
    for f in "${files[@]}"; do
        [ -e "$f.part" ] && echo part
        stat -c %s "$f" 2>/dev/null
    done
}
human() { numfmt --to=iec --format='%.1f' "$1" 2>/dev/null | sed -E 's/([0-9])([KMGT]?)$/\1 \2B/'; }

files=("$@")
last=""
for _ in $(seq 7200); do
    now=$(sizes)
    [[ "$now" != *part* ]] && [ "$now" = "$last" ] && break
    last=$now
    sleep 2
done

new=()
for f in "${files[@]}"; do
    [ -s "$f" ] && [ $(($(date +%s) - $(stat -c %Y "$f"))) -le 300 ] && new+=("$f")
done
[ ${#new[@]} -gt 0 ] || exit 0
dir=$(dirname "${new[0]}")

if [ ${#new[@]} -gt 1 ]; then
    total=0
    for f in "${new[@]}"; do total=$((total + $(stat -c %s "$f"))); done
    names=$(for f in "${new[@]:0:3}"; do basename "$f"; done | paste -sd ',' | sed 's/,/, /g')
    [ ${#new[@]} -gt 3 ] && names="$names and $((${#new[@]} - 3)) more"
    action=$(notify-send -a Downloads -i folder-download -A default="Show in folder" \
        "${#new[@]} downloads complete" "$names · $(human "$total")")
    [ "$action" = default ] && xdg-open "$dir"
    exit 0
fi

file="${new[0]}"
name=$(basename "$file")
size=$(human "$(stat -c %s "$file")")
# Tipo por el contenido; si no lo reconoce (o está a medias), por la extensión
mime=$(file -b --mime-type "$file" 2>/dev/null)
if [ "$mime" = application/octet-stream ]; then
    case "${name,,}" in
        *.mp4 | *.mkv | *.mov | *.webm | *.avi) mime=video/x ;;
        *.jpg | *.jpeg | *.png | *.gif | *.webp | *.heic) mime=image/x ;;
        *.mp3 | *.flac | *.ogg | *.m4a | *.wav | *.opus) mime=audio/x ;;
    esac
fi
case "$mime" in
    video/*) icon=video-x-generic ;;
    image/*) icon=image-x-generic ;;
    audio/*) icon=audio-x-generic ;;
    application/pdf) icon=application-pdf ;;
    application/zip | application/x-*tar* | application/x-7z* | application/x-rar* | application/gzip | application/zstd)
        icon=package-x-generic ;;
    *) icon=text-x-generic ;;
esac

action=$(notify-send -a Downloads -i "$icon" -A default=Open -A folder="Show in folder" \
    "Download complete" "$name · $size")
case "$action" in
    default) xdg-open "$file" ;;
    folder)
        # El gestor de archivos con el archivo seleccionado; si no lo admite, la carpeta
        gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 \
            --method org.freedesktop.FileManager1.ShowItems "['file://$file']" "" >/dev/null 2>&1 ||
            xdg-open "$dir"
        ;;
esac
