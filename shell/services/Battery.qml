pragma Singleton
// Batería vía UPower.
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property bool available: UPower.displayDevice?.isLaptopBattery ?? false
    readonly property int percent: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    readonly property bool charging: {
        const s = UPower.displayDevice?.state;
        return s === UPowerDeviceState.Charging
            || s === UPowerDeviceState.FullyCharged
            || s === UPowerDeviceState.PendingCharge;
    }
}
