pragma Singleton
// Batería vía UPower, y aviso de batería baja (Ajustes > Notifications > Low battery).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../common"

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
    // Funcionando con la batería (desenchufado). Sin batería de portátil, siempre false.
    readonly property bool onBattery: available && UPower.onBattery

    // Aviso de batería baja: uno al bajar del umbral "low" y otro, crítico, al bajar del
    // "critical" (-t 0: se queda en la isla hasta pulsarlo o enchufar). Cada nivel avisa una sola
    // vez por descarga; al enchufar se olvida.
    // 0 = sin avisar, 1 = avisado de baja, 2 = avisado de crítica.
    property int warned: 0
    readonly property bool ready: UPower.displayDevice?.ready ?? false
    readonly property string sounds: "/usr/share/sounds/freedesktop/stereo/"

    function check(): void {
        if (!onBattery) {
            // Al enchufar se quitan los avisos que sigan a la vista (el crítico no se va solo)
            if (warned > 0)
                for (const n of (Notifs.list?.values ?? []).slice())
                    if (n.appName === "Battery")
                        n.dismiss();
            warned = 0;
            return;
        }
        // Antes de que UPower dé el dato, percentage vale 0: no avisar de un falso 0 %.
        if (!ready || percent <= 0 || !Config.notificationBatteryLow)
            return;
        const critical = Config.notificationBatteryCriticalPercent;
        const low = Math.max(Config.notificationBatteryLowPercent, critical);
        if (percent <= critical && warned < 2) {
            warned = 2;
            // El crítico suena siempre (también en Focus/Game mode o con el sonido apagado): lo pone
            // aquí y le dice a Notifs que no lo repita.
            Quickshell.execDetached(["pw-play", sounds + "suspend-error.oga"]);
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "critical", "-i", "battery-000", "-t", "0",
                "-h", "boolean:suppress-sound:true",
                "Battery critical: " + percent + "%", "Plug in the charger now or the laptop will shut down."]);
        } else if (percent <= low && warned < 1) {
            warned = 1;
            // El de baja suena como las demás (Notifs.playSound: respeta el ajuste y Focus/Game mode).
            Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", "normal", "-i", "battery-020",
                "-h", "string:sound-file:" + sounds + "dialog-warning.oga",
                "Battery low: " + percent + "%", "Plug in the charger soon."]);
        }
    }

    // Se revisa con un respiro: al enchufar/desenchufar UPower cambia estado y nivel por separado.
    onPercentChanged: checkTimer.restart()
    onOnBatteryChanged: checkTimer.restart()
    onReadyChanged: checkTimer.restart()
    Timer {
        id: checkTimer
        interval: 2000
        onTriggered: root.check()
    }
}
