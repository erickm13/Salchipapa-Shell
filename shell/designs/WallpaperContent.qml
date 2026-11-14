pragma ComponentBehavior: Bound
// Selector de fondos, DENTRO de la isla (modo "wallpaper"). Igual que el de temas pero con
// miniaturas. Dos pestañas (Tab para cambiar): estáticos de ~/Pictures/Wallpapers
// (scripts/wallpaper.sh) y animados de Wallpaper Engine (scripts/animated-wallpaper.sh).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"

Item {
    id: root

    property int sel: 0
    property string query: ""
    property var files: [] // rutas de los wallpapers
    property bool applyColors: true // switch: generar colores del wallpaper (matugen)
    property bool animatedTab: false // pestaña de fondos animados (Wallpaper Engine)
    property var animatedList: [] // [{id, title, type, preview}]
    // Tema de cada fondo: estáticos, el de su carpeta (~/Pictures/Wallpapers/<tema>/); animados, el
    // de ~/.config/salchipapa-shell/animated-themes.json (scripts/classify-animated.py).
    property var themeMap: ({})
    property var themeNames: []
    readonly property string scripts: Quickshell.shellDir + "/../scripts"

    // Estáticos: rutas. Animados: objetos. Las celdas usan titleOf/previewOf para ambos.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (animatedTab)
            return q === "" ? animatedList : animatedList.filter(w => w.title.toLowerCase().includes(q));
        return q === "" ? files : files.filter(f => f.toLowerCase().includes(q));
    }

    function nameOf(path) {
        return (path.split("/").pop() || "").replace(/\.[^.]+$/, "");
    }
    function titleOf(item): string {
        return typeof item === "string" ? nameOf(item) : item.title;
    }
    function previewOf(item): string {
        return "file://" + (typeof item === "string" ? item : item.preview);
    }

    // Selecciona el wallpaper actual (la lista lo centra sola por StrictlyEnforceRange)
    function themeOf(item): string {
        if (typeof item === "string") {
            const m = item.match(/\/Wallpapers\/([^\/]+)\/[^\/]+$/);
            return m ? m[1] : "";
        }
        return root.themeMap[item.id] ?? "";
    }

    // ↑/↓: cambia el tema del seleccionado. Animados: su asignación (queda como corrección manual).
    // Estáticos: el archivo se mueve a la carpeta del tema (sin pisar uno con el mismo nombre); si es
    // el fondo puesto, se actualiza su ruta en el estado de la shell.
    property string pendingSelect: ""
    function cycleTheme(step: int): void {
        const item = results[sel];
        if (!item || themeNames.length === 0)
            return;
        const i = themeNames.indexOf(themeOf(item));
        const next = themeNames[((i < 0 ? (step > 0 ? -1 : 0) : i) + step + themeNames.length) % themeNames.length];
        if (!animatedTab) {
            const name = item.substring(item.lastIndexOf("/") + 1);
            const dest = Quickshell.env("HOME") + "/Pictures/Wallpapers/" + next + "/" + name;
            root.pendingSelect = dest;
            moveProc.command = ["sh", "-c", 'mkdir -p "${2%/*}" && [ ! -e "$2" ] && mv -n -- "$1" "$2" || exit 1; '
                + 's="$HOME/.local/state/salchipapa-shell"; '
                + 'if [ "$(cat "$s/wallpaper" 2>/dev/null)" = "$1" ]; then printf %s "$2" >"$s/wallpaper"; ln -sf "$2" "$s/current"; fi', "sh", item, dest];
            moveProc.running = true;
            return;
        }
        const m = Object.assign({}, root.themeMap);
        m[item.id] = next;
        root.themeMap = m;
        setThemeProc.command = ["python3", root.scripts + "/classify-animated.py", "--set", item.id, next];
        setThemeProc.running = true;
    }

    function selectCurrent(): void {
        const i = animatedTab ? results.findIndex(w => w.id === Wallpaper.animated) : results.findIndex(f => f === Wallpaper.current);
        sel = i >= 0 ? i : 0;
    }

    function setTab(animated: bool): void {
        if (animatedTab === animated)
            return;
        animatedTab = animated;
        if (animated && animatedList.length === 0)
            animatedProc.running = true;
        selectCurrent();
    }

    function apply(): void {
        const item = results[sel];
        if (!item)
            return;
        const colors = root.applyColors ? "colors" : "nocolors";
        if (animatedTab) {
            applyProc.command = [scripts + "/animated-wallpaper.sh", "set", item.id, colors];
        } else {
            // Un fondo estático quita el animado. wallpaper.sh cambia el fondo y (si el switch
            // está activo) genera los colores con matugen.
            applyProc.command = ["sh", "-c", '"$1/animated-wallpaper.sh" stop; "$1/wallpaper.sh" "$2" "$3"', "sh", scripts, item, colors];
        }
        applyProc.running = true;
        Overlay.close();
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "wallpaper") {
                root.query = "";
                searchInput.text = "";
                searchInput.forceActiveFocus();
                root.animatedTab = Wallpaper.animated !== "";
                listProc.running = true;
                mapProc.running = true;
                namesProc.running = true;
                if (root.animatedTab)
                    animatedProc.running = true;
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                root.files = listOut.text.trim().split("\n").filter(s => s.length > 0);
                const moved = root.files.indexOf(root.pendingSelect);
                root.pendingSelect = "";
                if (moved >= 0 && !root.animatedTab && root.query === "")
                    root.sel = moved;
                else
                    root.selectCurrent();
            }
        }
    }
    Process {
        id: animatedProc
        command: [root.scripts + "/animated-wallpaper.sh", "list"]
        stdout: StdioCollector {
            id: animatedOut
            onStreamFinished: {
                try {
                    root.animatedList = JSON.parse(animatedOut.text);
                } catch (e) {
                    root.animatedList = [];
                }
                if (root.animatedTab)
                    root.selectCurrent();
            }
        }
    }
    Process {
        id: applyProc
    }
    Process {
        id: mapProc
        command: ["sh", "-c", "cat \"$HOME/.config/salchipapa-shell/animated-themes.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            id: mapOut
            onStreamFinished: {
                try {
                    root.themeMap = JSON.parse(mapOut.text);
                } catch (e) {
                    root.themeMap = {};
                }
            }
        }
    }
    Process {
        id: namesProc
        command: ["jq", "-r", "keys_unsorted[] | select(. != \"dynamic\")", Quickshell.shellDir + "/themes/schemes.json"]
        stdout: StdioCollector {
            id: namesOut
            onStreamFinished: root.themeNames = namesOut.text.trim().split("\n").filter(s => s.length > 0).sort()
        }
    }
    Process {
        id: setThemeProc
    }
    Process {
        id: moveProc
        onExited: listProc.running = true // se relee la lista y se vuelve a seleccionar el movido
    }
    Process {
        id: stopProc
        command: [root.scripts + "/animated-wallpaper.sh", "stop"]
    }

    // --- Buscador + contador ---
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "wallpaper"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: Theme.overlay1
        }
        TextInput {
            font.family: Theme.bodyFontFamily
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: tabs.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(19)
            clip: true
            focus: Overlay.mode === "wallpaper"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.animatedTab ? "Search animated wallpapers…" : "Search wallpapers…") + "  (↑/↓: change its theme)"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onUpPressed: root.cycleTheme(-1)
            Keys.onDownPressed: root.cycleTheme(1)
            Keys.onReturnPressed: root.apply()
            Keys.onEnterPressed: root.apply()
            Keys.onEscapePressed: Overlay.close()
            Keys.onTabPressed: {
                root.setTab(!root.animatedTab);
                root.sel = 0;
                root.selectCurrent();
            }
        }

        // Pestañas: Estáticos / Animados (+ quitar el animado activo)
        Row {
            id: tabs
            anchors.right: colorToggle.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                visible: root.animatedTab && Wallpaper.animated !== ""
                width: stopRow.implicitWidth + 16
                height: 32
                radius: 12
                color: stopMouse.containsMouse ? Theme.red : Theme.surface0
                Row {
                    id: stopRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "stop_circle"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: stopMouse.containsMouse ? Theme.islandBg : Theme.secondaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Remove"
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(15)
                        color: stopMouse.containsMouse ? Theme.islandBg : Theme.secondaryText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stopProc.running = true
                }
            }

            Rectangle {
                width: tabRow.implicitWidth + 6
                height: 32
                radius: 12
                color: Theme.surface0
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [{ label: "Static", icon: "image", animated: false }, { label: "Animated", icon: "animated_images", animated: true }]
                        delegate: Rectangle {
                            id: tab
                            required property var modelData
                            readonly property bool on: root.animatedTab === modelData.animated
                            width: tabContent.implicitWidth + 14
                            height: 28
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
                                    font.pixelSize: Theme.fontPx(15)
                                    font.bold: tab.on
                                    color: tab.on ? Theme.islandBg : Theme.secondaryText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.setTab(tab.modelData.animated);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Switch: aplicar colores del wallpaper (matugen) sí/no
        Rectangle {
            id: colorToggle
            anchors.right: counter.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: toggleRow.implicitWidth + 16
            height: 32
            radius: 12
            color: root.applyColors ? Theme.green : Theme.surface0

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }

            Row {
                id: toggleRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                    text: "palette"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 14
                    color: root.applyColors ? Theme.islandBg : Theme.secondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    text: "Colors"
                    color: root.applyColors ? Theme.islandBg : Theme.secondaryText
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: root.applyColors
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyColors = !root.applyColors
            }
        }

        Text {
            font.family: Theme.bodyFontFamily
            id: counter
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.results.length > 0 ? (root.sel + 1) + "/" + root.results.length : "0/0"
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(15)
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.surface0
    }

    // --- Carrusel de miniaturas (cover-flow: el seleccionado va centrado y más grande) ---
    ListView {
        id: cards
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        height: 230
        orientation: ListView.Horizontal
        spacing: 14
        clip: true
        model: root.results
        currentIndex: root.sel
        highlightMoveDuration: 220
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - 310) / 2
        preferredHighlightEnd: (width - 310) / 2
        snapMode: ListView.SnapToItem
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cell
            required property int index
            required property var modelData
            readonly property bool active: index === root.sel

            width: 310
            height: cards.height

            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: 300
                height: 180
                radius: 15
                color: cell.active ? Theme.green : "transparent"
                scale: cell.active ? 1.14 : 0.86
                opacity: cell.active ? 1 : 0.6
                z: cell.active ? 1 : 0
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.movementDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: parent.width - (cell.active ? 6 : 0)
                    height: parent.height - (cell.active ? 6 : 0)
                    radius: 12
                    color: Theme.surface0

                    Image {
                        anchors.fill: parent
                        source: root.previewOf(cell.modelData)
                        sourceSize: Qt.size(360, 220)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }

                    // Tema del fondo (carpeta o asignación de los animados)
                    Rectangle {
                        visible: themeText.text !== ""
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6
                        width: themeText.implicitWidth + 12
                        height: 26
                        radius: 13
                        color: "#b3000000"
                        Text {
                            id: themeText
                            anchors.centerIn: parent
                            text: root.themeOf(cell.modelData)
                            color: "#ffffff"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(14)
                            font.bold: true
                        }
                    }

                    // Animados: tipo (escena, vídeo, web) y si es el activo
                    Rectangle {
                        visible: typeof cell.modelData !== "string"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: typeText.implicitWidth + 12
                        height: 26
                        radius: 13
                        color: "#b3000000"
                        Text {
                            id: typeText
                            anchors.centerIn: parent
                            text: typeof cell.modelData === "string" ? "" : ((cell.modelData.id === Wallpaper.animated ? "● " : "") + ({ scene: "Scene", video: "Video", web: "Web" }[cell.modelData.type] ?? cell.modelData.type))
                            color: typeof cell.modelData !== "string" && cell.modelData.id === Wallpaper.animated ? Theme.green : "#ffffff"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(14)
                            font.bold: true
                        }
                    }

                    // Nombre (franja inferior)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 34
                        color: "#b3000000"
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: root.titleOf(cell.modelData)
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(16)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = cell.index
                onClicked: {
                    root.sel = cell.index;
                    root.apply();
                }
            }
        }
    }

    Text {
        font.family: Theme.bodyFontFamily
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: "Enter to apply · Tab: static/animated"
        color: Theme.overlay1
        font.pixelSize: Theme.fontPx(14)
    }
}
