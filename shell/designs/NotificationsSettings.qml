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

        SettingGroup {
            width: parent.width
            SettingSliderRow {
                label: "Popup timeout"
                value: Config.opt.notificationPopupTimeout
                from: 500; to: 10000; unit: " ms"
                onMoved: v => Config.opt.notificationPopupTimeout = v
            }
            SettingSliderRow {
                label: "Urgent timeout"
                value: Config.opt.notificationUrgentTimeout
                from: 1000; to: 30000; unit: " ms"
                onMoved: v => Config.opt.notificationUrgentTimeout = v
            }
            SettingSliderRow {
                label: "Width"
                value: Config.opt.notificationWidth
                from: 320; to: 900; unit: " px"
                onMoved: v => Config.opt.notificationWidth = v
            }
            SettingToggleRow {
                label: "Show body text"
                checked: Config.opt.notificationShowBody
                onToggled: Config.opt.notificationShowBody = !Config.opt.notificationShowBody
            }
            SettingToggleRow {
                label: "Play sound"
                checked: Config.opt.notificationSound
                onToggled: Config.opt.notificationSound = !Config.opt.notificationSound
            }
            SettingSliderRow {
                label: "History height"
                value: Config.opt.notificationHistoryHeight
                from: 80; to: 600; unit: " px"
                onMoved: v => Config.opt.notificationHistoryHeight = v
            }
        }

        Text {
            width: parent.width
            text: "VOLUME & BRIGHTNESS"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            leftPadding: 2
            topPadding: 2
            bottomPadding: 1
        }

        SettingGroup {
            width: parent.width
            SettingSliderRow {
                label: "Duration"
                value: Config.opt.osdOnScreenTime
                from: 300; to: 10000; unit: " ms"
                onMoved: v => Config.opt.osdOnScreenTime = v
            }
            SettingSliderRow {
                label: "Bar thickness"
                value: Config.opt.osdLevelBarThickness
                from: 2; to: 20; unit: " px"
                onMoved: v => Config.opt.osdLevelBarThickness = v
            }
        }
    }

}
