#!/usr/bin/env bash
# Tema de Surfingkeys (extensión de Firefox) con los colores y la letra actuales de la shell.
#   surfingkeys-theme.sh [--scheme <nombre> [flavour]] [--copy]
#     sin --scheme: los colores del tema activo (~/.local/state/salchipapa-shell/colors.json)
#     --scheme salchipapa: los de un tema guardado (shell/themes/schemes.json), aunque no esté activo
#     --copy: al portapapeles (wl-copy) en vez de imprimirlo
# Se pega en Surfingkeys > Settings > Advanced mode y se pulsa Save. Firefox no deja que las
# extensiones lean archivos locales, así que no se puede cargar desde un file:// y hay que volver
# a pegarlo si cambias de tema o de fondo.
# Afecta al omnibar (t, og, b…), la ayuda (?), la barra de estado y de búsqueda, las etiquetas de
# `f` (Hints) y el modo visual. No toca ningún atajo.
set -euo pipefail

state="$HOME/.local/state/salchipapa-shell/colors.json"
config="$HOME/.config/salchipapa-shell/config.json"
schemes="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/shell/themes/schemes.json"

scheme="" flavour="" copy=false
while [ $# -gt 0 ]; do
    case "$1" in
    --scheme)
        scheme="${2:?falta el nombre del tema}"
        shift
        if [ $# -gt 1 ] && [ "${2#--}" = "$2" ]; then
            flavour="$2"
            shift
        fi
        ;;
    --copy) copy=true ;;
    *)
        echo "uso: surfingkeys-theme.sh [--scheme <nombre> [flavour]] [--copy]" >&2
        exit 1
        ;;
    esac
    shift
done

if [ -n "$scheme" ]; then
    # Primer flavour del tema si no se indica (salchipapa solo tiene "default")
    pal=$(jq -c --arg s "$scheme" --arg f "$flavour" '.[$s] // empty | if $f != "" then .[$f] else (to_entries[0].value) end // empty' "$schemes")
    [ -n "$pal" ] || {
        echo "tema no encontrado: $scheme $flavour (hay: $(jq -r 'keys | join(", ")' "$schemes"))" >&2
        exit 1
    }
else
    pal=$(jq -c '.colours // {}' "$state" 2>/dev/null || echo '{}')
fi

declare -A C
while IFS=$'\t' read -r k v; do C[$k]=${v,,}; done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' <<<"$pal")
c() { printf '#%s' "${C[$1]:-$2}"; }

# El acento personalizado de Ajustes solo con el tema activo (con --scheme, el del tema)
accent=""
[ -n "$scheme" ] || accent=$(jq -r '.appearanceAccent // ""' "$config" 2>/dev/null)
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
// Colores: ${scheme:-tema activo de la shell}${flavour:+ ($flavour)}.

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
/* Omnibar (t, og, b…) como el lanzador de la isla: centrado, redondeado, filas en pastilla */
#sk_omnibar.sk_theme {
    width: min(720px, 76vw);
    left: 50%;
    transform: translateX(-50%);
    padding: 6px;
    border-radius: 22px;
    border: 1px solid ${border};
    box-shadow: 0 18px 50px rgba(0, 0, 0, .55), 0 2px 8px rgba(0, 0, 0, .35);
}
#sk_omnibar.sk_omnibar_middle { top: 18%; }
.sk_theme #sk_omnibarSearchArea {
    margin: 0;
    padding: 12px 16px;
    border-bottom: none;
    background: ${bg_high};
    border-radius: 16px;
}
.sk_theme #sk_omnibarSearchArea > input { font-size: 17px; padding-left: 10px; color: ${fg}; }
.sk_theme #sk_omnibarSearchArea .prompt { font-size: 15px; color: ${primary}; font-weight: 700; }
.sk_theme #sk_omnibarSearchArea .resultPage { font-size: 13px; color: ${fg_dim}; }
.sk_theme #sk_omnibarSearchResult { margin: 8px 2px 2px; max-height: 50vh; overflow-y: auto; scrollbar-width: none; }
.sk_theme #sk_omnibarSearchResult > ul { margin: 0; }
.sk_theme #sk_omnibarSearchResult > ul > li { padding: 8px 12px; margin: 2px 0; border-radius: 12px; background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li:nth-child(odd) { background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li .title { color: ${fg}; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused { background: ${primary_container}; color: ${on_primary_container}; box-shadow: inset 3px 0 0 ${primary}; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused .url,
.sk_theme #sk_omnibarSearchResult > ul > li.focused .title { color: ${on_primary_container}; }
.sk_theme #sk_omnibarSearchResult li .icon { width: 18px; margin-right: 10px; }
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

if $copy; then
    printf '%s\n' "$js" | wl-copy
    echo "Copiado. Pégalo en Surfingkeys > Settings > Advanced mode y pulsa Save." >&2
else
    printf '%s\n' "$js"
fi
