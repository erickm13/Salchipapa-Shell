pragma Singleton
// Wallpaper actual. Lee el path que escribe `caelestia wallpaper` y se actualiza en vivo.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string current: ""

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
    }
}
