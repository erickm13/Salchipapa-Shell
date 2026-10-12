//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// Salchipapa-Shell — entrada.
// Monta UNA barra por monitor, con el diseño elegido en common/Config.qml.
// Para añadir otro diseño: crea designs/<Nombre>.qml (un PanelWindow) y añádelo al switch.
// Probar:  qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml   (recarga sola al guardar)

import Quickshell
import QtQuick
import "common"
import "designs"

ShellRoot {
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
}
