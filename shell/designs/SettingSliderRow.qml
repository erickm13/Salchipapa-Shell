// Fila de ajuste con slider, dentro de un SettingGroup. `unit` se pega tal cual al valor
// (" px", " ms", "%"…). Mismas medidas que el PxSlider de Settings.qml.
import QtQuick
import "../common"

Item {
    id: row
    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property string unit: ""
    signal moved(int value)

    width: parent.width
    height: 58
    opacity: enabled ? 1 : 0.45

    Text {
        id: rowLabel
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        text: row.label
        color: Theme.text
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(14)
        elide: Text.ElideRight
    }
    Text {
        id: valueText
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 12
        text: String(row.value) + row.unit
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(13)
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: rowLabel.bottom
        anchors.topMargin: 12
        height: 4
        radius: 2
        color: Theme.panelCardHi
        Rectangle {
            id: fill
            width: track.width * Math.max(0, Math.min(1, (row.value - row.from) / Math.max(1, row.to - row.from)))
            height: parent.height
            radius: 2
            color: Theme.green
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -18
            anchors.bottomMargin: -18
            enabled: row.enabled
            cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            function setAt(x: real): void {
                row.moved(Math.round(row.from + Math.max(0, Math.min(1, x / track.width)) * (row.to - row.from)));
            }
            onPressed: mouse => setAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    setAt(mouse.x);
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.divider
    }
}
