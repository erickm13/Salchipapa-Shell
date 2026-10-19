#!/usr/bin/env bash
# Primer arranque tras install.sh: aplica el fondo y el tema de defaults/theme.
# Se lanza en cada inicio de Hyprland (lua/autostart.lua), pero solo actúa si install.sh dejó
# la marca `first-run`. Va aquí y no en el instalador porque Salchipapa.Dots, que se instala
# después, reemplaza las configs de foot/kitty/fish que tematiza apply-colors.sh.
set -euo pipefail

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
state="$HOME/.local/state/salchipapa-shell"
marker="$state/first-run"
[ -f "$marker" ] || exit 0

scheme=$(sed -n 's/^scheme=//p' "$repo/defaults/theme")
wallpaper=$(sed -n 's/^wallpaper=//p' "$repo/defaults/theme")
wp="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers/$wallpaper"

if [ "$scheme" = "dynamic" ]; then
    "$repo/scripts/wallpaper.sh" "$wp" colors
else
    "$repo/scripts/wallpaper.sh" "$wp" nocolors
    "$repo/scripts/apply-colors.sh" scheme "$scheme"
fi

rm -f "$marker"
