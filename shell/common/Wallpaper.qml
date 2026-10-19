pragma Singleton
// Wallpaper actual (lo escribe scripts/wallpaper.sh) y el fondo animado activo, si lo hay
// (scripts/animated-wallpaper.sh). Se actualizan en vivo.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string current: ""
    // id de Wallpaper Engine del fondo animado; vacío = fondo estático
    property string animated: ""

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/animated"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.animated = text().trim()
        onLoadFailed: root.animated = ""
    }
}
