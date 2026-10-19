//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// Salchipapa-Shell — entrada.
// Monta UNA barra por monitor, con el diseño elegido en common/Config.qml.
// Para añadir otro diseño: crea designs/<Nombre>.qml (un PanelWindow) y añádelo al switch.
// Probar:  qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml   (recarga sola al guardar)

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "common"
import "designs"
import "picker"
import "background"
import "services"

ShellRoot {
    // Sincroniza la sombra nativa de Hyprland con los controles de Appearance.
    // Fondo de pantalla (capa Background, por monitor)
    Background {}

    // Empieza el fundido antes de que WlSessionLock cubra el escritorio.
    // LockScreen mantiene además su propia capa negra encima de la pantalla bloqueada.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: LockScreen.suspending
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusiveZone: -1

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: LockScreen.suspending ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 550; easing.type: Easing.InOutCubic }
                }
            }
        }
    }

    // Quickshell no refresca monitores/workspaces en todos los eventos; forzamos el
    // refresco en los que importan (p.ej. activespecial) para que la isla reaccione.
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (n === "configreloaded") {
                WindowShadowSync.sync();
            } else if (["activespecial", "workspace", "moveworkspace", "focusedmon"].includes(n)) {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshWorkspaces();
            }
        }
    }

    // Barra (una por monitor, según el diseño activo)
    Variants {
        model: Quickshell.screens

        Loader {
            id: barLoader
            required property var modelData

            active: true
            sourceComponent: {
                switch (Config.design) {
                case "island":
                default:
                    return islandComp;
                }
            }

            Component {
                id: islandComp
                DynamicIsland {
                    screen: barLoader.modelData
                }
            }
        }
    }

    // El lanzador (Super+R) y el selector de temas (Super+T) ahora son MODOS de la
    // Dynamic Island (ver common/Overlay.qml + designs/LauncherContent/ThemeContent).
    // Forzamos la instancia del singleton Overlay para que registre sus GlobalShortcuts.
    Component.onCompleted: {
        Overlay.mode;
        LockScreen.locked;
        LockScreen.mediaService = Media;
        WindowBlur.apply();
        WindowShadowSync.sync();
    }

    // Captura de región con freeze (Super+Shift+S)
    AreaPicker {}

    // Panel de ajustes (Super+I)
    Settings {}
}
