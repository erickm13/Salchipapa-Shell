pragma Singleton
// Estado del Bluetooth.
// Se apaga y enciende con rfkill (no solo con Powered de BlueZ): systemd-rfkill guarda ese estado,
// así que tras reiniciar el Bluetooth queda como se dejó. Con solo Powered, bluetoothd lo
// volvía a encender al arrancar (AutoEnable=true por defecto).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property int connectedCount: Bluetooth.devices?.values?.filter(d => d.connected).length ?? 0

    function toggle(): void {
        if (rfkillProc.running)
            return;
        rfkillProc.turnOn = !root.enabled;
        rfkillProc.command = ["rfkill", rfkillProc.turnOn ? "unblock" : "block", "bluetooth"];
        rfkillProc.running = true;
    }

    Process {
        id: rfkillProc
        property bool turnOn: false
        // Tras desbloquear, BlueZ no siempre enciende el adaptador solo: se le pide Powered=true
        onExited: {
            const a = Bluetooth.defaultAdapter;
            if (turnOn && a && !a.enabled)
                a.enabled = true;
        }
    }
}
