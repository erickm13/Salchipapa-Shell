pragma ComponentBehavior: Bound
// Contenido del selector de temas, para mostrarse DENTRO de la isla (modo "themes").
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"

Item {
    id: root

    property int sel: 0
    property string query: ""
    property var schemes: []
    property string currentScheme: "" // esquema activo (nombre o "dynamic")

    // Card "Dynamic": los colores los controla matugen según el wallpaper actual.
    readonly property var dynamicCard: ({
            name: "Dynamic",
            dynamic: true,
            swatches: [Theme.green, Theme.blue, Theme.peach, Theme.mauve, Theme.yellow, Theme.sapphire, Theme.red]
        })
    readonly property var allSchemes: [dynamicCard].concat(schemes)

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? allSchemes : allSchemes.filter(s => s.name.toLowerCase().includes(q));
    }

    // Selecciona (y centra) la card del esquema activo
    function selectCurrent(): void {
        const cur = currentScheme.toLowerCase();
        let i = results.findIndex(s => s.dynamic ? (cur === "dynamic" || cur === "") : s.name.toLowerCase() === cur);
        if (i < 0)
            i = 0;
        sel = i;
    }

    function apply(): void {
        const s = results[sel];
        if (!s)
            return;
        if (s.dynamic)
            // Dynamic: regenera los colores del wallpaper actual con matugen (-> scheme=dynamic)
            applyProc.command = [Quickshell.shellDir + "/../scripts/wallpaper.sh", Wallpaper.current, "colors"];
        else
            applyProc.command = [Quickshell.shellDir + "/../scripts/apply-colors.sh", "scheme", s.name];
        applyProc.running = true;
        Overlay.close();
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "themes") {
                root.query = "";
                searchInput.text = "";
                searchInput.forceActiveFocus();
                listProc.running = true;
                curProc.running = true;
            }
        }
    }

    Process {
        id: listProc
        // Temas GUARDADOS en el repo (ya no depende de caelestia)
        command: ["cat", Quickshell.shellDir + "/themes/schemes.json"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(listOut.text);
                    const roles = ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "error"];
                    root.schemes = Object.keys(data).filter(n => n !== "dynamic").sort().map(name => {
                        const c = data[name][Object.keys(data[name])[0]];
                        return {
                            name: name,
                            swatches: roles.map(r => c[r] ? "#" + c[r] : "#555555")
                        };
                    });
                } catch (e) {
                    root.schemes = [];
                }
                root.selectCurrent();
            }
        }
    }
    // Esquema activo (nombre o "dynamic") para preseleccionar su card
    Process {
        id: curProc
        command: ["sh", "-c", "cat \"$HOME/.local/state/salchipapa-shell/scheme\" 2>/dev/null"]
        stdout: StdioCollector {
            id: curOut
            onStreamFinished: {
                root.currentScheme = curOut.text.trim();
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
        height: 56

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
            color: Theme.overlay1
        }
        TextInput {
            font.family: Theme.bodyFontFamily
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: counter.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(19)
            clip: true
            focus: Overlay.mode === "themes"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search themes…"
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

    // --- Carrusel ---
    ListView {
        id: cards
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        height: 200
        orientation: ListView.Horizontal
        spacing: 16
        clip: true
        model: root.results
        currentIndex: root.sel
        highlightMoveDuration: 220
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - 330) / 2
        preferredHighlightEnd: (width - 330) / 2
        snapMode: ListView.SnapToItem
        boundsBehavior: Flickable.StopAtBounds

        // Como el selector de fondos: cada celda ocupa todo el alto del carrusel y la tarjeta va
        // centrada dentro, así al crecer no se corta arriba ni abajo.
        delegate: Item {
            id: cell
            required property int index
            required property var modelData
            readonly property bool active: index === root.sel

            width: 330
            height: cards.height

            Rectangle {
                id: card
                anchors.centerIn: parent
                // 320 de ancho: caben nombres largos (gentleman-kanagawa-blur) con la letra a 20
                width: 320
                height: 165
                radius: 16
                // Oscuras como el fondo de la terminal (040e0d, el terminal-bg de los temas); la seleccionada,
                // un poco más clara y con el borde del acento.
                color: cell.active ? "#0f1f1d" : "#040e0d"
                border.width: cell.active ? 3 : 0
                border.color: Theme.green
                // Como el selector de fondos: la seleccionada crece y las demás se encogen y atenúan
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

                // Marca de la card Dynamic (colores de matugen)
                Text {
                    visible: cell.modelData.dynamic === true
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    text: "auto_awesome"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 13
                    color: Theme.green
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Repeater {
                            model: cell.modelData.swatches
                            delegate: Rectangle {
                                required property var modelData
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData
                            }
                        }
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, card.width - 20)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: cell.modelData.name
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(20)
                        font.bold: cell.active
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
        text: "Enter to apply"
        color: Theme.overlay1
        font.pixelSize: Theme.fontPx(14)
    }
}
