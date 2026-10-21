pragma ComponentBehavior: Bound
// Historial del portapapeles, DENTRO de la isla (modo "clipboard", Super+V). Lee cliphist con
// scripts/clipboard.sh. Enter/clic = copiar, Supr = borrar del historial, "Clear" = todo.
// Las imágenes muestran una miniatura que se genera al verla (caché en ~/.cache).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"

Item {
    id: root

    readonly property string script: Quickshell.shellDir + "/../scripts/clipboard.sh"
    property int sel: 0
    property string query: ""
    property var items: [] // [{id, text, image}]
    property bool confirmWipe: false

    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? items : items.filter(i => !i.image && i.text.toLowerCase().includes(q));
    }

    function refresh(): void {
        listProc.exec([script, "list"]);
    }

    function copy(): void {
        const it = results[sel];
        if (!it)
            return;
        actionProc.exec([script, "copy", it.id]);
        Overlay.close();
    }

    function remove(): void {
        const it = results[sel];
        if (!it)
            return;
        actionProc.exec([script, "delete", it.id]);
        items = items.filter(i => i.id !== it.id);
        sel = Math.min(sel, results.length - 1);
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "clipboard") {
                root.query = "";
                root.sel = 0;
                root.confirmWipe = false;
                searchInput.text = "";
                searchInput.forceActiveFocus();
                root.refresh();
            }
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    root.items = JSON.parse(listOut.text);
                } catch (e) {
                    root.items = [];
                }
            }
        }
    }
    Process { id: actionProc }
    Process {
        id: wipeProc
        onExited: root.refresh()
    }

    // --- Buscador + vaciar ---
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
            text: "content_paste"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Theme.overlay1
        }
        TextInput {
            id: searchInput
            font.family: Theme.bodyFontFamily
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: wipeBtn.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(15)
            clip: true
            focus: Overlay.mode === "clipboard"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search clipboard (" + root.items.length + ")…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }

            Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onReturnPressed: root.copy()
            Keys.onEnterPressed: root.copy()
            Keys.onDeletePressed: root.remove()
            Keys.onEscapePressed: Overlay.close()
        }

        // Vaciar todo: el primer clic pide confirmación
        Rectangle {
            id: wipeBtn
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: wipeRow.implicitWidth + 16
            height: 26
            radius: 13
            visible: root.items.length > 0
            color: root.confirmWipe ? Theme.red : (wipeMouse.containsMouse ? Theme.surface1 : Theme.surface0)
            Row {
                id: wipeRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "delete_sweep"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 15
                    color: root.confirmWipe ? Theme.islandBg : Theme.secondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.confirmWipe ? "Clear all?" : "Clear"
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: root.confirmWipe
                    color: root.confirmWipe ? Theme.islandBg : Theme.secondaryText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: wipeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.confirmWipe) {
                        root.confirmWipe = false;
                        root.items = [];
                        wipeProc.exec([root.script, "wipe"]);
                    } else {
                        root.confirmWipe = true;
                    }
                }
            }
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
        id: list
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: hint.top
        anchors.margins: 8
        clip: true
        spacing: 2
        model: root.results
        currentIndex: root.sel
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120

        delegate: Rectangle {
            id: row
            required property int index
            required property var modelData
            property string thumb: ""

            width: ListView.view.width
            height: modelData.image ? 84 : 40
            radius: 12
            color: index === root.sel ? Theme.surface0 : "transparent"

            // Miniatura: se genera (o se lee de la caché) cuando la fila aparece
            Component.onCompleted: if (modelData.image) thumbProc.exec([root.script, "thumb", modelData.id])
            Process {
                id: thumbProc
                stdout: StdioCollector {
                    id: thumbOut
                    onStreamFinished: row.thumb = thumbOut.text.trim()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 24
                radius: 2
                color: Theme.green
                visible: row.index === root.sel
            }

            ClippingRectangle {
                id: thumbBox
                visible: row.modelData.image
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 120
                height: 68
                radius: 8
                color: Theme.surface0
                Image {
                    anchors.fill: parent
                    source: row.thumb !== "" ? "file://" + row.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            Text {
                anchors.left: row.modelData.image ? thumbBox.right : parent.left
                anchors.leftMargin: row.modelData.image ? 12 : 16
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                // Imágenes: "png · 1080x620 · 51 KiB" a partir de la vista previa de cliphist
                text: {
                    if (!row.modelData.image)
                        return row.modelData.text;
                    const m = row.modelData.text.match(/binary data ([\d.]+ \w+) (\w+) (\d+x\d+)/);
                    return m ? "Image " + m[2].toUpperCase() + " · " + m[3] + " · " + m[1] : "Image";
                }
                color: row.modelData.image ? Theme.secondaryText : "#ffffff"
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(12)
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.sel = row.index
                onClicked: {
                    root.sel = row.index;
                    root.copy();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: root.items.length === 0 ? "Clipboard is empty" : "No matches (search skips images)"
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
    }

    Text {
        id: hint
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: "Enter: copy · Del: remove"
        color: Theme.overlay1
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(10)
    }
}
