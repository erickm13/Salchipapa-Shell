pragma Singleton
import QtQuick
import Quickshell

// Mantiene la sombra nativa de Hyprland alineada con Appearance.
Singleton {
    id: root

    function sync(): void {
        const c = Theme.shadow;
        const hex = value => Math.round(value * 255).toString(16).padStart(2, "0");
        const rgba = "rgba(" + hex(c.r) + hex(c.g) + hex(c.b)
            + hex(Config.appearanceShadowOpacity / 100) + ")";
        const range = Math.min(100, Math.round(Config.appearanceShadowSpread * 0.22
            * Config.appearanceShadowBlur / 100));

        Quickshell.execDetached([
            Quickshell.shellDir + "/../scripts/sync-window-shadow.sh",
            rgba,
            String(range),
            String(Config.appearanceShadowOffset)
        ]);
    }

    function scheduleSync(): void {
        applyTimer.restart();
    }

    Timer {
        id: applyTimer
        interval: 100
        repeat: false
        onTriggered: root.sync()
    }

    Connections {
        target: Config
        function onAppearanceShadowOpacityChanged(): void { root.scheduleSync(); }
        function onAppearanceShadowBlurChanged(): void { root.scheduleSync(); }
        function onAppearanceShadowOffsetChanged(): void { root.scheduleSync(); }
        function onAppearanceShadowSpreadChanged(): void { root.scheduleSync(); }
    }

    Connections {
        target: Theme
        function onShadowChanged(): void { root.scheduleSync(); }
    }

    Component.onCompleted: applyTimer.start()
}
