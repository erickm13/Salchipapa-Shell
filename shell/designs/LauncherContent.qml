pragma ComponentBehavior: Bound
// Contenido del lanzador, para mostrarse DENTRO de la Dynamic Island (modo "launcher").
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../common"

Item {
    id: root

    property int sel: 0
    property string query: ""

    readonly property var results: {
        const all = DesktopEntries.applications.values;
        const q = query.trim().toLowerCase();
        const list = q === "" ? all.slice() : all.filter(a => (a.name ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q) || (a.comment ?? "").toLowerCase().includes(q));
        return list.sort((x, y) => (x.name ?? "").localeCompare(y.name ?? ""));
    }

    function launch(): void {
        const app = results[sel];
        if (app) {
            app.execute();
            Overlay.close();
        }
    }

    // Al abrir el modo, resetea la búsqueda
    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "launcher") {
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
        height: 52

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
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: 16
            clip: true
            focus: Overlay.mode === "launcher"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar aplicaciones…"
                color: Theme.overlay0
                font: parent.font
                visible: parent.text.length === 0
            }

            Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onReturnPressed: root.launch()
            Keys.onEnterPressed: root.launch()
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
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        clip: true
        spacing: 2
        model: root.results
        currentIndex: root.sel
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: item
            required property int index
            required property var modelData

            width: ListView.view.width
            height: 48
            radius: 12
            color: index === root.sel ? Theme.surface0 : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 24
                radius: 2
                color: Theme.green
                visible: index === root.sel
            }

            IconImage {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 30
                asynchronous: true
                source: Quickshell.iconPath(item.modelData.icon, "image-missing")
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text: item.modelData.name ?? ""
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: item.modelData.comment || item.modelData.genericName || ""
                    color: Theme.subtext
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = item.index
                onClicked: {
                    root.sel = item.index;
                    root.launch();
                }
            }
        }
    }
}
