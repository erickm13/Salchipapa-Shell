pragma ComponentBehavior: Bound
// Panel de ajustes de la shell. Ventana propia (modal, centrada): sidebar de categorías +
// buscador + contenido. Fase 1: "Bar & Island" funcional (escribe en Config, persistente);
// el resto de categorías son marcadores por ahora.
import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../common"
import "../services"

FloatingWindow {
    id: win

    visible: Overlay.settings
    color: "transparent"
    title: "Salchipapa Settings"
    screen: Quickshell.screens[0]
    implicitWidth: Math.min(1080, screen.width - 96)
    implicitHeight: Math.min(620, screen.height - 144)

    readonly property var categories: [
        {
            name: "Bar & Island",
            icon: "crop_16_9",
            desc: "Forma y tamaño de la isla, el notch y la barra de Game Mode."
        },
        {
            name: "Media",
            icon: "music_note",
            desc: "Reproductor y controles multimedia."
        },
        {
            name: "Clock & Date",
            icon: "schedule",
            desc: "Reloj, formato de hora y calendario."
        },
        {
            name: "Appearance",
            icon: "palette",
            desc: "Colores, tema y wallpaper."
        },
        {
            name: "Motion",
            icon: "animation",
            desc: "Animaciones y transiciones."
        },
        {
            name: "Launcher",
            icon: "search",
            desc: "Lanzador de aplicaciones."
        },
        {
            name: "Notifications",
            icon: "notifications",
            desc: "Notificaciones y modo No molestar."
        },
        {
            name: "Control Center",
            icon: "tune",
            desc: "Interruptores rápidos y páginas del centro de control."
        },
        {
            name: "Lock Screen",
            icon: "lock",
            desc: "Reloj, fondo y contenido de la pantalla de bloqueo."
        },
        {
            name: "Display",
            icon: "monitor",
            desc: "Monitores: posición, resolución, frecuencia, orientación y perfiles automáticos."
        },
        {
            name: "Login & Boot",
            icon: "login",
            desc: "Temas de la pantalla de login (SDDM) y del arranque (GRUB)."
        },
        {
            name: "System",
            icon: "settings",
            desc: "Espacios de trabajo e información de la shell."
        }
    ]

    property int category: 0
    property string query: ""
    property string currentScheme: "Dynamic"

    // Si los colores actuales salen del fondo, volver a generarlos al cambiar estilo o intensidad
    function regenerateWallpaperColors(): void {
        if (win.currentScheme.toLowerCase() === "dynamic" && Wallpaper.animated === "" && Wallpaper.current !== "")
            regenProc.exec([Quickshell.shellDir + "/../scripts/wallpaper.sh", "--colors-only", Wallpaper.current]);
    }
    Process { id: regenProc }

    readonly property var accentColors: [Theme.green, Theme.red, Theme.orange, Theme.yellow, Theme.aqua, Theme.blue, Theme.purple]
    // Fuentes de interfaz recomendadas primero (si están instaladas); luego el resto, sin las de
    // iconos/símbolos ni las variantes de escritura de Noto, que no sirven como texto de la shell.
    readonly property var suggestedFonts: ["Google Sans Flex", "Inter", "Inter Display", "Geist", "Rubik"]
    readonly property var installedFonts: {
        const all = Qt.fontFamilies();
        const picks = suggestedFonts.filter(f => all.includes(f));
        const skip = /Symbols|Icons|Awesome|Webdings|Standard Symbols|Music|Noto (Sans|Serif|Kufi|Naskh|Nastaliq|Rashi|Fangsong|Traditional|Znamenny) \S/;
        const rest = all.filter(f => !picks.includes(f) && !skip.test(f)).sort();
        return ["System default"].concat(picks, rest);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/scheme"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: win.currentScheme = text().trim() || "Dynamic"
        onLoadFailed: win.currentScheme = "Dynamic"
    }

    function openThemeSelector(): void {
        Overlay.settings = false;
        Overlay.mode = "themes";
    }

    function openWallpaperSelector(): void {
        Overlay.settings = false;
        Overlay.mode = "wallpaper";
    }

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        return q === "" ? categories : categories.filter(c => c.name.toLowerCase().includes(q));
    }

    // ===== Card =====
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Config.appearanceScreenCorners ? Config.appearanceScreenCornerRadius : 0
        color: Theme.panelBg
        border.width: 0
        border.color: Theme.divider

        focus: Overlay.settings
        Keys.onEscapePressed: Overlay.settings = false

        MouseArea {
            anchors.fill: parent // traga clics (no cierra)
        }

        // ---------- Sidebar ----------
        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 18
            anchors.bottomMargin: 18
            width: 220
            radius: parent.radius
            color: Theme.panelBg
            // Cuadra el borde derecho (tapa las esquinas redondeadas de ese lado)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 20
                color: Theme.panelBg
            }

            Rectangle {
                id: search
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 0
                height: 34
                radius: Theme.radiusSmall
                color: Theme.panelCard

                Text {
                    id: sIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.overlay1
                }
                TextInput {
                    font.family: Theme.bodyFontFamily
                    id: searchInput
                    anchors.left: sIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(13)
                    clip: true
                    focus: Overlay.settings
                    onTextChanged: win.query = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search Settings"
                        color: Theme.text
                        font: parent.font
                        visible: parent.text.length === 0
                    }
                    Keys.onEscapePressed: Overlay.settings = false
                }
            }

            ListView {
                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                clip: true
                spacing: 2
                model: win.filtered
                boundsBehavior: Flickable.StopAtBounds

                delegate: NavItem {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    iconName: modelData.icon
                    label: modelData.name
                    active: win.categories[win.category] && win.categories[win.category].name === modelData.name
                    onClicked: win.category = win.categories.findIndex(c => c.name === modelData.name)
                }
            }
        }

        // ---------- Contenido ----------
        Item {
            id: content
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18

            readonly property var cat: win.categories[win.category]

            Row {
                id: navArrows
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: 6
                NavArrow {
                    glyph: "arrow_back"
                }
                NavArrow {
                    glyph: "arrow_forward"
                }
            }

            // Header
            Rectangle {
                id: headerCard
                anchors.top: navArrows.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 10
                height: 118
                radius: 16
                color: Theme.panelCard

                Rectangle {
                    id: hIcon
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 14
                    width: 50
                    height: 50
                    radius: 14
                    color: Theme.panelCardHi
                    Text {
                        anchors.centerIn: parent
                        text: content.cat ? content.cat.icon : ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Theme.iconPx(26)
                        font.weight: Theme.iconWeight
                        color: Theme.green
                    }
                }
                Text {
                    font.family: Theme.displayFontFamily
                    id: hTitle
                    anchors.top: hIcon.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 6
                    text: content.cat ? content.cat.name : ""
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: true
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    anchors.top: hTitle.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 2
                    width: parent.width - 48
                    horizontalAlignment: Text.AlignHCenter
                    text: content.cat ? content.cat.desc : ""
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx(11)
                    wrapMode: Text.Wrap
                }
            }

            // Controles (scroll)
            Flickable {
                anchors.top: headerCard.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 14
                contentHeight: controlsCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: controlsCol
                    width: parent.width
                    spacing: Theme.space(3)

                    // ---- Bar & Island ----
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Notch mode"
                        checked: Config.notchMode
                        onToggled: Config.opt.notchMode = !Config.opt.notchMode
                    }
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Show the island on all monitors (off: only on the primary one, the one with workspace 1)"
                        checked: Config.islandAllScreens
                        onToggled: Config.opt.islandAllScreens = !Config.islandAllScreens
                    }
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Close the island's panels (launcher, themes, control center…) when clicking outside"
                        checked: Config.islandCloseOnClickOutside
                        onToggled: Config.opt.islandCloseOnClickOutside = !Config.islandCloseOnClickOutside
                    }
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Battery percentage in the island"
                        checked: Config.clockShowBatteryPercent
                        onToggled: Config.opt.clockShowBatteryPercent = !Config.clockShowBatteryPercent
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Bar height"
                        from: 20
                        to: 60
                        value: Config.barHeight
                        onMoved: v => Config.opt.barHeight = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Collapsed width"
                        from: 60
                        to: 420
                        value: Config.collapsedWidth
                        onMoved: v => Config.opt.collapsedWidth = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Expanded height"
                        from: 120
                        to: 260
                        value: Config.expandedHeight
                        onMoved: v => Config.opt.expandedHeight = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Gap from screen edge"
                        from: 0
                        to: 40
                        value: Config.topMargin
                        onMoved: v => Config.opt.gapFromEdge = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Inner padding"
                        from: 4
                        to: 30
                        value: Config.innerPadding
                        onMoved: v => Config.opt.innerPadding = v
                    }

                    // ---- Media ----
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Song name width"
                        from: 60
                        to: 240
                        value: Config.mediaTitleWidth
                        onMoved: v => Config.opt.mediaTitleWidth = v
                    }
                    PxSlider {
                        visible: win.category === 1
                        width: parent.width
                        label: "Album art size"
                        from: 40
                        to: 160
                        value: Config.mediaAlbumArtSize
                        onMoved: v => Config.opt.mediaAlbumArtSize = v
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 1
                        width: parent.width
                        text: "What to show"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Album line"
                        checked: Config.mediaShowAlbum
                        onToggled: Config.opt.mediaShowAlbum = !Config.mediaShowAlbum
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Artist line"
                        checked: Config.mediaShowArtist
                        onToggled: Config.opt.mediaShowArtist = !Config.mediaShowArtist
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Transport buttons"
                        checked: Config.mediaShowControls
                        onToggled: Config.opt.mediaShowControls = !Config.mediaShowControls
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Lyrics"
                        checked: Config.mediaShowLyrics
                        onToggled: Config.opt.mediaShowLyrics = !Config.mediaShowLyrics
                    }
                    ToggleRow {
                        visible: win.category === 1
                        width: parent.width
                        label: "Scroll to change track"
                        checked: Config.mediaScrollToChangeTrack
                        onToggled: Config.opt.mediaScrollToChangeTrack = !Config.mediaScrollToChangeTrack
                    }

                    // ---- Clock & Date ----
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "24-hour time"
                        checked: Config.clock24Hour
                        onToggled: Config.opt.clock24Hour = !Config.clock24Hour
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Show seconds"
                        checked: Config.clockShowSeconds
                        onToggled: Config.opt.clockShowSeconds = !Config.clockShowSeconds
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Workspace dots beside the clock"
                        checked: Config.clockShowWorkspaceDots
                        onToggled: Config.opt.clockShowWorkspaceDots = !Config.clockShowWorkspaceDots
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Battery and Wi-Fi beside the clock"
                        checked: Config.clockShowBatteryWifi
                        onToggled: Config.opt.clockShowBatteryWifi = !Config.clockShowBatteryWifi
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 2
                        width: parent.width
                        text: "Expanded island"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Workspaces on the left"
                        checked: Config.clockExpandedWorkspaces
                        onToggled: Config.opt.clockExpandedWorkspaces = !Config.clockExpandedWorkspaces
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Status on the right"
                        checked: Config.clockExpandedStatus
                        onToggled: Config.opt.clockExpandedStatus = !Config.clockExpandedStatus
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Media card under the clock"
                        checked: Config.clockExpandedMedia
                        onToggled: Config.opt.clockExpandedMedia = !Config.clockExpandedMedia
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 2
                        width: parent.width
                        text: "Calendar"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider {
                        visible: win.category === 2
                        width: parent.width
                        label: "Week starts on"
                        from: 0
                        to: 6
                        unit: ""
                        value: Config.clockWeekStart
                        onMoved: v => Config.opt.clockWeekStart = v
                    }
                    PxSlider {
                        visible: win.category === 2
                        width: parent.width
                        label: "Day cell height"
                        from: 20
                        to: 48
                        value: Config.clockCalendarDayHeight
                        onMoved: v => Config.opt.clockCalendarDayHeight = v
                    }
                    ToggleRow {
                        visible: win.category === 2
                        width: parent.width
                        label: "Show neighbouring months"
                        checked: Config.clockShowNeighbouringMonths
                        onToggled: Config.opt.clockShowNeighbouringMonths = !Config.clockShowNeighbouringMonths
                    }

                    // ---- Motion ----
                    ToggleRow {
                        visible: win.category === 4
                        width: parent.width
                        label: "Reduce motion"
                        checked: Config.opt.motionReduce
                        onToggled: Config.opt.motionReduce = !Config.opt.motionReduce
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Movement (size / position)"
                        from: 0
                        to: 1000
                        value: Config.opt.motionMovementDuration
                        unit: "ms"
                        onMoved: v => Config.opt.motionMovementDuration = v
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Fades & colour"
                        from: 0
                        to: 1000
                        value: Config.opt.motionFadeDuration
                        unit: "ms"
                        onMoved: v => Config.opt.motionFadeDuration = v
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Hover response"
                        from: 0
                        to: 1000
                        value: Config.opt.motionHoverDuration
                        unit: "ms"
                        onMoved: v => Config.opt.motionHoverDuration = v
                    }
                    PxSlider {
                        visible: win.category === 4
                        width: parent.width
                        label: "Bounce"
                        from: 0
                        to: 100
                        value: Config.opt.motionBounce
                        unit: "%"
                        onMoved: v => Config.opt.motionBounce = v
                    }

                    LauncherSettings {
                        visible: win.category === 5
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    NotificationsSettings {
                        visible: win.category === 6
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    ControlCenterSettings {
                        visible: win.category === 7
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    LockScreenSettings {
                        visible: win.category === 8
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    DisplaySettings {
                        visible: win.category === 9
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    BootThemesSettings {
                        visible: win.category === 10
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }
                    SystemSettings {
                        visible: win.category === 11
                        width: parent.width
                        height: visible ? implicitHeight : 0
                    }

                    // ---- Appearance ----
                    Rectangle {
                        visible: win.category === 3
                        width: parent.width
                        height: 68
                        radius: 12
                        color: Theme.panelCard

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 34
                            color: "transparent"
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Theme"
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    text: win.currentScheme
                                    color: Theme.secondaryText
                                    font.pixelSize: Theme.fontPx(11)
                                }
                                Text {
                                    text: "arrow_forward"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Theme.tertiaryText
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openThemeSelector()
                            }
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 34
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                    color: Theme.divider
                        }
                        Item {
                            anchors.top: parent.top
                            anchors.topMargin: 35
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 33
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Wallpaper"
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    text: Wallpaper.current.length > 0 ? Wallpaper.current.split("/").pop().replace(/\.[^.]+$/, "") : "Choose…"
                                    color: Theme.secondaryText
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideLeft
                                }
                                Text {
                                    text: "arrow_forward"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 13
                                    color: Theme.tertiaryText
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openWallpaperSelector()
                            }
                        }
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Accent"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    Rectangle {
                        visible: win.category === 3
                        width: parent.width
                        height: 44
                        radius: 12
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Accent colour"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: win.accentColors
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    width: 15
                                    height: 15
                                    radius: 8
                                    color: modelData
                                    border.width: (Config.appearanceAccent === String(modelData).replace("#", "") || (Config.appearanceAccent === "" && index === 0)) ? 2 : 0
                                    border.color: "#ffffff"

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -3
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Config.opt.appearanceAccent = index === 0 ? "" : String(modelData).replace("#", "")
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: win.category === 3
                        width: parent.width
                        height: 42
                        radius: 12
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Custom (#rrggbb)"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 150
                            height: 30
                            radius: 8
                        color: Theme.divider
                            TextInput {
                                font.family: Theme.bodyFontFamily
                                id: accentInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(13)
                                text: Config.appearanceAccent !== "" ? "#" + Config.appearanceAccent : ""
                                clip: true
                                validator: RegularExpressionValidator { regularExpression: /^#?[0-9a-fA-F]{6}$/ }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "#rrggbb"
                                    color: Theme.tertiaryText
                                    font: parent.font
                                    visible: accentInput.text.length === 0
                                }
                                onEditingFinished: {
                                    if (text.length === 0)
                                        Config.opt.appearanceAccent = "";
                                    else if (acceptableInput)
                                        Config.opt.appearanceAccent = text.replace("#", "").toLowerCase();
                                }
                            }
                        }
                        Connections {
                            target: Config
                            function onAppearanceAccentChanged(): void {
                                accentInput.text = Config.appearanceAccent !== "" ? "#" + Config.appearanceAccent : "";
                            }
                        }
                    }
                    ToggleRow {
                        visible: win.category === 3
                        width: parent.width
                        label: "Color burst (a different palette colour per surface)"
                        checked: Config.appearanceColorBurst
                        onToggled: Config.opt.appearanceColorBurst = !Config.appearanceColorBurst
                    }
                    ChoiceRow {
                        visible: win.category === 3
                        width: parent.width
                        label: "Wallpaper colours: style"
                        options: [
                            { value: "scheme-tonal-spot", label: "Soft" },
                            { value: "scheme-expressive", label: "Expressive" },
                            { value: "scheme-fidelity", label: "Faithful" },
                            { value: "scheme-vibrant", label: "Vibrant" },
                            { value: "scheme-rainbow", label: "Rainbow" },
                            { value: "scheme-fruit-salad", label: "Fruit salad" }
                        ]
                        current: Config.appearanceMatugenType
                        onPicked: value => {
                            Config.opt.appearanceMatugenType = value;
                            win.regenerateWallpaperColors();
                        }
                    }
                    ChoiceRow {
                        visible: win.category === 3
                        width: parent.width
                        label: "Wallpaper colours: intensity"
                        options: [
                            { value: "0", label: "Pastel" },
                            { value: "1", label: "Medium" },
                            { value: "2", label: "Vivid" }
                        ]
                        current: String(Config.appearanceMatugenIntensity)
                        onPicked: value => {
                            Config.opt.appearanceMatugenIntensity = parseInt(value);
                            win.regenerateWallpaperColors();
                        }
                    }
                    Text {
                        visible: win.category === 3
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Used when colours come from the wallpaper (Super+W with Colours on). Soft is the Material default; Expressive gives distinct hues. Intensity makes the accent colours deeper; backgrounds and text stay readable."
                        color: Theme.tertiaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Type"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider {
                        visible: win.category === 3
                        width: parent.width
                        label: "Font size"
                        from: 10
                        to: 24
                        value: Config.appearanceFontSize
                        onMoved: v => Config.opt.appearanceFontSize = v
                    }
                    Rectangle {
                        id: fontPicker
                        visible: win.category === 3
                        width: parent.width
                        height: fontList.visible ? 174 : 42
                        radius: 12
                        color: Theme.panelCard

                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: fontField.verticalCenter
                            text: "Body font"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            id: fontField
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            anchors.rightMargin: 8
                            width: 170
                            height: 30
                            radius: 8
                            color: Theme.panelCardHi
                            Text {
                                font.family: Theme.bodyFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: fontArrow.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.appearanceBodyFont || "System default"
                                color: Theme.text
                                font.pixelSize: Theme.fontPx(11)
                                elide: Text.ElideRight
                            }
                            Text {
                                id: fontArrow
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: fontList.visible ? "expand_less" : "expand_more"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: Theme.secondaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: fontList.visible = !fontList.visible
                            }
                        }
                        ListView {
                            id: fontList
                            visible: false
                            anchors.top: fontField.bottom
                            anchors.left: fontField.left
                            anchors.right: fontField.right
                            anchors.topMargin: 4
                            height: 126
                            clip: true
                            model: win.installedFonts
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width
                                height: 30
                                radius: 6
                                color: fontRowMouse.containsMouse ? Theme.panelCardHi : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.text
                                    font.family: modelData === "System default" ? Theme.bodyFontFamily : modelData
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: fontRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.opt.appearanceBodyFont = modelData === "System default" ? "" : modelData;
                                        fontList.visible = false;
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: displayFontPicker
                        visible: win.category === 3
                        width: parent.width
                        height: displayFontList.visible ? 174 : 42
                        radius: Theme.radiusMedium
                        color: Theme.panelCard
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: displayFontField.verticalCenter
                            text: "Display font"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                        }
                        Rectangle {
                            id: displayFontField
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 6
                            anchors.rightMargin: 8
                            width: 170
                            height: 30
                            radius: Theme.radiusSmall
                            color: Theme.panelCardHi
                            Text {
                                font.family: Theme.displayFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: displayFontArrow.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.appearanceDisplayFont || "System default"
                                color: Theme.text
                                font.pixelSize: Theme.fontPx(11)
                                elide: Text.ElideRight
                            }
                            Text {
                                id: displayFontArrow
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: displayFontList.visible ? "expand_less" : "expand_more"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 15
                                color: Theme.secondaryText
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: displayFontList.visible = !displayFontList.visible
                            }
                        }
                        ListView {
                            id: displayFontList
                            visible: false
                            anchors.top: displayFontField.bottom
                            anchors.left: displayFontField.left
                            anchors.right: displayFontField.right
                            anchors.topMargin: 4
                            height: 126
                            clip: true
                            model: win.installedFonts
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                required property string modelData
                                width: ListView.view.width
                                height: 30
                                radius: 6
                                color: displayFontRow.containsMouse ? Theme.panelCardHi : "transparent"
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.text
                                    font.family: modelData === "System default" ? Theme.displayFontFamily : modelData
                                    font.pixelSize: Theme.fontPx(11)
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: displayFontRow
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Config.opt.appearanceDisplayFont = modelData === "System default" ? "" : modelData;
                                        displayFontList.visible = false;
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Shape & depth"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Spacing unit"; from: 2; to: 8; value: Config.appearanceSpacingUnit; onMoved: v => Config.opt.appearanceSpacingUnit = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Small radius"; from: 0; to: 24; value: Config.appearanceSmallRadius; onMoved: v => Config.opt.appearanceSmallRadius = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Medium radius"; from: 0; to: 32; value: Config.appearanceMediumRadius; onMoved: v => Config.opt.appearanceMediumRadius = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Large radius"; from: 0; to: 40; value: Config.appearanceLargeRadius; onMoved: v => Config.opt.appearanceLargeRadius = v }
                    ToggleRow {
                        visible: win.category === 3
                        width: parent.width
                        label: "Screen corners"
                        checked: Config.appearanceScreenCorners
                        onToggled: Config.opt.appearanceScreenCorners = !Config.appearanceScreenCorners
                    }
                    PxSlider { visible: win.category === 3 && Config.appearanceScreenCorners; width: parent.width; label: "Screen corner radius"; from: 0; to: 32; value: Config.appearanceScreenCornerRadius; onMoved: v => Config.opt.appearanceScreenCornerRadius = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Icon size"; from: 12; to: 32; value: Config.appearanceIconSize; onMoved: v => Config.opt.appearanceIconSize = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Icon stroke"; from: 1; to: 20; value: Config.appearanceIconStroke; unit: ""; onMoved: v => Config.opt.appearanceIconStroke = v }

                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Surfaces & ink"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Surface lift"; from: 0; to: 20; value: Config.appearanceSurfaceLift; unit: "%"; onMoved: v => Config.opt.appearanceSurfaceLift = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Divider strength"; from: 0; to: 100; value: Config.appearanceDividerStrength; unit: "%"; onMoved: v => Config.opt.appearanceDividerStrength = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Secondary text"; from: 0; to: 100; value: Config.appearanceSecondaryText; unit: "%"; onMoved: v => Config.opt.appearanceSecondaryText = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Tertiary text"; from: 0; to: 100; value: Config.appearanceTertiaryText; unit: "%"; onMoved: v => Config.opt.appearanceTertiaryText = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Hover fill"; from: 0; to: 30; value: Config.appearanceHoverFill; unit: "%"; onMoved: v => Config.opt.appearanceHoverFill = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Selected fill"; from: 0; to: 30; value: Config.appearanceSelectedFill; unit: "%"; onMoved: v => Config.opt.appearanceSelectedFill = v }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Modal dim"; from: 0; to: 90; value: Config.appearanceModalDim; unit: "%"; onMoved: v => Config.opt.appearanceModalDim = v }

                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Shadow"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Opacity"; from: 0; to: 100; value: Config.appearanceShadowOpacity; unit: "%"; onMoved: v => { Config.opt.appearanceShadowOpacity = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Blur"; from: 0; to: 100; value: Config.appearanceShadowBlur; unit: "%"; onMoved: v => { Config.opt.appearanceShadowBlur = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Vertical offset"; from: 0; to: 30; value: Config.appearanceShadowOffset; onMoved: v => { Config.opt.appearanceShadowOffset = v; WindowShadowSync.scheduleSync(); } }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Spread"; from: 0; to: 450; value: Config.appearanceShadowSpread; onMoved: v => { Config.opt.appearanceShadowSpread = v; WindowShadowSync.scheduleSync(); } }
                    Text {
                        font.family: Theme.bodyFontFamily
                        visible: win.category === 3
                        width: parent.width
                        text: "Wallpaper"
                        color: Theme.text
                        font.pixelSize: Theme.fontPx(11)
                    }
                    PxSlider { visible: win.category === 3; width: parent.width; label: "Wallpaper crossfade"; from: 0; to: 1000; value: Config.appearanceWallpaperCrossfade; unit: "ms"; onMoved: v => Config.opt.appearanceWallpaperCrossfade = v }

                    // ---- Otras categorías (placeholder) ----
                    Item {
                        visible: false
                        width: parent.width
                        height: 90
                        Text {
                            font.family: Theme.bodyFontFamily
                            anchors.centerIn: parent
                            text: "Próximamente"
                            color: Theme.tertiaryText
                            font.pixelSize: Theme.fontPx(13)
                        }
                    }
                }
            }
        }
    }

    // ===================== Sub-componentes =====================

    component NavItem: Rectangle {
        id: nav
        property string iconName: ""
        property string label: ""
        property bool active: false
        signal clicked

        height: 40
        radius: Theme.radiusMedium
        color: active ? Theme.panelCard : (navMouse.containsMouse ? Qt.tint(Theme.panelCard, Theme.hoverFill) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        Rectangle {
            id: ic
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 13
            color: nav.active ? Theme.green : Theme.panelCardHi
            Text {
                anchors.centerIn: parent
                text: nav.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(15)
                font.weight: Theme.iconWeight
                color: nav.active ? Theme.islandBg : Theme.secondaryText
            }
        }
        Text {
            font.family: Theme.bodyFontFamily
            anchors.left: ic.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.active ? "#ffffff" : Theme.text
            font.pixelSize: Theme.fontPx(15)
            font.bold: nav.active
        }
        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    component NavArrow: Rectangle {
        id: arrow
        property string glyph: ""
        signal clicked
        width: 28
        height: 28
        radius: Theme.radiusSmall
        color: aMouse.containsMouse ? Qt.tint(Theme.panelCardHi, Theme.hoverFill) : Theme.panelCard
        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: Theme.iconPx(16)
            font.weight: Theme.iconWeight
            color: Theme.secondaryText
        }
        MouseArea {
            id: aMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }

    // Fila con opciones en píldoras (una elegida)
    component ChoiceRow: Rectangle {
        id: cr
        property string label: ""
        property var options: [] // [{value, label}]
        property string current: ""
        signal picked(string value)
        height: crCol.implicitHeight + 24
        radius: Theme.radiusMedium
        color: Theme.panelCard
        Column {
            id: crCol
            x: 16
            y: 12
            width: cr.width - 32
            spacing: 10
            Text {
                text: cr.label
                color: "#ffffff"
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(14)
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: cr.options
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool on: cr.current === modelData.value
                        width: chipText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: on ? Theme.green : (chipMouse.containsMouse ? Theme.panelCardHi : Qt.rgba(1, 1, 1, 0.04))
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: chip.on ? Theme.crust : Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(11)
                            font.bold: chip.on
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!chip.on) cr.picked(chip.modelData.value)
                        }
                    }
                }
            }
        }
    }

    component ToggleRow: Rectangle {
        id: tr
        property string label: ""
        property bool checked: false
        signal toggled

        height: 48
        radius: Theme.radiusMedium
        color: Theme.panelCard

        Text {
            font.family: Theme.bodyFontFamily
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(14)
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: 12
            color: tr.checked ? Theme.green : Theme.panelCardHi
            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }
            Rectangle {
                width: 18
                height: 18
                radius: 9
                anchors.verticalCenter: parent.verticalCenter
                x: tr.checked ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x {
                    NumberAnimation {
                        duration: Theme.movementDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tr.toggled()
            }
        }
    }

    component PxSlider: Rectangle {
        id: ps
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        property string unit: "px"
        signal moved(int v)

        height: 58
        radius: Theme.radiusMedium
        color: Theme.panelCard

        Text {
            font.family: Theme.bodyFontFamily
            id: pl
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 14
            text: ps.label
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(14)
        }
        Text {
            font.family: Theme.bodyFontFamily
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 14
            text: ps.unit === "" ? ("" + ps.value) : (ps.value + " " + ps.unit)
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(13)
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: pl.bottom
            anchors.topMargin: 12
            height: 4
            radius: 2
            color: Theme.panelCardHi

            Rectangle {
                id: fillr
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: 2
                width: parent.width * (ps.value - ps.from) / Math.max(1, ps.to - ps.from)
                color: Theme.green
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fillr.width - width / 2))
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -18
                anchors.bottomMargin: -18
                cursorShape: Qt.PointingHandCursor
                function setX(mx) {
                    const r = Math.max(0, Math.min(1, mx / track.width));
                    ps.moved(Math.round(ps.from + r * (ps.to - ps.from)));
                }
                onPressed: mouse => setX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setX(mouse.x);
                }
            }
        }
    }
}
