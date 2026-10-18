pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

Item {
    id: root
    visible: false
    width: 0
    height: 0

    function scheduleApply(): void {
        applyTimer.restart();
    }

    function apply(): void {
        const enabled = Config.windowBlurEnabled && !Config.gameMode ? "true" : "false";
        const lua = 'hl.config({["decoration.blur.enabled"]=' + enabled
            + ',["decoration.blur.size"]=' + Config.windowBlurSize
            + ',["decoration.blur.passes"]=' + Config.windowBlurPasses
            + ',["animations.enabled"]=' + (!Config.gameMode ? "true" : "false") + '})';
        applyProc.exec(["hyprctl", "eval", lua]);
    }

    Timer {
        id: applyTimer
        interval: 120
        repeat: false
        onTriggered: root.apply()
    }

    Process { id: applyProc }

    Connections {
        target: Config
        function onWindowBlurEnabledChanged(): void { root.scheduleApply(); }
        function onWindowBlurSizeChanged(): void { root.scheduleApply(); }
        function onWindowBlurPassesChanged(): void { root.scheduleApply(); }
        function onGameModeChanged(): void { root.scheduleApply(); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.scheduleApply();
        }
    }
}
