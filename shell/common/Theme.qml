pragma Singleton
// Paleta (Catppuccin Mocha) y curvas de animación. Un solo sitio para los colores.
import QtQuick
import Quickshell

Singleton {
    // Base
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay2: "#9399b2"
    readonly property color text: "#cdd6f4"
    readonly property color subtext: "#bac2de"

    // Acentos
    readonly property color blue: "#89b4fa"
    readonly property color sapphire: "#74c7ec"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"
    readonly property color mauve: "#cba6f7"

    // Isla
    readonly property color islandBg: "#0b0b0f"
    readonly property color islandBorder: "#1affffff"

    // Curvas de animación (Material 3)
    readonly property var spring: [0.38, 1.21, 0.22, 1, 1, 1]   // expressive, con overshoot (rebote)
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
}
