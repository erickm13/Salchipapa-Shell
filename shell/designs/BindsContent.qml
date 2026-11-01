pragma ComponentBehavior: Bound
// Glosario de atajos, DENTRO de la isla (modo "binds", Super+/). Lee lua/keybinds.lua en vivo:
// cada comentario suelto arriba de un bloque es una sección, y la descripción de un atajo es su
// comentario al final de la línea (o el de la línea anterior); si no tiene, se deduce de la acción.
// Tab cambia a los atajos de VS Code (scripts/vscode-keybinds.py: keybindings.json, extensiones y
// los básicos de VS Code), que se regeneran cada vez que se abre esa pestaña.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

Item {
    id: root

    property var all: [] // [{ section, keys: [string], desc }]
    property var vscode: [] // lo mismo, de VS Code
    property bool vscodeTab: false
    readonly property var source: vscodeTab ? vscode : all
    property string query: ""
    property int sel: 0 // fila seleccionada de `rows` (nunca una cabecera)
    property point mousePos: Qt.point(-1, -1)

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? source : source.filter(b => b.desc.toLowerCase().includes(q) || b.section.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q));
    }
    // Lo que pinta la lista: los atajos con una cabecera { header } delante de cada sección
    readonly property var rows: {
        const out = [];
        let last = null;
        for (const b of results) {
            if (b.section !== last)
                out.push({ header: b.section });
            last = b.section;
            out.push(b);
        }
        return out;
    }

    // Nombres de las teclas como se ven en el teclado
    readonly property var keyNames: ({
            "SUPER": "Super",
            "CTRL": "Ctrl",
            "SHIFT": "Shift",
            "ALT": "Alt",
            "RETURN": "Enter",
            "SPACE": "Space",
            "ESCAPE": "Esc",
            "BACKSPACE": "⌫",
            "TAB": "Tab",
            "PRINT": "Print",
            "PERIOD": ".",
            "COMMA": ",",
            "SEMICOLON": ";",
            "SLASH": "/",
            "MINUS": "-",
            "EQUAL": "=",
            "BACKSLASH": "\\",
            "PAGE_UP": "PgUp",
            "PAGE_DOWN": "PgDn",
            "LEFT": "←",
            "RIGHT": "→",
            "UP": "↑",
            "DOWN": "↓",
            "MOUSE_DOWN": "Scroll ↓",
            "MOUSE_UP": "Scroll ↑",
            "MOUSE:272": "Click izq.",
            "MOUSE:273": "Click der.",
            "XF86AUDIORAISEVOLUME": "Vol +",
            "XF86AUDIOLOWERVOLUME": "Vol −",
            "XF86AUDIOMUTE": "Mute",
            "XF86AUDIOMICMUTE": "Mic mute",
            "XF86AUDIOPLAY": "Play",
            "XF86AUDIOPAUSE": "Pause",
            "XF86AUDIONEXT": "Next",
            "XF86AUDIOPREV": "Prev",
            "XF86AUDIOSTOP": "Stop",
            "XF86MONBRIGHTNESSUP": "Brillo +",
            "XF86MONBRIGHTNESSDOWN": "Brillo −",
            "XF86TOUCHPADTOGGLE": "Touchpad"
        })
    readonly property var arrows: ({
            "left": "←",
            "l": "←",
            "right": "→",
            "r": "→",
            "up": "↑",
            "u": "↑",
            "down": "↓",
            "d": "↓"
        })
    // Paneles de la shell (hl.dsp.global("salchipapa:…")) sin comentario en keybinds.lua
    readonly property var globals: ({
            "launcher": "Lanzador (en la isla)",
            "themes": "Selector de temas (en la isla)",
            "screenshot": "Captura con selector",
            "mediaToggle": "Reproducir/pausar",
            "mediaNext": "Siguiente pista",
            "mediaPrev": "Pista anterior",
            "mediaStop": "Detener reproducción",
            "touchpad": "Activar/desactivar el touchpad"
        })

    function setTab(vs: bool): void {
        vscodeTab = vs;
        if (vs)
            vscodeProc.running = true; // al día con keybindings.json y las extensiones
        sel = firstRow();
        list.positionViewAtBeginning();
    }

    function firstRow(): int {
        return rows.findIndex(r => r.header === undefined);
    }
    // Como en el launcher, pero saltando las cabeceras; al llegar arriba de una sección la muestra
    function move(d: int): void {
        let i = sel + d;
        while (i >= 0 && i < rows.length && rows[i].header !== undefined)
            i += d;
        if (i < 0 || i >= rows.length)
            return;
        sel = i;
        if (rows[i - 1]?.header !== undefined)
            Qt.callLater(() => list.positionViewAtIndex(i - 1, ListView.Contain));
    }

    function keyLabel(k: string): string {
        if (k.includes(" / ")) // teclas de un bucle ipairs: "XF86AudioPlay / XF86AudioPause"
            return k.split(" / ").map(keyLabel).join(" / ");
        const name = keyNames[k.toUpperCase()];
        return name ?? (k.length === 1 ? k.toUpperCase() : k);
    }

    // `mod .. " + SHIFT + " .. key` → ["Super", "Shift", "0–9"]
    function parseKeys(expr: string, vars: var): var {
        const combo = expr.split("..").map(t => {
            t = t.trim();
            const lit = t.match(/^"(.*)"$/);
            if (lit)
                return lit[1];
            return t === "mod" ? "SUPER" : (vars[t] ?? t);
        }).join("");
        return combo.split("+").map(s => s.trim()).filter(s => s !== "").map(keyLabel);
    }

    function describe(action: string): string {
        let m;
        if ((m = action.match(/global\("salchipapa:(\w+)"\)/)))
            return globals[m[1]] ?? m[1];
        if ((m = action.match(/^v\.app\((.+)\)$/))) {
            const app = m[1].replace(/^v\./, "").replace(/"/g, "");
            return "Abrir " + ({
                    "terminal": "la terminal",
                    "browser": "el navegador",
                    "fileManager": "el gestor de archivos"
                }[app] ?? app);
        }
        if ((m = action.match(/focus\(\{ direction = "(\w+)" \}\)/)))
            return "Enfocar ventana " + (arrows[m[1]] ?? m[1]);
        if ((m = action.match(/focus\(\{ monitor = "(\w+)" \}\)/)))
            return "Enfocar monitor " + (arrows[m[1]] ?? m[1]);
        if ((m = action.match(/focus\(\{ workspace = (.+) \}\)/)))
            return wsTarget(m[1], "Ir al workspace");
        if ((m = action.match(/window\.move\(\{ direction = "(\w+)" \}\)/)))
            return "Mover ventana " + (arrows[m[1]] ?? m[1]);
        if ((m = action.match(/window\.move\(\{ monitor = "(\w+)" \}\)/)))
            return "Mover ventana al monitor " + (arrows[m[1]] ?? m[1]);
        if ((m = action.match(/window\.move\(\{ workspace = (.+) \}\)/)))
            return wsTarget(m[1], "Mover ventana al workspace");
        if (action.includes("out_of_group"))
            return "Sacar ventana del grupo";
        if ((m = action.match(/toggle_special\("(\w+)"\)/)))
            return "Mostrar/ocultar special:" + m[1];
        if ((m = action.match(/window\.resize\(\{ x = (-?\d+), y = (-?\d+)/))) {
            const x = Number(m[1]), y = Number(m[2]);
            return x < 0 ? "Estrechar ventana" : x > 0 ? "Ensanchar ventana" : y < 0 ? "Reducir alto de la ventana" : "Aumentar alto de la ventana";
        }
        if (action.includes("window.resize()"))
            return "Redimensionar ventana con el ratón";
        if (action.includes("window.drag()"))
            return "Arrastrar ventana";
        if (action.includes("window.close()"))
            return "Cerrar ventana";
        if (action.includes("dsp.exit()"))
            return "Salir de Hyprland";
        if (action.includes("window.fullscreen"))
            return "Pantalla completa";
        if (action.includes("window.pseudo()"))
            return "Pseudo-tiling";
        if (action.includes("togglesplit"))
            return "Alternar división horizontal/vertical";
        if (action.includes("window.center()"))
            return "Centrar ventana";
        if (action.includes("cycle_next({ next = false })"))
            return "Ventana anterior";
        if (action.includes("cycle_next()"))
            return "Ventana siguiente";
        if (action.includes("group.next()"))
            return "Siguiente pestaña del grupo";
        if (action.includes("group.prev()"))
            return "Pestaña anterior del grupo";
        if (action.includes("group.toggle()"))
            return "Agrupar/desagrupar ventanas";
        if (action.includes("group.lock"))
            return "Bloquear/desbloquear el grupo";
        if (action.includes("set-volume") && action.includes("%+"))
            return "Subir volumen";
        if (action.includes("set-volume"))
            return "Bajar volumen";
        if (action.includes("set-mute @DEFAULT_AUDIO_SOURCE@"))
            return "Silenciar micrófono";
        if (action.includes("set-mute"))
            return "Silenciar audio";
        if (action.includes("brightnessctl"))
            return action.includes("%+") ? "Subir brillo" : "Bajar brillo";
        if ((m = action.match(/v\.screenshot \.\. " (\w+)"/)))
            return m[1] === "region" ? "Captura de una región" : "Captura de pantalla completa";
        return action;
    }

    function wsTarget(t: string, verb: string): string {
        t = t.replace(/"/g, "");
        const named = {
            "-1": "anterior",
            "+1": "siguiente",
            "-10": "del grupo anterior",
            "+10": "del grupo siguiente",
            "e+1": "ocupado siguiente",
            "e-1": "ocupado anterior",
            "e+0": "actual"
        };
        if (named[t])
            return verb + " " + named[t];
        if (t.startsWith("special:"))
            return verb + " " + t;
        return verb + " con ese número";
    }

    // Separa `código -- comentario` sin confundir un "--" dentro de un string
    function splitComment(line: string): var {
        let quote = "";
        for (let j = 0; j < line.length; j++) {
            const c = line[j];
            if (quote !== "") {
                if (c === "\\")
                    j++;
                else if (c === quote)
                    quote = "";
            } else if (c === '"' || c === "'") {
                quote = c;
            } else if (c === "-" && line[j + 1] === "-") {
                return [line.slice(0, j).trim(), line.slice(j + 2).trim()];
            }
        }
        return [line.trim(), ""];
    }

    function parse(src: string): var {
        const out = [];
        const vars = {};
        const lines = src.split("\n");
        let section = "";
        let lastComment = ""; // comentario de la línea anterior (describe la siguiente)
        let sectionNote = ""; // lo que dice la sección tras ":" (si un atajo no tiene otra descripción)
        let fnDepth = 0; // dentro de una función local (su hl.bind es parte de un helper)
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            const t = line.trim();
            if (/^local function /.test(t)) {
                fnDepth = 1;
                continue;
            }
            if (fnDepth > 0) {
                if (/^end\b/.test(line))
                    fnDepth = 0;
                continue;
            }
            let m;
            if (/^--/.test(line)) { // comentario de primer nivel = sección
                // Solo la primera línea del bloque, sin lo que va tras ":" ni entre paréntesis
                if (!/^--/.test(lines[i - 1] ?? "")) {
                    const head = t.replace(/^--\s*/, "");
                    section = head.split(/[:,]/)[0].replace(/\s*\(.*\)/, "").replace(/\.$/, "").trim();
                    sectionNote = head.includes(":") ? head.slice(head.indexOf(":") + 1).replace(/\s*\(.*\)/, "").replace(/\.$/, "").trim() : "";
                }
                lastComment = "";
                continue;
            }
            if (/^--/.test(t)) {
                // Sin el atajo delante ("Super+Alt+numero: mover…")
                lastComment = t.replace(/^--\s*/, "").replace(/^[\w+]+:\s*/, "").replace(/\.$/, "");
                continue;
            }
            if ((m = t.match(/^for _, (\w+) in ipairs\(\{(.*)\}\) do/)))
                vars[m[1]] = m[2].split(",").map(s => s.trim().replace(/"/g, "")).join(" / ");
            else if ((m = t.match(/^for (\w+) = (\d+), (\d+) do/)))
                vars[m[1]] = m[2] + "–" + m[3];
            else if ((m = t.match(/^local (\w+) = (\w+) % 10/)))
                vars[m[1]] = "0–9";

            // hl.bind( … ) repartido en varias líneas: se junta hasta el ")" de cierre
            if (/^(hl\.bind|bindWorkspaceGroup)\($/.test(t)) {
                while (i + 1 < lines.length && !/^\s*\)/.test(lines[i + 1]))
                    line += " " + lines[++i].trim();
                line += lines[++i]?.trim() ?? "";
            }
            const [code, comment] = splitComment(line);
            m = code.match(/^(hl\.bind|bindWorkspaceGroup)\((.*)\)$/);
            if (!m) {
                lastComment = "";
                continue;
            }
            // Primer argumento: la combinación (hasta la primera coma fuera de llaves/paréntesis)
            const args = m[2];
            let depth = 0, cut = args.length;
            for (let j = 0; j < args.length; j++) {
                const c = args[j];
                if (c === "(" || c === "{")
                    depth++;
                else if (c === ")" || c === "}")
                    depth--;
                else if (c === "," && depth === 0) {
                    cut = j;
                    break;
                }
            }
            let action = args.slice(cut + 1).trim().replace(/,\s*\{[^}]*\}\s*$/, "").replace(/,$/, "").trim();
            const auto = describe(action);
            const desc = comment !== "" ? comment : lastComment !== "" ? lastComment : auto !== action ? auto : sectionNote !== "" ? sectionNote : action;
            out.push({
                section: section,
                keys: parseKeys(args.slice(0, cut), vars),
                desc: desc.charAt(0).toUpperCase() + desc.slice(1)
            });
            lastComment = "";
        }
        return out;
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "binds") {
                root.query = "";
                searchInput.text = "";
                root.vscodeTab = false;
                root.sel = root.firstRow();
                list.positionViewAtBeginning();
                searchInput.forceActiveFocus();
            }
        }
    }

    FileView {
        path: Quickshell.shellDir + "/../lua/keybinds.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.all = root.parse(text())
    }

    Process {
        id: vscodeProc
        command: ["python3", Quickshell.shellDir + "/../scripts/vscode-keybinds.py"]
        stdout: StdioCollector {
            id: vscodeOut
            onStreamFinished: {
                try {
                    root.vscode = JSON.parse(vscodeOut.text);
                } catch (e) {
                    return;
                }
                if (root.vscodeTab)
                    root.sel = root.firstRow();
            }
        }
    }

    // --- Buscador ---
    Item {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "keyboard"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Theme.overlay1
        }
        TextInput {
            id: searchInput
            font.family: Theme.bodyFontFamily
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: tabs.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(15)
            clip: true
            focus: Overlay.mode === "binds"
            onTextChanged: {
                root.query = text;
                root.sel = root.firstRow();
                list.positionViewAtBeginning();
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.vscodeTab ? "Search VS Code shortcuts…" : "Search shortcuts (action or key)…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onUpPressed: root.move(-1)
            Keys.onDownPressed: root.move(1)
            // Ctrl+J / Ctrl+K como en vim (j y k a secas se escriben en el buscador)
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_J || event.key === Qt.Key_K)) {
                    root.move(event.key === Qt.Key_J ? 1 : -1);
                    event.accepted = true;
                }
            }
            Keys.onEscapePressed: Overlay.close()
            Keys.onTabPressed: root.setTab(!root.vscodeTab)
            Keys.onBacktabPressed: root.setTab(!root.vscodeTab)
        }

        // Pestañas: Hyprland / VS Code (Tab o clic)
        Rectangle {
            id: tabs
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: tabRow.implicitWidth + 6
            height: 24
            radius: 12
            color: Theme.surface0
            Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: [{ label: "Hyprland", icon: "keyboard", vs: false }, { label: "VS Code", icon: "code", vs: true }]
                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool on: root.vscodeTab === modelData.vs
                        width: tabContent.implicitWidth + 14
                        height: 20
                        radius: 10
                        color: on ? Theme.green : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverDuration
                            }
                        }
                        Row {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: tab.modelData.icon
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 13
                                color: tab.on ? Theme.islandBg : Theme.secondaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: tab.modelData.label
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.bold: tab.on
                                color: tab.on ? Theme.islandBg : Theme.secondaryText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!tab.on)
                                    root.setTab(tab.modelData.vs);
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Lista agrupada por sección ---
    ListView {
        id: list
        anchors.top: search.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        clip: true
        model: root.rows
        currentIndex: root.sel
        // Igual que el launcher: duración fija para que la lista no siga sola al soltar la flecha
        highlightMoveVelocity: -1
        highlightMoveDuration: 100
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        // Todas las filas creadas de antemano (son ~120): crearlas al desplazar daba tirones
        cacheBuffer: 6000

        SmoothWheel {
            flickable: list
        }

        delegate: Rectangle {
            id: row
            required property int index
            required property var modelData
            readonly property bool isHeader: modelData.header !== undefined
            width: ListView.view.width
            height: isHeader ? 36 : 42
            radius: 10
            color: !isHeader && index === root.sel ? Theme.surface0 : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 24
                radius: 2
                color: Theme.green
                visible: !row.isHeader && row.index === root.sel
            }

            Text {
                visible: row.isHeader
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: row.modelData.header ?? ""
                color: Theme.green
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.DemiBold
            }

            Text {
                visible: !row.isHeader
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: caps.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.desc ?? ""
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(15)
                elide: Text.ElideRight
            }
            Row {
                id: caps
                visible: !row.isHeader
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: row.modelData.keys ?? []
                    delegate: Rectangle {
                        id: cap
                        required property string modelData
                        readonly property bool sep: modelData === "·" // entre las teclas de un acorde
                        width: sep ? capText.implicitWidth + 2 : Math.max(30, capText.implicitWidth + 16)
                        height: 30
                        radius: 7
                        color: sep ? "transparent" : Theme.surface0
                        border.width: sep ? 0 : 1
                        border.color: Theme.surface1
                        Text {
                            id: capText
                            anchors.centerIn: parent
                            text: cap.modelData
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(13)
                        }
                    }
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: !row.isHeader
                // Solo si el ratón se movió de verdad (como en el launcher): al bajar con las flechas
                // la fila que pasa bajo el cursor quieto no roba la selección
                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    if (row.isHeader || (p.x === root.mousePos.x && p.y === root.mousePos.y))
                        return;
                    root.mousePos = p;
                    root.sel = row.index;
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.source.length === 0 ? "Loading…" : "No matching shortcut"
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(13)
        }
    }

    // --- Pie ---
    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: root.results.length + " shortcuts · from " + (root.vscodeTab ? "keybindings.json, extensions and VS Code defaults" : "lua/keybinds.lua")
            color: Theme.overlay1
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "Tab: Hyprland/VS Code · ↑/↓ or Ctrl+J/K: move · Esc: close"
            color: Theme.overlay1
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
    }
}
