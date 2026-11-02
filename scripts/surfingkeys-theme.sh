#!/usr/bin/env bash
# Tema de Surfingkeys (extensión de Firefox) con los colores y la letra actuales de la shell.
#   surfingkeys-theme.sh          -> imprime el JS
#   surfingkeys-theme.sh --copy   -> lo copia al portapapeles (wl-copy)
# Se pega en Surfingkeys > Settings > Advanced mode y se pulsa Save. Firefox no deja que las
# extensiones lean archivos locales, así que no se puede cargar desde un file:// y hay que volver
# a pegarlo si cambias de tema o de fondo.
# Afecta al omnibar (t, og, b…), la ayuda (?), la barra de estado y de búsqueda, las etiquetas de
# `f` (Hints) y el modo visual. No toca ningún atajo.
set -euo pipefail

state="$HOME/.local/state/salchipapa-shell/colors.json"
config="$HOME/.config/salchipapa-shell/config.json"

declare -A C
while IFS=$'\t' read -r k v; do C[$k]=$v; done < <(jq -r '.colours // {} | to_entries[] | "\(.key)\t\(.value)"' "$state" 2>/dev/null)
c() { printf '#%s' "${C[$1]:-$2}"; }

accent=$(jq -r '.appearanceAccent // ""' "$config" 2>/dev/null)
primary=${accent:+#$accent}
primary=${primary:-$(c primary ff5759)}
font=$(jq -r '.appearanceBodyFont // ""' "$config" 2>/dev/null)
font=${font:-Inter}

bg=$(c surfaceContainer 1f1f1f)
bg_low=$(c surfaceContainerLow 1b1b1b)
bg_high=$(c surfaceContainerHigh 2a2a2a)
fg=$(c onSurface e2e2e2)
fg_dim=$(c onSurfaceVariant c6c6c6)
border=$(c outlineVariant 474747)
on_primary=$(c onPrimary 5f131c)
primary_container=$(c primaryContainer 7e2a30)
on_primary_container=$(c onPrimaryContainer ffdad9)
secondary=$(c secondary e26764)
tertiary=$(c tertiary f89f1e)

js=$(
    cat <<EOF
// Tema de Salchipapa-Shell para Surfingkeys (generado por scripts/surfingkeys-theme.sh).
// Colores del tema activo de la shell; vuelve a generarlo si cambias de tema o de fondo.

// Etiquetas de \`f\` (abrir enlaces) y de los modos de texto
api.Hints.style("border: none; border-radius: 6px; padding: 1px 5px; background: ${primary}; color: ${on_primary}; font-family: '${font}', sans-serif; font-size: 12px; font-weight: 700; box-shadow: 0 2px 6px rgba(0,0,0,.45);");
api.Hints.style("border: none; border-radius: 6px; padding: 1px 5px; background: ${tertiary}; color: ${bg}; font-family: '${font}', sans-serif; font-weight: 700;", "text");

// Modo visual: coincidencias y cursor
api.Visual.style("marks", "background-color: ${primary_container};");
api.Visual.style("cursor", "background-color: ${primary};");

// Omnibar, ayuda (?), barra de estado y de búsqueda
settings.theme = \`
.sk_theme {
    font-family: '${font}', sans-serif;
    font-size: 11pt;
    background: ${bg};
    color: ${fg};
    border: 1px solid ${border};
    border-radius: 14px;
}
.sk_theme tbody { color: ${fg}; }
.sk_theme input { color: ${fg}; font-family: '${font}', sans-serif; }
.sk_theme .url { color: ${primary}; }
.sk_theme .annotation { color: ${fg_dim}; }
.sk_theme .omnibar_highlight { color: ${tertiary}; font-weight: 700; }
.sk_theme .omnibar_timestamp { color: ${secondary}; }
.sk_theme .omnibar_visitcount { color: ${tertiary}; }
.sk_theme .omnibar_folder { color: ${secondary}; }
.sk_theme #sk_omnibarSearchArea { border-bottom: 1px solid ${border}; }
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) { background: ${bg_low}; }
.sk_theme #sk_omnibarSearchResult ul li.focused { background: ${primary_container}; color: ${on_primary_container}; border-radius: 8px; }
.sk_theme #sk_omnibarSearchResult ul li.focused .url { color: ${on_primary_container}; }
.sk_theme .feature_name { color: ${primary}; }
.sk_theme .feature_name > span { border-bottom: 2px solid ${border}; }
.sk_theme kbd {
    background: ${bg_high};
    color: ${fg};
    border: 1px solid ${border};
    border-radius: 5px;
    box-shadow: none;
    font-family: '${font}', sans-serif;
}
.sk_theme .prompt, .sk_theme .resultPage { color: ${fg_dim}; }
#sk_status, #sk_find {
    font-family: '${font}', sans-serif;
    font-size: 14pt;
    background: ${bg};
    color: ${fg};
    border: 1px solid ${border};
    border-radius: 10px;
}
#sk_keystroke { background: ${bg}; color: ${fg}; border-radius: 10px; }
#sk_keystroke kbd { background: ${bg_high}; color: ${primary}; border: 1px solid ${border}; }
#sk_banner { background: ${primary}; color: ${on_primary}; border-radius: 10px; font-family: '${font}', sans-serif; }
\`;
EOF
)

if [ "${1:-}" = "--copy" ]; then
    printf '%s\n' "$js" | wl-copy
    echo "Copiado. Pégalo en Surfingkeys > Settings > Advanced mode y pulsa Save." >&2
else
    printf '%s\n' "$js"
fi
