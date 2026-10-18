pragma ComponentBehavior: Bound
import QtQuick
import "../common"

// Controls shown inside the Settings page's scrollable column.
Item {
    id: root
    implicitWidth: 600
    implicitHeight: content.height

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(4)

        SettingsGroup {
            width: parent.width
            SliderRow {
                label: "Popup timeout"
                value: Config.opt.notificationPopupTimeout
                from: 500; to: 10000; unit: "ms"
                onMoved: v => Config.opt.notificationPopupTimeout = v
            }
            SliderRow {
                label: "Urgent timeout"
                value: Config.opt.notificationUrgentTimeout
                from: 1000; to: 30000; unit: "ms"
                onMoved: v => Config.opt.notificationUrgentTimeout = v
            }
            SliderRow {
                label: "Width"
                value: Config.opt.notificationWidth
                from: 320; to: 900; unit: "px"
                onMoved: v => Config.opt.notificationWidth = v
            }
            ToggleSettingRow {
                label: "Show body text"
                checked: Config.opt.notificationShowBody
                onToggled: Config.opt.notificationShowBody = !Config.opt.notificationShowBody
            }
            SliderRow {
                label: "History height"
                value: Config.opt.notificationHistoryHeight
                from: 80; to: 600; unit: "px"
                onMoved: v => Config.opt.notificationHistoryHeight = v
            }
        }

        Text {
            width: parent.width
            text: "VOLUME / BRIGHTNESS OSD"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            leftPadding: 2
            topPadding: 2
            bottomPadding: 1
        }

        SettingsGroup {
            width: parent.width
            SliderRow {
                label: "On-screen time"
                value: Config.opt.osdOnScreenTime
                from: 300; to: 10000; unit: "ms"
                onMoved: v => Config.opt.osdOnScreenTime = v
            }
            SliderRow {
                label: "Level bar thickness"
                value: Config.opt.osdLevelBarThickness
                from: 2; to: 20; unit: "px"
                onMoved: v => Config.opt.osdLevelBarThickness = v
            }
        }
    }

    component SettingsGroup: Rectangle {
        default property alias rows: rowsColumn.data
        implicitHeight: rowsColumn.implicitHeight
        height: implicitHeight
        radius: Theme.radiusMedium
        color: Theme.panelCard
        clip: true

        Column {
            id: rowsColumn
            width: parent.width
            spacing: 0
        }
    }

    component SliderRow: Item {
        id: row
        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 100
        property string unit: "px"
        signal moved(int value)

        width: parent.width
        height: 42

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 5
            text: row.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 5
            text: row.value + " " + row.unit
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
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
                width: 12; height: 12; radius: 6
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -15
                anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                function updateValue(mouseX: real): void {
                    const ratio = Math.max(0, Math.min(1, mouseX / track.width));
                    row.moved(Math.round(row.from + ratio * (row.to - row.from)));
                }
                onPressed: mouse => updateValue(mouse.x)
                onPositionChanged: mouse => { if (pressed) updateValue(mouse.x); }
            }
        }

        Rectangle {
            visible: row.y + row.height < parent.height
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: Theme.divider
        }
    }

    component ToggleSettingRow: Item {
        id: toggleRow
        property string label: ""
        property bool checked: false
        signal toggled
        width: parent.width
        height: 38

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: toggleRow.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
        }
        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 16; radius: 8
            color: toggleRow.checked ? Theme.green : Theme.panelCardHi
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                x: toggleRow.checked ? parent.width - width - 2 : 2
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleRow.toggled()
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: 1
            color: Theme.divider
        }
    }
}
