pragma ComponentBehavior: Bound
// Centro de control, para mostrarse DENTRO de la Dynamic Island (modo "control").
// Interruptores rápidos (WiFi/Focus/Bluetooth/Game mode + lock/night light),
// cards de Sound y Display (clic -> su subpágina), y la lista de notificaciones.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../common"
import "../services"

Item {
    id: root

    property bool wifiDetailsOpen: false
    property bool bluetoothDetailsOpen: false

    readonly property var defaultControlLayout: [
        { id: "wifi", size: 1 }, { id: "focus", size: 1 },
        { id: "bluetooth", size: 1 }, { id: "gameMode", size: 1 },
        { id: "sound", size: 2 }, { id: "display", size: 2 },
        { id: "notifications", size: 2 }
    ]
    readonly property var activeControls: {
        try {
            const saved = JSON.parse(Config.controlCenterLayout || "");
            const layout = Array.isArray(saved) ? saved : defaultControlLayout;
            return layout.slice(0, Config.controlCenterSlots);
        } catch (e) {
            return defaultControlLayout.slice(0, Config.controlCenterSlots);
        }
    }
    function hasControl(id: string): bool { return activeControls.some(item => item.id === id); }
    function controlSize(id: string): int {
        const item = activeControls.find(entry => entry.id === id);
        return item ? item.size : 1;
    }
    readonly property real cardsTop: 132
    function cardOffset(id: string): real {
        let offset = 0;
        for (let i = 0; i < activeControls.length; ++i) {
            const item = activeControls[i];
            if (item.id === id) return offset;
            if (item.id === "sound" || item.id === "display")
                offset += (item.size >= 2 ? 82 : 60) + 10;
        }
        return offset;
    }
    readonly property real cardsHeight: {
        let height = 0;
        for (let i = 0; i < activeControls.length; ++i) {
            const item = activeControls[i];
            if (item.id === "sound" || item.id === "display")
                height += (item.size >= 2 ? 82 : 60) + 10;
        }
        return height > 0 ? height - 10 : 0;
    }
    readonly property real notificationTop: (wifiDetailsOpen || bluetoothDetailsOpen) ? 344 : cardsTop + cardsHeight + 12
    readonly property int notificationControlHeight: controlSize("notifications") >= 2 ? Config.notificationHistoryHeight : Math.min(100, Config.notificationHistoryHeight)

    focus: Overlay.mode === "control"
    Keys.onEscapePressed: {
        if (wifiDetailsOpen)
            wifiDetailsOpen = false;
        else if (bluetoothDetailsOpen)
            bluetoothDetailsOpen = false;
        else
            Overlay.close();
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode !== "control")
                root.wifiDetailsOpen = false;
            if (Overlay.mode !== "control")
                root.bluetoothDetailsOpen = false;
        }
    }

    // ===== Interruptores rápidos (arriba) =====
    Item {
        id: toggles
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 120

        // Columna derecha: 2 botones redondos (lock + night light)
        Column {
            id: roundCol
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 56
            spacing: 8

            RoundBtn {
                glyph: "lock"
                onClicked: {
                    Overlay.close();
                    LockScreen.lock();
                }
            }
            RoundBtn {
                glyph: "dark_mode"
                accent: Theme.mauve
                on: Quick.nightLight
                onClicked: Quick.toggleNightLight()
            }
        }

        // La rejilla respeta el orden y la selección del editor de Control Center.
        Grid {
            id: grid
            anchors.left: parent.left
            anchors.right: roundCol.left
            anchors.rightMargin: 10
            anchors.top: parent.top
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            readonly property real cellW: (width - columnSpacing) / 2

            Repeater {
                model: root.activeControls.filter(item => ["wifi", "focus", "bluetooth", "gameMode"].includes(item.id))
                BigToggle {
                    required property var modelData
                    width: grid.cellW
                    height: modelData.size >= 2 ? 72 : 56
                    glyph: modelData.id === "wifi" ? (Net.wifiEnabled ? "wifi" : "wifi_off") : modelData.id === "focus" ? (Quick.dnd ? "do_not_disturb_on" : "do_not_disturb_off") : modelData.id === "bluetooth" ? "bluetooth" : "sports_esports"
                    title: modelData.id === "gameMode" ? "Game Mode" : modelData.id === "wifi" ? "Wi-Fi" : modelData.id === "bluetooth" ? "Bluetooth" : "Focus"
                    subtitle: modelData.id === "wifi" ? (Net.type === "wifi" ? (Net.connectedSsid || Net.name || "On") : (Net.wifiEnabled ? (Net.type === "ethernet" ? "Ethernet" : "On") : "Off")) : modelData.id === "bluetooth" ? (Bluetooth.enabled ? (Bluetooth.connectedCount > 0 ? Bluetooth.connectedCount + " conectado" + (Bluetooth.connectedCount > 1 ? "s" : "") : "On") : "Off") : modelData.id === "focus" ? (Quick.dnd ? "On" : "Off") : (Quick.gameMode ? "On" : "Off")
                    accent: modelData.id === "focus" ? Theme.peach : modelData.id === "bluetooth" ? Theme.blue : modelData.id === "gameMode" ? Theme.yellow : Theme.green
                    on: modelData.id === "wifi" ? Net.wifiEnabled : modelData.id === "bluetooth" ? Bluetooth.enabled : modelData.id === "focus" ? Quick.dnd : Quick.gameMode
                    splitAction: modelData.id === "wifi" || modelData.id === "bluetooth"
                    onClicked: {
                        if (modelData.id === "wifi") Net.toggleWifi();
                        else if (modelData.id === "bluetooth") Bluetooth.toggle();
                        else if (modelData.id === "focus") Quick.toggleDnd();
                        else Quick.toggleGameMode();
                    }
                    onDetailsClicked: {
                        root.wifiDetailsOpen = modelData.id === "wifi";
                        root.bluetoothDetailsOpen = modelData.id === "bluetooth";
                        if (modelData.id === "wifi") Net.scanNetworks();
                    }
                }
            }
        }
    }

    // ===== Cards de Sound / Display (clic -> subpágina) =====
    SettingCard {
        id: soundCard
        y: root.cardsTop + root.cardOffset("sound")
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.hasControl("sound") && !root.wifiDetailsOpen && !root.bluetoothDetailsOpen
        rowSize: root.controlSize("sound")
        label: "Sound"
        sliderGlyph: Audio.muted ? "volume_off" : "volume_up"
        sliderValue: Math.min(1, Audio.volume)
        onSliderMoved: v => Audio.setVolume(v)
        onSliderIconTapped: Audio.toggleMute()
        onOpened: Overlay.mode = "sound"
    }

    SettingCard {
        id: displayCard
        y: root.cardsTop + root.cardOffset("display")
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.hasControl("display") && !root.wifiDetailsOpen && !root.bluetoothDetailsOpen
        rowSize: root.controlSize("display")
        label: "Display"
        sliderGlyph: "brightness_6"
        sliderAccent: Theme.peach
        sliderValue: Brightness.value
        sliderEnabled: Brightness.available
        onSliderMoved: v => Brightness.setValue(v)
        onOpened: Overlay.mode = "display"
    }

    WifiContent {
        id: wifiDetails
        anchors.top: toggles.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        active: root.wifiDetailsOpen
        visible: root.wifiDetailsOpen
        onCloseRequested: root.wifiDetailsOpen = false
    }

    BluetoothContent {
        id: bluetoothDetails
        anchors.top: toggles.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        height: 200
        active: root.bluetoothDetailsOpen
        visible: root.bluetoothDetailsOpen
        onCloseRequested: root.bluetoothDetailsOpen = false
    }

    // ===== Notificaciones =====
    Rectangle {
        id: notificationPanel
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.notificationTop
        height: Math.max(0, Math.min(root.notificationControlHeight, parent.height - y))
        visible: root.hasControl("notifications")
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.04)

        // Cabecera
        Text {
            font.family: Theme.bodyFontFamily
            id: notifTitle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 16
            text: "Notifications"
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(11)
            font.bold: true
        }
        Text {
            font.family: Theme.bodyFontFamily
            anchors.verticalCenter: notifTitle.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            text: "Clear"
            color: clearMouse.containsMouse ? "#ffffff" : Theme.overlay1
            font.pixelSize: Theme.fontPx(11)
            visible: Notifs.activeCount > 0
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }

        // Vacío
        Text {
            font.family: Theme.bodyFontFamily
            anchors.top: notifTitle.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
            text: "No notifications"
            color: Theme.tertiaryText
            font.pixelSize: Theme.fontPx(12)
            visible: Notifs.activeCount === 0
        }

        // Lista
        ListView {
            anchors.top: notifTitle.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 8
            clip: true
            spacing: 4
            visible: Notifs.activeCount > 0
            model: Notifs.list ? Notifs.list.values : []
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: nItem
                required property var modelData
                width: ListView.view.width
                    height: Config.notificationShowBody && (modelData.body || "").length > 0 ? 58 : 50
                radius: 12
                color: Qt.rgba(1, 1, 1, nHover.containsMouse ? 0.08 : 0.04)
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }

                // Hover de la fila (sin robar el clic al botón de descartar)
                MouseArea {
                    id: nHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: nClose.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 1

                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: nItem.modelData.appName || "Notificación"
                        color: Theme.mauve
                        font.pixelSize: Theme.fontPx(10)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: nItem.modelData.summary || (Config.notificationShowBody ? nItem.modelData.body : "") || ""
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(12)
                        elide: Text.ElideRight
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: Config.notificationShowBody ? (nItem.modelData.body || "") : ""
                        color: Theme.secondaryText
                        font.pixelSize: Theme.fontPx(10)
                        elide: Text.ElideRight
                        visible: text.length > 0 && text !== nItem.modelData.summary
                    }
                }

                Text {
                    id: nClose
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "close"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: nCloseMouse.containsMouse ? Theme.red : Theme.tertiaryText
                    MouseArea {
                        id: nCloseMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: nItem.modelData.dismiss()
                    }
                }
            }
        }
    }

    // ================= Sub-componentes =================

    // Icono (Material Symbols Rounded)
    component Icon: Text {
        property real px: 18
        font.family: "Material Symbols Rounded"
        font.pixelSize: px
        verticalAlignment: Text.AlignVCenter
    }

    // Interruptor grande: badge redondo + título + subtítulo
    component BigToggle: Rectangle {
        id: bt
        property string glyph: ""
        property string title: ""
        property string subtitle: ""
        property bool on: false
        property color accent: Theme.green
        property bool splitAction: false
        signal clicked
        signal detailsClicked

        height: 56
        radius: 16
        color: on ? Qt.rgba(bt.accent.r, bt.accent.g, bt.accent.b, btMouse.containsMouse ? 0.26 : 0.16) : (btMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: 19
            color: bt.on ? bt.accent : Theme.panelCardHi
            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }
            Icon {
                anchors.centerIn: parent
                text: bt.glyph
                px: 20
                color: bt.on ? Theme.islandBg : Theme.secondaryText
            }
        }
        Column {
            anchors.left: badge.right
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                font.family: Theme.bodyFontFamily
                width: parent.width
                text: bt.title
                color: "#ffffff"
                font.pixelSize: Theme.fontPx(13)
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                font.family: Theme.bodyFontFamily
                width: parent.width
                text: bt.subtitle
                color: Theme.secondaryText
                font.pixelSize: Theme.fontPx(10)
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: btMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const dx = mouse.x - (badge.x + badge.width / 2);
                const dy = mouse.y - (badge.y + badge.height / 2);
                const insideBadge = dx * dx + dy * dy <= (badge.width / 2) * (badge.height / 2);
                if (bt.splitAction && !insideBadge)
                    bt.detailsClicked();
                else
                    bt.clicked();
            }
        }
    }

    // Botón redondo (lock, night light)
    component RoundBtn: Rectangle {
        id: rb
        property string glyph: ""
        property bool on: false
        property color accent: Theme.green
        signal clicked

        width: 56
        height: 56
        radius: height / 2
        color: on ? rb.accent : (rbMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }
        Icon {
            anchors.centerIn: parent
            text: rb.glyph
            px: 22
            color: rb.on ? Theme.islandBg : Theme.text
        }
        MouseArea {
            id: rbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }
}
