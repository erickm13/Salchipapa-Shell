pragma ComponentBehavior: Bound
import QtQuick
import "../common"
import "../services"

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
            title: "Popups"
            width: parent.width
            SettingToggleRow {
                label: "Queue hidden notifications"
                sublabel: "Ones in the +N badge move up when the visible ones leave"
                checked: Config.opt.notificationQueueHidden
                onToggled: Config.opt.notificationQueueHidden = !Config.opt.notificationQueueHidden
            }
            SettingToggleRow {
                label: "Show time left"
                sublabel: "Bar under the notification that empties until it hides"
                checked: Config.opt.notificationTimeoutBar
                onToggled: Config.opt.notificationTimeoutBar = !Config.opt.notificationTimeoutBar
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
        }

        SettingGroup {
            title: "Timing & size"
            hint: "How long popups stay, how wide they are and how many show at once"
            collapsible: true
            width: parent.width
            SettingSliderRow {
                label: "Popup timeout"
                value: Config.opt.notificationPopupTimeout
                from: 500; to: 10000; unit: " s"
                divisor: 1000; decimals: 1; snap: 500
                onMoved: v => Config.opt.notificationPopupTimeout = v
            }
            SettingSliderRow {
                label: "Urgent timeout"
                value: Config.opt.notificationUrgentTimeout
                from: 1000; to: 30000; unit: " s"
                divisor: 1000; decimals: 1; snap: 500
                onMoved: v => Config.opt.notificationUrgentTimeout = v
            }
            SettingSliderRow {
                label: "Width"
                value: Config.opt.notificationWidth
                from: 320; to: 900; unit: " px"
                onMoved: v => Config.opt.notificationWidth = v
            }
            SettingSliderRow {
                label: "Visible at once"
                value: Config.opt.notificationMaxVisible
                from: 1; to: 3
                onMoved: v => Config.opt.notificationMaxVisible = v
            }
        }

        SettingGroup {
            title: "Alerts"
            width: parent.width
            SettingToggleRow {
                label: "Finished downloads"
                sublabel: "Notify when a new file finishes downloading"
                checked: Config.opt.notificationDownloads
                onToggled: Config.opt.notificationDownloads = !Config.opt.notificationDownloads
            }
            SettingSliderRow {
                label: "Wait for progress (0 = off)"
                value: Config.opt.notificationProgressWait
                from: 0; to: 120; unit: " s"
                snap: 5
                onMoved: v => Config.opt.notificationProgressWait = v
            }
            SettingToggleRow {
                visible: Battery.available
                label: "Low battery"
                sublabel: "Warn when the battery runs low while unplugged"
                checked: Config.opt.notificationBatteryLow
                onToggled: Config.opt.notificationBatteryLow = !Config.opt.notificationBatteryLow
            }
            SettingSliderRow {
                visible: Battery.available
                label: "Low battery at"
                value: Config.opt.notificationBatteryLowPercent
                from: 10; to: 50; unit: "%"
                snap: 5
                enabled: Config.opt.notificationBatteryLow
                onMoved: v => Config.opt.notificationBatteryLowPercent = v
            }
            SettingSliderRow {
                visible: Battery.available
                label: "Critical battery at"
                value: Config.opt.notificationBatteryCriticalPercent
                from: 3; to: 20; unit: "%"
                enabled: Config.opt.notificationBatteryLow
                onMoved: v => Config.opt.notificationBatteryCriticalPercent = v
            }
        }

        SettingGroup {
            title: "History"
            hint: "Height of the history list in the control center"
            collapsible: true
            width: parent.width
            SettingSliderRow {
                label: "History height"
                value: Config.opt.notificationHistoryHeight
                from: 80; to: 600; unit: " px"
                onMoved: v => Config.opt.notificationHistoryHeight = v
            }
        }

        SettingGroup {
            title: "Volume & brightness popup"
            hint: "How long it stays and how thick the bar is"
            collapsible: true
            width: parent.width
            SettingSliderRow {
                label: "Duration"
                value: Config.opt.osdOnScreenTime
                from: 300; to: 10000; unit: " s"
                divisor: 1000; decimals: 1; snap: 100
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
