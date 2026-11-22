pragma ComponentBehavior: Bound
// Página Wi-Fi. Se usa en dos sitios:
//  - En la Dynamic Island como panel propio (modo "wifi", desde la tarjeta Wi-Fi del centro de
//    control): `inIsland: true`, con flecha para volver al centro de control.
//  - En Ajustes (Super+I) como sección "Wi-Fi": `inIsland: false`, sin flecha.
// `k` escala letras y filas (la isla la agranda para que se lea bien).
import QtQuick
import "../common"
import "../services"

Item {
    id: root

    property bool active: false
    property bool inIsland: true
    property real k: 1.25
    property string passwordSsid: ""
    property bool showConnectError: false
    signal closeRequested

    focus: inIsland && active
    Keys.onEscapePressed: event => {
        if (root.passwordSsid !== "")
            root.passwordSsid = "";
        else
            root.closeRequested();
        event.accepted = true;
    }
    onActiveChanged: {
        if (active) {
            if (Net.wifiEnabled)
                Net.scanNetworks();
        } else {
            passwordSsid = "";
        }
    }

    Connections {
        target: Net
        function onConnectionFinished(ssid: string, success: bool): void {
            if (!root.active)
                return;
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

    // ---------- Cabecera: volver + título + interruptor ----------
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
            text: "Wi-Fi"
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(Math.round((18) * root.k))
            font.bold: true
        }

        Rectangle {
            id: sw
            readonly property bool on: Net.wifiEnabled
            width: Math.round((44) * root.k)
            height: Math.round((26) * root.k)
            radius: height / 2
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: sw.on ? Theme.green : Theme.panelCardHi
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
                onClicked: Net.toggleWifi()
            }
            KeyButton {
                radius: sw.radius
                onActivated: Net.toggleWifi()
            }
        }
    }

    // ---------- Red conectada ----------
    Rectangle {
        id: connectedCard
        anchors.top: header.bottom
        anchors.topMargin: Math.round((10) * root.k)
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? Math.round((68) * root.k) : 0
        radius: Math.round((16) * root.k)
        color: Theme.panelCard
        visible: Net.wifiEnabled && Net.type === "wifi" && Net.connectedSsid.length > 0

        Rectangle {
            id: connectedBadge
            width: Math.round((40) * root.k)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.leftMargin: Math.round((12) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.green
            Icon {
                anchors.centerIn: parent
                text: "wifi"
                px: Math.round((20) * root.k)
                color: Theme.islandBg
            }
        }

        Column {
            anchors.left: connectedBadge.right
            anchors.leftMargin: Math.round((12) * root.k)
            anchors.right: disconnectButton.left
            anchors.rightMargin: Math.round((8) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: Net.connectedSsid || Net.name
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((14) * root.k))
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: "Connected" + (Net.connectedSecurity ? " · " + Net.connectedSecurity : "") + " · " + Net.wifiSignal + "% signal"
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
                elide: Text.ElideRight
            }
        }

        Pill {
            id: disconnectButton
            anchors.right: parent.right
            anchors.rightMargin: Math.round((12) * root.k)
            anchors.verticalCenter: parent.verticalCenter
            label: "Disconnect"
            onClicked: Net.disconnectWifi()
        }
    }

    // ---------- Redes cercanas ----------
    Text {
        id: networksTitle
        anchors.top: connectedCard.visible ? connectedCard.bottom : header.bottom
        anchors.topMargin: Math.round((14) * root.k)
        anchors.left: parent.left
        anchors.leftMargin: Math.round((4) * root.k)
        text: "Networks"
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
        font.bold: true
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Math.round((4) * root.k)
        anchors.verticalCenter: networksTitle.verticalCenter
        spacing: Math.round((6) * root.k)
        Rectangle {
            width: Math.round((6) * root.k)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Net.scanning ? Theme.yellow : Theme.green
        }
        Text {
            text: Net.scanning ? "Scanning…" : "Scan"
            color: scanMouse.containsMouse ? Theme.text : Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            MouseArea {
                id: scanMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: !Net.scanning && Net.wifiEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Net.scanNetworks()
            }
        }
    }

    Rectangle {
        anchors.top: networksTitle.bottom
        anchors.topMargin: Math.round((8) * root.k)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: Math.round((16) * root.k)
        color: Theme.panelCard

        ListView {
            id: networkList
            anchors.fill: parent
            anchors.margins: Math.round((6) * root.k)
            clip: true
            spacing: Math.round((2) * root.k)
            model: Net.wifiEnabled ? Net.networks.filter(n => !n.active) : []
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: networkItem
                required property var modelData
                // Esta red se está conectando: fila resaltada, "Connecting…" y spinner
                readonly property bool connecting: Net.connectionPending && Net.requestedSsid === modelData.ssid
                width: ListView.view.width
                height: Math.round((52) * root.k)
                radius: Math.round((12) * root.k)
                color: connecting ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14) : networkMouse.containsMouse ? Theme.panelCardHi : "transparent"
                opacity: Net.connectionPending && !connecting ? 0.5 : 1

                Rectangle {
                    id: netBadge
                    width: Math.round((34) * root.k)
                    height: width
                    radius: width / 2
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round((8) * root.k)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.surface0
                    Icon {
                        anchors.centerIn: parent
                        text: networkItem.modelData.signal >= 67 ? "signal_wifi_4_bar" : networkItem.modelData.signal >= 34 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                        px: Math.round((17) * root.k)
                        color: Theme.secondaryText
                    }
                }
                Column {
                    anchors.left: netBadge.right
                    anchors.leftMargin: Math.round((12) * root.k)
                    anchors.right: rowEnd.left
                    anchors.rightMargin: Math.round((8) * root.k)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: networkItem.modelData.ssid
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(Math.round((13) * root.k))
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: networkItem.connecting ? "Connecting…" : (networkItem.modelData.security || "Open") + " · " + networkItem.modelData.signal + "% signal"
                        color: networkItem.connecting ? Theme.green : Theme.tertiaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(Math.round((11) * root.k))
                        elide: Text.ElideRight
                    }
                }
                Item {
                    id: rowEnd
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round((12) * root.k)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round((20) * root.k)
                    height: width
                    Icon {
                        anchors.centerIn: parent
                        visible: !networkItem.connecting
                        text: networkItem.modelData.security ? "lock" : ""
                        px: Math.round((15) * root.k)
                        color: Theme.tertiaryText
                    }
                    Spinner {
                        anchors.centerIn: parent
                        running: networkItem.connecting
                        size: Math.round((18) * root.k)
                        color: Theme.green
                    }
                }
                MouseArea {
                    id: networkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Net.connectionPending
                    onClicked: Net.connectTo(networkItem.modelData.ssid)
                }
                KeyButton {
                    radius: networkItem.radius
                    onActivated: if (!Net.connectionPending) Net.connectTo(networkItem.modelData.ssid)
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - Math.round((24) * root.k)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: networkList.count === 0
                text: !Net.wifiEnabled ? "Turn on Wi-Fi to see networks" : (Net.scanning ? "Looking for networks…" : "No networks found")
                color: Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            }
        }
    }

    // ---------- Contraseña ----------
    Rectangle {
        id: passwordDialog
        z: 2
        anchors.centerIn: parent
        width: parent.width - Math.round((16) * root.k)
        height: Math.round((132) * root.k)
        radius: Math.round((16) * root.k)
        color: Theme.panelCardHi
        border.width: 1
        border.color: Theme.divider
        visible: root.passwordSsid.length > 0

        Column {
            anchors.fill: parent
            anchors.margins: Math.round((14) * root.k)
            spacing: Math.round((10) * root.k)
            Text {
                width: parent.width
                text: root.showConnectError ? "Could not connect · check the password" : "Password for " + root.passwordSsid
                color: root.showConnectError ? Theme.red : Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(Math.round((13) * root.k))
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                width: parent.width
                height: Math.round((34) * root.k)
                radius: Math.round((10) * root.k)
                color: Theme.surface0
                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: Math.round((10) * root.k)
                    anchors.rightMargin: Math.round((10) * root.k)
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(Math.round((13) * root.k))
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
                spacing: Math.round((8) * root.k)
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: Net.connectionPending
                    size: Math.round((18) * root.k)
                    color: Theme.green
                }
                Pill {
                    label: "Cancel"
                    onClicked: root.passwordSsid = ""
                }
                Pill {
                    label: Net.connectionPending ? "Connecting…" : "Connect"
                    accent: true
                    enabled: !Net.connectionPending && passwordInput.text.length > 0
                    onClicked: Net.connectTo(root.passwordSsid, passwordInput.text)
                }
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

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property bool accent: false
        signal clicked
        width: pillText.implicitWidth + Math.round((26) * root.k)
        height: Math.round((30) * root.k)
        radius: height / 2
        opacity: enabled ? 1 : 0.5
        color: accent ? (pillMouse.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green) : (pillMouse.containsMouse ? Theme.surface2 : Theme.surface1)
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.accent ? Theme.islandBg : Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(Math.round((12) * root.k))
            font.bold: pill.accent
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
        KeyButton {
            radius: pill.radius
            onActivated: pill.clicked()
        }
    }
}
