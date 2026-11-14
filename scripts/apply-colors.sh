#!/usr/bin/env bash
# Aplica un esquema de color propio (sin caelestia): escribe el estado que leen la shell
# (colors.json) y Hyprland (colors.conf, formato `$clave = hex`).
#
# Uso:
#   apply-colors.sh scheme <nombre> [flavour]   -> de shell/themes/schemes.json (temas de caelestia guardados)
#   apply-colors.sh file <palette.json>         -> un JSON { "role": "hex", ... } (p.ej. salida de matugen)
#
# Tras escribir el estado, la shell se recolorea sola (FileView). Los colores de Hyprland
# se actualizan en vivo sin recargar la configuración ni reajustar los monitores.
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
schemes="$repo/shell/themes/schemes.json"
state="$HOME/.local/state/salchipapa-shell"
mkdir -p "$state"

mode="${1:-}"
arg="${2:-}"
flavour="${3:-}"

case "$mode" in
    scheme)
        if [ -n "$flavour" ]; then
            pal=$(jq -c --arg n "$arg" --arg f "$flavour" '.[$n][$f]' "$schemes")
        else
            # por defecto: el flavour con el background más oscuro (modo oscuro)
            pal=$(jq -c --arg n "$arg" '.[$n] | to_entries | min_by(.value.background // "ffffff") | .value' "$schemes")
        fi
        ;;
    file)
        pal=$(jq -c '.' "$arg")
        ;;
    *)
        echo "uso: apply-colors.sh scheme <nombre> [flavour] | file <palette.json>" >&2
        exit 1
        ;;
esac

if [ -z "$pal" ] || [ "$pal" = "null" ]; then
    echo "paleta no encontrada: $mode $arg" >&2
    exit 1
fi

# Estado para la shell (mismo formato que leía: { "colours": { role: hex } })
echo "{\"colours\": $pal}" | jq '.' >"$state/colors.json"

# Estado para Hyprland/Lua ($clave = hex)
echo "$pal" | jq -r 'to_entries[] | "$\(.key) = \(.value)"' >"$state/colors.conf"

# Esquema activo: el nombre (modo scheme) o 'dynamic' (modo file: matugen/wallpaper).
# Lo lee la shell para preseleccionar la card correcta en el selector de temas.
if [ "$mode" = "scheme" ]; then
    printf '%s' "$arg" >"$state/scheme"
else
    printf 'dynamic' >"$state/scheme"
fi

# Cargar TODA la paleta en memoria de una sola vez (1 jq, no ~190). Antes `c()` lanzaba
# un jq por cada rol -> era el grueso del tiempo. Ahora lee de un array asociativo.
declare -A COL
while IFS=$'\t' read -r _k _v; do COL[$_k]=$_v; done < <(echo "$pal" | jq -r 'to_entries[] | "\(.key)\t\(.value)"')
# Helper: valor de un rol (hex sin #), con fallback gris
c() { printf '%s' "${COL[$1]:-808080}"; }
# Helper: color ANSI i (0-15) de la terminal (casilla 1 = rojo, 2 = verde, 3 = amarillo...).
# Los temas con la paleta de terminal oficial usan su term0-term15. El resto (los generados por
# caelestia, salchipapa y matugen) traen term* sin ese orden y se rellenan con los roles.
ANSI_SCHEMES=" gruvbox solarized-osaka gentleman-kanagawa-blur "
TERM_ROLES=(surfaceContainerLowest error tertiary secondary primary tertiary secondary onSurfaceVariant
    outline error tertiary secondary primary tertiary secondary onBackground)
use_term=false
[ "$mode" = "scheme" ] && [[ "$ANSI_SCHEMES" == *" $arg "* ]] && use_term=true
t() { if $use_term && [ -n "${COL[term$1]:-}" ]; then printf '%s' "${COL[term$1]}"; else c "${TERM_ROLES[$1]}"; fi; }

# Temas hechos a mano: shell/themes/<tema>/ trae un archivo por app (yazi.toml, fish.fish, fzf,
# eza.yml, starship.toml, bat…). theme_file <archivo> da su ruta si el tema elegido lo trae; si no,
# esa app usa su estilo por defecto (nombres ANSI: la paleta de la terminal). Añadir un tema nuevo
# = crear su carpeta, sin tocar este script.
theme_dir="$repo/shell/themes/$arg"
theme_file() { [ "$mode" = "scheme" ] && [ -f "$theme_dir/$1" ] && printf '%s' "$theme_dir/$1"; }
# Fondo de la terminal: el del tema (terminal-bg, un hex sin #) o el background de la paleta.
term_bg() { if f=$(theme_file terminal-bg); then head -n1 "$f"; else c background; fi; }

# ------------------------------------------------------------------ GTK 3 / 4
gtk_css() {
    cat <<EOF
/* Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano. */
@define-color accent_color #$(c primary);
@define-color accent_bg_color #$(c primary);
@define-color accent_fg_color #$(c onPrimary);
@define-color destructive_color #$(c error);
@define-color destructive_bg_color #$(c error);
@define-color destructive_fg_color #$(c onError);
@define-color success_color #$(c tertiary);
@define-color warning_color #$(c secondary);
@define-color error_color #$(c error);
@define-color window_bg_color #$(c background);
@define-color window_fg_color #$(c onBackground);
@define-color view_bg_color #$(c surfaceContainerLowest);
@define-color view_fg_color #$(c onSurface);
@define-color headerbar_bg_color #$(c surfaceContainerLow);
@define-color headerbar_fg_color #$(c onSurface);
@define-color headerbar_border_color #$(c onSurface);
@define-color headerbar_backdrop_color #$(c surface);
@define-color card_bg_color #$(c surfaceContainerLow);
@define-color card_fg_color #$(c onSurface);
@define-color popover_bg_color #$(c surfaceContainer);
@define-color popover_fg_color #$(c onSurface);
@define-color dialog_bg_color #$(c surfaceContainerHigh);
@define-color dialog_fg_color #$(c onSurface);
@define-color sidebar_bg_color #$(c surfaceContainerLow);
@define-color sidebar_fg_color #$(c onSurface);
@define-color sidebar_backdrop_color #$(c surface);
@define-color sidebar_border_color #$(c outlineVariant);

/* Nombres clásicos GTK3 (Adwaita) — los usan Thunar, Nemo y demás apps GTK3 */
@define-color theme_bg_color #$(c background);
@define-color theme_fg_color #$(c onBackground);
@define-color theme_base_color #$(c surfaceContainerLowest);
@define-color theme_text_color #$(c onSurface);
@define-color theme_selected_bg_color #$(c primary);
@define-color theme_selected_fg_color #$(c onPrimary);
@define-color theme_unfocused_bg_color #$(c background);
@define-color theme_unfocused_fg_color #$(c onBackground);
@define-color theme_unfocused_base_color #$(c surfaceContainerLowest);
@define-color theme_unfocused_text_color #$(c onSurface);
@define-color theme_unfocused_selected_bg_color #$(c primary);
@define-color theme_unfocused_selected_fg_color #$(c onPrimary);
@define-color insensitive_bg_color #$(c surface);
@define-color insensitive_fg_color #$(c onSurfaceVariant);
@define-color insensitive_base_color #$(c surface);
@define-color theme_tooltip_bg_color #$(c surfaceContainer);
@define-color theme_tooltip_fg_color #$(c onSurface);
@define-color borders #$(c outlineVariant);
@define-color unfocused_borders #$(c outlineVariant);
@define-color wm_bg #$(c surfaceContainerLow);
@define-color wm_title #$(c onSurface);
EOF
}

# El del tema (gtk.css) o, por defecto, el generado con los roles de la paleta.
for d in gtk-3.0 gtk-4.0; do
    mkdir -p "$HOME/.config/$d"
    if f=$(theme_file gtk.css); then
        { echo "/* Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano. */"; cat "$f"; } \
            >"$HOME/.config/$d/gtk.css"
    else
        gtk_css >"$HOME/.config/$d/gtk.css"
    fi
done

# ------------------------------------------------------------------ kitty
kdir="$HOME/.config/kitty"
if [ -d "$kdir" ]; then
    cat >"$kdir/salchipapa-colors.conf" <<EOF
# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.
background #$(term_bg)
foreground #$(c onBackground)
cursor #$(c primary)
cursor_text_color #$(c onPrimary)
selection_background #$(c primary)
selection_foreground #$(c onPrimary)
color0  #$(t 0)
color1  #$(t 1)
color2  #$(t 2)
color3  #$(t 3)
color4  #$(t 4)
color5  #$(t 5)
color6  #$(t 6)
color7  #$(t 7)
color8  #$(t 8)
color9  #$(t 9)
color10 #$(t 10)
color11 #$(t 11)
color12 #$(t 12)
color13 #$(t 13)
color14 #$(t 14)
color15 #$(t 15)
EOF
    # Incluir el archivo al final de kitty.conf (gana sobre colores inline)
    if [ -f "$kdir/kitty.conf" ] && ! grep -qxF "include salchipapa-colors.conf" "$kdir/kitty.conf"; then
        printf '\ninclude salchipapa-colors.conf\n' >>"$kdir/kitty.conf"
    fi
fi

# --------------------------------------------- Qt (qtengine) + KDE (kdeglobals)
# Formato KDE colorscheme, reutilizado por qtengine (apps Qt no-KDE) y kdeglobals (apps KDE: Dolphin…)
kde_colors() {
    # El del tema (qt.colors) o, por defecto, generado con los roles de la paleta.
    if f=$(theme_file qt.colors); then
        cat "$f"
        return
    fi
    cat <<EOF
[Colors:Window]
BackgroundNormal=#$(c background)
BackgroundAlternate=#$(c surfaceContainerLow)
ForegroundNormal=#$(c onBackground)
ForegroundInactive=#$(c onSurfaceVariant)
ForegroundActive=#$(c primary)
ForegroundLink=#$(c primary)
ForegroundNegative=#$(c error)
DecorationFocus=#$(c primary)
DecorationHover=#$(c primary)

[Colors:View]
BackgroundNormal=#$(c surfaceContainerLowest)
BackgroundAlternate=#$(c surfaceContainerLow)
ForegroundNormal=#$(c onSurface)
ForegroundInactive=#$(c onSurfaceVariant)
ForegroundActive=#$(c primary)
ForegroundNegative=#$(c error)
DecorationFocus=#$(c primary)
DecorationHover=#$(c primary)

[Colors:Button]
BackgroundNormal=#$(c surfaceContainer)
BackgroundAlternate=#$(c surfaceContainerHigh)
ForegroundNormal=#$(c onSurface)
ForegroundInactive=#$(c onSurfaceVariant)
ForegroundNegative=#$(c error)
DecorationFocus=#$(c primary)
DecorationHover=#$(c primary)

[Colors:Selection]
BackgroundNormal=#$(c primary)
ForegroundNormal=#$(c onPrimary)
ForegroundActive=#$(c onPrimary)
ForegroundInactive=#$(c onPrimary)

[Colors:Tooltip]
BackgroundNormal=#$(c surfaceContainerHigh)
ForegroundNormal=#$(c onSurface)

[Colors:Complementary]
BackgroundNormal=#$(c background)
ForegroundNormal=#$(c onBackground)
DecorationFocus=#$(c primary)

[Colors:Header]
BackgroundNormal=#$(c surfaceContainerLow)
ForegroundNormal=#$(c onSurface)
DecorationFocus=#$(c primary)

[WM]
activeBackground=#$(c surfaceContainer)
activeForeground=#$(c onSurface)
inactiveBackground=#$(c surface)
inactiveForeground=#$(c onSurfaceVariant)
EOF
}

# qtengine (apps Qt que no son KDE)
qdir="$HOME/.config/qtengine"
if [ -d "$qdir" ]; then
    {
        echo "[General]"
        echo "Name=Salchipapa"
        echo
        kde_colors
    } >"$qdir/salchipapa.colors"
    if command -v jq >/dev/null && [ -f "$qdir/config.json" ]; then
        tmp=$(mktemp)
        jq '.theme.colorScheme = "~/.config/qtengine/salchipapa.colors"' "$qdir/config.json" >"$tmp" && mv "$tmp" "$qdir/config.json"
    fi
fi

# kdeglobals (apps KDE: Dolphin, Kate, Gwenview…)
{
    echo "[General]"
    echo "ColorScheme=Salchipapa"
    echo
    echo "[Icons]"
    echo "Theme=Papirus-Dark"
    echo
    kde_colors
} >"$HOME/.config/kdeglobals"

# ------------------------------------------------------------------ eza (ls)
# Color de los directorios de `ls` (eza --icons); lo relee en cada ejecución. El del tema
# (eza.yml) o, por defecto, la casilla azul de la terminal en negrita.
mkdir -p "$HOME/.config/eza"
if f=$(theme_file eza.yml); then
    { echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; cat "$f"; } \
        >"$HOME/.config/eza/theme.yml"
else
    cat >"$HOME/.config/eza/theme.yml" <<EOF
# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.
colourful: true
filekinds:
  directory: {foreground: Blue, is_bold: true}
EOF
fi

# ------------------------------------------------------------------ bat
# Tema de bat (lo relee en cada ejecución): el suyo propio si bat lo trae; si no, `ansi` (la
# paleta de la terminal). El fish de Salchipapa.Dots no define BAT_THEME si existe este archivo.
# El del tema (archivo `bat` con el nombre de un tmTheme de shell/themes/bat/ o de los que trae
# bat) o, si no, `ansi` (la paleta de la terminal).
if f=$(theme_file bat); then
    bat_theme=$(head -n1 "$f")
else
    bat_theme='ansi'
fi
mkdir -p "$HOME/.config/bat"
# Temas y sintaxis propios del repo (shell/themes/bat, los genera scripts/build-bat-theme.py):
# enlazados en la carpeta de bat. Las sintaxis (bash con más detalle: números, true/false, case)
# valen para cualquier tema. bat los lee de su caché, que se reconstruye solo si falta el tema o
# algún archivo es más nuevo que ella.
bat_repo="$repo/shell/themes/bat"
if command -v bat >/dev/null && [ -d "$bat_repo" ]; then
    bat_conf="$(bat --config-dir)"
    mkdir -p "$bat_conf/themes" "$bat_conf/syntaxes"
    bat_files=("$bat_repo"/*.tmTheme "$bat_repo"/syntaxes/*.sublime-syntax)
    for f in "${bat_files[@]}"; do
        [ -f "$f" ] || continue
        case "$f" in
            *.tmTheme) ln -sfn "$f" "$bat_conf/themes/${f##*/}" ;;
            *) ln -sfn "$f" "$bat_conf/syntaxes/${f##*/}" ;;
        esac
    done
    bat_cache="$(bat --cache-dir)/themes.bin"
    bat_stale=false
    [ -f "$bat_cache" ] || bat_stale=true
    for f in "${bat_files[@]}"; do [ "$f" -nt "$bat_cache" ] && bat_stale=true; done
    if [ -f "$bat_repo/$bat_theme.tmTheme" ] \
        && ! bat --list-themes --color=never 2>/dev/null | grep -qxF "$bat_theme"; then
        bat_stale=true
    fi
    if $bat_stale; then
        # bat toma un argumento "cache" como archivo si existe en el directorio actual
        (cd / && bat cache --build >/dev/null 2>&1) || bat_theme='gruvbox-dark'
    fi
fi
# --italic-text: bat no pone cursivas si no se le pide (comentarios en cursiva, como nvim)
printf '# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.\n--theme="%s"\n--italic-text=always\n' "$bat_theme" >"$HOME/.config/bat/config"

# delta (diffs de git y lazygit): el mismo tema de sintaxis que bat y las decoraciones del tema
# (delta.gitconfig). ~/.gitconfig lo incluye después del delta.gitconfig de los dotfiles, así que
# gana a su syntax-theme. delta lee los temas de la caché de bat.
{
    echo "# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano."
    echo "[delta]"
    echo "    syntax-theme = $bat_theme"
    if f=$(theme_file delta.gitconfig); then cat "$f"; fi
} >"$state/delta.gitconfig"
# shellcheck disable=SC2088 # la ~ va literal: la expande git, como las otras include.path
if command -v git >/dev/null && ! git config --global --get-all include.path 2>/dev/null |
    grep -qxF "~/.local/state/salchipapa-shell/delta.gitconfig"; then
    git config --global --add include.path "~/.local/state/salchipapa-shell/delta.gitconfig"
fi

# ------------------------------------------------------------------ fish (resaltado)
# Colores del resaltado de fish del tema (fish.fish). Sin él, el config.fish de Salchipapa.Dots usa
# nombres ANSI. Las fish abiertas lo recargan al cambiar la universal `salchipapa_theme` (handler
# en config.fish).
fish_colors="$state/fish-colors.fish"
if f=$(theme_file fish.fish); then
    { echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; cat "$f"; } >"$fish_colors"
else
    rm -f "$fish_colors"
fi
if command -v fish >/dev/null; then
    # con la hora: cambia siempre, aunque se vuelva a aplicar el mismo tema
    fish -c "set -U salchipapa_theme '${arg:-dynamic} $(date +%s%N)'" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ starship
# Copia del starship.toml de los dotfiles con la paleta del tema (starship.toml del tema, una tabla
# [palettes.theme]); sin ella, la paleta "salchipapa" de los dotfiles (nombres ANSI). fish apunta
# STARSHIP_CONFIG a la copia y starship la relee en cada prompt. Si el starship.toml de los
# dotfiles cambia, se ve al volver a aplicar un tema.
starship_src="$HOME/.config/starship.toml"
if [ -f "$starship_src" ]; then
    {
        echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $starship_src. No editar:"
        echo "# se edita aquel (o la paleta del tema) y se vuelve a aplicar el tema."
        if f=$(theme_file starship.toml); then
            sed 's/^palette = .*/palette = "theme"/' "$(readlink -f "$starship_src")"
            echo
            cat "$f"
        else
            sed 's/^palette = .*/palette = "salchipapa"/' "$(readlink -f "$starship_src")"
        fi
    } >"$state/starship.toml.tmp" && mv "$state/starship.toml.tmp" "$state/starship.toml"
fi

# ------------------------------------------------------------------ fzf
# Opciones de color de fzf (FZF_DEFAULT_OPTS_FILE en el fish de Salchipapa.Dots); fzf lo lee cada
# vez que se abre. Las del tema (fzf) o, por defecto, nombres ANSI (la paleta de la terminal).
if f=$(theme_file fzf); then
    cp "$f" "$state/fzf-colors"
else
    cat >"$state/fzf-colors" <<'EOF'
--color=fg:-1,bg:-1,gutter:-1,hl:blue,fg+:bright-white,bg+:bright-black,hl+:bright-blue
--color=prompt:blue,pointer:magenta,marker:green,info:cyan,spinner:cyan,header:yellow,border:bright-black,label:cyan
EOF
fi

# ------------------------------------------------------------------ btop
# El del tema (btop.theme) como ~/.config/btop/themes/salchipapa.theme; sin él, "TTY" (los 16
# colores de la terminal). btop lee el tema al abrirse. Ojo: btop guarda btop.conf al salir, así
# que si está abierto mientras se cambia de tema, al cerrarlo deja el color_theme que tenía.
btop_conf="$HOME/.config/btop/btop.conf"
if [ -f "$btop_conf" ]; then
    if f=$(theme_file btop.theme); then
        mkdir -p "$HOME/.config/btop/themes"
        { echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; cat "$f"; } \
            >"$HOME/.config/btop/themes/salchipapa.theme"
        btop_theme='salchipapa'
    else
        btop_theme='TTY'
    fi
    sed -i "s|^color_theme = .*|color_theme = \"$btop_theme\"|" "$btop_conf"
fi

# ------------------------------------------------------------------ lazygit
# Colores del tema (lazygit.yml) en el estado; fish los añade a LG_CONFIG_FILE junto al config.yml
# de los dotfiles. Sin él, lazygit con sus colores. Desde nvim, snacks pone los suyos.
if f=$(theme_file lazygit.yml); then
    { echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; cat "$f"; } \
        >"$state/lazygit-theme.yml"
else
    rm -f "$state/lazygit-theme.yml"
fi

# ------------------------------------------------------------------ herdr
# herdr no puede incluir otro archivo: ~/.config/herdr/config.toml pasa a ser una copia del de los
# dotfiles con la sección [theme] del tema (herdr.toml); sin ella, la de los dotfiles. Se recarga
# al momento. La primera vez es un enlace a los dotfiles: se apunta su ruta para las siguientes.
# Si cambia el config.toml de los dotfiles, se ve al volver a aplicar un tema.
herdr_cfg="$HOME/.config/herdr/config.toml"
if [ -L "$herdr_cfg" ]; then
    readlink -f "$herdr_cfg" >"$state/herdr-source"
fi
herdr_src="$(cat "$state/herdr-source" 2>/dev/null || true)"
if [ -n "$herdr_src" ] && [ -f "$herdr_src" ]; then
    {
        echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $herdr_src."
        echo "# No editar: se edita aquel y se vuelve a aplicar el tema (Super+T)."
        if f=$(theme_file herdr.toml); then
            # quitar [theme] y sus subtablas ([theme.custom]…) y poner las del tema al final
            awk '/^\[/{skip = ($0 ~ /^\[theme(\]|\.)/)} !skip' "$herdr_src"
            echo
            cat "$f"
        else
            cat "$herdr_src"
        fi
    } >"$herdr_cfg.tmp" && mv -f "$herdr_cfg.tmp" "$herdr_cfg"
    if command -v herdr >/dev/null && herdr status server 2>/dev/null | grep -q running; then
        herdr server reload-config >/dev/null 2>&1 || true
    fi
fi

# ------------------------------------------------------------------ nvim
# Colorscheme del tema (archivo `nvim` con su nombre) para el colorscheme.lua de Salchipapa.Dots;
# sin él, el de siempre de los dotfiles. Los nvim abiertos lo cambian al momento: cada uno escucha
# en un socket ($XDG_RUNTIME_DIR/nvim.*) y se le pide que llame a SalchipapaApplyColorscheme().
if f=$(theme_file nvim); then
    cp "$f" "$state/nvim-colorscheme"
else
    rm -f "$state/nvim-colorscheme"
fi
if command -v nvim >/dev/null; then
    for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*; do
        [ -S "$sock" ] || continue
        timeout 2 nvim --server "$sock" --remote-expr \
            "luaeval('_G.SalchipapaApplyColorscheme and _G.SalchipapaApplyColorscheme()')" >/dev/null 2>&1 || true
    done
fi

# ------------------------------------------------------------------ fastfetch
# Opciones de color del tema (fastfetch: una opción o valor por línea, p. ej. --color-keys y su
# color) para la función fastfetch de fish. Sin él, los colores del config.jsonc de los dotfiles.
if f=$(theme_file fastfetch); then
    cp "$f" "$state/fastfetch-args"
else
    rm -f "$state/fastfetch-args"
fi

# ------------------------------------------------------------------ Spotify (Spicetify)
# Tema "Salchipapa" de Spicetify: el diseño text (shell/themes/spicetify/text) con los colores del
# tema (spicetify.ini) como esquema "base". Sin él no se toca Spicetify. Los temas del Marketplace
# solo funcionan con current_theme = marketplace. Spotify toma los colores al abrirse (spicetify refresh los deja en el
# cliente parcheado; si Spotify está abierto, se ven al reiniciarlo).
if command -v spicetify >/dev/null && f=$(theme_file spicetify.ini); then
    sdir="$(spicetify path userdata 2>/dev/null || echo "$HOME/.config/spicetify")/Themes/Salchipapa"
    mkdir -p "$sdir"
    { echo "; Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; echo "[base]"; cat "$f"; } \
        >"$sdir/color.ini"
    # Diseño: el user.css de text (shell/themes/spicetify/text, MIT); los colores son los del tema.
    # + spotify-1.3.css: sus recuadros de paneles sobre los nombres que siguen en Spotify 1.3.x.
    cat "$repo/shell/themes/spicetify/text/user.css" "$repo/shell/themes/spicetify/text/spotify-1.3.css" >"$sdir/user.css"
    spicetify config current_theme Salchipapa color_scheme base >/dev/null 2>&1 || true
    spicetify refresh >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ VS Code
# Ajustes del tema (vscode.json: workbench.colorTheme y colorCustomizations) mezclados en el
# settings.json del usuario; VS Code lo recarga solo. Sin él, vuelve el colorTheme que tenía el
# usuario (guardado la primera vez). La extensión del tema la instala el usuario (README del tema).
if [ -f "$HOME/.config/Code/User/settings.json" ]; then
    if f=$(theme_file vscode.json); then
        python3 "$repo/scripts/vscode-settings.py" apply "$f" "$state" || true
    else
        python3 "$repo/scripts/vscode-settings.py" restore "$state" || true
    fi
fi

# ------------------------------------------------------------------ Vesktop (Vencord)
# Colores del tema (vesktop.css: variables de color de system24) en un bloque marcado del QuickCSS
# de Vesktop; Vencord lo recarga en vivo. Lo que el usuario tenga fuera del bloque no se toca. Sin
# el archivo, se quita el bloque (vuelven los colores del tema de Vesktop).
vcss="$HOME/.config/vesktop/settings/quickCss.css"
if [ -d "$(dirname "$vcss")" ]; then
    f=$(theme_file vesktop.css) || f=""
    python3 - "$vcss" "$f" <<'PY' || true
import re, sys
from pathlib import Path
path, theme = Path(sys.argv[1]), sys.argv[2]
begin, end = "/* salchipapa-shell: tema (no editar este bloque) */", "/* salchipapa-shell: fin */"
text = path.read_text() if path.exists() else ""
text = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.S)
if theme:
    text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + begin + "\n" + Path(theme).read_text().rstrip("\n") + "\n" + end + "\n"
path.write_text(text)
PY
fi

# ------------------------------------------------------------------ foot
fdir="$HOME/.config/foot"
if [ -d "$fdir" ]; then
    cat >"$fdir/salchipapa-colors.ini" <<EOF
[colors-dark]
foreground=$(c onBackground)
background=$(term_bg)
regular0=$(t 0)
regular1=$(t 1)
regular2=$(t 2)
regular3=$(t 3)
regular4=$(t 4)
regular5=$(t 5)
regular6=$(t 6)
regular7=$(t 7)
bright0=$(t 8)
bright1=$(t 9)
bright2=$(t 10)
bright3=$(t 11)
bright4=$(t 12)
bright5=$(t 13)
bright6=$(t 14)
bright7=$(t 15)
selection-foreground=$(c onPrimary)
selection-background=$(c primary)
EOF
    # Incluir al principio de foot.ini (preamble) si no está
    if [ -f "$fdir/foot.ini" ] && ! grep -qF "salchipapa-colors.ini" "$fdir/foot.ini"; then
        sed -i "1i include=$fdir/salchipapa-colors.ini" "$fdir/foot.ini"
    fi
fi

# ------------------------------------------------------------------ yazi
ydir="$HOME/.config/yazi"
# El del tema (yazi.toml) o, por defecto, uno con nombres ANSI (sigue la paleta de la terminal y
# cambia en vivo). yazi lee el theme.toml al abrirse.
if [ -d "$ydir" ] && f=$(theme_file yazi.toml); then
    { echo "# Generado por Salchipapa-Shell (apply-colors.sh) desde $f. No editar a mano."; cat "$f"; } \
        >"$ydir/theme.toml"
elif [ -d "$ydir" ]; then
    cat >"$ydir/theme.toml" <<EOF
# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.
# Usa nombres ANSI (no hex) para que yazi siga la paleta del terminal y los
# colores se actualicen EN VIVO (vía OSC) sin tener que reiniciar yazi.
# Mapa: blue=primary, yellow=secondary, green=tertiary, red=error,
#       darkgray=outline, gray=onSurfaceVariant, black=fondo.
[mgr]
cwd = { fg = "blue" }
hovered = { reversed = true }
find_keyword = { fg = "yellow", bold = true }
marker_copied = { fg = "green", bg = "green" }
marker_cut = { fg = "red", bg = "red" }
marker_selected = { fg = "blue", bg = "blue" }
border_symbol = "│"
border_style = { fg = "darkgray" }

[tabs]
active = { fg = "black", bg = "blue", bold = true }
inactive = { fg = "gray", bg = "black" }

[mode]
normal_main = { fg = "black", bg = "blue", bold = true }
normal_alt = { fg = "blue", bg = "black" }
select_main = { fg = "black", bg = "green", bold = true }
select_alt = { fg = "green", bg = "black" }
unset_main = { fg = "black", bg = "red", bold = true }
unset_alt = { fg = "red", bg = "black" }

[status]
# Barra inferior: ruta/cwd, permisos y progreso.
cwd = { fg = "blue" }
perm_type = { fg = "blue" }
perm_read = { fg = "green" }
perm_write = { fg = "yellow" }
perm_exec = { fg = "red" }
perm_sep = { fg = "darkgray" }
progress_label = { fg = "white", bold = true }
progress_normal = { fg = "blue", bg = "black" }
progress_error = { fg = "red", bg = "black" }
EOF
fi

# ------------------------------------------------- Iconos de carpeta (Papirus)
# Papirus está en /usr/share (de root). Para teñir las carpetas con el tema hace
# falta una regla sudoers acotada (ver README / instalar-papirus-sudo):
#   <usuario> ALL=(root) NOPASSWD: /usr/bin/papirus-folders
# Si esa regla existe, elegimos el color Papirus más cercano al 'primary' y lo
# aplicamos sin contraseña. Si no, se omite en silencio (no rompe nada).
if command -v papirus-folders >/dev/null && [ -d /usr/share/icons/Papirus-Dark ] &&
    sudo -n papirus-folders -V >/dev/null 2>&1; then
    # El del tema (archivo `papirus` con el nombre de un color de papirus-folders -l) o, si no, el
    # más cercano al primary.
    if f=$(theme_file papirus); then
        folder_color=$(head -n1 "$f")
    else
    folder_color=$(python3 - "$(c primary)" 2>/dev/null <<'PY'
import sys, colorsys
hexv = sys.argv[1].lstrip('#')
r, g, b = (int(hexv[i:i + 2], 16) / 255 for i in (0, 2, 4))
_, L, S = colorsys.rgb_to_hls(r, g, b)
H = colorsys.rgb_to_hls(r, g, b)[0] * 360
cols = {
    'adwaita': '#3367d6', 'black': '#4d4d4d', 'blue': '#5294e2', 'bluegrey': '#607d8b',
    'breeze': '#3daee9', 'brown': '#ae8e6c', 'carmine': '#b0282d', 'cyan': '#00bcd4',
    'darkcyan': '#00838f', 'deeporange': '#ff7043', 'green': '#87b158', 'grey': '#8a8a8a',
    'indigo': '#5c6bc0', 'magenta': '#d81b60', 'nordic': '#81a1c1', 'orange': '#ff9800',
    'palebrown': '#c5a880', 'paleorange': '#ffb067', 'pink': '#f06292', 'red': '#e25252',
    'teal': '#16a085', 'violet': '#8c6dd0', 'white': '#d3d3d3', 'yaru': '#e95420', 'yellow': '#e4b400',
}
def hls(hx):
    hx = hx.lstrip('#'); rr, gg, bb = (int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(rr, gg, bb)
best, bd = 'blue', 1e9
for name, hx in cols.items():
    hh, ll, ss = hls(hx); HH = hh * 360
    dh = abs(H - HH); dh = min(dh, 360 - dh)
    if S < 0.12:  # tema casi gris -> favorece tonos neutros
        score = abs(L - ll) * 120 + ss * 220
    else:  # manda el MATIZ (tono); la saturación/luminosidad solo desempatan
        score = dh * 1.0 + abs(S - ss) * 25 + abs(L - ll) * 15
    if score < bd:
        bd = score; best = name
print(best)
PY
)
    fi
    # El cambio real (papirus-folders -u, ~4s) se hace AL FINAL en segundo plano,
    # para no retrasar el recoloreado de las apps (Thunar/terminal/shell).
fi

# Actualizar solo los colores de Hyprland (si hay sesión). Una recarga completa ejecutaba
# lua/monitors.lua y hacía que monitor-autodetect reaplicara el perfil de pantallas:
# la isla y el fondo parpadeaban como si Quickshell se hubiera reiniciado.
# Mantener estos roles alineados con lua/group.lua y lua/misc.lua. Las sombras las aplica
# WindowShadowSync.qml al cambiar Theme.shadow, conservando Appearance y Game Mode.
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl eval "hl.config({
        group = {
            col = {
                border_active = { colors = { 'rgba($(c primary)ee)', 'rgba($(c tertiary)ee)' }, angle = 45 },
                border_inactive = 'rgba($(c onSurfaceVariant)11)',
                border_locked_active = 'rgba($(c primary)ee)',
                border_locked_inactive = 'rgba($(c onSurfaceVariant)11)',
            },
            groupbar = {
                text_color = 'rgb($(c onPrimary))',
                col = {
                    active = 'rgba($(c primary)d4)',
                    inactive = 'rgba($(c outlineVariant)d4)',
                    locked_active = 'rgba($(c primary)d4)',
                    locked_inactive = 'rgba($(c secondary)d4)',
                },
            },
        },
        misc = { background_color = 'rgb($(c surfaceContainer))' },
    })" >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ Live-reload
# GTK: toggle del tema para que las apps relean gtk.css (GTK3 en vivo; GTK4/libadwaita
# a veces necesita reabrir la ventana).
if command -v gsettings >/dev/null; then
    # Toggle de gtk-theme (GNOME + Cinnamon/Nemo) para que relean gtk.css. UNA sola
    # pausa para todos los schemas (antes era una por schema -> el doble de lento).
    schemas="org.gnome.desktop.interface"
    gsettings list-schemas 2>/dev/null | grep -qx org.cinnamon.desktop.interface &&
        schemas="$schemas org.cinnamon.desktop.interface"
    saved=""
    for s in $schemas; do
        cur=$(gsettings get "$s" gtk-theme 2>/dev/null | tr -d "'")
        [ -n "$cur" ] || continue
        saved="$saved$s=$cur
"
        gsettings set "$s" gtk-theme "Adwaita" 2>/dev/null || true
    done
    sleep 0.4 # que las apps GTK registren el cambio y relean gtk.css
    printf '%s' "$saved" | while IFS='=' read -r s v; do
        [ -n "$s" ] && gsettings set "$s" gtk-theme "$v" 2>/dev/null || true
    done
fi
# (El refresco del tema de ICONOS por el nuevo color de carpeta va en el bloque de
#  segundo plano del final, tras papirus-folders.)

# Terminales (kitty, foot, cualquier terminal): colores en vivo por secuencias OSC
# (fg=OSC10, bg=OSC11, cursor=OSC12, paleta 0-15=OSC4). Se guardan para las nuevas terminales.
term_sequences() {
    local esc st
    esc=$'\033'
    st=$'\033\\'
    printf '%s]10;#%s%s' "$esc" "$(c onBackground)" "$st"
    printf '%s]11;#%s%s' "$esc" "$(term_bg)" "$st"
    printf '%s]12;#%s%s' "$esc" "$(c primary)" "$st"
    local i
    for i in $(seq 0 15); do
        printf '%s]4;%d;#%s%s' "$esc" "$i" "$(t "$i")" "$st"
    done
}
seqs=$(term_sequences)
printf '%s' "$seqs" >"$state/sequences.txt"
# Aplicar a las terminales abiertas (pts que podemos escribir)
for pts in /dev/pts/*; do
    [ -w "$pts" ] && printf '%s' "$seqs" >"$pts" 2>/dev/null || true
done

# conf.d de fish para que las terminales NUEVAS apliquen los colores al abrir
fconf="$HOME/.config/fish/conf.d/salchipapa-sequences.fish"
if [ -d "$HOME/.config/fish" ] && [ ! -f "$fconf" ]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    cat >"$fconf" <<'FISH'
# Colores de terminal (OSC) de Salchipapa-Shell — aplicados al abrir una shell interactiva
if status is-interactive
    and test -f "$HOME/.local/state/salchipapa-shell/sequences.txt"
    cat "$HOME/.local/state/salchipapa-shell/sequences.txt"
end
FISH
fi

# ------------------------------------------------------------------ Fondo del tema
# Si el tema tiene carpeta de fondos (~/Pictures/Wallpapers/<tema>/) y el fondo actual no es de
# ella, se pone uno al azar de ahí (wallpaper.sh … nocolors: solo el fondo). No cuando el tema lo
# aplica wallpaper.sh por haber elegido un fondo de esa carpeta.
# Con un fondo animado puesto, uno animado del tema (animated-themes.json) si el actual no lo es.
animated=$(cat "$state/animated" 2>/dev/null || true)
if [ "$mode" = "scheme" ] && [ -z "${SALCHIPAPA_FROM_WALLPAPER:-}" ] && [ -n "$animated" ]; then
    amap="$HOME/.config/salchipapa-shell/animated-themes.json"
    if [ "$(jq -r --arg id "$animated" '.[$id] // empty' "$amap" 2>/dev/null)" != "$arg" ]; then
        apick=$(jq -r --arg t "$arg" 'to_entries[] | select(.value == $t) | .key' "$amap" 2>/dev/null | shuf -n1)
        if [ -n "$apick" ]; then
            setsid -f "$repo/scripts/animated-wallpaper.sh" set "$apick" nocolors >/dev/null 2>&1 || true
        fi
    fi
elif [ "$mode" = "scheme" ] && [ -z "${SALCHIPAPA_FROM_WALLPAPER:-}" ]; then
    wdir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers/$arg"
    cur=$(cat "$state/wallpaper" 2>/dev/null || true)
    if [ -d "$wdir" ] && [ "${cur%/*}" != "$wdir" ]; then
        pick=$(find "$wdir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n1)
        if [ -n "$pick" ]; then
            "$repo/scripts/wallpaper.sh" "$pick" nocolors >/dev/null 2>&1 || true
        fi
    fi
fi

# -------------------------------- Color de carpeta Papirus (en SEGUNDO PLANO) --------------------------------
# papirus-folders -u tarda ~4s (reconstruye la caché de iconos). Lo dejamos para el final
# y desacoplado con setsid, para que el recoloreado de Thunar/terminal/shell sea instantáneo.
# Cuando termina, refresca el tema de iconos de las apps GTK (toggle de icon-theme) para que
# Thunar/Nemo repinten las carpetas con el color nuevo.
if [ -n "${folder_color:-}" ]; then
    bg_folders() {
        sudo -n papirus-folders -C "$folder_color" -t Papirus-Dark -u >/dev/null 2>&1 || return
        command -v gsettings >/dev/null || return
        for sch in org.gnome.desktop.interface org.cinnamon.desktop.interface; do
            cur=$(gsettings get "$sch" icon-theme 2>/dev/null | tr -d "'") || continue
            [ -z "$cur" ] && continue
            gsettings set "$sch" icon-theme Adwaita 2>/dev/null || true
            sleep 0.3
            gsettings set "$sch" icon-theme "$cur" 2>/dev/null || true
        done
    }
    setsid -f sh -c "$(declare -f bg_folders); folder_color='$folder_color' bg_folders" >/dev/null 2>&1
fi
