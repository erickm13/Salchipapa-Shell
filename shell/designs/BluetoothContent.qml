pragma ComponentBehavior: Bound
// Página Bluetooth. Igual que WifiContent, se usa en dos sitios:
//  - En la Dynamic Island como panel propio (modo "bluetooth"): `inIsland: true`, con flecha.
//  - En Ajustes (Super+I) como sección "Bluetooth": `inIsland: false`.
// `k` escala letras y filas.
import QtQuick
import Quickshell.Bluetooth
import "../common"
import "../services"

Item {
    id: root

    property bool active: false
    property bool inIsland: true
    property real k: 1.25
    property var adapter: Bluetooth.defaultAdapter
    property bool startedDiscoveryHere: false
    signal closeRequested

    readonly property var savedDevices: adapter?.devices?.values?.filter(d => d.paired || d.bonded) ?? []
    readonly property var nearbyDevices: adapter?.devices?.values?.filter(d => !d.paired && !d.bonded && (d.name || d.deviceName)) ?? []

    function updateDiscovery(): void {
        if (!adapter)
            return;
        if (active && adapter.enabled) {
            if (!adapter.discovering) {
                adapter.discovering = true;
                startedDiscoveryHere = true;
            }
        } else if (startedDiscoveryHere) {
            if (adapter.enabled)
                adapter.discovering = false;
            startedDiscoveryHere = false;
        }
    }
    onActiveChanged: updateDiscovery()
    Connections {
        target: root.adapter
        function onEnabledChanged(): void { root.updateDiscovery(); }
    }

    focus: inIsland && active
    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    // ---------- Cabecera ----------
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.round((36) * root.k)

        Rectangle {
            id: backBtn
            visible: root.inIsland
            width: Math.round((32) * root.k)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard
            Icon {
                anchors.centerIn: parent
                text: "chevron_left"
                px: Math.round((20) * root.k)
                color: Theme.secondaryText
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
            KeyButton {
                radius: backBtn.radius
                onActivated: root.closeRequested()
            }
        }

        Text {
            anchors.left: backBtn.visible ? backBtn.right : parent.left
            anchors.leftMargin: backBtn.visible ? Math.round((10) * root.k) : Math.round((4) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(Math.round((18) * root.k))
            font.bold: true
        }

        Rectangle {
            id: sw
            readonly property bool on: root.adapter?.enabled ?? false
            width: Math.round((44) * root.k)
            height: Math.round((26) * root.k)
            radius: height / 2
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.adapter ? 1 : 0.5
            color: on ? Theme.blue : Theme.panelCardHi
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            Rectangle {
                width: sw.height - Math.round((6) * root.k)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: sw.on ? sw.width - width - Math.round((3) * root.k) : Math.round((3) * root.k)
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: Theme.movementDuration } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Bluetooth.toggle()
            }
            KeyButton {
                radius: sw.radius
                onActivated: Bluetooth.toggle()
            }
        }
    }

    // ---------- Guardados ----------
    Text {
        id: savedTitle
        anchors.top: header.bottom
        anchors.topMargin: Math.round((14) * root.k)
        anchors.left: parent.left
        anchors.leftMargin: Math.round((4) * root.k)
        text: "My devices"
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
        font.bold: true
    }

    Rectangle {
        id: savedCard
        anchors.top: savedTitle.bottom
        anchors.topMargin: Math.round((8) * root.k)
        anchors.left: parent.left
        anchors.right: parent.right
        // Hasta 3 filas a la vista; con más, se desplaza
        height: Math.round((12) * root.k) + Math.max(1, Math.min(root.savedDevices.length, 3)) * Math.round((54) * root.k)
        radius: Math.round((16) * root.k)
        color: Theme.panelCard

        ListView {
            id: savedList
            anchors.fill: parent
            anchors.margins: Math.round((6) * root.k)
            clip: true
            spacing: 0
            model: root.savedDevices
            boundsBehavior: Flickable.StopAtBounds
            delegate: DeviceRow {
                required property var modelData
                width: ListView.view.width
                device: modelData
                saved: true
            }
            Text {
                anchors.centerIn: parent
                visible: savedList.count === 0
                text: "No paired devices"
                color: Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            }
        }
    }

    // ---------- Cercanos ----------
    Text {
        id: nearbyTitle
        anchors.top: savedCard.bottom
        anchors.topMargin: Math.round((14) * root.k)
        anchors.left: parent.left
        anchors.leftMargin: Math.round((4) * root.k)
        text: "Nearby"
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
        font.bold: true
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Math.round((4) * root.k)
        anchors.verticalCenter: nearbyTitle.verticalCenter
        spacing: Math.round((6) * root.k)
        Rectangle {
            width: Math.round((6) * root.k)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.adapter?.discovering ? Theme.green : Theme.overlay1
        }
        Text {
            text: root.adapter?.discovering ? "Scanning…" : "Scan"
            color: scanMouse.containsMouse ? Theme.text : Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            MouseArea {
                id: scanMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: !!root.adapter && root.adapter.enabled && !root.adapter.discovering
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.adapter.discovering = true;
                    root.startedDiscoveryHere = true;
                }
            }
        }
    }

    Rectangle {
        anchors.top: nearbyTitle.bottom
        anchors.topMargin: Math.round((8) * root.k)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: Math.round((16) * root.k)
        color: Theme.panelCard

        ListView {
            id: nearbyList
            anchors.fill: parent
            anchors.margins: Math.round((6) * root.k)
            clip: true
            spacing: 0
            model: root.nearbyDevices
            boundsBehavior: Flickable.StopAtBounds
            delegate: DeviceRow {
                required property var modelData
                width: ListView.view.width
                device: modelData
                saved: false
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - Math.round((24) * root.k)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: nearbyList.count === 0
                text: !root.adapter?.enabled
                    ? "Turn on Bluetooth to find devices"
                    : (root.adapter?.discovering ? "Looking for devices… put yours in pairing mode" : "No devices found")
                color: Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            }
        }
    }

    // ================= Sub-componentes =================
    component Icon: Text {
        property real px: 18
        font.family: "Material Symbols Rounded"
        font.pixelSize: Theme.iconPx(px)
        font.weight: Theme.iconWeight
        verticalAlignment: Text.AlignVCenter
    }

    component DeviceRow: Rectangle {
        id: row
        property var device
        property bool saved: false
        readonly property string kind: (device?.icon ?? "").toLowerCase()
        readonly property bool busy: device?.state === BluetoothDeviceState.Connecting || device?.state === BluetoothDeviceState.Disconnecting || (device?.pairing ?? false)

        function act(): void {
            if (!device)
                return;
            if (device.connected)
                device.disconnect();
            else if (saved)
                device.connect();
            else
                device.pair();
        }

        height: Math.round((54) * root.k)
        radius: Math.round((12) * root.k)
        color: row.busy ? Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, 0.14) : rowMouse.containsMouse ? Theme.panelCardHi : "transparent"

        Rectangle {
            id: devBadge
            width: Math.round((34) * root.k)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Math.round((8) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            color: row.device?.connected ? Theme.blue : Theme.surface0
            Icon {
                anchors.centerIn: parent
                text: row.kind.includes("audio") || row.kind.includes("head") ? "headphones"
                    : row.kind.includes("phone") ? "smartphone"
                    : row.kind.includes("mouse") ? "mouse"
                    : row.kind.includes("keyboard") ? "keyboard"
                    : row.kind.includes("gaming") || row.kind.includes("joystick") ? "sports_esports"
                    : row.kind.includes("computer") ? "computer"
                    : "bluetooth"
                px: Math.round((17) * root.k)
                color: row.device?.connected ? Theme.islandBg : Theme.secondaryText
            }
        }

        Column {
            anchors.left: devBadge.right
            anchors.leftMargin: Math.round((12) * root.k)
            anchors.right: action.left
            anchors.rightMargin: Math.round((8) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: row.device?.name || row.device?.deviceName || "Bluetooth device"
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((13) * root.k))
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: row.device?.pairing ? "Pairing…"
                    : row.device?.state === BluetoothDeviceState.Connecting ? "Connecting…"
                    : row.device?.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                    : (row.device?.connected ? "Connected" : (row.saved ? "Not connected" : "Available"))
                    + (row.device?.batteryAvailable ? " · " + Math.round(row.device.battery * 100) + "%" : "")
                color: row.busy || row.device?.connected ? Theme.blue : Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((11) * root.k))
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: action
            width: actionText.implicitWidth + Math.round((26) * root.k)
            height: Math.round((30) * root.k)
            radius: height / 2
            anchors.right: parent.right
            anchors.rightMargin: Math.round((8) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            color: rowMouse.containsMouse ? Theme.surface2 : Theme.surface1
            Text {
                id: actionText
                anchors.centerIn: parent
                visible: !row.busy
                text: row.device?.connected ? "Disconnect" : (row.saved ? "Connect" : "Pair")
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            }
            Spinner {
                anchors.centerIn: parent
                running: row.busy
                size: Math.round((16) * root.k)
                color: Theme.blue
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !!row.device && !row.busy
            onClicked: row.act()
        }
        KeyButton {
            radius: row.radius
            onActivated: row.act()
        }
    }
}
