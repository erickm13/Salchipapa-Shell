#!/usr/bin/env bash
# Letra de una canción desde LRCLIB (https://lrclib.net, gratis y sin cuenta) para el panel de
# música de la isla (Super+A). Uso: lyrics.sh <artista> <título> <álbum> <duración en s>
# Imprime un JSON: {"synced": "<LRC con [mm:ss.xx]>", "plain": "<texto>", "instrumental": bool}
# o {} si no hay letra. Caché en ~/.cache/salchipapa-shell/lyrics/ (también los "no encontrado",
# para no repetir la consulta en cada apertura).
# OJO: envía artista, título, álbum y duración a lrclib.net.
set -uo pipefail

artist="${1:-}" title="${2:-}" album="${3:-}" duration="${4:-0}"
[ -n "$title" ] || { echo '{}'; exit 0; }

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/lyrics"
mkdir -p "$cache_dir"
key=$(printf '%s\n%s\n%s' "$artist" "$title" "$album" | sha1sum | cut -c1-40)
cache="$cache_dir/$key.json"
[ -s "$cache" ] && { cat "$cache"; exit 0; }

api="https://lrclib.net/api"
ua="salchipapa-shell (https://github.com/erickm13/Salchipapa-Shell)"

# GET con un reintento si el servidor está ocupado
fetch() {
    local out i
    for i in 1 2; do
        out=$(curl -sG --max-time 12 -H "User-Agent: $ua" "$@") || out=""
        if echo "$out" | jq -e 'type == "object" and (.message // "" | test("busy"))' >/dev/null 2>&1; then
            sleep 2
            continue
        fi
        echo "$out"
        return
    done
}

pick='{synced: (.syncedLyrics // ""), plain: (.plainLyrics // ""), instrumental: (.instrumental // false)}'

# 1) Coincidencia exacta (artista, título, álbum y duración)
res=$(fetch "$api/get" --data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title" \
    --data-urlencode "album_name=$album" --data-urlencode "duration=$duration")
json=$(echo "$res" | jq -c "if type == \"object\" and (.id // null) != null then $pick else empty end" 2>/dev/null)

# 2) Búsqueda por título y artista: la de duración más parecida, prefiriendo las sincronizadas
if [ -z "$json" ]; then
    res=$(fetch "$api/search" --data-urlencode "track_name=$title" --data-urlencode "artist_name=$artist")
    json=$(echo "$res" | jq -c --argjson d "${duration:-0}" \
        "if type == \"array\" and length > 0 then (sort_by((if .syncedLyrics then 0 else 1 end), (((.duration // 0) - \$d) | fabs)) | .[0] | $pick) else empty end" 2>/dev/null)
fi

# Sin respuesta (red caída) o servidor aún saturado: no se guarda en caché, para reintentarlo
if [ -z "$res" ] || echo "$res" | jq -e 'type == "object" and (.message // "" | test("busy"))' >/dev/null 2>&1; then
    echo '{}'
    exit 0
fi
[ -n "$json" ] || json='{}'
echo "$json" | tee "$cache"
