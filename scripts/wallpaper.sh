#!/usr/bin/env bash
# Cambia el fondo de pantalla (y genera los colores Material You del fondo).
# Reutiliza `caelestia wallpaper`, que escribe ~/.local/state/caelestia/wallpaper/path.txt
# (lo lee la shell para renderizarlo) y actualiza el esquema de color.
#   wallpaper.sh            -> aleatorio de ~/Pictures/Wallpapers
#   wallpaper.sh <archivo>  -> ese wallpaper concreto
set -euo pipefail

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"

if [ -n "${1:-}" ] && [ -f "$1" ]; then
    caelestia wallpaper -f "$1"
else
    caelestia wallpaper -r "$dir"
fi
