// Grupo "When idle" de Lock Screen: bloquear/suspender por inactividad con sus minutos.
// Se usa dos veces (enchufado y con batería); quien lo usa decide qué claves de Config tocar.
import QtQuick
import "../common"

SettingGroup {
    id: ig
    property bool lockEnabled
    property int lockMinutes
    property bool suspendEnabled
    property int suspendMinutes
    signal toggleLock
    signal setLockMinutes(int v)
    signal toggleSuspend
    signal setSuspendMinutes(int v)
    SettingToggleRow { label: "Lock when idle"; checked: ig.lockEnabled; onToggled: ig.toggleLock() }
    SettingSliderRow {
        visible: ig.lockEnabled
        label: "Lock after"
        value: ig.lockMinutes
        from: 1; to: 60; unit: " min"
        onMoved: v => ig.setLockMinutes(v)
    }
    SettingToggleRow { label: "Suspend when idle"; checked: ig.suspendEnabled; onToggled: ig.toggleSuspend() }
    SettingSliderRow {
        visible: ig.suspendEnabled
        label: "Suspend after"
        value: ig.suspendMinutes
        from: 5; to: 120; unit: " min"
        onMoved: v => ig.setSuspendMinutes(v)
    }
}
