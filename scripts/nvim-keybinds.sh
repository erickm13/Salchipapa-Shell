#!/usr/bin/env bash
# Atajos de Neovim para el glosario de la isla (Super+/, pestaña Neovim): JSON por stdout.
# Arrancar Neovim con LazyVim tarda ~2 s, así que se guarda en caché y solo se regenera si cambió
# algo en la config (~/.config/nvim, incluido lazy-lock.json) o se pasa --refresh.
set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
conf="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/nvim")"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/nvim-keybinds.json"
mkdir -p "$(dirname "$cache")"

command -v nvim >/dev/null && [ -d "$conf" ] || {
    echo "[]"
    exit 0
}

if [ "${1:-}" != "--refresh" ] && [ -s "$cache" ] && [ -z "$(find "$conf" -newer "$cache" -print -quit 2>/dev/null)" ] &&
    [ "$cache" -nt "$here/nvim-keybinds.lua" ]; then
    cat "$cache"
    exit 0
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
# Desde /tmp (sin .nvim.lua de ningún proyecto), sin shada ni swap; -V1 para saber dónde se definió
# cada atajo
if (cd /tmp && timeout 30 nvim --headless -V1 -i NONE -n -c "luafile $here/nvim-keybinds.lua" -c "qa!" >"$tmp" 2>/dev/null) &&
    jq -e 'type == "array"' "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$cache"
    trap - EXIT
fi
cat "$cache" 2>/dev/null || echo "[]"
