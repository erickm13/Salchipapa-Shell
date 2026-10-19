pragma ComponentBehavior: Bound
// Selector de fondos, DENTRO de la isla (modo "wallpaper"). Igual que el de temas pero con
// miniaturas. Al aplicar usa `caelestia wallpaper -f`, que genera los colores del fondo.
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

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? files : files.filter(f => f.toLowerCase().includes(q));
    }

    function nameOf(path) {
        return (path.split("/").pop() || "").replace(/\.[^.]+$/, "");
    }

    // Selecciona el wallpaper actual (la lista lo centra sola por StrictlyEnforceRange)
    function selectCurrent(): void {
        const i = results.findIndex(f => f === Wallpaper.current);
        sel = i >= 0 ? i : 0;
    }

    function apply(): void {
        const f = results[sel];
        if (f) {
            // Cambia el fondo, pone el esquema en 'dynamic' (sigue al wallpaper) y recarga
            // Hyprland (para que el glow de ventanas también tome los colores nuevos).
            // wallpaper.sh cambia el fondo y (si el switch está activo) genera los colores con matugen
            applyProc.command = [Quickshell.shellDir + "/../scripts/wallpaper.sh", f, root.applyColors ? "colors" : "nocolors"];
            applyProc.running = true;
            Overlay.close();
        }
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "wallpaper") {
                root.query = "";
                searchInput.text = "";
                searchInput.forceActiveFocus();
                listProc.running = true;
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
        id: applyProc
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
            anchors.right: colorToggle.left
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
                text: "Buscar fondos…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onReturnPressed: root.apply()
            Keys.onEnterPressed: root.apply()
            Keys.onEscapePressed: Overlay.close()
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
                    text: "Colores"
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
            font.pixelSize: Theme.fontPx(12)
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
                        source: "file://" + cell.modelData
                        sourceSize: Qt.size(360, 220)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
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
                            text: root.nameOf(cell.modelData)
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(10)
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
        text: "Enter para aplicar"
        color: Theme.overlay1
        font.pixelSize: Theme.fontPx(11)
    }
}
