pragma ComponentBehavior: Bound
// Editor visual del centro de control para incrustar en la sección de Settings.
// Persistencia compartida: Config.opt.controlCenterSlots (int) y
// Config.opt.controlCenterLayout (string JSON con [{"id":"sound","size":1}]).
import QtQuick
import "../common"

Item {
    id: root

    implicitHeight: editorColumn.implicitHeight

    readonly property var controlCatalog: [
        { id: "wifi", label: "Wi-Fi", icon: "wifi" },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
        { id: "focus", label: "Focus", icon: "do_not_disturb_on" },
        { id: "gameMode", label: "Game Mode", icon: "sports_esports" },
        { id: "sound", label: "Sound", icon: "volume_up" },
        { id: "display", label: "Display", icon: "brightness_6" },
        { id: "notifications", label: "Notifications", icon: "notifications" }
    ]

    readonly property var defaultLayout: [
        { id: "wifi", size: 1 }, { id: "focus", size: 1 },
        { id: "bluetooth", size: 1 }, { id: "gameMode", size: 1 },
        { id: "sound", size: 2 }, { id: "display", size: 2 },
        { id: "notifications", size: 2 }
    ]

    property int slotCount: Config.opt.controlCenterSlots || 7
    property var layout: {
        try {
            const parsed = JSON.parse(Config.opt.controlCenterLayout || "");
            return Array.isArray(parsed) && parsed.length > 0 ? parsed : defaultLayout;
        } catch (e) {
            return defaultLayout;
        }
    }
    property var undoStack: []

    function saveSnapshot(): void {
        const snapshots = undoStack.slice();
        snapshots.push(JSON.stringify(layout));
        if (snapshots.length > 20)
            snapshots.shift();
        undoStack = snapshots;
    }

    function persist(): void {
        Config.opt.controlCenterSlots = slotCount;
        Config.opt.controlCenterLayout = JSON.stringify(layout);
    }

    function itemInfo(id: string): var {
        for (let i = 0; i < controlCatalog.length; ++i)
            if (controlCatalog[i].id === id)
                return controlCatalog[i];
        return { id: id, label: id, icon: "widgets" };
    }

    function moveItem(from: int, to: int): void {
        if (to < 0 || to >= layout.length || from === to)
            return;
        saveSnapshot();
        const next = layout.slice();
        const moved = next.splice(from, 1)[0];
        next.splice(to, 0, moved);
        layout = next;
        persist();
    }

    function moveId(id: string, direction: int): void {
        for (let i = 0; i < layout.length; ++i) {
            if (layout[i].id === id) {
                moveItem(i, i + direction);
                return;
            }
        }
    }

    function removeItem(index: int): void {
        saveSnapshot();
        const next = layout.slice();
        next.splice(index, 1);
        layout = next;
        persist();
    }

    function addItem(id: string): void {
        for (let i = 0; i < layout.length; ++i)
            if (layout[i].id === id)
                return;
        saveSnapshot();
        layout = layout.concat([{ id: id, size: 1 }]);
        persist();
    }

    function resizeItem(index: int): void {
        saveSnapshot();
        const next = layout.slice();
        const entry = Object.assign({}, next[index]);
        entry.size = entry.size >= 2 ? 1 : 2;
        next[index] = entry;
        layout = next;
        persist();
    }

    Column {
        id: editorColumn
        width: parent.width
        spacing: Theme.space(3)

        // Toolbar
        Row {
            width: parent.width
            height: 34
            spacing: 6

            Row {
                height: parent.height
                spacing: 3
                Repeater {
                    model: [5, 6, 7, 8, 9]
                    delegate: Rectangle {
                        id: slotChip
                        required property int modelData
                        width: 27
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 9
                        color: root.slotCount === modelData ? Theme.green : Theme.panelCard
                        Text {
                            anchors.centerIn: parent
                            text: slotChip.modelData
                            color: root.slotCount === slotChip.modelData ? Theme.panelBg : Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.saveSnapshot();
                                root.slotCount = slotChip.modelData;
                                root.persist();
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 1 }

            Repeater {
                model: ["Tidy", "Undo", "Reset"]
                delegate: Rectangle {
                    id: actionChip
                    required property string modelData
                    width: actionText.implicitWidth + 18
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 9
                    color: Theme.panelCard
                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: actionChip.modelData
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (actionChip.modelData === "Undo") {
                                if (root.undoStack.length > 0) {
                                    const stack = root.undoStack.slice();
                                    root.layout = JSON.parse(stack.pop());
                                    root.undoStack = stack;
                                    root.persist();
                                }
                            } else {
                                root.saveSnapshot();
                                if (actionChip.modelData === "Reset") {
                                    root.slotCount = 7;
                                    root.layout = root.defaultLayout;
                                } else {
                                    const compact = root.layout.slice();
                                    compact.sort((a, b) => (a.size || 1) - (b.size || 1));
                                    root.layout = compact;
                                }
                                root.persist();
                            }
                        }
                    }
                }
            }

            Item { width: Math.max(0, parent.width - 480); height: 1 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Drag to move · corner to resize · right-click for sizes"
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(9)
            }
        }

        // Preview: la disposición editable se serializa; el consumidor de ControlContent
        // debe aplicar esos mismos IDs y tamaños para reflejarla en el panel real.
        Item {
            id: preview
            width: parent.width
            height: previewColumn.implicitHeight

            Column {
                id: previewColumn
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 360)
                spacing: 8

                Grid {
                    width: parent.width
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8
                    Repeater {
                        model: root.layout.filter(x => ["wifi", "focus", "bluetooth", "gameMode", "lock", "nightLight"].includes(x.id)).slice(0, root.slotCount)
                        delegate: Rectangle {
                            id: quickPreviewItem
                            required property var modelData
                            width: (previewColumn.width - 16) / 3
                            height: quickPreviewItem.modelData.size >= 2 ? 54 : 42
                            radius: 18
                            color: Theme.panelCard
                            Text {
                                anchors.centerIn: parent
                                text: root.itemInfo(quickPreviewItem.modelData.id).icon
                                color: Theme.secondaryText
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: Theme.iconPx(18)
                            }
                        }
                    }
                }

                Repeater {
                    model: root.layout.filter(x => ["sound", "display", "notifications", "nowPlaying"].includes(x.id))
                    delegate: Rectangle {
                        id: cardPreviewItem
                        required property var modelData
                        required property int index
                        property real dragStartY: 0
                        width: previewColumn.width
                        height: cardPreviewItem.modelData.id === "notifications" ? (cardPreviewItem.modelData.size >= 2 ? 66 : 48) : (cardPreviewItem.modelData.size >= 2 ? 36 : 28)
                        radius: 14
                        color: Theme.panelCard
                        border.width: 1
                        border.color: Theme.green

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.itemInfo(cardPreviewItem.modelData.id).label
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                        }
                        Text {
                            id: removeGlyph
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.top: parent.top
                            text: "remove"
                            color: Theme.secondaryText
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Theme.iconPx(14)
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeItem(cardPreviewItem.index)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: cardPreviewItem
                            onPressed: mouse => {
                                cardPreviewItem.dragStartY = mouse.y;
                            }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.resizeItem(root.layout.findIndex(x => x.id === cardPreviewItem.modelData.id));
                            }
                            onReleased: {
                                if (Math.abs(cardPreviewItem.y) > 24)
                                    root.moveId(cardPreviewItem.modelData.id, cardPreviewItem.y < 0 ? -1 : 1);
                                cardPreviewItem.x = 0;
                                cardPreviewItem.y = 0;
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "Add a control"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }

        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.controlCatalog.filter(c => !root.layout.some(x => x.id === c.id))
                delegate: Rectangle {
                    id: addChip
                    required property var modelData
                    width: addText.implicitWidth + 24
                    height: 26
                    radius: 13
                    color: Theme.panelCard
                    Row {
                        id: addText
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: addChip.modelData.icon
                            color: Theme.text
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Theme.iconPx(14)
                        }
                        Text {
                            text: addChip.modelData.label
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addItem(addChip.modelData.id)
                    }
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Drag a control to move it, use the right mouse button to switch sizes, or remove it with the corner button. Changes are saved automatically."
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(9)
        }
    }
}
