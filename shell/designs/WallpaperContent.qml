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
                if (root.animatedTab)
                    animatedProc.running = true;
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                root.files = listOut.text.trim().split("\n").filter(s => s.length > 0);
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
        id: stopProc
        command: [root.scripts + "/animated-wallpaper.sh", "stop"]
    }

    // --- Buscador + contador ---
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44

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
            font.pixelSize: Theme.fontPx(15)
            clip: true
            focus: Overlay.mode === "wallpaper"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.animatedTab ? "Search animated wallpapers…" : "Search wallpapers…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
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
                height: 24
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
                        font.pixelSize: Theme.fontPx(11)
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
                height: 24
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
            height: 24
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
                    font.pixelSize: Theme.fontPx(11)
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
            font.pixelSize: Theme.fontPx(11)
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
        height: 134
        orientation: ListView.Horizontal
        spacing: 14
        clip: true
        model: root.results
        currentIndex: root.sel
        highlightMoveDuration: 220
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - 180) / 2
        preferredHighlightEnd: (width - 180) / 2
        snapMode: ListView.SnapToItem
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: cell
            required property int index
            required property var modelData
            readonly property bool active: index === root.sel

            width: 180
            height: cards.height

            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: 172
                height: 104
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

                    // Animados: tipo (escena, vídeo, web) y si es el activo
                    Rectangle {
                        visible: typeof cell.modelData !== "string"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: typeText.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: "#b3000000"
                        Text {
                            id: typeText
                            anchors.centerIn: parent
                            text: typeof cell.modelData === "string" ? "" : ((cell.modelData.id === Wallpaper.animated ? "● " : "") + ({ scene: "Scene", video: "Video", web: "Web" }[cell.modelData.type] ?? cell.modelData.type))
                            color: typeof cell.modelData !== "string" && cell.modelData.id === Wallpaper.animated ? Theme.green : "#ffffff"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.bold: true
                        }
                    }

                    // Nombre (franja inferior)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 22
                        color: "#b3000000"
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            text: root.titleOf(cell.modelData)
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(11)
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
        font.pixelSize: Theme.fontPx(10)
    }
}
