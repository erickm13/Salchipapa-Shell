pragma Singleton
// Configuración global de la shell, PERSISTENTE en ~/.config/salchipapa-shell/config.json.
// La edita el panel de ajustes (Settings.qml) vía `Config.opt.<clave> = valor` y se guarda
// sola (onAdapterUpdated -> writeAdapter). El resto de la shell lee los accesos readonly.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Diseño de barra activo (no persistido por ahora)
    property string design: "island"

    // Objeto de ajustes para EDITAR desde el panel (p.ej. Config.opt.barHeight = 40)
    property alias opt: settings

    // --- Accesos READONLY para el resto de la shell ---
    readonly property int workspaceCount: settings.workspaceCount
    readonly property int topMargin: settings.gapFromEdge // separación de la barra al borde superior
    // Bar & Island
    readonly property bool notchMode: settings.notchMode
    readonly property int barHeight: settings.barHeight
    readonly property int collapsedWidth: settings.collapsedWidth
    readonly property int expandedHeight: settings.expandedHeight
    readonly property int innerPadding: settings.innerPadding

    FileView {
        path: Quickshell.env("HOME") + "/.config/salchipapa-shell/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter(); // crea el archivo con los valores por defecto
        }

        JsonAdapter {
            id: settings

            // General
            property int workspaceCount: 5

            // Bar & Island
            property bool notchMode: false
            property int barHeight: 30
            property int collapsedWidth: 90
            property int expandedHeight: 190
            property int gapFromEdge: 6
            property int innerPadding: 18
        }
    }
}
