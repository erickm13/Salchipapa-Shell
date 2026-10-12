pragma ComponentBehavior: Bound
// Selector de temas (Super+T). Lista los esquemas de caelestia con sus muestras de color
// y al aplicar llama a `caelestia scheme set`, que tematiza TODAS las apps. La shell lee el
// nuevo esquema de scheme.json (ver Theme.qml) y también se recolorea en vivo.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

Scope {
    id: root

    property bool active: false
    property int sel: 0
    property string query: ""
    property var schemes: [] // [{ name, swatches: [#hex,...] }]

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? schemes : schemes.filter(s => s.name.toLowerCase().includes(q));
    }

    function open(): void {
        query = "";
        sel = 0;
        active = true;
        listProc.running = true; // refresca la lista al abrir
    }
    function close(): void {
        active = false;
    }
    function toggle(): void {
        active ? close() : open();
    }
    function apply(): void {
        const s = results[sel];
        if (s) {
            applyProc.command = ["caelestia", "scheme", "set", "-n", s.name];
            applyProc.running = true;
            close();
        }
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "themes"
        description: "Abrir/cerrar el selector de temas"
        onPressed: root.toggle()
    }

    // Lista de esquemas (JSON) de caelestia
    Process {
        id: listProc
        command: ["caelestia", "scheme", "list"]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(listOut.text);
                    const roles = ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "error"];
                    root.schemes = Object.keys(data).sort().map(name => {
                        const flavours = data[name];
                        const c = flavours[Object.keys(flavours)[0]];
                        return {
                            name: name,
                            swatches: roles.map(r => c[r] ? "#" + c[r] : "#555555")
                        };
                    });
                } catch (e) {
                    root.schemes = [];
                }
            }
        }
    }

    Process {
        id: applyProc
    }

    PanelWindow {
        id: win

        visible: root.active
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: if (visible)
            searchInput.forceActiveFocus()

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // ===== Panel =====
        Rectangle {
            id: panel

            width: 720
            height: 210
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.5 - height / 2
            radius: 26
            color: Theme.islandBg
            border.color: Theme.islandBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
            }

            // --- Buscador + contador ---
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 46

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
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 12
                    anchors.right: counter.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: 15
                    clip: true
                    onTextChanged: {
                        root.query = text;
                        root.sel = 0;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar temas…"
                        color: Theme.overlay0
                        font: parent.font
                        visible: parent.text.length === 0
                    }

                    Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
                    Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
                    Keys.onReturnPressed: root.apply()
                    Keys.onEnterPressed: root.apply()
                    Keys.onEscapePressed: root.close()
                }
                Text {
                    id: counter
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.results.length > 0 ? (root.sel + 1) + "/" + root.results.length : "0/0"
                    color: Theme.subtext
                    font.pixelSize: 13
                }
            }

            Rectangle {
                id: divider
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Theme.surface0
            }

            // --- Carrusel de temas ---
            ListView {
                id: cards
                anchors.top: divider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 14
                height: 120
                orientation: ListView.Horizontal
                spacing: 14
                leftMargin: 18
                rightMargin: 18
                clip: true
                model: root.results
                currentIndex: root.sel
                highlightMoveDuration: 180
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width - 150
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    width: 150
                    height: 110
                    radius: 16
                    color: index === root.sel ? Theme.surface1 : Theme.surface0
                    border.width: index === root.sel ? 2 : 0
                    border.color: Theme.green

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        // Muestras de color
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            Repeater {
                                model: card.modelData.swatches
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 11
                                    height: 11
                                    radius: 6
                                    color: modelData
                                }
                            }
                        }
                        // Nombre
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.name
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: index === root.sel
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

            // Pista
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                text: "Enter para aplicar"
                color: Theme.overlay1
                font.pixelSize: 11
            }
        }
    }
}
