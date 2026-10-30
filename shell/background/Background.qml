pragma ComponentBehavior: Bound
// Fondo de pantalla renderizado por la shell (capa Background, una por monitor).
// Lee el wallpaper de Wallpaper.current (lo escribe scripts/wallpaper.sh) y lo revela en círculo.
// Con un fondo animado (linux-wallpaperengine, también en la capa Background) se oculta para no taparlo.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData
        visible: Wallpaper.animated === ""

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        color: "black"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WallpaperReveal {
            anchors.fill: parent
            source: Wallpaper.current ? "file://" + Wallpaper.current : ""
            duration: Config.appearanceWallpaperCrossfade
            reduceMotion: Theme.reduceMotion
        }
    }
}
