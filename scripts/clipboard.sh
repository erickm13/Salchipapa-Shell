#!/usr/bin/env bash
# Historial del portapapeles (cliphist) para el modo "clipboard" de la isla (Super+V).
#   clipboard.sh list          -> JSON [{id, text, image}] (lo más reciente primero)
#   clipboard.sh thumb <id>    -> miniatura PNG de una imagen (caché); imprime la ruta
#   clipboard.sh copy <id>     -> la vuelve a poner en el portapapeles
#   clipboard.sh delete <id>   -> la borra del historial
#   clipboard.sh wipe          -> vacía el historial
# Lo guardan los `wl-paste --watch cliphist store` de lua/autostart.lua.
set -euo pipefail

thumbs="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/clipboard"
mkdir -p "$thumbs"

# La línea completa de una entrada ("id<TAB>vista previa"), que es lo que esperan decode/delete
entry() {
    # (sin `exit` en awk: cortar la tubería mataría a cliphist con SIGPIPE y pipefail aborta)
    cliphist list | awk -F '\t' -v id="$1" '$1 == id && !found { print; found = 1 }'
}

case "${1:-}" in
list)
    cliphist list | jq -R -s -c '
        split("\n") | map(select(length > 0) | capture("^(?<id>[0-9]+)\t(?<text>.*)$"; "s")) |
        map(. + {image: (.text | test("^\\[\\[ binary data .* (png|jpe?g|webp|gif|bmp) "))})'
    ;;
thumb)
    id="${2:?falta el id}"
    out="$thumbs/$id.png"
    if [ ! -s "$out" ]; then
        line=$(entry "$id")
        [ -n "$line" ] || exit 1
        printf '%s\n' "$line" | cliphist decode | magick - -thumbnail '320x160>' "png:$out"
    fi
    echo "$out"
    ;;
copy)
    line=$(entry "${2:?falta el id}")
    [ -n "$line" ] || exit 1
    printf '%s\n' "$line" | cliphist decode | wl-copy
    ;;
delete)
    line=$(entry "${2:?falta el id}")
    [ -n "$line" ] || exit 0
    printf '%s\n' "$line" | cliphist delete
    rm -f "$thumbs/${2}.png"
    ;;
wipe)
    cliphist wipe
    rm -f "$thumbs"/*.png
    ;;
*)
    echo "uso: clipboard.sh list | thumb <id> | copy <id> | delete <id> | wipe" >&2
    exit 1
    ;;
esac
