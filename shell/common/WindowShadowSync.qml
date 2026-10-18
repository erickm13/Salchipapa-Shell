pragma Singleton
import QtQuick
import Quickshell

// Mantiene la sombra nativa de Hyprland alineada con Appearance.
Singleton {
    id: root

    // Hyprland's range is a pixel radius. Keep the same effective radius for
    // Quickshell's MultiEffect shadow so both surfaces use the same controls.
    readonly property int range: Math.min(100, Math.round(Config.appearanceShadowSpread * 0.22
        * Config.appearanceShadowBlur / 100))
    // Island shadow values can be scaled independently from Hyprland's values.
    readonly property int quickshellRange: Math.min(100, range * 2)
    readonly property real quickshellBlur: Math.min(1, Config.appearanceShadowBlur / 100 * 2)
    readonly property int quickshellBlurRadius: Math.round(quickshellRange * quickshellBlur)
    readonly property real quickshellOpacity: Math.min(1, Config.appearanceShadowOpacity / 100 * 2)

    function sync(): void {
        const c = Theme.shadow;
        const hex = value => Math.round(value * 255).toString(16).padStart(2, "0");
        const rgba = "rgba(" + hex(c.r) + hex(c.g) + hex(c.b)
            + hex(Config.appearanceShadowOpacity / 100) + ")";
        Quickshell.execDetached([
            Quickshell.shellDir + "/../scripts/sync-window-shadow.sh",
            rgba,
            String(root.range),
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
