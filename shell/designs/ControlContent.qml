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

    focus: Overlay.mode === "control"
    Keys.onEscapePressed: Overlay.close()

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
                onClicked: Hyprland.dispatch("hl.dsp.exec_cmd('loginctl lock-session')")
            }
            RoundBtn {
                glyph: "dark_mode"
                accent: Theme.mauve
                on: Quick.nightLight
                onClicked: Quick.toggleNightLight()
            }
        }

        // Rejilla 2×2 de interruptores grandes
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

            BigToggle {
                width: grid.cellW
                glyph: "wifi"
                title: "Wi-Fi"
                subtitle: Net.type === "wifi" ? (Net.name || "On") : (Net.wifiEnabled ? (Net.type === "ethernet" ? "Ethernet" : "On") : "Off")
                on: Net.wifiEnabled
                onClicked: Net.toggleWifi()
            }
            BigToggle {
                width: grid.cellW
                glyph: Quick.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                title: "Focus"
                subtitle: Quick.dnd ? "On" : "Off"
                accent: Theme.peach
                on: Quick.dnd
                onClicked: Quick.toggleDnd()
            }
            BigToggle {
                width: grid.cellW
                glyph: "bluetooth"
                title: "Bluetooth"
                subtitle: Bluetooth.enabled ? (Bluetooth.connectedCount > 0 ? Bluetooth.connectedCount + " conectado" + (Bluetooth.connectedCount > 1 ? "s" : "") : "On") : "Off"
                accent: Theme.blue
                on: Bluetooth.enabled
                onClicked: Bluetooth.toggle()
            }
            BigToggle {
                width: grid.cellW
                glyph: "sports_esports"
                title: "Game Mode"
                subtitle: Quick.gameMode ? "On" : "Off"
                accent: Theme.yellow
                on: Quick.gameMode
                onClicked: Quick.toggleGameMode()
            }
        }
    }

    // ===== Cards de Sound / Display (clic -> subpágina) =====
    SettingCard {
        id: soundCard
        anchors.top: toggles.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Sound"
        sliderGlyph: Audio.muted ? "volume_off" : "volume_up"
        sliderValue: Math.min(1, Audio.volume)
        onSliderMoved: v => Audio.setVolume(v)
        onSliderIconTapped: Audio.toggleMute()
        onOpened: Overlay.mode = "sound"
    }

    SettingCard {
        id: displayCard
        anchors.top: soundCard.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        label: "Display"
        sliderGlyph: "brightness_6"
        sliderAccent: Theme.peach
        sliderValue: Brightness.value
        sliderEnabled: Brightness.available
        onSliderMoved: v => Brightness.setValue(v)
        onOpened: Overlay.mode = "display"
    }

    // ===== Notificaciones =====
    Rectangle {
        anchors.top: displayCard.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: 18
        color: Qt.rgba(1, 1, 1, 0.04)

        // Cabecera
        Text {
            id: notifTitle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 16
            text: "Notifications"
            color: Theme.subtext
            font.pixelSize: 11
            font.bold: true
        }
        Text {
            anchors.verticalCenter: notifTitle.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            text: "Clear"
            color: clearMouse.containsMouse ? "#ffffff" : Theme.overlay1
            font.pixelSize: 11
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
            anchors.top: notifTitle.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
            text: "No notifications"
            color: Theme.overlay0
            font.pixelSize: 12
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
                height: 50
                radius: 12
                color: Qt.rgba(1, 1, 1, nHover.containsMouse ? 0.08 : 0.04)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
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
                        width: parent.width
                        text: nItem.modelData.appName || "Notificación"
                        color: Theme.mauve
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: nItem.modelData.summary || nItem.modelData.body || ""
                        color: "#ffffff"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: nItem.modelData.body || ""
                        color: Theme.subtext
                        font.pixelSize: 10
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
                    color: nCloseMouse.containsMouse ? Theme.red : Theme.overlay0
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
        signal clicked

        height: 56
        radius: 16
        color: on ? Qt.rgba(bt.accent.r, bt.accent.g, bt.accent.b, btMouse.containsMouse ? 0.26 : 0.16) : (btMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
        Behavior on color {
            ColorAnimation {
                duration: 120
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
                    duration: 150
                }
            }
            Icon {
                anchors.centerIn: parent
                text: bt.glyph
                px: 20
                color: bt.on ? Theme.islandBg : Theme.subtext
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
                width: parent.width
                text: bt.title
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: bt.subtitle
                color: Theme.subtext
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: btMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bt.clicked()
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
                duration: 120
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
