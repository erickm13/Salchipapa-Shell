pragma Singleton
// Estado del Bluetooth.
import Quickshell
import Quickshell.Bluetooth

Singleton {
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property int connectedCount: Bluetooth.devices?.values?.filter(d => d.connected).length ?? 0
}
