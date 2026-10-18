pragma ComponentBehavior: Bound
// Diseño "island": Dynamic Island estilo iPhone.
// Una ventana por pantalla. Estados: idle (compacto), expanded (hover) y
// peeks contextuales transitorios (media / volume / notif).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../common"
import "../services"

PanelWindow {
    id: win

    // Fuente oficial actualizada: incluye los glifos de batería con sufijo _2.
    FontLoader {
        id: batterySymbols
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SalchipapaShell/MaterialSymbolsOutlined.ttf"
    }

    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 620
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (Overlay.mode !== "" || island.showPolkit) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 34 + Config.topMargin

    // Solo la píldora captura el ratón; el resto deja pasar los clics
    mask: Region {
        x: island.x
        y: island.y
        width: island.width
        height: island.height
    }

    Item {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        // Notch: pegado al borde superior (el -2 mete el borde de 1px fuera de pantalla para
        // que el cuerpo del pill bese el borde sin dejar línea). Pill: flotando con el gap.
        y: Config.notchMode ? -2 : Config.topMargin
        Behavior on y {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.OutCubic
            }
        }

        property bool ready: false
        property bool hovered: false
        property string peek: "" // "", "media", "volume", "notif"
        readonly property bool showPolkit: PolicyAuth.active && (Hyprland.focusedMonitor?.name ? Hyprland.focusedMonitor.name === win.screen?.name : Quickshell.screens[0] === win.screen)

        // Una notificación nueva también debe verse si el dashboard está abierto.
        // El resto de overlays conserva prioridad sobre los peeks normales.
        readonly property string mode: showPolkit ? "polkit" : (peek === "notif" ? "notif" : (Overlay.mode !== "" ? Overlay.mode : (hovered ? "expanded" : (peek !== "" ? peek : "idle"))))
        readonly property string batteryGlyph: Battery.charging ? (Battery.percent >= 95 ? "battery_charging_full_2" : Battery.percent >= 65 ? "battery_charging_80_2" : Battery.percent >= 35 ? "battery_charging_50_2" : "battery_charging_20_2") : Battery.percent >= 95 ? "battery_android_full" : Battery.percent >= 80 ? "battery_android_6" : Battery.percent >= 65 ? "battery_android_5" : Battery.percent >= 50 ? "battery_android_4" : Battery.percent >= 35 ? "battery_android_3" : Battery.percent >= 20 ? "battery_android_2" : Battery.percent >= 5 ? "battery_android_1" : "battery_android_0"
        readonly property string networkGlyph: Net.type === "ethernet" ? "lan" : Net.type === "wifi" ? (Net.wifiSignal >= 80 ? "signal_wifi_4_bar" : Net.wifiSignal >= 60 ? "network_wifi_3_bar" : Net.wifiSignal >= 35 ? "network_wifi_2_bar" : Net.wifiSignal >= 10 ? "network_wifi_1_bar" : "signal_wifi_0_bar") : "wifi_off"

        // Notch: fondo negro + alas laterales. Solo en reposo/peeks (no expandido/overlay).
        readonly property color notchBg: Theme.panelBg
        readonly property bool notchResting: Config.notchMode && (mode === "idle" || mode === "media" || mode === "volume" || mode === "brightness" || mode === "notif")

        // ¿Hay un scratchpad (workspace especial) mostrándose ahora?
        readonly property bool inSpecial: (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "") !== ""

        // Datos del peek de notificación
        property string notifApp: ""
        property string notifText: ""
        property bool notifUrgent: false

        // Estado del dashboard (expandido). Night light / Game mode viven en Quick (compartidos
        // con el centro de control).
        property real mediaPos: 0
        property var calendarMonth: new Date()
        property var selectedDate: new Date()
        readonly property var calendarMonthDate: new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1)
        readonly property int calendarFirstDayOffset: (calendarMonthDate.getDay() - Config.clockWeekStart + 7) % 7
        readonly property int calendarDaysInMonth: new Date(calendarMonthDate.getFullYear(), calendarMonthDate.getMonth() + 1, 0).getDate()

        function fmt(s: real): string {
            s = Math.max(0, Math.floor(s));
            const m = Math.floor(s / 60);
            const sec = s % 60;
            return m + ":" + (sec < 10 ? "0" + sec : sec);
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: island.mediaPos = Media.active?.position ?? 0
        }

        Component.onCompleted: ready = true

        function showPeek(name: string): void {
            peek = name;
            peekTimer.interval = name === "notif" ? (notifUrgent ? Config.notificationUrgentTimeout : Config.notificationPopupTimeout) : (name === "volume" || name === "brightness") ? Config.osdOnScreenTime : (name === "media" ? 3000 : 1400);
            peekTimer.restart();
        }

        Timer {
            id: peekTimer
            onTriggered: island.peek = ""
        }

        // Tamaños por modo
        width: mode === "polkit" ? 370 : mode === "control" ? 440 : mode === "display" ? 460 : mode === "sound" ? 420 : mode === "launcher" ? Config.launcherWidth : mode === "themes" ? 720 : mode === "wallpaper" ? 760 : mode === "calendar" ? 300 : mode === "expanded" ? 500 : mode === "notif" ? Config.notificationWidth : mode === "media" ? 370 : mode === "volume" || mode === "brightness" ? 300 : Math.max(Config.collapsedWidth, idleRow.implicitWidth + Config.innerPadding * 2)
        height: mode === "polkit" ? 250 : mode === "control" ? Math.max(470, 350 + Config.notificationHistoryHeight) : mode === "display" ? (142 + (Hyprland.monitors?.values?.length ?? 1) * 206) : mode === "sound" ? (213 + Math.min(Audio.sinks?.length ?? 1, 5) * 42 + Math.min(Audio.sources?.length ?? 1, 4) * 42 + Math.max(1, Math.min(Audio.apps?.length ?? 0, 4)) * 62) : mode === "launcher" ? (85 + Config.launcherRowsBeforeScrolling * Config.launcherRowHeight + (Config.launcherRowsBeforeScrolling - 1) * 2) : mode === "themes" ? 210 : mode === "wallpaper" ? 250 : mode === "calendar" ? 250 : mode === "expanded" ? 116 : mode === "notif" ? 74 : mode === "media" ? 58 : mode === "volume" || mode === "brightness" ? 42 : Config.barHeight

        Behavior on width {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }

        SystemClock {
            id: clock
            precision: Config.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        // --- Disparadores de peeks contextuales ---
        Connections {
            target: Audio
            function onVolumeChanged(): void {
                if (island.ready)
                    island.showPeek("volume");
            }
            function onMutedChanged(): void {
                if (island.ready)
                    island.showPeek("volume");
            }
        }
        Connections {
            target: Media
            function onTitleChanged(): void {
                if (island.ready && Media.hasPlayer)
                    island.showPeek("media");
            }
        }
        Connections {
            target: Brightness
            function onValueChanged(): void {
                if (island.ready && Brightness.available)
                    island.showPeek("brightness");
            }
        }
        Connections {
            target: Notifs
            function onReceived(appName: string, summary: string, body: string, urgent: bool): void {
                if (Quick.silenced) // Focus / Game mode: no molestar
                    return;
                island.notifApp = appName;
                island.notifText = Config.notificationShowBody && body.length > 0 ? (summary.length > 0 ? summary + "\n" + body : body) : summary;
                island.notifUrgent = urgent;
                island.showPeek("notif");
            }
        }

        // ================= Píldora =================
        Item {
            id: pillShadow
            // Match Hyprland's effective pixel range and leave room for its offset.
            readonly property int pad: Math.max(2, WindowShadowSync.quickshellRange * 2 + Math.abs(Config.appearanceShadowOffset) + 2)
            x: -pad
            y: -pad
            width: island.width + pad * 2
            height: island.height + pad * 2
            layer.enabled: !Config.gameMode && WindowShadowSync.quickshellBlurRadius > 0 && WindowShadowSync.quickshellOpacity > 0
            layer.effect: MultiEffect {
                shadowEnabled: !Config.gameMode && WindowShadowSync.quickshellBlurRadius > 0 && WindowShadowSync.quickshellOpacity > 0
                shadowColor: Theme.shadow
                shadowOpacity: WindowShadowSync.quickshellOpacity
                // blurMax is the radius; use the already-combined range once.
                shadowBlur: WindowShadowSync.quickshellBlur
                blurMax: Math.max(2, WindowShadowSync.quickshellRange)
                shadowVerticalOffset: Config.appearanceShadowOffset
                // pillShadow.pad provides explicit padding, including offset.
                autoPaddingEnabled: false
            }

            Rectangle {
                x: pillShadow.pad
                y: pillShadow.pad
                width: pillShadow.width - pillShadow.pad * 2
                height: pillShadow.height - pillShadow.pad * 2
                readonly property real uni: (island.mode === "polkit" || island.mode === "expanded" || island.mode === "calendar" || island.mode === "launcher" || island.mode === "themes" || island.mode === "wallpaper" || island.mode === "control" || island.mode === "display" || island.mode === "sound") ? Theme.radiusLarge : (Config.notchMode ? Theme.radiusMedium : height / 2)
                topLeftRadius: Config.notchMode ? 0 : uni
                topRightRadius: Config.notchMode ? 0 : uni
                bottomLeftRadius: uni
                bottomRightRadius: uni
                color: Config.notchMode ? island.notchBg : Theme.islandBg

                NotchWing {
                    anchors.right: parent.left
                    anchors.top: parent.top
                    size: 24
                    fill: island.notchBg
                    mirror: true
                    visible: Config.notchMode
                }
                NotchWing {
                    anchors.left: parent.right
                    anchors.top: parent.top
                    size: 24
                    fill: island.notchBg
                    mirror: false
                    visible: Config.notchMode
                }
            }
        }
        Rectangle {
            id: pill
            anchors.fill: parent
            // Radio base (uniforme). En notch, las esquinas superiores van rectas (pegadas al borde).
            readonly property real uni: (island.mode === "polkit" || island.mode === "expanded" || island.mode === "calendar" || island.mode === "launcher" || island.mode === "themes" || island.mode === "wallpaper" || island.mode === "control" || island.mode === "display" || island.mode === "sound") ? Theme.radiusLarge : (Config.notchMode ? Theme.radiusMedium : height / 2)
            topLeftRadius: Config.notchMode ? 0 : uni
            topRightRadius: Config.notchMode ? 0 : uni
            bottomLeftRadius: uni
            bottomRightRadius: uni
            color: Config.notchMode ? island.notchBg : Theme.islandBg
            border.color: Theme.islandBorder
            border.width: Config.notchMode ? 0 : 1

            Behavior on topLeftRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on topRightRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on bottomLeftRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on bottomRightRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }

            // Alas laterales cóncavas: funden el notch con el borde superior de la pantalla
            NotchWing {
                anchors.right: parent.left
                anchors.top: parent.top
                size: 24
                fill: island.notchBg
                mirror: true
                visible: Config.notchMode
            }
            NotchWing {
                anchors.left: parent.right
                anchors.top: parent.top
                size: 24
                fill: island.notchBg
                mirror: false
                visible: Config.notchMode
            }

            // ---------- idle (compacto) ----------
            Item {
                anchors.fill: parent
                opacity: island.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                // Fila centrada: la píldora se ajusta a su ancho (ver island.width)
                Row {
                    id: idleRow
                    anchors.centerIn: parent
                    spacing: 14

                    // Izquierda: workspaces + estado
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: !Quick.gameMode && PowerProfiles.mode === "balanced"

                        // Glow en el color principal sobre los indicadores (solo en notch)
                        layer.enabled: Config.notchMode && !Config.gameMode
                        layer.effect: MultiEffect {
                            shadowEnabled: !Config.gameMode
                            shadowColor: Theme.green
                            shadowBlur: 1.0
                            blurMax: 18
                            shadowOpacity: 0.8
                            autoPaddingEnabled: true
                        }

                        WsRow {
                            barWidth: 7
                            baseLen: 7
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.clockShowWorkspaceDots && !island.inSpecial // ocultar ws normales si estás en un scratchpad
                        }
                        // Scratchpads activos (música/comms/sysmon…)
                        SpecialRow {
                            cell: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.green
                            visible: Media.isPlaying
                        }
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.red
                            visible: Audio.micMuted
                        }
                    }

                    // Hora
                    Text {
                            font.family: Theme.displayFontFamily
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, Config.clock24Hour ? (Config.clockShowSeconds ? "HH:mm:ss" : "HH:mm") : (Config.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(16)
                        font.bold: true
                        visible: !Quick.gameMode && PowerProfiles.mode === "balanced"
                    }

                    // Indicador persistente para que Game Mode siga visible
                    // cuando la isla vuelve a su estado compacto.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: Quick.gameMode || PowerProfiles.mode !== "balanced"

                        Icon {
                            text: Quick.gameMode ? "sports_esports" : PowerProfiles.mode === "turbo" ? "rocket_launch" : PowerProfiles.mode === "silent" ? "volume_off" : "speed"
                            px: 18
                            color: Quick.gameMode ? Theme.yellow : PowerProfiles.mode === "turbo" ? Theme.peach : PowerProfiles.mode === "silent" ? Theme.blue : Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: Quick.gameMode ? "GAME MODE" : PowerProfiles.mode === "turbo" ? "TURBO" : PowerProfiles.mode === "silent" ? "SILENCIOSO" : "RENDIMIENTO"
                            color: Quick.gameMode ? Theme.yellow : PowerProfiles.mode === "turbo" ? Theme.peach : PowerProfiles.mode === "silent" ? Theme.blue : Theme.green
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Derecha: wifi + batería
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        visible: Config.clockShowBatteryWifi && !Quick.gameMode && PowerProfiles.mode === "balanced"

                        // Glow en el color principal sobre wifi/batería (solo en notch)
                        layer.enabled: Config.notchMode && !Config.gameMode
                        layer.effect: MultiEffect {
                            shadowEnabled: !Config.gameMode
                            shadowColor: Theme.green
                            shadowBlur: 1.0
                            blurMax: 18
                            shadowOpacity: 0.8
                            autoPaddingEnabled: true
                        }

                        Icon {
                            text: island.networkGlyph
                            iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                            px: 18
                            color: Net.online ? Theme.green : Theme.surface1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Battery.available
                            spacing: 4

                            Icon {
                                text: island.batteryGlyph
                                iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                                px: 22
                                color: Theme.green
                            }

                            Text {
                                visible: Config.clockShowBatteryPercent
                                text: Battery.percent + "%"
                                color: Theme.text
                                font.family: Theme.displayFontFamily
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: 600
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // ---------- expanded (hover): isla compacta horizontal ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                opacity: island.mode === "expanded" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }

                // Marca y escritorios a la izquierda.
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    visible: Config.clockExpandedWorkspaces

                    Row {
                        spacing: 5
                        Icon {
                            text: "terminal"
                            px: 13
                            color: Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            text: "Quickshell"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(12)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    WsRow {
                        barWidth: 7
                        baseLen: 8
                        visible: Config.clockShowWorkspaceDots && !island.inSpecial
                    }
                    SpecialRow {
                        cell: 13
                    }
                }

                // Hora y fecha centradas, con el reproductor debajo.
                Column {
                    anchors.centerIn: parent
                    spacing: 7

                    Item {
                        id: clockDateTarget
                        width: clockDateRow.implicitWidth
                        height: clockDateRow.implicitHeight

                        Row {
                            id: clockDateRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                font.family: Theme.displayFontFamily
                                text: Qt.formatDateTime(clock.date, Config.clock24Hour ? (Config.clockShowSeconds ? "HH:mm:ss" : "HH:mm") : (Config.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(18)
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                font.family: Theme.bodyFontFamily
                                text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                                color: Theme.secondaryText
                                font.pixelSize: Theme.fontPx(11)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                island.calendarMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
                                island.selectedDate = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
                                Overlay.mode = "calendar";
                            }
                        }
                    }

                    Rectangle {
                        width: 194
                        height: 39
                        radius: 13
                        color: Theme.surface0
                        visible: Config.clockExpandedMedia

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 9
                            spacing: 7

                            Rectangle {
                                width: 27
                                height: 27
                                radius: 8
                                color: Theme.surface1
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: Media.active?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    px: 14
                                    color: Theme.green
                                    visible: !(Media.active?.trackArtUrl)
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 92
                                spacing: 1
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    width: parent.width
                                    text: Media.title || "Sin reproducción"
                                    color: "#ffffff"
                                    font.pixelSize: Theme.fontPx(12)
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    font.family: Theme.bodyFontFamily
                                    width: parent.width
                                    text: Media.artist || Media.album
                                    color: Theme.secondaryText
                                    font.pixelSize: Theme.fontPx(10)
                                    elide: Text.ElideRight
                                }
                            }
                            Item {
                                width: 43
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater {
                                        model: 7
                                        Rectangle {
                                            required property int index
                                            width: 2
                                            height: 2
                                            radius: 1
                                            color: Theme.green
                                            opacity: Media.isPlaying ? 0.35 + ((index % 3) * 0.2) : 0.3
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Media.toggle()
                            cursorShape: Qt.PointingHandCursor
                        }
                        WheelHandler {
                            enabled: Config.mediaScrollToChangeTrack
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                if (event.angleDelta.y > 0) Media.prev();
                                else if (event.angleDelta.y < 0) Media.next();
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Notificaciones y estado de red/energía a la derecha.
                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: Config.clockExpandedStatus

                    Row {
                        anchors.right: parent.right
                        spacing: 5
                        Text {
                            font.family: Theme.bodyFontFamily
                            text: Notifs.count > 0 ? (Notifs.count + " notifications") : "All caught up"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(11)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            text: "notifications"
                            px: 12
                            color: Notifs.count > 0 ? Theme.green : Theme.secondaryText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 7
                        Icon {
                            text: island.networkGlyph
                            iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                            px: 18
                            color: Net.online ? Theme.green : Theme.tertiaryText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            text: island.batteryGlyph
                            iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                            px: 19
                            color: Battery.percent <= 20 && !Battery.charging ? Theme.red : Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ---------- calendario (clic en la fecha) ----------
            Item {
                id: calendarPopup
                anchors.fill: parent
                opacity: island.mode === "calendar" ? 1 : 0
                visible: opacity > 0
                focus: island.mode === "calendar"
                Keys.onEscapePressed: Overlay.close()
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 22
                        spacing: 8
                        IslandButton {
                            glyph: "‹"
                            size: 22
                            onTapped: island.calendarMonth = new Date(island.calendarMonth.getFullYear(), island.calendarMonth.getMonth() - 1, 1)
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            width: parent.width - 60
                            text: Qt.formatDateTime(island.calendarMonthDate, "MMMM yyyy")
                            color: Theme.secondaryText
                            font.pixelSize: Theme.fontPx(14)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        IslandButton {
                            glyph: "›"
                            size: 22
                            onTapped: island.calendarMonth = new Date(island.calendarMonth.getFullYear(), island.calendarMonth.getMonth() + 1, 1)
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 3
                        columnSpacing: 2

                        Repeater {
                            model: 7
                            delegate: Text {
                                required property int index
                                width: (parent.width - 12) / 7
                                height: 20
                                text: ["S", "M", "T", "W", "T", "F", "S"][(index + Config.clockWeekStart) % 7]
                                color: Theme.tertiaryText
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(10)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: calendarCell
                                required property int index
                                readonly property int dayNumber: index - island.calendarFirstDayOffset + 1
                                readonly property bool inMonth: dayNumber >= 1 && dayNumber <= island.calendarDaysInMonth
                                readonly property var cellDate: new Date(island.calendarMonthDate.getFullYear(), island.calendarMonthDate.getMonth(), dayNumber)
                                readonly property bool selected: inMonth && island.selectedDate.getFullYear() === cellDate.getFullYear() && island.selectedDate.getMonth() === cellDate.getMonth() && island.selectedDate.getDate() === cellDate.getDate()
                                width: (parent.width - 12) / 7
                                height: 25
                                radius: 10
                                color: selected ? Theme.green : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: calendarCell.inMonth || Config.clockShowNeighbouringMonths ? calendarCell.cellDate.getDate() : ""
                                    color: calendarCell.selected ? Theme.islandBg : (calendarCell.inMonth ? Theme.secondaryText : Theme.tertiaryText)
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: calendarCell.inMonth || Config.clockShowNeighbouringMonths
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        island.selectedDate = calendarCell.cellDate;
                                        if (!calendarCell.inMonth)
                                            island.calendarMonth = new Date(calendarCell.cellDate.getFullYear(), calendarCell.cellDate.getMonth(), 1);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- media (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "media" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Rectangle {
                    id: mediaDot
                    width: 10
                    height: 10
                    radius: 5
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Media.isPlaying ? Theme.green : Theme.tertiaryText
                }

                Column {
                    anchors.left: mediaDot.right
                    anchors.leftMargin: 10
                    anchors.right: mediaControls.visible ? mediaControls.left : parent.right
                    anchors.rightMargin: mediaControls.visible ? 10 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: Media.title || "Sin reproducción"
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(12)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: Media.album
                        color: Theme.secondaryText
                        font.pixelSize: Theme.fontPx(10)
                        elide: Text.ElideRight
                        visible: Config.mediaShowAlbum && Media.album !== ""
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: Media.artist
                        color: Theme.secondaryText
                        font.pixelSize: Theme.fontPx(10)
                        elide: Text.ElideRight
                        visible: Config.mediaShowArtist && Media.artist !== ""
                    }
                }

                Row {
                    id: mediaControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: Config.mediaShowControls

                    IslandButton {
                        glyph: "◁"
                        onTapped: Media.prev()
                    }
                    IslandButton {
                        glyph: Media.isPlaying ? "❚❚" : "▷"
                        onTapped: Media.toggle()
                    }
                    IslandButton {
                        glyph: "▷|"
                        onTapped: Media.next()
                    }
                }
            }

            // ---------- volume (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "volume" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Text {
                    font.family: Theme.bodyFontFamily
                    id: volIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.muted ? "🔇" : "🔊"
                    font.pixelSize: Theme.fontPx(14)
                }
                Rectangle {
                    anchors.left: volIcon.right
                    anchors.right: volPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: Config.osdLevelBarThickness
                    radius: height / 2
                    color: Theme.surface0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, Audio.volume)
                        radius: height / 2
                        color: Audio.muted ? Theme.tertiaryText : Theme.sapphire
                    }
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    id: volPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Audio.volume * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                }
            }

            // ---------- brightness (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "brightness" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }
                Text {
                    id: brightnessIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "brightness_6"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Theme.fontPx(16)
                    color: Theme.peach
                }
                Rectangle {
                    anchors.left: brightnessIcon.right
                    anchors.right: brightnessPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: Config.osdLevelBarThickness
                    radius: height / 2
                    color: Theme.surface0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, Brightness.value)
                        radius: height / 2
                        color: Theme.peach
                    }
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    id: brightnessPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Brightness.value * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                }
            }

            // ---------- notif (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "notif" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Rectangle {
                    id: notifDot
                    width: 8
                    height: 8
                    radius: 4
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.mauve
                }
                Column {
                    anchors.left: notifDot.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: island.notifApp || "Notificación"
                        color: Theme.mauve
                        font.pixelSize: Theme.fontPx(16)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        font.family: Theme.bodyFontFamily
                        width: parent.width
                        text: island.notifText
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(18)
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ---------- launcher (modo overlay dentro de la isla) ----------
            LauncherContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "launcher" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- themes (selector de temas dentro de la isla) ----------
            ThemeContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "themes" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- wallpaper (selector de fondos dentro de la isla) ----------
            WallpaperContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "wallpaper" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- control (centro de control dentro de la isla) ----------
            ControlContent {
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "control" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- display (ajustes de pantalla) ----------
            DisplayContent {
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "display" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- sound (ajustes de sonido) ----------
            SoundContent {
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "sound" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- solicitud de permisos de administrador (PolicyKit) ----------
            PolkitPrompt {
                anchors.fill: parent
                active: island.showPolkit
                opacity: island.mode === "polkit" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }
            }

            // Hover: expande (NoButton => no roba los clics a los botones internos).
            // Desactivado en modos overlay para que el launcher/temas reciban hover y clics.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: Overlay.mode === ""
                onEntered: island.hovered = true
                onExited: island.hovered = false
            }
        }
    }

    // --- Componentes internos reutilizables ---

    // Workspaces persistentes 1..N como barras de carga VERTICALES (sin número).
    // Activo = barra alta (acento); ocupado = barra media; vacío = corta.
    component WsRow: Row {
        property int barWidth: 6
        property int baseLen: 8 // alto de un ws vacío
        spacing: 6

        Repeater {
            model: Config.workspaceCount
            delegate: Rectangle {
                id: wsCell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                anchors.verticalCenter: parent.verticalCenter
                width: barWidth
                height: wsCell.focused ? baseLen * 2.0 : (wsCell.occupied ? baseLen * 1.7 : baseLen * 1.3)
                radius: width / 2
                color: wsCell.focused ? Theme.green : (wsCell.occupied ? Theme.overlay2 : Theme.surface0)

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.movementDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + wsCell.wsId + "})")
                }
            }
        }
    }

    // Scratchpads activos (workspaces especiales con ventanas): icono por cada uno,
    // resaltado si está mostrándose; clic = mostrar/ocultar (como caelestia).
    component SpecialRow: Row {
        property int cell: 18
        spacing: 4

        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.name.startsWith("special:"))
            delegate: Rectangle {
                id: sp
                required property var modelData
                readonly property string sname: modelData.name.slice(8) // quita "special:"
                // Resaltado si ese scratchpad se está MOSTRANDO en el monitor (se refresca
                // en shell.qml al recibir 'activespecial'; si no, lastIpcObject no es reactivo)
                readonly property bool shown: Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name === modelData.name
                // Colores vivos por app (fijos, para que resalten con cualquier tema)
                readonly property color accent: {
                    switch (sp.sname) {
                    case "music":
                        return "#1ed760"; // verde Spotify
                    case "comms":
                        return "#5865f2"; // azul Discord
                    case "sysmon":
                        return "#fab387"; // melocotón
                    case "magic":
                        return "#cba6f7"; // malva
                    default:
                        return "#89b4fa";
                    }
                }

                width: cell + 6
                height: cell
                radius: height / 2
                color: sp.shown ? sp.accent : Qt.rgba(sp.accent.r, sp.accent.g, sp.accent.b, 0.22)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Text {
                    anchors.centerIn: parent
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(cell * 0.72)
                    color: sp.shown ? Theme.islandBg : sp.accent
                    text: {
                        switch (sp.sname) {
                        case "music":
                            return "music_note";
                        case "comms":
                            return "forum";
                        case "sysmon":
                            return "monitoring";
                        case "magic":
                            return "filter_drama";
                        default:
                            return "star";
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special('" + sp.sname + "')")
                }
            }
        }
    }

    component IslandStat: Row {
        property string label: ""
        property real value: 0
        property color barColor: "#ffffff"
        spacing: 5
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.label
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(10)
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 34
            height: 5
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surface0
            Rectangle {
                anchors.left: parent.left
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, parent.parent.value))
                radius: 3
                color: parent.parent.barColor
            }
        }
    }

    component IslandButton: Rectangle {
        property string glyph: ""
        property bool useIconFont: false
        property int size: 26
        signal tapped
        width: size
        height: size
        radius: size / 2
        color: tapArea.containsMouse ? Theme.surface0 : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: "#ffffff"
            font.pixelSize: parent.useIconFont ? Math.round(parent.size * 0.68) : 12
            font.family: parent.useIconFont ? "Material Symbols Rounded" : Qt.application.font.family
        }
        MouseArea {
            id: tapArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.tapped()
        }
    }

    // Icono (Material Symbols Rounded; el texto es el nombre del icono, ej. "wifi")
    component Icon: Text {
        property real px: 18
        property string iconFontFamily: "Material Symbols Rounded"
        font.family: iconFontFamily
        font.pixelSize: Theme.iconPx(px)
        font.weight: Theme.iconWeight
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
    }

    // Fila del panel Status: icono + valor + etiqueta
    component StatusRow: Row {
        property string glyph: ""
        property string value: ""
        property string label: ""
        property color glyphColor: Theme.text
        spacing: 8
        height: 20

        Icon {
            text: parent.glyph
            color: parent.glyphColor
            px: 17
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.value
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.label
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(12)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Botón tipo píldora (Night light / Game mode)
    component PillButton: Rectangle {
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal toggled

        height: 24
        radius: 12
        implicitWidth: pbRow.implicitWidth + 18
        width: implicitWidth
        color: on ? Theme.surface1 : Theme.surface0

        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                text: parent.parent.glyph
                px: 14
                color: parent.parent.on ? Theme.yellow : Theme.secondaryText
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                font.family: Theme.bodyFontFamily
                text: parent.parent.label
                color: Theme.text
                font.pixelSize: Theme.fontPx(11)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

}
