pragma Singleton
// Bloqueo y suspensión automáticos por inactividad (sustituye a hypridle).
// Usa ext-idle-notify de Wayland; respeta los inhibidores (vídeo, apps a pantalla completa…).
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

Singleton {
    id: root

    // Con la batería se usan los ajustes idleBattery*; enchufado (o sin batería), los idle*.
    readonly property bool onBattery: Battery.onBattery
    readonly property bool lockEnabled: onBattery ? Config.idleBatteryLockEnabled : Config.idleLockEnabled
    readonly property int lockMinutes: onBattery ? Config.idleBatteryLockMinutes : Config.idleLockMinutes
    readonly property bool suspendEnabled: onBattery ? Config.idleBatterySuspendEnabled : Config.idleSuspendEnabled
    readonly property int suspendMinutes: onBattery ? Config.idleBatterySuspendMinutes : Config.idleSuspendMinutes

    // IdleMonitor no aplica un `timeout` nuevo si ya está activo: hay que apagarlo y
    // volverlo a encender (también al cargar config.json, que llega tras los valores por
    // defecto, y al enchufar/desenchufar, que cambia de juego de ajustes).
    property bool lockArmed: true
    property bool suspendArmed: true

    onLockMinutesChanged: {
        lockArmed = false;
        Qt.callLater(() => lockArmed = true);
    }
    onSuspendMinutesChanged: {
        suspendArmed = false;
        Qt.callLater(() => suspendArmed = true);
    }

    IdleMonitor {
        enabled: root.lockEnabled && root.lockArmed
        timeout: root.lockMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                LockScreen.lock();
        }
    }

    // LockScreen.suspend() bloquea primero y luego llama a `systemctl suspend`.
    IdleMonitor {
        enabled: root.suspendEnabled && root.suspendArmed
        timeout: root.suspendMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle && !LockScreen.suspending)
                LockScreen.suspend();
        }
    }
}
