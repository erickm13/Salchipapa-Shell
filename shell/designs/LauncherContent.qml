pragma ComponentBehavior: Bound
// Contenido del lanzador, para mostrarse DENTRO de la Dynamic Island (modo "launcher").
// Tipo Spotlight: además de apps busca comandos de la shell, archivos (fd), calcula
// ("2*(3+4)", "15% de 80") y busca en la web (prefijos "g ", "yt ", "gh ", "w ", "aur ").
// Cada resultado es { kind, id, title, subtitle, icon | glyph, tag, run(alt) }.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"
import "../services"

Item {
    id: root
    // Más grande que el resto de la shell (Theme.fontPx con su escala): se lee mejor
    readonly property real uiScale: 1.25

    property int sel: 0
    property string query: ""
    // Última posición del ratón sobre el launcher (ver el MouseArea de cada fila)
    property point mousePos: Qt.point(-1, -1)

    // --- Frecencia: las apps que más usas arriba; las que dejas de usar van bajando ---
    // Por app se guarda { s: puntuación, t: último uso en ms }. Cada lanzamiento suma 1 a la
    // puntuación, que pierde la mitad de su valor cada `halfLifeDays` sin usarse.
    readonly property string usagePath: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/launcher-usage.json"
    readonly property real halfLifeDays: 7
    property var usage: ({})
    // Momento de referencia: se fija al abrir el launcher para que el orden no cambie mientras está abierto
    property real now: Date.now()

    function score(id: string): real {
        const u = usage[id];
        if (!u)
            return 0;
        return u.s * Math.pow(0.5, (now - u.t) / (halfLifeDays * 86400000));
    }

    function recordLaunch(id: string): void {
        const t = Date.now();
        const u = usage[id];
        const s = (u ? u.s * Math.pow(0.5, (t - u.t) / (halfLifeDays * 86400000)) : 0) + 1;
        const next = Object.assign({}, usage);
        next[id] = { s: s, t: t };
        // Olvida las que ya casi no cuentan (y las de apps desinstaladas) para que el archivo no crezca
        for (const k in next)
            if (next[k].s * Math.pow(0.5, (t - next[k].t) / (halfLifeDays * 86400000)) < 0.01)
                delete next[k];
        usage = next;
        usageFile.setText(JSON.stringify(usage));
    }

    FileView {
        id: usageFile
        path: root.usagePath
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    // --- Calculadora (sin qalc: un parser pequeño, sin eval) ---
    readonly property var mathFns: ({
            sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, exp: Math.exp, ln: Math.log, log: Math.log10,
            sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
            round: Math.round, floor: Math.floor, ceil: Math.ceil
        })
    readonly property var mathConsts: ({ pi: Math.PI, "π": Math.PI, e: Math.E })

    // Devuelve el número o null si `src` no es una expresión (así "firefox 2" no se toma por cuenta)
    function calc(src: string): var {
        let s = src.trim().replace(/^=/, "").toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
        // "15% de 80", "15% of 80" → 15/100*80
        s = s.replace(/([\d.]+)\s*%\s*(de|of)\s+/g, "($1/100)*");
        if (!/\d/.test(s) || !/[+\-*/^%!()a-zπ]/.test(s) || /^[\d.\s]+$/.test(s))
            return null;
        const toks = s.match(/\d*\.?\d+(e[+-]?\d+)?|[a-zπ]+|[+\-*/^%!()]|\S/g) ?? [];
        let i = 0;
        const peek = () => toks[i];
        const fail = () => {
            throw 0;
        };
        const fact = n => {
            if (n < 0 || n > 170 || n % 1)
                fail();
            let r = 1;
            for (let k = 2; k <= n; k++)
                r *= k;
            return r;
        };
        let expr, unary;
        const primary = () => {
            const t = toks[i++];
            if (t === undefined)
                fail();
            if (/^\d|^\./.test(t))
                return parseFloat(t);
            if (t === "(") {
                const v = expr();
                if (toks[i++] !== ")")
                    fail();
                return v;
            }
            if (t in root.mathConsts)
                return root.mathConsts[t];
            if (t in root.mathFns) {
                if (toks[i++] !== "(")
                    fail();
                const v = expr();
                if (toks[i++] !== ")")
                    fail();
                return root.mathFns[t](v);
            }
            return fail();
        };
        const postfix = () => {
            let v = primary();
            while (peek() === "%" || peek() === "!")
                v = toks[i++] === "%" ? v / 100 : fact(v);
            return v;
        };
        const power = () => {
            const b = postfix();
            return peek() === "^" ? (i++, Math.pow(b, unary())) : b;
        };
        unary = () => peek() === "-" ? (i++, -unary()) : peek() === "+" ? (i++, unary()) : power();
        const term = () => {
            let v = unary();
            while (peek() === "*" || peek() === "/")
                v = toks[i++] === "*" ? v * unary() : v / unary();
            return v;
        };
        expr = () => {
            let v = term();
            while (peek() === "+" || peek() === "-")
                v = toks[i++] === "+" ? v + term() : v - term();
            return v;
        };
        try {
            const v = expr();
            return i === toks.length && isFinite(v) ? v : null;
        } catch (e) {
            return null;
        }
    }

    function fmt(v: real): string {
        return String(Number(v.toPrecision(12)));
    }

    // --- Comandos de la shell (título en inglés como el resto de la UI; palabras clave también en español) ---
    function openMode(m: string): void {
        Overlay.mode = m;
    }
    readonly property var commands: [
        { id: "lock", title: "Lock Screen", glyph: "lock", kw: "bloquear pantalla", run: () => { Overlay.close(); LockScreen.lock(); } },
        { id: "suspend", title: "Suspend", glyph: "bedtime", kw: "suspender dormir sleep", run: () => { Overlay.close(); LockScreen.suspend(); } },
        { id: "logout", title: "Log Out", glyph: "logout", kw: "cerrar sesión salir", run: () => { Overlay.powerRequest = "logout"; root.openMode("power"); } },
        { id: "reboot", title: "Reboot", glyph: "restart_alt", kw: "reiniciar restart", run: () => { Overlay.powerRequest = "reboot"; root.openMode("power"); } },
        { id: "poweroff", title: "Power Off", glyph: "power_settings_new", kw: "apagar shutdown", run: () => { Overlay.powerRequest = "poweroff"; root.openMode("power"); } },
        { id: "power", title: "Power Menu", glyph: "power_settings_new", kw: "energía menú", run: () => root.openMode("power") },
        { id: "settings", title: "Settings", glyph: "settings", kw: "ajustes configuración preferencias", run: () => { Overlay.close(); if (!Overlay.settings) Overlay.toggleSettings(); } },
        { id: "control", title: "Control Center", glyph: "tune", kw: "centro de control", run: () => root.openMode("control") },
        { id: "wifi", title: "Wi-Fi", glyph: "wifi", kw: "red internet network", run: () => root.openMode("wifi") },
        { id: "bluetooth", title: "Bluetooth", glyph: "bluetooth", kw: "auriculares dispositivos", run: () => root.openMode("bluetooth") },
        { id: "sound", title: "Sound", glyph: "volume_up", kw: "sonido audio volumen micrófono", run: () => root.openMode("sound") },
        { id: "display", title: "Displays", glyph: "desktop_windows", kw: "pantalla monitor resolución", run: () => root.openMode("display") },
        { id: "themes", title: "Themes", glyph: "palette", kw: "temas colores", run: () => root.openMode("themes") },
        { id: "wallpaper", title: "Wallpaper", glyph: "wallpaper", kw: "fondo de pantalla", run: () => root.openMode("wallpaper") },
        { id: "clipboard", title: "Clipboard History", glyph: "content_paste", kw: "portapapeles historial", run: () => root.openMode("clipboard") },
        { id: "emoji", title: "Emoji Picker", glyph: "mood", kw: "emojis", run: () => root.openMode("emoji") },
        { id: "music", title: "Music", glyph: "music_note", kw: "música spotify reproductor", run: () => root.openMode("music") },
        { id: "perf", title: "Performance", glyph: "monitoring", kw: "rendimiento cpu ram gpu", run: () => root.openMode("perf") },
        { id: "binds", title: "Keybinds", glyph: "keyboard", kw: "atajos teclas glosario", run: () => root.openMode("binds") },
        { id: "calendar", title: "Calendar", glyph: "calendar_month", kw: "calendario fecha", run: () => root.openMode("calendar") },
        // La espera deja que la isla se cierre antes de capturar
        { id: "shot-region", title: "Screenshot Region", glyph: "screenshot_region", kw: "captura de pantalla área recorte", run: () => { Overlay.close(); Quickshell.execDetached(["sh", "-c", 'sleep 0.4; exec "$0" region', Quickshell.shellDir + "/../scripts/screenshot.sh"]); } },
        { id: "shot-screen", title: "Screenshot Screen", glyph: "screenshot_monitor", kw: "captura de pantalla completa monitor", run: () => { Overlay.close(); Quickshell.execDetached(["sh", "-c", 'sleep 0.4; exec "$0" screen', Quickshell.shellDir + "/../scripts/screenshot.sh"]); } }
    ]

    // --- Web ---
    readonly property var engines: ({
            g: { name: "Google", url: "https://www.google.com/search?q=" },
            yt: { name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
            gh: { name: "GitHub", url: "https://github.com/search?q=" },
            w: { name: "Wikipedia", url: "https://es.wikipedia.org/w/index.php?search=" },
            aur: { name: "AUR", url: "https://aur.archlinux.org/packages?K=" }
        })
    function openUrl(url: string): void {
        Quickshell.execDetached(["xdg-open", url]);
        Overlay.close();
    }
    function webItem(engine: string, text: string): var {
        const e = engines[engine];
        return { kind: "web", id: "", title: "Search " + e.name + " for “" + text + "”", subtitle: e.url.replace(/^https:\/\/(www\.)?/, "").split("/")[0], glyph: "travel_explore", tag: "Web", run: () => root.openUrl(e.url + encodeURIComponent(text)) };
    }

    // --- Archivos: fd en ~ (sin ocultos ni lo que ignora git), con espera para no lanzar uno por tecla ---
    readonly property string home: Quickshell.env("HOME")
    property var files: []
    property string filesFor: ""
    Timer {
        id: fileTimer
        interval: 140
        onTriggered: {
            const q = root.query.trim();
            fileProc.running = false;
            fileProc.forQuery = q;
            fileProc.command = ["fd", "--fixed-strings", "--ignore-case", "--max-results", "60", "--exclude", "node_modules", "--", q, root.home];
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        property string forQuery: ""
        stdout: StdioCollector {
            id: fileOut
            onStreamFinished: {
                if (fileProc.forQuery !== root.query.trim())
                    return;
                const q = fileProc.forQuery.toLowerCase();
                const base = p => p.replace(/\/$/, "").split("/").pop().toLowerCase();
                // Primero los que EMPIEZAN por la búsqueda; después los de ruta más corta
                root.files = fileOut.text.split("\n").filter(l => l !== "").sort((a, b) => (base(b).startsWith(q) - base(a).startsWith(q)) || a.length - b.length).slice(0, 6);
                root.filesFor = fileProc.forQuery;
            }
        }
    }
    function fileIcon(path: string): string {
        if (path.endsWith("/"))
            return "folder";
        const ext = (path.match(/\.([^./]+)$/)?.[1] ?? "").toLowerCase();
        if (ext === "pdf")
            return "application-pdf";
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "avif"].includes(ext))
            return "image-x-generic";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext))
            return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext))
            return "audio-x-generic";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(ext))
            return "package-x-generic";
        return "text-x-generic";
    }
    function fileItem(path: string): var {
        const isDir = path.endsWith("/");
        const clean = path.replace(/\/$/, "");
        const parent = clean.substring(0, clean.lastIndexOf("/")) || "/";
        const pretty = p => p.startsWith(home) ? "~" + p.substring(home.length) : p;
        return { kind: "file", id: "", title: clean.split("/").pop(), subtitle: pretty(parent), icon: fileIcon(path), tag: isDir ? "Folder" : "File",
                 // Ctrl+Enter: abrir la carpeta que lo contiene
                 run: alt => root.openUrl(alt ? parent : clean) };
    }

    readonly property var results: {
        const raw = query.trim();
        const q = raw.toLowerCase();

        // Prefijo de buscador ("yt lofi") → solo esa búsqueda
        const pre = raw.match(/^(\w+)\s+(.+)$/);
        if (pre && engines[pre[1].toLowerCase()])
            return [webItem(pre[1].toLowerCase(), pre[2])];

        const out = [];
        const v = calc(raw);
        if (v !== null) {
            const r = fmt(v);
            out.push({ kind: "calc", id: "", title: r, subtitle: raw.replace(/^=/, "") + " =", glyph: "calculate", tag: "Copy", run: () => { Quickshell.execDetached(["wl-copy", "--", r]); Overlay.close(); } });
        }
        // Algo con pinta de URL (con esquema o "www.") va primero
        const isUrl = /^(https?:\/\/|www\.)\S+$/i.test(raw);
        const urlItem = { kind: "web", id: "", title: "Open " + raw, subtitle: "Link", glyph: "open_in_new", tag: "Web", run: () => root.openUrl(/^https?:/i.test(raw) ? raw : "https://" + raw) };
        if (isUrl)
            out.push(urlItem);

        const all = DesktopEntries.applications.values;
        // También por el id del .desktop (p. ej. "baobab" encuentra "Disk Usage Analyzer", que es como se llama en el menú)
        const apps = q === "" ? all.slice() : all.filter(a => (a.name ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q) || (a.comment ?? "").toLowerCase().includes(q) || (a.id ?? "").toLowerCase().includes(q));
        const items = apps.map(a => ({ kind: "app", id: a.id ?? "", title: a.name ?? "", subtitle: a.comment || a.genericName || "", icon: a.icon ?? "", tag: "", app: a }));
        // Los comandos solo al escribir (sin búsqueda, la lista son tus apps)
        if (q !== "")
            for (const c of commands)
                if (c.title.toLowerCase().includes(q) || c.kw.includes(q) || c.id.includes(q))
                    items.push({ kind: "cmd", id: "cmd:" + c.id, title: c.title, subtitle: "Command", glyph: c.glyph, tag: "Command", run: c.run });

        // Primero los que EMPIEZAN por la búsqueda, luego los que la tienen en el nombre y al final
        // los que solo coinciden por id/descripción ("thunar" → "Thunar File Manager" antes que "Bulk Rename")
        const rank = it => {
            const n = it.title.toLowerCase();
            return n.startsWith(q) || n.split(/\s+/).some(w => w.startsWith(q)) && it.kind === "cmd" ? 0 : n.includes(q) ? 1 : 2;
        };
        // Dentro de cada grupo, los más usados primero; los nunca usados, por orden alfabético
        const sc = {};
        for (const it of items)
            sc[it.id] = root.score(it.id);
        items.sort((x, y) => (q === "" ? 0 : rank(x) - rank(y)) || sc[y.id] - sc[x.id] || x.title.localeCompare(y.title));
        for (const it of items)
            out.push(it);

        if (q.length >= 2) {
            if (filesFor === raw)
                for (const f of files)
                    out.push(fileItem(f));
            if (!isUrl && /^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(raw) && /\.[a-z]{2,}(\/|$)/i.test(raw) && !/\.(qml|md|txt|js|ts|py|sh|lua|json|conf|ini|toml|ya?ml|css|html|png|jpe?g|pdf)$/i.test(raw))
                out.push(urlItem);
            out.push(webItem("g", raw));
        }
        return out;
    }

    function launch(alt: bool): void {
        const it = results[sel];
        if (!it)
            return;
        if (it.id)
            root.recordLaunch(it.id);
        if (it.kind !== "app") {
            it.run(alt);
            return;
        }
        // Con uwsm, la app va en su propia unidad de la sesión (se cierra al salir); ver scripts/app.sh
        if (Quickshell.env("UWSM_FINALIZE_VARNAMES") && it.id)
            Quickshell.execDetached([Quickshell.shellDir + "/../scripts/app.sh", it.id + ".desktop"]);
        else
            it.app.execute();
        Overlay.close();
    }

    // Al abrir el modo, resetea la búsqueda
    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "launcher") {
                root.now = Date.now();
                root.query = "";
                root.sel = 0;
                searchInput.text = "";
                searchInput.forceActiveFocus();
            }
        }
    }

    // --- Buscador ---
    Item {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 62

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Theme.overlay1
        }
        TextInput {
            font.family: Theme.bodyFontFamily
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx((15) * root.uiScale)
            clip: true
            focus: Overlay.mode === "launcher"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
                if (text.trim().length >= 2)
                    fileTimer.restart();
                else {
                    fileTimer.stop();
                    root.files = [];
                    root.filesFor = "";
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search apps, commands, files, the web…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }

            Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
            // Ctrl+J / Ctrl+K como en vim (j y k a secas se escriben en el buscador)
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_J || event.key === Qt.Key_K)) {
                    root.sel = Math.max(0, Math.min(root.results.length - 1, root.sel + (event.key === Qt.Key_J ? 1 : -1)));
                    event.accepted = true;
                }
            }
            // Ctrl+Enter: acción alternativa (en un archivo, abrir su carpeta)
            Keys.onReturnPressed: event => root.launch(!!(event.modifiers & Qt.ControlModifier))
            Keys.onEnterPressed: event => root.launch(!!(event.modifiers & Qt.ControlModifier))
            Keys.onEscapePressed: Overlay.close()
        }
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.surface0
    }

    // --- Lista ---
    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        clip: true
        spacing: 2
        model: root.results
        currentIndex: root.sel
        // Duración fija en vez de la velocidad por defecto (400 px/s): con la flecha mantenida
        // la selección avanza más rápido que eso y la lista seguía desplazándose sola al soltar
        highlightMoveVelocity: -1
        highlightMoveDuration: 100
        boundsBehavior: Flickable.StopAtBounds
        // Filas ya creadas por encima y por debajo de lo visible (se crean sin bloquear, al abrir):
        // crear una fila al desplazar busca y rasteriza su icono, y eso daba tirones
        cacheBuffer: 3000

        SmoothWheel {
            flickable: list
        }

        delegate: Rectangle {
            id: item
            required property int index
            required property var modelData

            // Icono y textos crecen con el alto de fila (Ajustes → Launcher); con 50 px, tamaños base
            readonly property real rowScale: Config.launcherRowHeight / 50

            width: ListView.view.width
            height: Config.launcherRowHeight
            radius: 12
            color: index === root.sel ? Theme.surface0 : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round(24 * item.rowScale)
                radius: 2
                color: Theme.green
                visible: index === root.sel
            }

            Item {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(30 * item.rowScale)
                height: width

                AppIcon {
                    anchors.fill: parent
                    size: parent.width
                    visible: !item.modelData.glyph
                    icon: item.modelData.icon ?? ""
                }
                // Comandos, calculadora y web: símbolo en un cuadrado redondeado
                Rectangle {
                    anchors.fill: parent
                    visible: !!item.modelData.glyph
                    radius: 8
                    color: Theme.surface1
                    Text {
                        anchors.centerIn: parent
                        text: item.modelData.glyph ?? ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Math.round(parent.width * 0.6)
                        color: item.modelData.kind === "calc" ? Theme.green : item.modelData.kind === "web" ? Theme.blue : Theme.text
                    }
                }
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: Math.round(12 * item.rowScale)
                anchors.right: tag.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: item.modelData.title ?? ""
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx((13 * item.rowScale) * root.uiScale)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: item.modelData.subtitle ?? ""
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx((10 * item.rowScale) * root.uiScale)
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Tipo de resultado (vacío en las apps)
            Text {
                id: tag
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: item.modelData.tag ?? ""
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(10 * root.uiScale)
                color: Theme.tertiaryText
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Solo si el ratón se movió de verdad: al bajar con las flechas la lista se desplaza
                // y la fila que pasa bajo el cursor quieto también recibe hover, robando la selección
                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    if (p.x === root.mousePos.x && p.y === root.mousePos.y)
                        return;
                    root.mousePos = p;
                    root.sel = item.index;
                }
                onClicked: mouse => {
                    root.sel = item.index;
                    root.launch(!!(mouse.modifiers & Qt.ControlModifier));
                }
            }
        }
    }
}
