#!/usr/bin/env bash
# Aplica un esquema de color propio (sin caelestia): escribe el estado que leen la shell
# (colors.json) y Hyprland (colors.conf, formato `$clave = hex`).
#
# Uso:
#   apply-colors.sh scheme <nombre> [flavour]   -> de shell/themes/schemes.json (temas de caelestia guardados)
#   apply-colors.sh file <palette.json>         -> un JSON { "role": "hex", ... } (p.ej. salida de matugen)
#
# Tras escribir el estado, la shell se recolorea sola (FileView). Para el glow de ventanas
# se recarga Hyprland.
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$HOME/proyects/Salchipapa-Shell}"
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

# Helper: valor de un rol (hex sin #), con fallback gris
c() { echo "$pal" | jq -r --arg k "$1" '.[$k] // "808080"'; }

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
EOF
}

for d in gtk-3.0 gtk-4.0; do
    mkdir -p "$HOME/.config/$d"
    gtk_css >"$HOME/.config/$d/gtk.css"
done

# ------------------------------------------------------------------ kitty
kdir="$HOME/.config/kitty"
if [ -d "$kdir" ]; then
    cat >"$kdir/salchipapa-colors.conf" <<EOF
# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.
background #$(c background)
foreground #$(c onBackground)
cursor #$(c primary)
cursor_text_color #$(c onPrimary)
selection_background #$(c primary)
selection_foreground #$(c onPrimary)
color0  #$(c surfaceContainerLowest)
color8  #$(c outline)
color1  #$(c error)
color9  #$(c error)
color2  #$(c tertiary)
color10 #$(c tertiary)
color3  #$(c secondary)
color11 #$(c secondary)
color4  #$(c primary)
color12 #$(c primary)
color5  #$(c tertiary)
color13 #$(c tertiary)
color6  #$(c secondary)
color14 #$(c secondary)
color7  #$(c onSurfaceVariant)
color15 #$(c onBackground)
EOF
    # Incluir el archivo al final de kitty.conf (gana sobre colores inline)
    if [ -f "$kdir/kitty.conf" ] && ! grep -qxF "include salchipapa-colors.conf" "$kdir/kitty.conf"; then
        printf '\ninclude salchipapa-colors.conf\n' >>"$kdir/kitty.conf"
    fi
fi

# --------------------------------------------- Qt (qtengine) + KDE (kdeglobals)
# Formato KDE colorscheme, reutilizado por qtengine (apps Qt no-KDE) y kdeglobals (apps KDE: Dolphin…)
kde_colors() {
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

# ------------------------------------------------------------------ foot
fdir="$HOME/.config/foot"
if [ -d "$fdir" ]; then
    cat >"$fdir/salchipapa-colors.ini" <<EOF
[colors]
foreground=$(c onBackground)
background=$(c background)
regular0=$(c surfaceContainerLowest)
regular1=$(c error)
regular2=$(c tertiary)
regular3=$(c secondary)
regular4=$(c primary)
regular5=$(c tertiary)
regular6=$(c secondary)
regular7=$(c onSurfaceVariant)
bright0=$(c outline)
bright1=$(c error)
bright2=$(c tertiary)
bright3=$(c secondary)
bright4=$(c primary)
bright5=$(c tertiary)
bright6=$(c secondary)
bright7=$(c onBackground)
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
if [ -d "$ydir" ]; then
    cat >"$ydir/theme.toml" <<EOF
# Generado por Salchipapa-Shell (apply-colors.sh). No editar a mano.
[mgr]
cwd = { fg = "#$(c primary)" }
hovered = { reversed = true }
find_keyword = { fg = "#$(c tertiary)", bold = true }
marker_copied = { fg = "#$(c tertiary)", bg = "#$(c tertiary)" }
marker_cut = { fg = "#$(c error)", bg = "#$(c error)" }
marker_selected = { fg = "#$(c primary)", bg = "#$(c primary)" }
border_symbol = "│"
border_style = { fg = "#$(c outline)" }

[tabs]
active = { fg = "#$(c onPrimary)", bg = "#$(c primary)", bold = true }
inactive = { fg = "#$(c onSurfaceVariant)", bg = "#$(c surfaceContainer)" }

[mode]
normal_main = { fg = "#$(c onPrimary)", bg = "#$(c primary)", bold = true }
normal_alt = { fg = "#$(c primary)", bg = "#$(c surfaceContainer)" }
select_main = { fg = "#$(c onTertiary)", bg = "#$(c tertiary)", bold = true }
select_alt = { fg = "#$(c tertiary)", bg = "#$(c surfaceContainer)" }
unset_main = { fg = "#$(c onError)", bg = "#$(c error)", bold = true }
unset_alt = { fg = "#$(c error)", bg = "#$(c surfaceContainer)" }
EOF
fi

# Recargar Hyprland para el glow (si hay sesión)
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ Live-reload
# GTK: toggle del tema para que las apps relean gtk.css (GTK3 en vivo; GTK4/libadwaita
# a veces necesita reabrir la ventana).
if command -v gsettings >/dev/null; then
    gt=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
    if [ -n "$gt" ]; then
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" 2>/dev/null || true
        sleep 0.4 # dar tiempo a que las apps GTK registren el cambio y relean gtk.css
        gsettings set org.gnome.desktop.interface gtk-theme "$gt" 2>/dev/null || true
    fi
fi
# kitty: recargar config en vivo
pkill -USR1 -x kitty 2>/dev/null || true
