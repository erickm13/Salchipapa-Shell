pragma ComponentBehavior: Bound
// Página Bluetooth del centro de control, dentro de la Dynamic Island.
import QtQuick
import Quickshell.Bluetooth
import "../common"
import "../services"

Item {
    id: root

    property bool active: false
    property var adapter: Bluetooth.defaultAdapter
    property bool startedDiscoveryHere: false
    signal closeRequested

    focus: Overlay.mode === "control" && active
    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    onActiveChanged: {
        if (!adapter)
            return;
        if (active) {
            if (adapter.enabled && !adapter.discovering) {
                adapter.discovering = true;
                startedDiscoveryHere = true;
            }
        } else if (startedDiscoveryHere) {
            adapter.discovering = false;
            startedDiscoveryHere = false;
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Rectangle {
            width: 30
            height: 30
            radius: 15
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard
            Text {
                anchors.centerIn: parent
                text: "chevron_left"
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(18)
                font.weight: Theme.iconWeight
                color: Theme.secondaryText
            }
            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            text: "Bluetooth"
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(18)
            font.bold: true
        }

        Rectangle {
            width: 38
            height: 22
            radius: 11
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: root.adapter?.enabled ? Theme.green : Theme.panelCardHi
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: root.adapter?.enabled ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: Theme.movementDuration } }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!root.adapter
                cursorShape: Qt.PointingHandCursor
                onClicked: Bluetooth.toggle()
            }
        }
    }

    Text {
        id: savedTitle
        anchors.top: header.bottom
        anchors.topMargin: 7
        anchors.left: parent.left
        text: "Saved"
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(12)
    }

    ListView {
        id: savedList
        anchors.top: savedTitle.bottom
        anchors.topMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(contentHeight, 78)
        clip: true
        spacing: 3
        model: root.adapter?.devices?.values?.filter(device => device.paired || device.bonded) ?? []
        boundsBehavior: Flickable.StopAtBounds
        delegate: DeviceRow {
            required property var modelData
            width: ListView.view.width
            device: modelData
            saved: true
        }
    }

    Text {
        id: nearbyTitle
        anchors.top: savedList.bottom
        anchors.topMargin: 7
        anchors.left: parent.left
        text: "Nearby"
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(12)
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: nearbyTitle.verticalCenter
        spacing: 5
        Rectangle {
            width: 4
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.adapter?.discovering ? Theme.green : Theme.overlay1
        }
        Text {
            text: root.adapter?.discovering ? "Scanning" : "Scan"
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                enabled: !!root.adapter && root.adapter.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adapter.discovering = true
            }
        }
    }

    ListView {
        id: nearbyList
        anchors.top: nearbyTitle.bottom
        anchors.topMargin: 3
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 3
        model: root.adapter?.devices?.values?.filter(device => !device.paired && !device.bonded) ?? []
        boundsBehavior: Flickable.StopAtBounds
        delegate: DeviceRow {
            required property var modelData
            width: ListView.view.width
            device: modelData
            saved: false
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 3
            text: !root.adapter?.enabled
                ? "Turn on Bluetooth to find devices"
                : (root.adapter?.discovering ? "Looking for devices… put your device in pairing mode" : "No devices found")
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
            wrapMode: Text.WordWrap
            visible: nearbyList.count === 0
        }
    }

    component DeviceRow: Rectangle {
        id: row
        property var device
        property bool saved: false
        height: 40
        radius: 11
        color: actionMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard

        Rectangle {
            width: 24
            height: 24
            radius: 12
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surface2
            Text {
                anchors.centerIn: parent
                text: row.device?.icon?.toLowerCase().includes("audio") || row.device?.icon?.toLowerCase().includes("head") ? "headphones" : "bluetooth"
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(14)
                font.weight: Theme.iconWeight
                color: Theme.secondaryText
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.right: action.left
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                text: row.device?.name || row.device?.deviceName || "Bluetooth device"
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(12)
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: row.device?.connected ? "Connected" : (row.saved ? "Saved" : "Available")
                color: Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: action
            width: 52
            height: 22
            radius: 11
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surface1
            Text {
                anchors.centerIn: parent
                text: row.device?.connected ? "Disconnect" : (row.saved ? "Connect" : "Pair")
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
            }
            MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !!row.device
                onClicked: {
                    if (row.device.connected)
                        row.device.disconnect();
                    else if (row.saved)
                        row.device.connect();
                    else
                        row.device.pair();
                }
            }
        }

    }
}
