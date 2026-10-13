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

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? schemes : schemes.filter(s => s.name.toLowerCase().includes(q));
    }

    function apply(): void {
        const s = results[sel];
        if (s) {
            applyProc.command = ["sh", "-c", "caelestia scheme set -n \"$1\" && hyprctl reload", "sh", s.name];
            applyProc.running = true;
            Overlay.close();
        }
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "themes") {
                root.query = "";
                root.sel = 0;
                searchInput.text = "";
                listProc.running = true;
            }
        }
    }

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
                        const c = data[name][Object.keys(data[name])[0]];
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
            text: "search"
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
            focus: Overlay.mode === "themes"
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

    // --- Carrusel ---
    ListView {
        id: cards
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        height: 110
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
        preferredHighlightEnd: width - 140
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: card
            required property int index
            required property var modelData

            width: 140
            height: 100
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
                spacing: 12

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Repeater {
                        model: card.modelData.swatches
                        delegate: Rectangle {
                            required property var modelData
                            width: 10
                            height: 10
                            radius: 5
                            color: modelData
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.modelData.name
                    color: "#ffffff"
                    font.pixelSize: 12
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

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        text: "Enter para aplicar"
        color: Theme.overlay1
        font.pixelSize: 11
    }
}
