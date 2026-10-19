pragma Singleton
// Bloqueo y suspensión automáticos por inactividad (sustituye a hypridle).
// Usa ext-idle-notify de Wayland; respeta los inhibidores (vídeo, apps a pantalla completa…).
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

Singleton {
    id: root

    // IdleMonitor no aplica un `timeout` nuevo si ya está activo: hay que apagarlo y
    // volverlo a encender (también al cargar config.json, que llega tras los valores por defecto).
    property bool lockArmed: true
    property bool suspendArmed: true

    Connections {
        target: Config
        function onIdleLockMinutesChanged(): void {
            root.lockArmed = false;
            Qt.callLater(() => root.lockArmed = true);
        }
        function onIdleSuspendMinutesChanged(): void {
            root.suspendArmed = false;
            Qt.callLater(() => root.suspendArmed = true);
        }
    }

    IdleMonitor {
        enabled: Config.idleLockEnabled && root.lockArmed
        timeout: Config.idleLockMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                LockScreen.lock();
        }
    }

    // LockScreen.suspend() bloquea primero y luego llama a `systemctl suspend`.
    IdleMonitor {
        enabled: Config.idleSuspendEnabled && root.suspendArmed
        timeout: Config.idleSuspendMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle && !LockScreen.suspending)
                LockScreen.suspend();
        }
    }
}
