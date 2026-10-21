// Fila de ajuste con interruptor (y subtítulo opcional), dentro de un SettingGroup.
// Mismas medidas que el ToggleRow de Settings.qml para que todas las páginas se vean iguales.
import QtQuick
import "../common"

Item {
    id: row
    property string label: ""
    property string sublabel: ""
    property bool checked: false
    signal toggled

    width: parent.width
    height: sublabel !== "" ? 64 : 48

    activeFocusOnTab: true
    onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(row)
    Keys.onUpPressed: KeyNav.move(row, false)
    Keys.onDownPressed: KeyNav.move(row, true)
    Keys.onSpacePressed: row.toggled()
    Keys.onReturnPressed: row.toggled()
    Keys.onEnterPressed: row.toggled()

    // Marco del control enfocado con el teclado
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusMedium
        color: "transparent"
        border.width: 2
        border.color: Theme.green
        visible: row.activeFocus
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: toggle.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Text {
            width: parent.width
            text: row.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
            elide: Text.ElideRight
        }
        Text {
            visible: row.sublabel !== ""
            width: parent.width
            text: row.sublabel
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: toggle
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 24
        radius: 12
        color: row.checked ? Theme.green : Theme.panelCardHi
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }
        Rectangle {
            width: 18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: row.checked ? parent.width - width - 3 : 3
            color: "#ffffff"
            Behavior on x {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
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
