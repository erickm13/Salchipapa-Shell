pragma ComponentBehavior: Bound
// Editor del centro de control (Ajustes > Control Center). Vista previa a escala con la misma
// estructura y medidas que ControlContent.qml: interruptores en 2 columnas + botones redondos,
// Power mode, cards y notificaciones abajo. Clic en un control -> moverlo (entre los de su tipo),
// cambiar su tamaño o quitarlo. Se guarda en Config.opt.controlCenterLayout ([{"id","size"}]).
import QtQuick
import "../common"

Item {
    id: root

    implicitHeight: editorColumn.implicitHeight

    readonly property var controlCatalog: [
        { id: "wifi", label: "Wi-Fi", icon: "wifi", kind: "toggle" },
        { id: "focus", label: "Focus", icon: "do_not_disturb_on", kind: "toggle" },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth", kind: "toggle" },
        { id: "gameMode", label: "Game Mode", icon: "sports_esports", kind: "toggle" },
        { id: "sound", label: "Sound", icon: "volume_up", kind: "card" },
        { id: "display", label: "Display", icon: "brightness_6", kind: "card" },
        { id: "record", label: "Screen recording", icon: "screen_record", kind: "card" },
        { id: "notifications", label: "Notifications", icon: "notifications", kind: "notifications" }
    ]

    readonly property var defaultLayout: [
        { id: "wifi", size: 1 }, { id: "focus", size: 1 },
        { id: "bluetooth", size: 1 }, { id: "gameMode", size: 1 },
        { id: "sound", size: 2 }, { id: "display", size: 2 },
        { id: "record", size: 1 }, { id: "notifications", size: 2 }
    ]

    property var layout: {
        try {
            const parsed = JSON.parse(Config.opt.controlCenterLayout || "");
            return Array.isArray(parsed) && parsed.length > 0 ? parsed : defaultLayout;
        } catch (e) {
            return defaultLayout;
        }
    }
    property var undoStack: []
    property string selected: ""

    // Escala de la vista previa respecto al panel real (440 px de ancho, 16 de margen)
    readonly property real k: 0.8
    readonly property real realW: 408

    function info(id: string): var {
        return controlCatalog.find(c => c.id === id) ?? { id: id, label: id, icon: "widgets", kind: "card" };
    }
    function kindOf(id: string): string { return info(id).kind; }
    readonly property var toggles: layout.filter(x => kindOf(x.id) === "toggle")
    readonly property var cards: layout.filter(x => kindOf(x.id) === "card")
    readonly property var notif: layout.find(x => x.id === "notifications") ?? null
    readonly property var selectedEntry: layout.find(x => x.id === selected) ?? null

    function commit(next: var): void {
        const snapshots = undoStack.slice();
        snapshots.push(JSON.stringify(layout));
        if (snapshots.length > 30)
            snapshots.shift();
        undoStack = snapshots;
        layout = next;
        Config.opt.controlCenterLayout = JSON.stringify(next);
    }

    // Mover entre los del mismo tipo (en la lista hay interruptores y cards mezclados)
    function move(id: string, dir: int): void {
        const kind = kindOf(id);
        const same = layout.map((x, i) => ({ x: x, i: i })).filter(o => kindOf(o.x.id) === kind);
        const pos = same.findIndex(o => o.x.id === id);
        const other = same[pos + dir];
        if (!other)
            return;
        const next = layout.slice();
        const a = same[pos].i, b = other.i;
        [next[a], next[b]] = [next[b], next[a]];
        commit(next);
    }
    function canMove(id: string, dir: int): bool {
        const same = layout.filter(x => kindOf(x.id) === kindOf(id));
        const pos = same.findIndex(x => x.id === id);
        return pos + dir >= 0 && pos + dir < same.length;
    }
    function resize(id: string): void {
        commit(layout.map(x => x.id === id ? Object.assign({}, x, { size: x.size >= 2 ? 1 : 2 }) : x));
    }
    function remove(id: string): void {
        commit(layout.filter(x => x.id !== id));
        selected = "";
    }
    function add(id: string): void {
        if (layout.some(x => x.id === id))
            return;
        // Cada uno con los de su tipo: interruptores y cards antes de las notificaciones
        const next = layout.slice();
        const kind = kindOf(id);
        let at = next.length;
        if (kind !== "notifications") {
            const lastSame = next.map(x => kindOf(x.id)).lastIndexOf(kind);
            at = lastSame >= 0 ? lastSame + 1 : next.findIndex(x => kindOf(x.id) === "notifications");
            if (at < 0)
                at = next.length;
        }
        next.splice(at, 0, { id: id, size: kind === "toggle" ? 1 : 2 });
        commit(next);
        selected = id;
    }

    Column {
        id: editorColumn
        width: parent.width
        spacing: Theme.space(3)

        // ---- Barra: deshacer / restablecer ----
        Item {
            width: parent.width
            height: 36
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Chip {
                    icon: "undo"
                    label: "Undo"
                    enabled: root.undoStack.length > 0
                    onClicked: {
                        const stack = root.undoStack.slice();
                        root.layout = JSON.parse(stack.pop());
                        root.undoStack = stack;
                        Config.opt.controlCenterLayout = JSON.stringify(root.layout);
                    }
                }
                Chip {
                    icon: "restart_alt"
                    label: "Reset"
                    onClicked: {
                        root.commit(root.defaultLayout);
                        root.selected = "";
                    }
                }
            }
        }

        // ---- Acciones del control seleccionado ----
        Rectangle {
            width: parent.width
            height: 54
            radius: Theme.radiusMedium
            color: Theme.panelCard

            Text {
                visible: root.selectedEntry === null
                anchors.centerIn: parent
                text: "Select a control in the preview to edit it"
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(13)
            }
            Row {
                visible: root.selectedEntry !== null
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    text: root.selectedEntry ? root.info(root.selected).icon : ""
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 18
                    color: Theme.green
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.selectedEntry ? root.info(root.selected).label : ""
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(14)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                visible: root.selectedEntry !== null
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                readonly property bool isToggle: root.selectedEntry !== null && root.kindOf(root.selected) === "toggle"
                readonly property bool isNotif: root.selected === "notifications"
                Chip {
                    visible: !parent.isNotif
                    icon: parent.isToggle ? "arrow_back" : "arrow_upward"
                    label: parent.isToggle ? "Before" : "Up"
                    enabled: root.selectedEntry !== null && root.canMove(root.selected, -1)
                    onClicked: root.move(root.selected, -1)
                }
                Chip {
                    visible: !parent.isNotif
                    icon: parent.isToggle ? "arrow_forward" : "arrow_downward"
                    label: parent.isToggle ? "After" : "Down"
                    enabled: root.selectedEntry !== null && root.canMove(root.selected, 1)
                    onClicked: root.move(root.selected, 1)
                }
                Chip {
                    icon: "aspect_ratio"
                    label: root.selectedEntry && root.selectedEntry.size >= 2 ? (parent.isNotif ? "Make short" : "Make compact") : (parent.isNotif ? "Show full history" : "Make large")
                    onClicked: root.resize(root.selected)
                }
                Chip {
                    icon: "delete"
                    label: "Remove"
                    danger: true
                    onClicked: root.remove(root.selected)
                }
            }
        }

        // ---- Añadir ----
        Text {
            visible: addFlow.children.length > 1
            text: "ADD A CONTROL"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
        Flow {
            id: addFlow
            width: parent.width
            spacing: 6
            Repeater {
                model: root.controlCatalog.filter(c => !root.layout.some(x => x.id === c.id))
                delegate: Chip {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    onClicked: root.add(modelData.id)
                }
            }
        }

        // ---- Vista previa (misma geometría que el panel real, escalada) ----
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.realW * root.k + 24
            height: previewBody.height + 24
            radius: 22
            color: Theme.islandBg
            border.width: 1
            border.color: Theme.divider

            Item {
                id: previewBody
                x: 12
                y: 12
                width: root.realW * root.k
                height: notifBox.visible ? notifBox.y + notifBox.height : cardsCol.y + cardsCol.height

                // Interruptores: 2 columnas (fila grande si alguno es grande)
                Grid {
                    id: toggleGrid
                    width: parent.width - (56 + 10) * root.k
                    columns: 2
                    rowSpacing: 8 * root.k
                    columnSpacing: 8 * root.k
                    Repeater {
                        model: root.toggles
                        delegate: Block {
                            required property var modelData
                            required property int index
                            readonly property var mate: root.toggles[index % 2 === 0 ? index + 1 : index - 1]
                            entry: modelData
                            width: (toggleGrid.width - toggleGrid.columnSpacing) / 2
                            height: (modelData.size >= 2 || (mate && mate.size >= 2) ? 72 : 56) * root.k
                            radius: height / 2
                            showLabel: true
                        }
                    }
                }
                // Botones redondos fijos (bloquear, luz nocturna): no se editan
                Column {
                    anchors.right: parent.right
                    spacing: 8 * root.k
                    Repeater {
                        model: ["lock", "dark_mode"]
                        delegate: Rectangle {
                            required property string modelData
                            width: 56 * root.k
                            height: width
                            radius: width / 2
                            color: Theme.panelCard
                            opacity: 0.55
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 17
                                color: Theme.secondaryText
                            }
                        }
                    }
                }

                // Power mode (fijo)
                Rectangle {
                    id: powerBox
                    y: Math.max(toggleGrid.height, 120 * root.k) + 12 * root.k
                    width: parent.width
                    height: 74 * root.k
                    radius: 16 * root.k
                    color: Theme.panelCard
                    opacity: 0.55
                    Text {
                        anchors.centerIn: parent
                        text: "Power mode"
                        color: Theme.secondaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                    }
                }

                // Cards en su orden
                Column {
                    id: cardsCol
                    y: powerBox.y + powerBox.height + 10 * root.k
                    width: parent.width
                    spacing: 10 * root.k
                    Repeater {
                        model: root.cards
                        delegate: Block {
                            required property var modelData
                            entry: modelData
                            width: cardsCol.width
                            height: (modelData.size >= 2 ? 82 : 60) * root.k
                            radius: Theme.radiusLarge * root.k
                            showLabel: true
                            sizeHint: modelData.size >= 2 ? "Large" : "Compact"
                        }
                    }
                }

                // Notificaciones: siempre abajo
                Block {
                    id: notifBox
                    visible: root.notif !== null
                    entry: root.notif ?? ({ id: "notifications", size: 2 })
                    y: cardsCol.y + cardsCol.height + (root.cards.length > 0 ? 2 : 12) * root.k
                    width: parent.width
                    height: (root.notif && root.notif.size >= 2 ? Math.min(Config.notificationHistoryHeight, 220) : Math.min(100, Config.notificationHistoryHeight)) * root.k
                    radius: 18 * root.k
                    showLabel: true
                    sizeHint: root.notif && root.notif.size >= 2 ? "Full history" : "Short"
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Same layout as the real control center. Lock, night light and Power mode are always shown. Changes save automatically."
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }

    // Control editable de la vista previa: clic = seleccionar, clic derecho = cambiar tamaño
    component Block: Rectangle {
        id: block
        property var entry: ({ id: "", size: 1 })
        property bool showLabel: true
        property string sizeHint: ""
        readonly property bool isSelected: root.selected === entry.id
        color: isSelected ? Theme.selectedFill : (blockMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
        border.width: isSelected ? 2 : 0
        border.color: Theme.green
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text: root.info(block.entry.id).icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: block.isSelected ? Theme.green : Theme.secondaryText
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: block.showLabel
                text: root.info(block.entry.id).label
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(10)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            visible: block.sizeHint !== ""
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: block.sizeHint
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(9)
        }
        MouseArea {
            id: blockMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    root.resize(block.entry.id);
                root.selected = block.entry.id;
            }
        }
        // Teclado: Espacio/Enter = seleccionar, R = cambiar tamaño (como el clic derecho)
        KeyButton {
            radius: block.radius
            onActivated: root.selected = block.entry.id
            Keys.onPressed: event => {
                if (event.key === Qt.Key_R) {
                    root.resize(block.entry.id);
                    root.selected = block.entry.id;
                    event.accepted = true;
                }
            }
        }
    }

    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property bool danger: false
        signal clicked
        width: chipRow.implicitWidth + 24
        height: 34
        radius: 17
        opacity: enabled ? 1 : 0.4
        color: danger ? (chipMouse.containsMouse ? Theme.red : Theme.panelCardHi) : (chipMouse.containsMouse && enabled ? Theme.panelCardHi : Theme.panelCard)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: chip.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: chip.danger && chipMouse.containsMouse ? Theme.crust : (chip.danger ? Theme.red : Theme.text)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.label
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(12)
                color: chip.danger && chipMouse.containsMouse ? Theme.crust : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
        KeyButton {
            radius: chip.radius
            onActivated: chip.clicked()
        }
    }
}
