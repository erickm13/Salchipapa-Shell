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

        SettingGroup {
            width: parent.width
            SettingToggleRow { label: "Show date"; checked: Config.lockShowDate; onToggled: Config.opt.lockShowDate = !Config.lockShowDate }
            SettingToggleRow { label: "Show clock"; checked: Config.lockShowClock; onToggled: Config.opt.lockShowClock = !Config.lockShowClock }
            SettingToggleRow { label: "24-hour clock"; checked: Config.lockClock24Hour; onToggled: Config.opt.lockClock24Hour = !Config.lockClock24Hour }
            SettingToggleRow { label: "Music card"; checked: Config.lockShowMusic; onToggled: Config.opt.lockShowMusic = !Config.lockShowMusic }
        }

        SettingGroup {
            width: parent.width
            SettingSliderRow {
                label: "Background blur"
                value: Config.lockBackgroundBlur
                from: 0; to: 100; unit: "%"
                onMoved: v => Config.opt.lockBackgroundBlur = v
            }
            SettingSliderRow {
                label: "Background dim"
                value: Config.lockBackgroundDim
                from: 0; to: 80; unit: "%"
                onMoved: v => Config.opt.lockBackgroundDim = v
            }
        }

        SettingGroup {
            width: parent.width
            SettingToggleRow { label: "Lock when idle"; checked: Config.idleLockEnabled; onToggled: Config.opt.idleLockEnabled = !Config.idleLockEnabled }
            SettingSliderRow {
                visible: Config.idleLockEnabled
                label: "Lock after"
                value: Config.idleLockMinutes
                from: 1; to: 60; unit: " min"
                onMoved: v => Config.opt.idleLockMinutes = v
            }
            SettingToggleRow { label: "Suspend when idle"; checked: Config.idleSuspendEnabled; onToggled: Config.opt.idleSuspendEnabled = !Config.idleSuspendEnabled }
            SettingSliderRow {
                visible: Config.idleSuspendEnabled
                label: "Suspend after"
                value: Config.idleSuspendMinutes
                from: 5; to: 120; unit: " min"
                onMoved: v => Config.opt.idleSuspendMinutes = v
            }
        }

        Text {
            width: parent.width
            text: "Idle timers pause while an app blocks idle (video, fullscreen)."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }

}
