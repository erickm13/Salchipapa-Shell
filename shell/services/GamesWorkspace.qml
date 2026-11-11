pragma Singleton
// Pone el workspace de juegos (name:games, ver lua/windowrules.lua) en el monitor principal
// (Overlay.primaryMonitor = Ajustes > Display > Primary monitor, o uno que exista). Así no se fija
// un conector concreto en la config, que en otro equipo no existiría. Volver a declarar la regla
// con `hyprctl eval` sustituye la anterior; tras `hyprctl reload` se vuelve a aplicar.
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property string monitor: Overlay.primaryMonitor
    onMonitorChanged: applyTimer.restart()

    function apply(): void {
        if (monitor === "")
            return;
        applyProc.exec(["hyprctl", "eval", 'hl.workspace_rule({ workspace = "name:games", monitor = ' + JSON.stringify(monitor) + ' })']);
    }

    Timer {
        id: applyTimer
        interval: 120
        repeat: false
        onTriggered: root.apply()
    }

    Process { id: applyProc }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                applyTimer.restart();
        }
    }
}
