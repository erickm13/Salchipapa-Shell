pragma Singleton
// Paleta de la shell. Lee el esquema ACTUAL de caelestia (~/.local/state/caelestia/scheme.json)
// y se actualiza en vivo al aplicar un tema. Si no existe, usa Catppuccin Mocha como fallback.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Mapa de roles Material 3 -> hex (sin #) del esquema activo
    property var c: ({})

    function col(role: string, fallback: string): string {
        const v = c[role];
        return v ? "#" + v : fallback;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text()).colours ?? ({});
            } catch (e) {
                root.c = ({});
            }
        }
    }

    // --- Superficies ---
    readonly property color base: col("background", "#1e1e2e")
    readonly property color mantle: col("surfaceContainerLow", "#181825")
    readonly property color crust: col("surfaceContainerLowest", "#11111b")
    readonly property color surface0: col("surfaceContainerHigh", "#313244")
    readonly property color surface1: col("surfaceContainerHighest", "#45475a")
    readonly property color overlay0: col("outline", "#6c7086")
    readonly property color overlay1: col("outlineVariant", "#7f849c")
    readonly property color overlay2: col("outline", "#9399b2")
    readonly property color text: col("onBackground", "#cdd6f4")
    readonly property color subtext: col("onSurfaceVariant", "#bac2de")

    // --- Acentos (mapeados a roles M3; el acento principal es "green" = primary) ---
    readonly property color green: col("primary", "#a6e3a1")
    readonly property color blue: col("secondary", "#89b4fa")
    readonly property color sapphire: col("primary", "#74c7ec")
    readonly property color peach: col("tertiary", "#fab387")
    readonly property color mauve: col("secondary", "#cba6f7")
    readonly property color yellow: col("tertiary", "#f9e2af")
    readonly property color red: col("error", "#f38ba8")

    // --- Isla ---
    readonly property color islandBg: col("surfaceContainerLowest", "#0b0b0f")
    readonly property color islandBorder: "#1affffff"

    // --- Curvas de animación (Material 3) ---
    readonly property var spring: [0.38, 1.21, 0.22, 1, 1, 1]   // expressive, con overshoot (rebote)
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
}
