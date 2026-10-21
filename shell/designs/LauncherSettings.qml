pragma ComponentBehavior: Bound
// Controles de tamaño y densidad del lanzador para incrustar en Settings.qml.
import QtQuick
import "../common"

Item {
    id: root

    implicitHeight: controls.implicitHeight

    Column {
        id: controls
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(3)

        RangeRow {
            width: parent.width
            label: "Width"
            from: 360
            to: 900
            value: Config.launcherWidth
            unit: "px"
            onMoved: v => Config.opt.launcherWidth = v
        }
        RangeRow {
            width: parent.width
            label: "Row height"
            from: 36
            to: 80
            value: Config.launcherRowHeight
            unit: "px"
            onMoved: v => Config.opt.launcherRowHeight = v
        }
        RangeRow {
            width: parent.width
            label: "Visible rows"
            from: 3
            to: 12
            value: Config.launcherRowsBeforeScrolling
            unit: ""
            onMoved: v => Config.opt.launcherRowsBeforeScrolling = v
        }
    }

    component RangeRow: Rectangle {
        id: row
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        property string unit: "px"
        signal moved(int value)

        height: 58
        radius: Theme.radiusMedium
        color: Theme.panelCard

        Text {
            id: rowLabel
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 14
            text: row.label
            color: "#ffffff"
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
        }

        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 14
            text: row.unit === "" ? String(row.value) : row.value + " " + row.unit
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(13)
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: rowLabel.bottom
            anchors.topMargin: 12
            height: 4
            radius: 2
            color: Theme.panelCardHi

            Rectangle {
                id: fill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: track.width * Math.max(0, Math.min(1, (row.value - row.from) / Math.max(1, row.to - row.from)))
                height: parent.height
                radius: 2
                color: Theme.green
            }

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -18
                anchors.bottomMargin: -18
                cursorShape: Qt.PointingHandCursor

                function setValueAt(x: real): void {
                    const ratio = Math.max(0, Math.min(1, x / track.width));
                    row.moved(Math.round(row.from + ratio * (row.to - row.from)));
                }

                onPressed: mouse => setValueAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setValueAt(mouse.x);
                }
            }
        }
    }
}
