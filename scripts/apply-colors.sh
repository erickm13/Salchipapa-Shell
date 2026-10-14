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
    # El cambio real (papirus-folders) + el refresco de iconos se hacen AL FINAL
    # en segundo plano: papirus-folders tarda ~3s y si no, bloquearía todo lo demás.
fi

# Recargar Hyprland para el glow (si hay sesión)
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ Live-reload
# NOTA: los "avisos" para apps GTK (toggle gtk-theme, con sleeps) y KDE (señal D-Bus),
# y el color de carpeta de Papirus, se hacen AL FINAL en segundo plano (ver más abajo),
# para que esto no bloquee. Aquí solo lo instantáneo: terminales por OSC.

# Terminales (kitty, foot, cualquier terminal): colores en vivo por secuencias OSC
# (fg=OSC10, bg=OSC11, cursor=OSC12, paleta 0-15=OSC4). Se guardan para las nuevas terminales.
term_sequences() {
    local esc st
    esc=$'\033'
    st=$'\033\\'
    printf '%s]10;#%s%s' "$esc" "$(c onBackground)" "$st"
    printf '%s]11;#%s%s' "$esc" "$(c background)" "$st"
    printf '%s]12;#%s%s' "$esc" "$(c primary)" "$st"
    local roles=(surfaceContainerLowest error tertiary secondary primary tertiary secondary onSurfaceVariant outline error tertiary secondary primary tertiary secondary onBackground)
    local i
    for i in $(seq 0 15); do
        printf '%s]4;%d;#%s%s' "$esc" "$i" "$(c "${roles[$i]}")" "$st"
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

# ------------------------------------------------- Carpetas Papirus (en segundo plano)
# papirus-folders tarda ~3s; lo dejamos para el final y DESACOPLADO (&) para que todo
# lo anterior (colores, terminal, GTK, KDE) se aplique al instante. Cuando termina,
# refresca el tema de iconos de las apps GTK y avisa a KDE para el nuevo color.
# --------------------------------------------- Avisos a otras apps (en segundo plano)
# Todo esto solo hace que las apps YA ABIERTAS relean el tema; tiene sleeps y/o es lento
# (papirus-folders ~3s), así que va desacoplado con setsid para no retrasar nada.
bg_nudges() {
    # GTK (Thunar, Nemo, GTK3 en general): toggle de gtk-theme -> relee gtk.css.
    toggle_key() { # $1=schema $2=key $3=valor nuevo temporal
        local cur
        cur=$(gsettings get "$1" "$2" 2>/dev/null | tr -d "'") || return
        [ -z "$cur" ] && return
        gsettings set "$1" "$2" "$3" 2>/dev/null || true
        sleep 0.3
        gsettings set "$1" "$2" "$cur" 2>/dev/null || true
    }
    if command -v gsettings >/dev/null; then
        toggle_key org.gnome.desktop.interface gtk-theme Adwaita
        gsettings list-schemas 2>/dev/null | grep -qx org.cinnamon.desktop.interface &&
            toggle_key org.cinnamon.desktop.interface gtk-theme Adwaita
    fi
    # KDE (Dolphin, Kate…): paleta recargada en vivo.
    command -v dbus-send >/dev/null &&
        dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true

    # Color de carpeta Papirus (si hay regla sudoers) + refresco del tema de iconos.
    # -u reconstruye icon-theme.cache: sin ella las apps GTK siguen mostrando el
    # icono de carpeta viejo cacheado. Va en 2º plano, así su coste (~2s) no molesta.
    if [ -n "$folder_color" ] && sudo -n papirus-folders -C "$folder_color" -t Papirus-Dark -u >/dev/null 2>&1; then
        if command -v gsettings >/dev/null; then
            toggle_key org.gnome.desktop.interface icon-theme Adwaita
            gsettings list-schemas 2>/dev/null | grep -qx org.cinnamon.desktop.interface &&
                toggle_key org.cinnamon.desktop.interface icon-theme Adwaita
        fi
        command -v dbus-send >/dev/null &&
            dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:4 int32:0 2>/dev/null || true
    fi
}
setsid -f sh -c "$(declare -f bg_nudges); folder_color='${folder_color:-}' bg_nudges" >/dev/null 2>&1
