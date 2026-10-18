pragma ComponentBehavior: Bound
// Mezclador de sonido: dispositivos de salida/entrada y volumen por aplicación.
import QtQuick
import Quickshell
import "../common"
import "../services"

Item {
    id: root

    focus: Overlay.mode === "sound"
    Keys.onEscapePressed: Overlay.mode = "control"

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32

        Rectangle {
            width: 30
            height: 30
            radius: 15
            anchors.left: parent.left
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
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            text: "Sound"
            color: "#ffffff"
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(18)
            font.bold: true
        }
    }

    Column {
        id: sections
        anchors.top: header.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 6

        Text {
            text: "Output"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            leftPadding: 4
            height: 15
        }

        Repeater {
            model: Audio.sinks.slice(0, 5)
            delegate: Rectangle {
                id: outputRow
                required property var modelData
                width: sections.width
                height: 36
                radius: 14
                readonly property bool isDefault: Audio.sink === modelData
                color: isDefault ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14) : (outputMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
                Icon {
                    id: outputIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: outputRow.modelData.name.toLowerCase().includes("headphone") ? "headphones" : (outputRow.modelData.name.toLowerCase().includes("hdmi") || outputRow.modelData.name.toLowerCase().includes("displayport") ? "desktop_windows" : "speaker")
                    px: 18
                    color: outputRow.isDefault ? Theme.green : Theme.secondaryText
                }
                Text {
                    anchors.left: outputIcon.right
                    anchors.right: outputCheck.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: outputRow.modelData.description || outputRow.modelData.nickname || outputRow.modelData.name || "Output"
                    color: "#ffffff"
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: outputRow.isDefault
                    elide: Text.ElideRight
                }
                Icon {
                    id: outputCheck
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check"
                    px: 18
                    color: Theme.green
                    visible: outputRow.isDefault
                }
                MouseArea {
                    id: outputMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.setDefaultSink(outputRow.modelData)
                }
            }
        }

        SettingSlider {
            width: sections.width
            height: 36
            glyph: Audio.muted ? "volume_off" : "volume_up"
            value: Math.min(1, Audio.volume)
            onMoved: v => Audio.setVolume(v)
            onIconTapped: Audio.toggleMute()
        }

        Text {
            text: "Input"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            leftPadding: 4
            height: 15
        }

        Repeater {
            model: Audio.sources.slice(0, 4)
            delegate: Rectangle {
                id: inputRow
                required property var modelData
                width: sections.width
                height: 36
                radius: 14
                readonly property bool isDefault: Audio.source === modelData
                color: isDefault ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.14) : (inputMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
                Icon {
                    id: inputIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: "mic"
                    px: 18
                    color: inputRow.isDefault ? Theme.green : Theme.secondaryText
                }
                Text {
                    anchors.left: inputIcon.right
                    anchors.right: inputCheck.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: inputRow.modelData.description || inputRow.modelData.nickname || inputRow.modelData.name || "Input"
                    color: "#ffffff"
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: inputRow.isDefault
                    elide: Text.ElideRight
                }
                Icon {
                    id: inputCheck
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check"
                    px: 18
                    color: Theme.green
                    visible: inputRow.isDefault
                }
                MouseArea {
                    id: inputMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.setDefaultSource(inputRow.modelData)
                }
            }
        }

        SettingSlider {
            width: sections.width
            height: 36
            glyph: Audio.micMuted ? "mic_off" : "mic"
            value: Math.min(1, Audio.micVolume)
            onMoved: v => Audio.setNodeVolume(Audio.source, v)
            onIconTapped: Audio.toggleMic()
        }

        Text {
            text: "Apps"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            leftPadding: 4
            height: 15
        }

        Repeater {
            model: Audio.apps.slice(0, 4)
            delegate: Rectangle {
                id: appEntry
                required property var modelData
                width: sections.width
                height: 56
                radius: 14
                color: Theme.panelCard

                Text {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.topMargin: 5
                    width: parent.width - 16
                    text: appEntry.modelData.name
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                    elide: Text.ElideRight
                }
                SettingSlider {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 5
                    height: 30
                    glyph: Audio.appMuted(appEntry.modelData.nodes) ? "volume_off" : "volume_up"
                    value: Math.min(1, Audio.appVolume(appEntry.modelData.nodes))
                    onMoved: v => Audio.setAppVolume(appEntry.modelData.nodes, v)
                    onIconTapped: Audio.toggleAppMute(appEntry.modelData.nodes)
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
