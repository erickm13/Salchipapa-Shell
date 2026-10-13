pragma Singleton
// Estado compartido de los "modos overlay" de la isla (launcher / selector de temas)
// y los atajos globales que los abren. La UI vive DENTRO de la Dynamic Island.
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // "" = nada; "launcher" | "themes" | "wallpaper" = la isla muestra ese modo
    property string mode: ""

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
}
