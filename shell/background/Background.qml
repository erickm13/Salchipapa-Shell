pragma ComponentBehavior: Bound
// Fondo de pantalla renderizado por la shell (capa Background, una por monitor).
// Lee el wallpaper de Wallpaper.current (lo escribe `caelestia wallpaper`) y hace crossfade.
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

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        color: "black"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property string src: Wallpaper.current ? "file://" + Wallpaper.current : ""

        // Imagen base (la actual)
        Image {
            id: base
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            source: win.src
        }

        // Imagen superior: aparece con fade cuando cambia el wallpaper, luego pasa a base
        Image {
            id: top
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0

            onStatusChanged: if (status === Image.Ready && source != base.source)
                fadeIn.restart()

            NumberAnimation {
                id: fadeIn
                target: top
                property: "opacity"
                to: 1
                duration: Theme.reduceMotion ? 0 : Config.appearanceWallpaperCrossfade
                easing.type: Easing.InOutQuad
                onFinished: {
                    base.source = top.source;
                    top.opacity = 0;
                }
            }
        }

        onSrcChanged: if (src)
            top.source = src
    }
}
