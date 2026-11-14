// Tema de Salchipapa-Shell para Surfingkeys (generado por scripts/surfingkeys-theme.sh).
// Colores: gentleman-kanagawa-blur.

// Traductor (al "es"). Surfingkeys para Firefox ignora api.Front.registerInlineQuery (en
// esta versión solo funciona en Chrome), así que Q usa el omnibar como un buscador más ("t"): mientras
// escribes, la traducción sale en vivo como sugerencia (la petición la hace el fondo de la extensión y
// la respuesta se procesa aquí). Enter abre Google Translate con el texto. q (visual) y st (lo
// seleccionado, en modo normal): ventana emergente.
const skEsc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const skTrUrl = "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=es&q=";
const skTrPage = "https://translate.google.com/?sl=auto&tl=es&op=translate&text=";
function skTrParse(text) {
    const r = JSON.parse(text);
    const first = Array.isArray(r[0]) ? r[0] : r; // [["traducción","en"]] o ["traducción","en"]
    return { text: first[0], from: first[1] };
}
function skTrHtml(q, t) {
    const note = t.from === "es" ? "Ya está en es" : skEsc(t.from || "?") + " → es";
    return '<div class="sk_tr"><div class="sk_tr_src">' + skEsc(q) + '</div><div class="sk_tr_text">' + skEsc(t.text) + '</div><div class="sk_tr_note">' + note + "</div></div>";
}
api.addSearchAlias("t", "Traducir", skTrPage, "s", skTrUrl, function (response, req) {
    try {
        const t = skTrParse(response.text);
        return t.text ? [{ html: skTrHtml(req.query, t), url: skTrPage + encodeURIComponent(req.query) }] : [];
    } catch (e) {
        return [];
    }
}, "o", { skipMaps: true });
api.mapkey("Q", "#8Traducir al es (con lo seleccionado, si hay)", function () {
    api.Front.openOmnibar({ type: "SearchEngine", extra: "t", pref: window.getSelection().toString().trim() });
});
async function skTranslate(q) {
    q = (q || "").trim();
    if (!q) return;
    try {
        const res = await fetch(skTrUrl + encodeURIComponent(q));
        api.Front.showPopup(skTrHtml(q, skTrParse(await res.text())));
    } catch (e) {
        api.Front.showBanner("No se pudo traducir: " + e);
    }
}
api.vmapkey("q", "#9Traducir la selección al es", function () {
    skTranslate(window.getSelection().toString());
});
// st: lo seleccionado (con el ratón, doble clic…) en la ventana emergente, como sg/sy buscan la selección
api.mapkey("st", "#6Traducir lo seleccionado al es", function () {
    const sel = window.getSelection().toString().trim();
    if (sel) skTranslate(sel);
    else api.Front.showBanner("Selecciona un texto primero (o usa Q para escribirlo)");
});
api.unmap("cq"); // traducir con etiquetas: en Firefox solo abría la wiki

// on: pestaña nueva escribiendo ya la URL o la búsqueda (el omnibar de t). El "on" original abre una
// pestaña vacía sin foco en la barra de direcciones: una extensión no puede enfocarla ni pulsar Ctrl+T.
api.map("on", "t");

// Etiquetas de `f` (abrir enlaces) y de los modos de texto
api.Hints.style("border: none; border-radius: 6px; padding: 1px 5px; background: #a3b5d6; color: #06080f; font-family: 'Inter Display', sans-serif; font-size: 12px; font-weight: 700; box-shadow: 0 2px 6px rgba(0,0,0,.45);");
api.Hints.style("border: none; border-radius: 6px; padding: 1px 5px; background: #e0c15a; color: #232a36; font-family: 'Inter Display', sans-serif; font-weight: 700;", "text");

// Modo visual: coincidencias y cursor
// Coincidencias de / y * en un tono translúcido; la actual (y el cursor) en el acento, sólida y con
// contorno, para saber en cuál estás al saltar con n / N
api.Visual.style("marks", "background-color: rgba(224, 193, 90, .38); border-radius: 3px;");
api.Visual.style("cursor", "background-color: #a3b5d6; color: #06080f; border-radius: 3px; outline: 2px solid #a3b5d6; box-shadow: 0 0 0 4px rgba(163, 181, 214, .35);");

// Omnibar, ayuda (?), barra de estado y de búsqueda
settings.theme = `
.sk_theme {
    font-family: 'Inter Display', sans-serif;
    font-size: 11pt;
    background: #232a36;
    color: #f3f6f9;
    border: 1px solid #2a3142;
    border-radius: 14px;
}
.sk_theme tbody { color: #f3f6f9; }
.sk_theme input { color: #f3f6f9; font-family: 'Inter Display', sans-serif; }
.sk_theme .url { color: #a3b5d6; }
.sk_theme .annotation { color: #a3b5c1; }
.sk_theme .omnibar_highlight { color: #e0c15a; font-weight: 700; }
.sk_theme .omnibar_timestamp { color: #c99ad6; }
.sk_theme .omnibar_visitcount { color: #e0c15a; }
.sk_theme .omnibar_folder { color: #c99ad6; }
/* Omnibar (t, og, b…) como el lanzador de la isla: grande, centrado, con el fondo de la paleta */
#sk_omnibar.sk_theme {
    width: min(900px, 84vw);
    left: 50%;
    transform: translateX(-50%);
    padding: 8px;
    border-radius: 26px;
    background: #06080f;
    border: 1px solid #2a3142;
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
}
#sk_omnibar.sk_omnibar_middle { top: 16%; }
.sk_theme #sk_omnibarSearchArea {
    margin: 0;
    padding: 16px 22px;
    border-bottom: none;
    background: #191e28;
    border-radius: 18px;
}
.sk_theme #sk_omnibarSearchArea > input {
    font-family: 'Geist', 'Inter Display', sans-serif;
    font-size: 23px;
    font-weight: 500;
    letter-spacing: .01em;
    padding-left: 14px;
    color: #f3f6f9;
    caret-color: #a3b5d6;
}
.sk_theme #sk_omnibarSearchArea > input::placeholder { color: #a3b5c1; opacity: .6; }
.sk_theme #sk_omnibarSearchArea .prompt { font-size: 18px; color: #a3b5d6; font-weight: 700; display: inline-flex; align-items: center; }
/* Icono del buscador (Google, YouTube, Wikipedia…): Surfingkeys le pone width:20px en línea */
.sk_theme #sk_omnibarSearchArea .prompt img { width: 34px !important; height: 34px !important; border-radius: 8px; }
.sk_theme #sk_omnibarSearchArea .resultPage { font-size: 14px; color: #a3b5c1; }
.sk_theme #sk_omnibarSearchResult { margin: 10px 2px 2px; max-height: 55vh; overflow-y: auto; scrollbar-width: none; font-size: 15px; }
.sk_theme #sk_omnibarSearchResult > ul { margin: 0; }
.sk_theme #sk_omnibarSearchResult > ul > li { padding: 10px 14px; margin: 2px 0; border-radius: 14px; background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li:nth-child(odd) { background: transparent; }
.sk_theme #sk_omnibarSearchResult > ul > li .title { color: #f3f6f9; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused { background: #292e3b; color: #a3b5d6; box-shadow: inset 3px 0 0 #a3b5d6; }
.sk_theme #sk_omnibarSearchResult > ul > li.focused .url,
.sk_theme #sk_omnibarSearchResult > ul > li.focused .title { color: #a3b5d6; }
.sk_theme #sk_omnibarSearchResult li .icon { width: 22px; height: 22px; margin-right: 12px; }
.sk_theme .feature_name { color: #a3b5d6; }
.sk_theme .feature_name > span { border-bottom: 2px solid #2a3142; }
.sk_theme kbd {
    background: #2a3142;
    color: #f3f6f9;
    border: 1px solid #2a3142;
    border-radius: 5px;
    box-shadow: none;
    font-family: 'Inter Display', sans-serif;
}
.sk_theme .prompt, .sk_theme .resultPage { color: #a3b5c1; }
/* Ayuda (?): panel centrado con un mosaico de tarjetas, una por grupo */
#sk_usage.sk_theme {
    width: min(1500px, 92vw);
    left: 50%;
    transform: translateX(-50%);
    top: 5%;
    max-height: 88vh;
    padding: 22px;
    background: #06080f;
    border: 1px solid #2a3142;
    border-radius: 26px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
    display: grid; /* sin !important: Surfingkeys la oculta con style="display: none" */
    grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
    gap: 16px;
    align-items: start;
    overflow-x: hidden;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: #2a3142 transparent;
    font-family: 'Inter Display', sans-serif;
}
#sk_usage.sk_theme > div {
    display: block;
    margin: 0;
    padding: 14px 16px 12px;
    background: #191e28;
    border: 1px solid #2a3142;
    border-radius: 18px;
}
#sk_usage.sk_theme .feature_name { text-align: left; padding: 0 0 10px 2px; }
#sk_usage.sk_theme .feature_name > span {
    border-bottom: none;
    color: #a3b5d6;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: .08em;
    text-transform: uppercase;
}
#sk_usage.sk_theme > div > div:not(.feature_name) { display: flex; align-items: center; gap: 12px; padding: 3px 0; }
#sk_usage.sk_theme .kbd-span { width: 86px; flex-shrink: 0; text-align: right; }
#sk_usage.sk_theme span.annotation { padding-left: 0; color: #f3f6f9; font-size: 13px; line-height: 1.35; }
#sk_usage.sk_theme kbd {
    padding: 4px 7px;
    line-height: 14px;
    font: 600 12px 'CaskaydiaCove Nerd Font Mono', 'CaskaydiaCove NFM', monospace;
    background: #2a3142;
    color: #a3b5d6;
    border: 1px solid #2a3142;
    border-radius: 7px;
    box-shadow: inset 0 -2px 0 #232a36;
}
#sk_usage.sk_theme > p { grid-column: 1 / -1; margin: 0 4px; font-size: 12px; }
#sk_usage.sk_theme > p a { color: #e0c15a !important; text-decoration: none; }

/* Ventana emergente (la traducción de Q / q) */
#sk_popup.sk_theme {
    width: min(640px, 80vw);
    left: 50%;
    transform: translateX(-50%);
    top: 20%;
    padding: 22px 26px;
    background: #06080f;
    border: 1px solid #2a3142;
    border-radius: 24px;
    box-shadow: 0 24px 60px rgba(0, 0, 0, .6), 0 2px 10px rgba(0, 0, 0, .4);
    font-family: 'Inter Display', sans-serif;
}
.sk_tr_src { font-size: 14px; color: #a3b5c1; margin-bottom: 8px; }
.sk_theme #sk_omnibarSearchResult .sk_tr { padding: 6px 4px; }
.sk_theme #sk_omnibarSearchResult .sk_tr_src { display: none; }
.sk_tr_text { font-family: 'Geist', 'Inter Display', sans-serif; font-size: 26px; font-weight: 600; line-height: 1.3; color: #f3f6f9; }
.sk_tr_note { margin-top: 12px; font-size: 12px; font-weight: 700; color: #a3b5d6; text-transform: uppercase; letter-spacing: .08em; }
#sk_bubble { background: #06080f; color: #f3f6f9; border: 1px solid #2a3142; border-radius: 14px; }
#sk_bubble .sk_bubble_content { padding: 8px 14px; }
#sk_status, #sk_find {
    font-family: 'Inter Display', sans-serif;
    font-size: 14pt;
    background: #232a36;
    color: #f3f6f9;
    border: 1px solid #2a3142;
    border-radius: 10px;
}
#sk_keystroke { background: #232a36; color: #f3f6f9; border-radius: 10px; }
#sk_keystroke kbd { background: #2a3142; color: #a3b5d6; border: 1px solid #2a3142; }
/* Banner: los avisos que bajan desde arriba */
#sk_banner.sk_theme, #sk_banner {
    width: min(720px, 80vw);
    left: 50%;
    transform: translateX(-50%);
    padding: 12px 20px;
    background: #2a3142;
    color: #f3f6f9;
    border: 1px solid #a3b5d6;
    border-top-style: none;
    border-radius: 0 0 16px 16px;
    font-family: 'Inter Display', sans-serif;
    font-size: 14px;
}
`;
