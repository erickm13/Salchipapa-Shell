pragma Singleton
// Estado compartido de los "modos overlay" de la isla (launcher / selector de temas)
// y los atajos globales que los abren. La UI vive DENTRO de la Dynamic Island.
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // "" = nada; el resto son overlays que se muestran dentro de la isla.
    property string mode: ""

    // Panel de ajustes (ventana propia, no es un modo de la isla). La ventana se crea al abrirlo
    // (shell.qml), con el tamaño del monitor enfocado en ese momento; la categoría se recuerda aquí.
    property bool settings: false
    property string settingsMonitor: ""
    property int settingsCategory: 0
    // Índice del buscador de ajustes ([{ cat, label }]): se arma la primera vez que se abre el panel
    property var settingsIndex: []

    // Monitor principal (isla cuando no va en todos, Display > Primary monitor): el elegido en
    // ajustes si está conectado; si no, el del workspace 1; si no, el primero. Nunca el enfocado:
    // un workspace 1 vacío deja de existir al cambiar de workspace y la isla seguía al foco.
    readonly property string primaryMonitor: {
        const names = Hyprland.monitors.values.map(m => m.name);
        if (Config.primaryMonitor !== "" && names.includes(Config.primaryMonitor))
            return Config.primaryMonitor;
        return Hyprland.workspaces.values.find(w => w.id === 1)?.monitor?.name ?? names[0] ?? "";
    }

    function toggleSettings(): void {
        if (!settings)
            settingsMonitor = Hyprland.focusedMonitor?.name ?? "";
        settings = !settings;
    }

    function close(): void {
        mode = "";
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "launcher"
        description: "Abrir/cerrar el lanzador (dentro de la isla)"
        onPressed: root.mode = root.mode === "launcher" ? "" : "launcher"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "themes"
        description: "Abrir/cerrar el selector de temas (dentro de la isla)"
        onPressed: root.mode = root.mode === "themes" ? "" : "themes"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "wallpaper"
        description: "Abrir/cerrar el selector de fondos (dentro de la isla)"
        onPressed: root.mode = root.mode === "wallpaper" ? "" : "wallpaper"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "clipboard"
        description: "Abrir/cerrar el historial del portapapeles (dentro de la isla)"
        onPressed: root.mode = root.mode === "clipboard" ? "" : "clipboard"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "emoji"
        description: "Abrir/cerrar el selector de emojis (dentro de la isla)"
        onPressed: root.mode = root.mode === "emoji" ? "" : "emoji"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "perf"
        description: "Abrir/cerrar la página de rendimiento (dentro de la isla)"
        onPressed: root.mode = root.mode === "perf" ? "" : "perf"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "control"
        description: "Abrir/cerrar el centro de control (dentro de la isla)"
        onPressed: root.mode = root.mode === "control" ? "" : "control"
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "settings"
        description: "Abrir/cerrar el panel de ajustes"
        onPressed: root.toggleSettings()
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "power"
        description: "Abrir/cerrar el menú de energía dentro de la isla"
        onPressed: root.mode = root.mode === "power" ? "" : "power"
    }
}
