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
    // Media
    readonly property int mediaTitleWidth: settings.mediaTitleWidth
    readonly property int mediaAlbumArtSize: settings.mediaAlbumArtSize
    readonly property bool mediaShowAlbum: settings.mediaShowAlbum
    readonly property bool mediaShowArtist: settings.mediaShowArtist
    readonly property bool mediaShowControls: settings.mediaShowControls
    readonly property bool mediaShowLyrics: settings.mediaShowLyrics
    readonly property bool mediaScrollToChangeTrack: settings.mediaScrollToChangeTrack
    // Clock & Date
    readonly property bool clock24Hour: settings.clock24Hour
    readonly property bool clockShowSeconds: settings.clockShowSeconds
    readonly property bool clockShowWorkspaceDots: settings.clockShowWorkspaceDots
    readonly property bool clockShowBatteryWifi: settings.clockShowBatteryWifi
    readonly property bool clockShowBatteryPercent: settings.clockShowBatteryPercent
    readonly property bool clockExpandedWorkspaces: settings.clockExpandedWorkspaces
    readonly property bool clockExpandedStatus: settings.clockExpandedStatus
    readonly property bool clockExpandedMedia: settings.clockExpandedMedia
    readonly property int clockWeekStart: settings.clockWeekStart
    readonly property int clockCalendarDayHeight: settings.clockCalendarDayHeight
    readonly property bool clockShowNeighbouringMonths: settings.clockShowNeighbouringMonths
    // Appearance
    readonly property string appearanceAccent: settings.appearanceAccent
    readonly property bool appearanceColorBurst: settings.appearanceColorBurst
    readonly property int appearanceFontSize: settings.appearanceFontSize
    readonly property string appearanceBodyFont: settings.appearanceBodyFont
    readonly property string appearanceDisplayFont: settings.appearanceDisplayFont
    readonly property int appearanceSpacingUnit: settings.appearanceSpacingUnit
    readonly property int appearanceSmallRadius: settings.appearanceSmallRadius
    readonly property int appearanceMediumRadius: settings.appearanceMediumRadius
    readonly property int appearanceLargeRadius: settings.appearanceLargeRadius
    readonly property bool appearanceScreenCorners: settings.appearanceScreenCorners
    readonly property int appearanceScreenCornerRadius: settings.appearanceScreenCornerRadius
    readonly property int appearanceIconSize: settings.appearanceIconSize
    readonly property int appearanceIconStroke: settings.appearanceIconStroke
    readonly property int appearanceSurfaceLift: settings.appearanceSurfaceLift
    readonly property int appearanceDividerStrength: settings.appearanceDividerStrength
    readonly property int appearanceSecondaryText: settings.appearanceSecondaryText
    readonly property int appearanceTertiaryText: settings.appearanceTertiaryText
    readonly property int appearanceHoverFill: settings.appearanceHoverFill
    readonly property int appearanceSelectedFill: settings.appearanceSelectedFill
    readonly property int appearanceModalDim: settings.appearanceModalDim
    readonly property int appearanceShadowOpacity: settings.appearanceShadowOpacity
    readonly property int appearanceShadowBlur: settings.appearanceShadowBlur
    readonly property int appearanceShadowOffset: settings.appearanceShadowOffset
    readonly property int appearanceShadowSpread: settings.appearanceShadowSpread
    readonly property int appearanceWallpaperCrossfade: settings.appearanceWallpaperCrossfade

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

            // Media
            property int mediaTitleWidth: 104
            property int mediaAlbumArtSize: 90
            property bool mediaShowAlbum: true
            property bool mediaShowArtist: true
            property bool mediaShowControls: true
            property bool mediaShowLyrics: false
            property bool mediaScrollToChangeTrack: true

            // Clock & Date
            property bool clock24Hour: true
            property bool clockShowSeconds: false
            property bool clockShowWorkspaceDots: true
            property bool clockShowBatteryWifi: true
            property bool clockShowBatteryPercent: true
            property bool clockExpandedWorkspaces: true
            property bool clockExpandedStatus: true
            property bool clockExpandedMedia: true
            property int clockWeekStart: 0 // 0 = domingo, 6 = sábado
            property int clockCalendarDayHeight: 32
            property bool clockShowNeighbouringMonths: true

            // Appearance
            property string appearanceAccent: "" // vacío = color principal del tema
            property bool appearanceColorBurst: false
            property int appearanceFontSize: 15
            property string appearanceBodyFont: "" // vacío = fuente predeterminada de Qt
            property string appearanceDisplayFont: ""
            property int appearanceSpacingUnit: 4
            property int appearanceSmallRadius: 10
            property int appearanceMediumRadius: 14
            property int appearanceLargeRadius: 18
            property bool appearanceScreenCorners: true
            property int appearanceScreenCornerRadius: 14
            property int appearanceIconSize: 18
            property int appearanceIconStroke: 10
            property int appearanceSurfaceLift: 2
            property int appearanceDividerStrength: 15
            property int appearanceSecondaryText: 55
            property int appearanceTertiaryText: 50
            property int appearanceHoverFill: 8
            property int appearanceSelectedFill: 13
            property int appearanceModalDim: 50
            property int appearanceShadowOpacity: 63
            property int appearanceShadowBlur: 100
            property int appearanceShadowOffset: 8
            property int appearanceShadowSpread: 74
            property int appearanceWallpaperCrossfade: 450
        }
    }
}
