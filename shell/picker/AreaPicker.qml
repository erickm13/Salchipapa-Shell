pragma ComponentBehavior: Bound
// Selector de región con FREEZE (como caelestia), independiente.
// Congela la pantalla con ScreencopyView, dejas seleccionar un área y al soltar
// recorta (magick) -> copia al portapapeles -> abre swappy para anotar.
// Se abre con: bind = $mod SHIFT, S, global, salchipapa:screenshot
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common"

Scope {
    id: root

    property bool active: false

    GlobalShortcut {
        appid: "salchipapa"
        name: "screenshot"
        description: "Captura de región con freeze"
        onPressed: root.active = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            visible: root.active
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "salchipapa-picker" // para el layerrule de animación (popin)
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Estado de la selección
            property bool selecting: false
            property real sx: 0
            property real sy: 0
            property real ex: 0
            property real ey: 0
            readonly property real rx: Math.min(sx, ex)
            readonly property real ry: Math.min(sy, ey)
            readonly property real rw: Math.abs(ex - sx)
            readonly property real rh: Math.abs(ey - sy)

            onVisibleChanged: {
                if (visible) {
                    sx = sy = ex = ey = 0;
                    selecting = false;
                }
            }

            function finish(): void {
                if (rw < 3 || rh < 3 || !freezeLoader.item) {
                    root.active = false;
                    return;
                }
                const geom = Math.round(rw) + "x" + Math.round(rh) + "+" + Math.round(rx) + "+" + Math.round(ry);
                freezeLoader.item.grabToImage(function (result) {
                    const tmp = "/tmp/salchipapa-freeze.png";
                    result.saveToFile(tmp);
                    const out = Quickshell.env("HOME") + "/Pictures/Screenshots/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
                    Quickshell.execDetached(["sh", "-c", "mkdir -p ~/Pictures/Screenshots; magick " + tmp + " -crop " + geom + " +repage \"" + out + "\"; wl-copy -t image/png < \"" + out + "\"; swappy -f \"" + out + "\""]);
                    root.active = false;
                });
            }

            // Pantalla congelada (se crea al abrir => captura el momento actual)
            Loader {
                id: freezeLoader
                anchors.fill: parent
                active: root.active
                sourceComponent: ScreencopyView {
                    captureSource: win.screen
                    live: false
                }
            }

            // Atenuado con "hueco" en la selección (4 rectángulos)
            Rectangle {
                color: "#80000000"
                x: 0
                y: 0
                width: parent.width
                height: win.ry
            }
            Rectangle {
                color: "#80000000"
                x: 0
                y: win.ry + win.rh
                width: parent.width
                height: parent.height - (win.ry + win.rh)
            }
            Rectangle {
                color: "#80000000"
                x: 0
                y: win.ry
                width: win.rx
                height: win.rh
            }
            Rectangle {
                color: "#80000000"
                x: win.rx + win.rw
                y: win.ry
                width: parent.width - (win.rx + win.rw)
                height: win.rh
            }

            // Borde de la selección
            Rectangle {
                x: win.rx
                y: win.ry
                width: win.rw
                height: win.rh
                color: "transparent"
                border.color: Theme.green
                border.width: 2
                visible: win.rw > 1 && win.rh > 1
            }

            // Ayuda
            Text {
                anchors.centerIn: parent
                text: "Arrastra para seleccionar · Esc para cancelar"
                color: "#ffffff"
                font.pixelSize: 15
                visible: !win.selecting && win.rw < 3
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                focus: true

                onPressed: event => {
                    win.sx = event.x;
                    win.sy = event.y;
                    win.ex = event.x;
                    win.ey = event.y;
                    win.selecting = true;
                }
                onPositionChanged: event => {
                    if (win.selecting) {
                        win.ex = event.x;
                        win.ey = event.y;
                    }
                }
                onReleased: {
                    win.selecting = false;
                    win.finish();
                }
                Keys.onEscapePressed: root.active = false
            }
        }
    }
}
