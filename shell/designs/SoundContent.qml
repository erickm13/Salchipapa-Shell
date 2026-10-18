pragma ComponentBehavior: Bound
// Subpágina "Sound" del centro de control: volumen maestro, micrófono y
// selección de dispositivo de salida (PipeWire).
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../common"
import "../services"

Item {
    id: root

    focus: Overlay.mode === "sound"
    Keys.onEscapePressed: Overlay.mode = "control"

    // ===== Cabecera =====
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: backMouse.containsMouse ? Theme.panelCard : "transparent"
                Icon {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    px: 22
                    color: Theme.text
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Overlay.mode = "control"
                }
            }
            Text {
                font.family: Theme.bodyFontFamily
                anchors.verticalCenter: parent.verticalCenter
                text: "Sound"
                color: "#ffffff"
                font.pixelSize: Theme.fontPx(16)
                font.bold: true
            }
        }
    }

    Column {
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10

        // --- Volumen maestro ---
        LabeledSlider {
            width: parent.width
            label: "Volume"
            glyph: Audio.muted ? "volume_off" : "volume_up"
            value: Math.min(1, Audio.volume)
            onMoved: v => Audio.setVolume(v)
            onIconTapped: Audio.toggleMute()
        }

        // --- Micrófono ---
        LabeledSlider {
            width: parent.width
            label: "Microphone"
            accent: Theme.blue
            glyph: Audio.micMuted ? "mic_off" : "mic"
            value: Math.min(1, Audio.micVolume)
            onIconTapped: Audio.toggleMic()
        }

        Text {
            font.family: Theme.bodyFontFamily
            text: "Output"
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(11)
            font.bold: true
            leftPadding: 4
            topPadding: 2
        }

        // --- Dispositivos de salida ---
        Repeater {
            model: Audio.sinks

            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property bool isDefault: Audio.sink === dev.modelData
                width: parent.width
                height: 48
                radius: 14
                color: isDefault ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14) : (devMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Icon {
                    id: devIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: dev.isDefault ? "volume_up" : "speaker"
                    px: 18
                    color: dev.isDefault ? Theme.green : Theme.secondaryText
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    anchors.left: devIcon.right
                    anchors.right: devCheck.left
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: dev.modelData.description || dev.modelData.nickname || dev.modelData.name || "Salida"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: dev.isDefault
                    elide: Text.ElideRight
                }
                Icon {
                    id: devCheck
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check"
                    px: 18
                    color: Theme.green
                    visible: dev.isDefault
                }
                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.setDefaultSink(dev.modelData)
                }
            }
        }
    }

    // Slider con etiqueta encima (para las páginas de ajustes)
    component LabeledSlider: Item {
        id: ls
        property string label: ""
        property string glyph: ""
        property real value: 0
        property color accent: Theme.green
        signal moved(real v)
        signal iconTapped

        implicitHeight: lbl.height + 4 + 30
        height: implicitHeight

        Text {
            font.family: Theme.bodyFontFamily
            id: lbl
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 4
            text: ls.label
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(11)
            font.bold: true
        }
        SettingSlider {
            anchors.top: lbl.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            height: 30
            glyph: ls.glyph
            value: ls.value
            accent: ls.accent
            onMoved: v => ls.moved(v)
            onIconTapped: ls.iconTapped()
        }
    }

    component Icon: Text {
        property real px: 18
        font.family: "Material Symbols Rounded"
        font.pixelSize: px
        verticalAlignment: Text.AlignVCenter
    }
}
