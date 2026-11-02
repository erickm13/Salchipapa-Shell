#!/usr/bin/env bash
# Tema de Surfingkeys (extensión de Firefox) con los colores y la letra actuales de la shell.
#   surfingkeys-theme.sh [--scheme <nombre> [flavour]] [--copy]
#     sin --scheme: los colores del tema activo (~/.local/state/salchipapa-shell/colors.json)
#     --scheme salchipapa: los de un tema guardado (shell/themes/schemes.json), aunque no esté activo
#     --copy: al portapapeles (wl-copy) en vez de imprimirlo
#   SURFINGKEYS_INPUT_FONT: letra del texto que escribes en el omnibar (por defecto Geist)
#   SURFINGKEYS_TRANSLATE_TO: idioma al que traducen Q y q (por defecto es)
# Además del tema redefine Q / q como traductor (Surfingkeys no trae ninguno y en Firefox ignora
# registerInlineQuery) con el servicio de Google que usa su extensión de diccionario (sin clave).
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

input_font="${SURFINGKEYS_INPUT_FONT:-Geist}"
translate_to="${SURFINGKEYS_TRANSLATE_TO:-es}"
bg_base=$(c background 131313) # el fondo de la paleta: el del omnibar
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

// Traductor (al "${translate_to}"). Surfingkeys para Firefox ignora api.Front.registerInlineQuery (en
// esta versión solo funciona en Chrome), así que Q y q (visual) se redefinen: piden la traducción
// aquí mismo y la muestran en la ventana emergente del tema.
//   Q: traduce lo seleccionado o, si no hay nada, pregunta qué traducir.   q (visual): la selección.
const skEsc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
async function skTranslate(q) {
    q = (q || "").trim();
    if (!q) return;
    try {
        const res = await fetch("https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=${translate_to}&q=" + encodeURIComponent(q));
        const r = await res.json();
        const first = Array.isArray(r[0]) ? r[0] : r; // [["traducción","en"]] o ["traducción","en"]
        const text = first[0], from = first[1];
        const note = from === "${translate_to}" ? "Ya está en ${translate_to}" : skEsc(from || "?") + " → ${translate_to}";
        api.Front.showPopup('<div class="sk_tr"><div class="sk_tr_src">' + skEsc(q) + '</div><div class="sk_tr_text">' + skEsc(text) + '</div><div class="sk_tr_note">' + note + '</div></div>');
    } catch (e) {
        api.Front.showBanner("No se pudo traducir: " + e);
    }
}
api.mapkey("Q", "#8Traducir (lo seleccionado o lo que escribas) al ${translate_to}", function () {
    const sel = window.getSelection().toString();
    skTranslate(sel.trim() ? sel : window.prompt("Traducir al ${translate_to}:"));
});
api.vmapkey("q", "#9Traducir la selección al ${translate_to}", function () {
    skTranslate(window.getSelection().toString());
});
api.unmap("cq"); // traducir con etiquetas: en Firefox solo abría la wiki

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
/* Omnibar (t, og, b…) como el lanzador de la isla: grande, centrado, con el fondo de la paleta */
#sk_omnibar.sk_theme {
    width: min(900px, 84vw);
    left: 50%;
    transform: translateX(-50%);
    padding: 8px;
    border-radius: 26px;
    background: ${bg_base};
    border: 1px solid ${border};
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
}
#sk_omnibar.sk_omnibar_middle { top: 16%; }
.sk_theme #sk_omnibarSearchArea {
    margin: 0;
    padding: 16px 22px;
    border-bottom: none;
    background: ${bg_low};
    border-radius: 18px;
}
.sk_theme #sk_omnibarSearchArea > input {
    font-family: '${input_font}', '${font}', sans-serif;
    font-size: 23px;
    font-weight: 500;
    letter-spacing: .01em;
    padding-left: 14px;
    color: ${fg};
    caret-color: ${primary};
}
.sk_theme #sk_omnibarSearchArea > input::placeholder { color: ${fg_dim}; opacity: .6; }
.sk_theme #sk_omnibarSearchArea .prompt { font-size: 18px; color: ${primary}; font-weight: 700; display: inline-flex; align-items: center; }
/* Icono del buscador (Google, YouTube, Wikipedia…): Surfingkeys le pone width:20px en línea */
.sk_theme #sk_omnibarSearchArea .prompt img { width: 34px !important; height: 34px !important; border-radius: 8px; }
.sk_theme #sk_omnibarSearchArea .resultPage { font-size: 14px; color: ${fg_dim}; }
.sk_theme #sk_omnibarSearchResult { margin: 10px 2px 2px; max-height: 55vh; overflow-y: auto; scrollbar-width: none; font-size: 15px; }
.sk_theme #sk_omnibarSearchResult > ul { margin: 0; }
.sk_theme #sk_omnibarSearchResult > ul > li { padding: 10px 14px; margin: 2px 0; border-radius: 14px; background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li:nth-child(odd) { background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li .title { color: ${fg}; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused { background: ${primary_container}; color: ${on_primary_container}; box-shadow: inset 3px 0 0 ${primary}; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused .url,
.sk_theme #sk_omnibarSearchResult > ul > li.focused .title { color: ${on_primary_container}; }
.sk_theme #sk_omnibarSearchResult li .icon { width: 22px; height: 22px; margin-right: 12px; }
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
/* Ayuda (?): panel centrado con un mosaico de tarjetas, una por grupo */
#sk_usage.sk_theme {
    width: min(1500px, 92vw);
    left: 50%;
    transform: translateX(-50%);
    top: 5%;
    max-height: 88vh;
    padding: 22px;
    background: ${bg_base};
    border: 1px solid ${border};
    border-radius: 26px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
    display: grid; /* sin !important: Surfingkeys la oculta con style="display: none" */
    grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
    gap: 16px;
    align-items: start;
    overflow-x: hidden;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: ${border} transparent;
    font-family: '${font}', sans-serif;
}
#sk_usage.sk_theme > div {
    display: block;
    margin: 0;
    padding: 14px 16px 12px;
    background: ${bg_low};
    border: 1px solid ${border};
    border-radius: 18px;
}
#sk_usage.sk_theme .feature_name { text-align: left; padding: 0 0 10px 2px; }
#sk_usage.sk_theme .feature_name > span {
    border-bottom: none;
    color: ${primary};
    font-size: 12px;
    font-weight: 700;
    letter-spacing: .08em;
    text-transform: uppercase;
}
#sk_usage.sk_theme > div > div:not(.feature_name) { display: flex; align-items: center; gap: 12px; padding: 3px 0; }
#sk_usage.sk_theme .kbd-span { width: 86px; flex-shrink: 0; text-align: right; }
#sk_usage.sk_theme span.annotation { padding-left: 0; color: ${fg}; font-size: 13px; line-height: 1.35; }
#sk_usage.sk_theme kbd {
    padding: 4px 7px;
    line-height: 14px;
    font: 600 12px 'CaskaydiaCove Nerd Font Mono', 'CaskaydiaCove NFM', monospace;
    background: ${bg_high};
    color: ${primary};
    border: 1px solid ${border};
    border-radius: 7px;
    box-shadow: inset 0 -2px 0 ${bg};
}
#sk_usage.sk_theme > p { grid-column: 1 / -1; margin: 0 4px; font-size: 12px; }
#sk_usage.sk_theme > p a { color: ${tertiary} !important; text-decoration: none; }

/* Ventana emergente (la traducción de Q / q) */
#sk_popup.sk_theme {
    width: min(640px, 80vw);
    left: 50%;
    transform: translateX(-50%);
    top: 20%;
    padding: 22px 26px;
    background: ${bg_base};
    border: 1px solid ${border};
    border-radius: 24px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
    font-family: '${font}', sans-serif;
}
.sk_tr_src { font-size: 14px; color: ${fg_dim}; margin-bottom: 8px; }
.sk_tr_text { font-family: '${input_font}', '${font}', sans-serif; font-size: 26px; font-weight: 600; line-height: 1.3; color: ${fg}; }
.sk_tr_note { margin-top: 12px; font-size: 12px; font-weight: 700; color: ${primary}; text-transform: uppercase; letter-spacing: .08em; }
#sk_bubble { background: ${bg_base}; color: ${fg}; border: 1px solid ${border}; border-radius: 14px; }
#sk_bubble .sk_bubble_content { padding: 8px 14px; }
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
/* Banner: los avisos que bajan desde arriba */
#sk_banner.sk_theme, #sk_banner {
    width: min(720px, 80vw);
    left: 50%;
    transform: translateX(-50%);
    padding: 12px 20px;
    background: ${bg_high};
    color: ${fg};
    border: 1px solid ${primary};
    border-top-style: none;
    border-radius: 0 0 16px 16px;
    font-family: '${font}', sans-serif;
    font-size: 14px;
}
\`;
EOF
)

if $copy; then
    printf '%s\n' "$js" | wl-copy
    echo "Copiado. Pégalo en Surfingkeys > Settings > Advanced mode y pulsa Save." >&2
else
    printf '%s\n' "$js"
fi
