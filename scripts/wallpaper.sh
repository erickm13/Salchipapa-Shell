#!/usr/bin/env bash
# Cambia el fondo (independiente de caelestia). Guarda el estado que lee la shell y,
# si procede, genera los colores del fondo con matugen y los aplica (apply-colors.sh).
#   wallpaper.sh <archivo> [nocolors]   -> ese fondo (por defecto genera colores)
#   wallpaper.sh random   [nocolors]    -> aleatorio de ~/Pictures/Wallpapers
#   wallpaper.sh --colors-only <imagen>  -> solo genera y aplica los colores de esa imagen
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
state="$HOME/.local/state/salchipapa-shell"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"
mkdir -p "$state"

arg="${1:-random}"
colors="${2:-colors}" # "colors" (por defecto) o "nocolors"

# --colors-only <imagen>: solo los colores de esa imagen, sin cambiar el fondo (fondos animados)
colors_only=0
if [ "$arg" = "--colors-only" ]; then
    colors_only=1
    arg="${2:?falta la imagen}"
    colors=colors
fi

if [ "$arg" = "random" ] || [ ! -f "$arg" ]; then
    wp=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n1)
else
    wp="$arg"
fi
[ -z "$wp" ] && {
    echo "no hay wallpaper en $dir" >&2
    exit 1
}

# Estado del wallpaper (la shell lo renderiza)
if [ "$colors_only" -eq 0 ]; then
    printf '%s' "$wp" >"$state/wallpaper"
    ln -sf "$wp" "$state/current"
fi

# Colores del wallpaper con matugen (Material You) -> apply-colors.sh
if [ "$colors" != "nocolors" ] && command -v matugen >/dev/null; then
    pal=$(matugen -j hex -m dark --prefer=saturation image "$wp" 2>/dev/null | jq -c '
        .colors | to_entries
        | map({ key: (.key | gsub("_(?<c>[a-z])"; (.c | ascii_upcase))), value: (.value.dark.color | ltrimstr("#")) })
        | from_entries')
    if [ -n "$pal" ] && [ "$pal" != "null" ]; then
        tmp=$(mktemp)
        printf '%s' "$pal" >"$tmp"
        "$repo/scripts/apply-colors.sh" file "$tmp"
        rm -f "$tmp"
    fi
fi
