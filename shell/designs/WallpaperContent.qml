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

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? files : files.filter(f => f.toLowerCase().includes(q));
    }

    function nameOf(path) {
        return (path.split("/").pop() || "").replace(/\.[^.]+$/, "");
    }

    function apply(): void {
        const f = results[sel];
        if (f) {
            // Cambia el fondo, pone el esquema en 'dynamic' (sigue al wallpaper) y recarga
            // Hyprland (para que el glow de ventanas también tome los colores nuevos).
            applyProc.command = ["sh", "-c", "caelestia wallpaper -f \"$1\" && caelestia scheme set -n dynamic && hyprctl reload", "sh", f];
            applyProc.running = true;
            Overlay.close();
        }
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "wallpaper") {
                root.query = "";
                root.sel = 0;
                searchInput.text = "";
                listProc.running = true;
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.files = listOut.text.trim().split("\n").filter(s => s.length > 0)
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
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: counter.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: 15
            clip: true
            focus: Overlay.mode === "wallpaper"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar fondos…"
                color: Theme.overlay0
                font: parent.font
                visible: parent.text.length === 0
            }
            Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onReturnPressed: root.apply()
            Keys.onEnterPressed: root.apply()
            Keys.onEscapePressed: Overlay.close()
        }
        Text {
            id: counter
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: root.results.length > 0 ? (root.sel + 1) + "/" + root.results.length : "0/0"
            color: Theme.subtext
            font.pixelSize: 12
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

    // --- Carrusel de miniaturas ---
    ListView {
        id: cards
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        height: 120
        orientation: ListView.Horizontal
        spacing: 12
        leftMargin: 16
        rightMargin: 16
        clip: true
        model: root.results
        currentIndex: root.sel
        highlightMoveDuration: 180
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: width - 180
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: card
            required property int index
            required property var modelData

            width: 180
            height: 112
            radius: 15
            color: index === root.sel ? Theme.green : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            ClippingRectangle {
                anchors.centerIn: parent
                width: parent.width - (index === root.sel ? 6 : 0)
                height: parent.height - (index === root.sel ? 6 : 0)
                radius: 12
                color: Theme.surface0

                Image {
                    anchors.fill: parent
                    source: "file://" + card.modelData
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
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: root.nameOf(card.modelData)
                        color: "#ffffff"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = card.index
                onClicked: {
                    root.sel = card.index;
                    root.apply();
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: "Enter para aplicar"
        color: Theme.overlay1
        font.pixelSize: 11
    }
}
