pragma ComponentBehavior: Bound
// Página Wi-Fi del centro de control, dentro de la Dynamic Island.
import QtQuick
import "../common"
import "../services"

Item {
    id: root

    property bool active: false
    property string passwordSsid: ""
    property bool showConnectError: false
    signal closeRequested

    focus: Overlay.mode === "control" && active
    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }
    onActiveChanged: {
        if (!active)
            passwordSsid = "";
    }

    Connections {
        target: Net
        function onConnectionFinished(ssid: string, success: bool): void {
            if (success) {
                root.passwordSsid = "";
                passwordInput.text = "";
                root.showConnectError = false;
            } else {
                const retry = root.passwordSsid === ssid;
                root.passwordSsid = ssid;
                passwordInput.text = "";
                root.showConnectError = retry;
                passwordInput.forceActiveFocus();
            }
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: root.visible && root.active && Net.wifiEnabled
        onTriggered: Net.scanNetworks()
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
            Icon {
                anchors.centerIn: parent
                text: "chevron_left"
                px: 18
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
            font.family: Theme.bodyFontFamily
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            text: "Wi-Fi"
            color: Theme.text
            font.pixelSize: Theme.fontPx(18)
            font.bold: true
        }

        Rectangle {
            id: wifiSwitch
            width: 38
            height: 22
            radius: 11
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Net.wifiEnabled ? Theme.green : Theme.panelCardHi
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: Net.wifiEnabled ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: Theme.movementDuration } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.toggleWifi()
            }
        }
    }

    Rectangle {
        id: connectedCard
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: 64
        radius: 15
        color: Theme.panelCard
        visible: Net.type === "wifi" && Net.connectedSsid.length > 0

        Rectangle {
            width: 34
            height: 34
            radius: 17
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.green
            Icon {
                anchors.centerIn: parent
                text: "wifi"
                px: 19
                color: Theme.islandBg
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 52
            anchors.right: disconnectButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                font.family: Theme.bodyFontFamily
                width: parent.width
                text: Net.connectedSsid || Net.name
                color: Theme.text
                font.pixelSize: Theme.fontPx(14)
                elide: Text.ElideRight
            }
            Text {
                font.family: Theme.bodyFontFamily
                width: parent.width
                text: "Connected" + (Net.connectedSecurity ? " · " + Net.connectedSecurity : "") + " · " + Net.wifiSignal + "% signal"
                color: Theme.secondaryText
                font.pixelSize: Theme.fontPx(12)
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: disconnectButton
            width: 65
            height: 25
            radius: 13
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: disconnectMouse.containsMouse ? Theme.surface2 : Theme.surface1
            Text {
                font.family: Theme.bodyFontFamily
                anchors.centerIn: parent
                text: "Disconnect"
                color: Theme.text
                font.pixelSize: Theme.fontPx(12)
            }
            MouseArea {
                id: disconnectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.disconnectWifi()
            }
        }
    }

    Text {
        id: networksTitle
        font.family: Theme.bodyFontFamily
        anchors.top: connectedCard.visible ? connectedCard.bottom : header.bottom
        anchors.topMargin: connectedCard.visible ? 10 : 12
        anchors.left: parent.left
        text: "Networks"
        color: Theme.secondaryText
        font.pixelSize: Theme.fontPx(13)
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: networksTitle.verticalCenter
        spacing: 5
        Rectangle {
            width: 4
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Net.scanning ? Theme.yellow : Theme.green
        }
        Text {
            font.family: Theme.bodyFontFamily
            text: Net.scanning ? "Scanning" : "Scan"
            color: Theme.tertiaryText
            font.pixelSize: Theme.fontPx(12)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                enabled: !Net.scanning && Net.wifiEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.scanNetworks()
            }
        }
    }

    ListView {
        id: networkList
        anchors.top: networksTitle.bottom
        anchors.topMargin: 5
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        spacing: 3
        model: Net.wifiEnabled ? Net.networks.filter(n => !n.active) : []
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: networkItem
            required property var modelData
            width: ListView.view.width
            height: 38
            radius: 11
            color: networkMouse.containsMouse ? Theme.panelCardHi : "transparent"

            Icon {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: networkItem.modelData.security ? "wifi_lock" : "wifi"
                px: 17
                color: networkItem.modelData.active ? Theme.green : Theme.secondaryText
            }
            Column {
                anchors.left: parent.left
                anchors.leftMargin: 34
                anchors.right: signalText.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: networkItem.modelData.ssid
                    color: Theme.text
                    font.pixelSize: Theme.fontPx(13)
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: (networkItem.modelData.security || "Open") + " · " + networkItem.modelData.signal + "% signal"
                    color: Theme.tertiaryText
                    font.pixelSize: Theme.fontPx(11)
                    elide: Text.ElideRight
                }
            }
            Text {
                id: signalText
                font.family: Theme.bodyFontFamily
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: networkItem.modelData.active ? "Connected" : ""
                color: Theme.green
                font.pixelSize: Theme.fontPx(11)
            }
            MouseArea {
                id: networkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: networkItem.modelData.active ? Qt.ArrowCursor : Qt.PointingHandCursor
                enabled: !networkItem.modelData.active && !Net.connectionPending
                onClicked: Net.connectTo(networkItem.modelData.ssid)
            }
        }
    }

    Rectangle {
        id: passwordDialog
        z: 2
        anchors.centerIn: parent
        width: parent.width - 12
        height: 112
        radius: 15
        color: Theme.panelCardHi
        border.width: 1
        border.color: Theme.divider
        visible: root.passwordSsid.length > 0

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            Text {
                font.family: Theme.bodyFontFamily
                width: parent.width
                text: root.showConnectError ? "Could not connect · check password" : "Password · " + root.passwordSsid
                color: root.showConnectError ? Theme.red : Theme.text
                font.pixelSize: Theme.fontPx(13)
                elide: Text.ElideRight
            }
            Rectangle {
                width: parent.width
                height: 29
                radius: 8
                color: Theme.surface0
                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(13)
                    echoMode: TextInput.Password
                    selectByMouse: true
                    onAccepted: {
                        if (text.length > 0)
                            Net.connectTo(root.passwordSsid, text);
                    }
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 12
                Text {
                    font.family: Theme.bodyFontFamily
                    text: "Cancel"
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx(12)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.passwordSsid = ""
                    }
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    text: Net.connectionPending ? "Connecting…" : "Connect"
                    color: Theme.green
                    font.pixelSize: Theme.fontPx(12)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: !Net.connectionPending && passwordInput.text.length > 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Net.connectTo(root.passwordSsid, passwordInput.text)
                    }
                }
            }
        }
    }

    component Icon: Text {
        property real px: 18
        font.family: "Material Symbols Rounded"
        font.pixelSize: Theme.iconPx(px)
        font.weight: Theme.iconWeight
        verticalAlignment: Text.AlignVCenter
    }
}
