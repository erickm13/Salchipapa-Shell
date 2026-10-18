pragma ComponentBehavior: Bound
import QtQuick
import "../common"

Item {
    id: root
    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(4)

        SettingsGroup {
            width: parent.width
            ToggleRow { label: "Show date"; checked: Config.lockShowDate; onToggled: Config.opt.lockShowDate = !Config.lockShowDate }
            ToggleRow { label: "Show clock"; checked: Config.lockShowClock; onToggled: Config.opt.lockShowClock = !Config.lockShowClock }
            ToggleRow { label: "24-hour clock"; checked: Config.lockClock24Hour; onToggled: Config.opt.lockClock24Hour = !Config.lockClock24Hour }
            ToggleRow { label: "Show music card when playing"; checked: Config.lockShowMusic; onToggled: Config.opt.lockShowMusic = !Config.lockShowMusic }
        }

        SettingsGroup {
            width: parent.width
            SliderRow {
                label: "Background blur"
                value: Config.lockBackgroundBlur
                from: 0; to: 100; unit: "%"
                onMoved: v => Config.opt.lockBackgroundBlur = v
            }
            SliderRow {
                label: "Background dim"
                value: Config.lockBackgroundDim
                from: 0; to: 80; unit: "%"
                onMoved: v => Config.opt.lockBackgroundDim = v
            }
        }

        Text {
            width: parent.width
            text: "Authentication is handled by PAM. Power actions remain available on the lock screen."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
    }

    component SettingsGroup: Rectangle {
        default property alias rows: rowsColumn.data
        implicitHeight: rowsColumn.implicitHeight
        height: implicitHeight
        radius: Theme.radiusMedium
        color: Theme.panelCard
        clip: true
        Column { id: rowsColumn; width: parent.width; spacing: 0 }
    }

    component ToggleRow: Item {
        id: row
        property string label: ""
        property bool checked: false
        signal toggled
        width: parent.width
        height: 42
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.label; color: Theme.text
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(12)
        }
        Rectangle {
            id: toggle
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 18; radius: 9
            color: row.checked ? Theme.green : Theme.panelCardHi
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? parent.width - width - 2 : 2
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 10; anchors.rightMargin: 10
            height: 1; color: Theme.divider
        }
    }

    component SliderRow: Item {
        id: row
        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 100
        property string unit: ""
        signal moved(int value)
        width: parent.width
        height: 48
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.top: parent.top; anchors.topMargin: 5
            text: row.label; color: Theme.text
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(11)
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 5
            text: row.value + row.unit; color: Theme.secondaryText
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(10)
        }
        Rectangle {
            id: track
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            anchors.leftMargin: 12; anchors.rightMargin: 12
            height: 4; radius: 2; color: Theme.panelCardHi
            Rectangle {
                id: fill
                width: track.width * Math.max(0, Math.min(1, (row.value - row.from) / Math.max(1, row.to - row.from)))
                height: parent.height; radius: 2; color: Theme.green
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter; color: Theme.text
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -15; anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                function setAt(x: real): void {
                    row.moved(Math.round(row.from + Math.max(0, Math.min(1, x / track.width)) * (row.to - row.from)));
                }
                onPressed: mouse => setAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) setAt(mouse.x); }
            }
        }
    }
}
