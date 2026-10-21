pragma ComponentBehavior: Bound
// Selector de emojis, DENTRO de la isla (modo "emoji", Super+.). Datos en assets/emojis.json
// (scripts/update-emojis.sh): nombres en español e inglés, categorías de emojibase y glifos de
// Nerd Font. Enter/clic: lo copia y, si está `wtype`, lo escribe en la ventana enfocada.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

Item {
    id: root

    readonly property string recentPath: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/emoji-recent.json"
    readonly property var tabs: [
        { g: -1, icon: "history", name: "Recent" },
        { g: 0, icon: "sentiment_satisfied", name: "Smileys & Emotion" },
        { g: 1, icon: "emoji_people", name: "People & Body" },
        { g: 3, icon: "pets", name: "Animals & Nature" },
        { g: 4, icon: "restaurant", name: "Food & Drink" },
        { g: 5, icon: "flight", name: "Travel & Places" },
        { g: 6, icon: "sports_soccer", name: "Activities" },
        { g: 7, icon: "lightbulb", name: "Objects" },
        { g: 8, icon: "emoji_symbols", name: "Symbols" },
        { g: 9, icon: "flag", name: "Flags" },
        { g: 10, icon: "terminal", name: "Nerd Font" }
    ]

    property var all: []
    property var recent: [] // caracteres, el más reciente primero
    property int tab: 1
    property string query: ""
    property int sel: 0

    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q !== "") {
            // Primero los emojis y luego los glifos de Nerd Font; tope para que la cuadrícula vaya fluida
            const words = q.split(/\s+/);
            const hits = all.filter(it => words.every(w => it.k.includes(w)));
            return hits.filter(it => it.g !== 10).concat(hits.filter(it => it.g === 10)).slice(0, 600);
        }
        const g = tabs[tab].g;
        if (g === -1)
            return recent.map(e => all.find(it => it.e === e) ?? { e: e, n: "", g: 0, k: "" });
        return all.filter(it => it.g === g);
    }
    readonly property var current: results[sel] ?? null

    function pick(): void {
        const it = current;
        if (!it)
            return;
        recent = [it.e].concat(recent.filter(e => e !== it.e)).slice(0, 48);
        recentFile.setText(JSON.stringify(recent));
        Overlay.close();
        // Copia siempre; con wtype además lo escribe cuando la ventana recupera el foco
        pickProc.exec(["sh", "-c", 'printf %s "$1" | wl-copy; if command -v wtype >/dev/null; then sleep 0.3; wtype -- "$1"; fi', "sh", it.e]);
    }

    function move(d: int): void {
        sel = Math.max(0, Math.min(results.length - 1, sel + d));
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "emoji") {
                root.query = "";
                searchInput.text = "";
                root.tab = root.recent.length > 0 ? 0 : 1;
                root.sel = 0;
                searchInput.forceActiveFocus();
            }
        }
    }

    FileView {
        path: Quickshell.shellDir + "/assets/emojis.json"
        onLoaded: root.all = JSON.parse(text())
    }
    FileView {
        id: recentFile
        path: root.recentPath
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text());
            } catch (e) {
                root.recent = [];
            }
        }
    }
    Process { id: pickProc }

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
            text: "mood"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Theme.overlay1
        }
        TextInput {
            id: searchInput
            font.family: Theme.bodyFontFamily
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(15)
            clip: true
            focus: Overlay.mode === "emoji"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search emoji (English or Spanish)…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onLeftPressed: event => {
                if (root.query === "" || cursorPosition === 0) root.move(-1);
                else event.accepted = false;
            }
            Keys.onRightPressed: event => {
                if (root.query === "" || cursorPosition === text.length) root.move(1);
                else event.accepted = false;
            }
            Keys.onUpPressed: root.move(-grid.columns)
            Keys.onDownPressed: root.move(grid.columns)
            Keys.onTabPressed: {
                root.tab = (root.tab + 1) % root.tabs.length;
                root.sel = 0;
            }
            Keys.onBacktabPressed: {
                root.tab = (root.tab + root.tabs.length - 1) % root.tabs.length;
                root.sel = 0;
            }
            Keys.onReturnPressed: root.pick()
            Keys.onEnterPressed: root.pick()
            Keys.onEscapePressed: Overlay.close()
        }
    }

    // --- Pestañas de categorías ---
    Row {
        id: tabRow
        anchors.top: search.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        opacity: root.query === "" ? 1 : 0.4
        Repeater {
            model: root.tabs
            delegate: Rectangle {
                id: tabBtn
                required property int index
                required property var modelData
                readonly property bool on: root.tab === index
                width: 40
                height: 32
                radius: 10
                color: on ? Theme.surface0 : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: tabBtn.modelData.icon
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 19
                    color: tabBtn.on ? Theme.green : Theme.secondaryText
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        searchInput.text = "";
                        root.tab = tabBtn.index;
                        root.sel = 0;
                        searchInput.forceActiveFocus();
                    }
                }
            }
        }
    }

    // --- Cuadrícula ---
    GridView {
        id: grid
        readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
        anchors.top: tabRow.bottom
        anchors.topMargin: 8
        anchors.bottom: footer.top
        anchors.horizontalCenter: parent.horizontalCenter
        // Ancho = columnas enteras (centrada, sin hueco a la derecha)
        width: Math.floor((root.width - 24) / cellWidth) * cellWidth
        cellWidth: 50
        cellHeight: 50
        clip: true
        model: root.results
        currentIndex: root.sel
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        cacheBuffer: 200

        delegate: Rectangle {
            id: cell
            required property int index
            required property var modelData
            width: 46
            height: 46
            radius: 12
            color: index === root.sel ? Theme.surface0 : "transparent"
            border.width: index === root.sel ? 1 : 0
            border.color: Theme.green
            Text {
                anchors.centerIn: parent
                text: cell.modelData.e
                // Los glifos de Nerd Font solo se ven con una fuente Nerd
                font.family: cell.modelData.g === 10 ? "CaskaydiaCove Nerd Font" : Theme.bodyFontFamily
                // Los símbolos largos (¯\_(ツ)_/¯) en pequeño; los emojis compuestos con ZWJ no
                font.pixelSize: cell.modelData.g === 8 && Array.from(cell.modelData.e).length > 2 ? 13 : 26
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = cell.index
                onClicked: {
                    root.sel = cell.index;
                    root.pick();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.all.length === 0 ? "Loading…" : root.query !== "" ? "No matching emoji" : "No recent emoji yet"
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
    }

    // --- Pie: nombre del seleccionado ---
    Item {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 34
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: hint.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? root.current.n : (root.query === "" ? root.tabs[root.tab].name : "")
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            elide: Text.ElideRight
        }
        Text {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter: pick · Tab: category"
            color: Theme.overlay1
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
    }
}
