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
    // Estado temporal del modo de juego; nunca se guarda en config.json.
    property bool gameMode: false

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
    // Motion
    readonly property bool motionReduce: settings.motionReduce
    readonly property int motionMovementDuration: motionReduce ? 0 : settings.motionMovementDuration
    readonly property int motionFadeDuration: motionReduce ? 0 : settings.motionFadeDuration
    readonly property int motionHoverDuration: motionReduce ? 0 : settings.motionHoverDuration
    readonly property int motionBounce: motionReduce ? 0 : settings.motionBounce
    // Launcher
    readonly property int launcherWidth: settings.launcherWidth
    readonly property int launcherRowHeight: settings.launcherRowHeight
    readonly property int launcherRowsBeforeScrolling: settings.launcherRowsBeforeScrolling
    // Notifications / OSD
    readonly property int notificationPopupTimeout: settings.notificationPopupTimeout
    readonly property int notificationUrgentTimeout: settings.notificationUrgentTimeout
    readonly property int notificationWidth: settings.notificationWidth
    readonly property bool notificationShowBody: settings.notificationShowBody
    readonly property bool notificationSound: settings.notificationSound
    readonly property int notificationHistoryHeight: settings.notificationHistoryHeight
    readonly property int osdOnScreenTime: settings.osdOnScreenTime
    readonly property int osdLevelBarThickness: settings.osdLevelBarThickness
    // Control Center
    readonly property int controlCenterSlots: settings.controlCenterSlots
    readonly property string controlCenterLayout: settings.controlCenterLayout
    // Lock Screen
    readonly property bool lockShowDate: settings.lockShowDate
    readonly property bool lockShowClock: settings.lockShowClock
    readonly property bool lockClock24Hour: settings.lockClock24Hour
    readonly property bool lockShowMusic: settings.lockShowMusic
    readonly property int lockBackgroundBlur: settings.lockBackgroundBlur
    readonly property int lockBackgroundDim: settings.lockBackgroundDim
    readonly property bool idleLockEnabled: settings.idleLockEnabled
    readonly property int idleLockMinutes: settings.idleLockMinutes
    readonly property bool idleSuspendEnabled: settings.idleSuspendEnabled
    readonly property int idleSuspendMinutes: settings.idleSuspendMinutes
    // Hyprland window blur
    readonly property bool windowBlurEnabled: settings.windowBlurEnabled
    readonly property int windowBlurSize: settings.windowBlurSize
    readonly property int windowBlurPasses: settings.windowBlurPasses

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

            // Motion
            property bool motionReduce: false
            property int motionMovementDuration: 420
            property int motionFadeDuration: 180
            property int motionHoverDuration: 150
            property int motionBounce: 40

            // Launcher
            property int launcherWidth: 550
            property int launcherRowHeight: 50
            property int launcherRowsBeforeScrolling: 6

            // Notifications / OSD
            property int notificationPopupTimeout: 2000
            property int notificationUrgentTimeout: 6000
            property int notificationWidth: 480
            property bool notificationShowBody: true
            property bool notificationSound: true
            property int notificationHistoryHeight: 200
            property int osdOnScreenTime: 1500
            property int osdLevelBarThickness: 6

            // Control Center
            property int controlCenterSlots: 7
            property string controlCenterLayout: ""

            // Lock Screen
            property bool lockShowDate: true
            property bool lockShowClock: true
            property bool lockClock24Hour: false
            property bool lockShowMusic: true
            property int lockBackgroundBlur: 100
            property int lockBackgroundDim: 40
            property bool idleLockEnabled: true
            property int idleLockMinutes: 5
            property bool idleSuspendEnabled: true
            property int idleSuspendMinutes: 15

            // Hyprland window blur
            property bool windowBlurEnabled: true
            property int windowBlurSize: 5
            property int windowBlurPasses: 2
        }
    }
}
