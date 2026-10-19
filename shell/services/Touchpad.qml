pragma Singleton
// Activar/desactivar el touchpad (Ajustes > System y la tecla del touchpad, `salchipapa:touchpad`).
// Lo aplica Hyprland con hl.device({ name, enabled }) a cada dispositivo con "touchpad" en el nombre.
// El estado se guarda en config.json y se reaplica al iniciar y tras recargar Hyprland.
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    function toggle(): void {
        Config.opt.touchpadEnabled = !Config.touchpadEnabled;
    }

    function apply(): void {
        devicesQuery.exec(["hyprctl", "devices", "-j"]);
    }

    Process {
        id: devicesQuery
        stdout: StdioCollector {
            id: devicesOut
            onStreamFinished: {
                let names = [];
                try {
                    names = JSON.parse(devicesOut.text).mice.map(m => m.name).filter(n => n.toLowerCase().includes("touchpad"));
                } catch (e) {
                    return;
                }
                if (names.length === 0)
                    return;
                const lua = names.map(n => 'hl.device({ name = "' + n + '", enabled = ' + (Config.touchpadEnabled ? "true" : "false") + ' })').join("\n");
                applyProc.exec(["hyprctl", "eval", lua]);
            }
        }
    }
    Process { id: applyProc }
    Process { id: notifyProc }

    GlobalShortcut {
        appid: "salchipapa"
        name: "touchpad"
        description: "Activar/desactivar el touchpad"
        onPressed: {
            root.toggle();
            notifyProc.exec(["notify-send", "-i", "input-touchpad-symbolic", "-t", "2000", "Touchpad", Config.touchpadEnabled ? "Activado" : "Desactivado"]);
        }
    }

    Connections {
        target: Config
        function onTouchpadEnabledChanged(): void { root.apply(); }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.apply();
        }
    }
}
