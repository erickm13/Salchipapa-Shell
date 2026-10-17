pragma ComponentBehavior: Bound
// Selector de región con FREEZE (como caelestia), independiente.
// Congela la pantalla con ScreencopyView, dejas seleccionar un área y al soltar
// recorta (magick) -> copia al portapapeles -> abre swappy para anotar.
// Se abre con: bind = $mod SHIFT, S, global, salchipapa:screenshot
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../common"

Scope {
    id: root

    property bool active: false
    property var clients: []
    property var hoveredWindow: null

    onActiveChanged: {
        hoveredWindow = null;
        clients = [];
        if (active)
            clientsProc.running = true;
    }

    function windowAt(x, y): var {
        const matches = clients.filter(client =>
            client.mapped !== false && client.hidden !== true && client.at && client.size &&
            x >= client.at[0] && y >= client.at[1] &&
            x < client.at[0] + client.size[0] && y < client.at[1] + client.size[1]
        );
        if (matches.length === 0)
            return null;

        const client = matches[matches.length - 1];
        const left = Math.floor(client.at[0]);
        const top = Math.floor(client.at[1]);
        return {
            x: left,
            y: top,
            width: Math.ceil(client.at[0] + client.size[0]) - left,
            height: Math.ceil(client.at[1] + client.size[1]) - top
        };
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            id: clientsOut
            onStreamFinished: {
                try {
                    root.clients = JSON.parse(clientsOut.text);
                } catch (error) {
                    root.clients = [];
                }
            }
        }
    }

    function captureWindow(window): void {
        if (!window)
            return;
        root.active = false;
        Quickshell.execDetached([
            "bash",
            Quickshell.shellDir + "/../scripts/screenshot.sh",
            "window", String(window.x), String(window.y), String(window.width), String(window.height)
        ]);
    }

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
            WlrLayershell.namespace: "salchipapa-picker" // sin animación para capturas limpias
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Connections {
                target: root
                function onClientsChanged(): void {
                    if (pointerArea.containsMouse)
                        root.hoveredWindow = root.windowAt(pointerArea.mouseX + win.screen.x, pointerArea.mouseY + win.screen.y);
                }
            }

            // Estado de la selección
            property bool selecting: false
            property real sx: 0
            property real sy: 0
            property real ex: 0
            property real ey: 0
            property var pressedWindow: null
            readonly property real rx: Math.min(sx, ex)
            readonly property real ry: Math.min(sy, ey)
            readonly property real rw: Math.abs(ex - sx)
            readonly property real rh: Math.abs(ey - sy)
            readonly property real areaX: selecting ? rx : (root.hoveredWindow ? Math.max(0, root.hoveredWindow.x - screen.x) : 0)
            readonly property real areaY: selecting ? ry : (root.hoveredWindow ? Math.max(0, root.hoveredWindow.y - screen.y) : 0)
            readonly property real areaW: selecting ? rw : (root.hoveredWindow ? Math.max(0, Math.min(screen.x + width, root.hoveredWindow.x + root.hoveredWindow.width) - Math.max(screen.x, root.hoveredWindow.x)) : 0)
            readonly property real areaH: selecting ? rh : (root.hoveredWindow ? Math.max(0, Math.min(screen.y + height, root.hoveredWindow.y + root.hoveredWindow.height) - Math.max(screen.y, root.hoveredWindow.y)) : 0)

            onVisibleChanged: {
                if (visible) {
                    sx = sy = ex = ey = 0;
                    selecting = false;
                }
            }

            function finish(): void {
                if (!freezeLoader.item) {
                    root.active = false;
                    return;
                }
                // Un clic se atiende en onClicked; aquí solo procesamos regiones arrastradas.
                if (rw < 3 || rh < 3) {
                    return;
                }
                const geom = Math.round(rw) + "x" + Math.round(rh) + "+" + Math.round(rx) + "+" + Math.round(ry);
                freezeLoader.item.grabToImage(function (result) {
                    // BMP: codificar/leer es mucho más rápido que PNG para la pantalla completa
                    const tmp = "/tmp/salchipapa-freeze.bmp";
                    result.saveToFile(tmp);
                    root.active = false; // cierra el freeze YA; el recorte+swappy van en segundo plano
                    const out = Quickshell.env("HOME") + "/Pictures/Screenshots/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
                    Quickshell.execDetached(["sh", "-c", "mkdir -p ~/Pictures/Screenshots; magick " + tmp + " -crop " + geom + " +repage \"" + out + "\"; wl-copy -t image/png < \"" + out + "\"; swappy -f \"" + out + "\""]);
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
                height: win.areaY
            }
            Rectangle {
                color: "#80000000"
                x: 0
                y: win.areaY + win.areaH
                width: parent.width
                height: parent.height - (win.areaY + win.areaH)
            }
            Rectangle {
                color: "#80000000"
                x: 0
                y: win.areaY
                width: win.areaX
                height: win.areaH
            }
            Rectangle {
                color: "#80000000"
                x: win.areaX + win.areaW
                y: win.areaY
                width: parent.width - (win.areaX + win.areaW)
                height: win.areaH
            }

            // Borde de la selección
            Rectangle {
                x: win.areaX
                y: win.areaY
                width: win.areaW
                height: win.areaH
                color: "transparent"
                border.color: Theme.green
                border.width: 3
                visible: win.areaW > 1 && win.areaH > 1
            }

            MouseArea {
                id: pointerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.hoveredWindow && !win.selecting ? Qt.PointingHandCursor : Qt.CrossCursor
                focus: true

                onEntered: {
                    root.hoveredWindow = root.windowAt(mouseX + win.screen.x, mouseY + win.screen.y);
                }
                onPressed: event => {
                    win.sx = event.x;
                    win.sy = event.y;
                    win.ex = event.x;
                    win.ey = event.y;
                    win.pressedWindow = root.windowAt(event.x + win.screen.x, event.y + win.screen.y);
                    win.selecting = true;
                }
                onPositionChanged: event => {
                    if (win.selecting) {
                        win.ex = event.x;
                        win.ey = event.y;
                    } else {
                        root.hoveredWindow = root.windowAt(event.x + win.screen.x, event.y + win.screen.y);
                    }
                }
                onReleased: {
                    win.selecting = false;
                    if (win.rw >= 3 && win.rh >= 3)
                        win.finish();
                }
                onClicked: {
                    if (win.rw < 3 || win.rh < 3)
                        root.captureWindow(win.pressedWindow);
                    win.pressedWindow = null;
                }
                Keys.onEscapePressed: root.active = false
            }
        }
    }
}
