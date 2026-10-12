pragma ComponentBehavior: Bound
// Diseño "island": Dynamic Island estilo iPhone.
// Una ventana por pantalla. Estados: idle (compacto), expanded (hover) y
// peeks contextuales transitorios (media / volume / notif).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../common"
import "../services"

PanelWindow {
    id: win

    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 230
    WlrLayershell.layer: WlrLayer.Top
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
        y: Config.topMargin

        property bool ready: false
        property bool hovered: false
        property string peek: "" // "", "media", "volume", "notif"

        // Modo efectivo: hover manda; si no, un peek activo; si no, idle
        readonly property string mode: hovered ? "expanded" : (peek !== "" ? peek : "idle")

        // Datos del peek de notificación
        property string notifApp: ""
        property string notifText: ""

        // Estado del dashboard (expandido)
        property bool nightLight: false
        property bool gameMode: false
        property real mediaPos: 0

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
            peekTimer.interval = name === "notif" ? 4500 : (name === "media" ? 3000 : 1400);
            peekTimer.restart();
        }

        Timer {
            id: peekTimer
            onTriggered: island.peek = ""
        }

        // Tamaños por modo
        width: mode === "expanded" ? 820 : mode === "notif" ? 430 : mode === "media" ? 370 : mode === "volume" ? 300 : 300
        height: mode === "expanded" ? 190 : mode === "notif" ? 74 : mode === "media" ? 58 : mode === "volume" ? 42 : 30

        Behavior on width {
            NumberAnimation {
                duration: 480
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 480
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
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
            target: Notifs
            function onReceived(appName: string, summary: string, body: string): void {
                island.notifApp = appName;
                island.notifText = summary || body;
                island.showPeek("notif");
            }
        }

        // ================= Píldora =================
        Rectangle {
            id: pill
            anchors.fill: parent
            radius: island.mode === "expanded" ? 26 : height / 2
            color: Theme.islandBg
            border.color: Theme.islandBorder
            border.width: 1

            Behavior on radius {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            // ---------- idle (compacto) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 14
                opacity: island.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                    }
                }

                // Izquierda: workspaces + puntos de estado (pegados a la hora)
                Row {
                    anchors.right: clockText.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    WsRow {
                        barWidth: 7
                        baseLen: 7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Punto verde: reproduciendo
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.green
                        visible: Media.isPlaying
                    }
                    // Punto rojo: micro silenciado
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.red
                        visible: Audio.micMuted
                    }
                }

                // Centro: hora
                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                // Derecha: wifi + batería (pegados a la hora)
                Row {
                    anchors.left: clockText.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Señal de red (3 barras)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Rectangle {
                            width: 3
                            height: 5
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: Net.online ? Theme.green : Theme.surface1
                        }
                        Rectangle {
                            width: 3
                            height: 8
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: Net.online ? Theme.green : Theme.surface1
                        }
                        Rectangle {
                            width: 3
                            height: 11
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: Net.online ? Theme.green : Theme.surface1
                        }
                    }

                    // Batería (cápsula verde, sin %)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Battery.available
                        width: 26
                        height: 13
                        radius: 6.5
                        color: Theme.surface1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: Math.max(parent.height, parent.width * Battery.percent / 100)
                            radius: parent.radius
                            color: Battery.percent <= 20 && !Battery.charging ? Theme.red : Theme.green
                        }
                    }
                }
            }

            // ---------- expanded (hover): dashboard ----------
            Item {
                anchors.fill: parent
                anchors.margins: 18
                opacity: island.mode === "expanded" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                // ===== Zona superior: 3 columnas =====
                Item {
                    id: topArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    // --- Izquierda: Desktop (workspaces verticales) ---
                    Column {
                        id: leftCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: 100
                        spacing: 6

                        Text {
                            text: "Desktop"
                            color: Theme.subtext
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Repeater {
                            model: Config.workspaceCount
                            delegate: Item {
                                id: dw
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                                width: leftCol.width
                                height: 17

                                Rectangle {
                                    id: dwBar
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: dw.focused ? 15 : (dw.occupied ? 11 : 7)
                                    radius: 2
                                    color: dw.focused ? Theme.green : (dw.occupied ? Theme.overlay2 : Theme.surface1)
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                                Text {
                                    anchors.left: dwBar.right
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: dw.wsId
                                    color: dw.focused ? "#ffffff" : (dw.occupied ? Theme.text : Theme.overlay0)
                                    font.pixelSize: 13
                                    font.bold: dw.focused
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + dw.wsId)
                                }
                            }
                        }
                    }

                    // --- Centro: reloj + calendario ---
                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: "#ffffff"
                            font.pixelSize: 32
                            font.bold: true
                        }
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: calRow.width
                            height: calRow.height

                            Row {
                                id: calRow
                                spacing: 8
                                Repeater {
                                    model: 5
                                    delegate: Column {
                                        id: cal
                                        required property int index
                                        readonly property date d: {
                                            const b = new Date(clock.date);
                                            b.setDate(b.getDate() + (index - 2));
                                            return b;
                                        }
                                        readonly property bool today: index === 2
                                        readonly property bool weekend: d.getDay() === 0 || d.getDay() === 6
                                        spacing: 2
                                        width: 30

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: cal.today ? ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"][cal.d.getDay()] : ["D", "L", "M", "X", "J", "V", "S"][cal.d.getDay()]
                                            color: cal.today ? Theme.green : (cal.weekend ? Theme.red : Theme.overlay0)
                                            font.pixelSize: 10
                                            font.bold: cal.today
                                        }
                                        Item {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 30
                                            height: 24
                                            Text {
                                                anchors.centerIn: parent
                                                text: cal.d.getDate()
                                                color: cal.today ? Theme.green : (cal.weekend ? Theme.red : Theme.text)
                                                font.pixelSize: cal.today ? 19 : 13
                                                font.bold: cal.today
                                            }
                                        }
                                    }
                                }
                            }

                            // Desvanecido en los lados (los días lejanos se difuminan)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 34
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: Theme.islandBg
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "transparent"
                                    }
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 34
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: "transparent"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: Theme.islandBg
                                    }
                                }
                            }
                        }
                    }

                    // --- Derecha: Status ---
                    Column {
                        id: rightCol
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: 200
                        spacing: 4

                        Text {
                            text: "Status"
                            color: Theme.subtext
                            font.pixelSize: 12
                            font.bold: true
                        }
                        StatusRow {
                            glyph: Battery.charging ? "battery_charging_full" : "battery_full"
                            glyphColor: Theme.green
                            value: Battery.percent + "%"
                            label: Battery.charging ? "plugged in" : "on battery"
                        }
                        StatusRow {
                            glyph: "wifi"
                            glyphColor: Net.online ? Theme.green : Theme.overlay0
                            value: Net.type === "wifi" ? Net.name : (Net.type === "ethernet" ? "Ethernet" : "Sin red")
                            label: ""
                        }
                        StatusRow {
                            glyph: "bluetooth"
                            glyphColor: Bluetooth.enabled ? Theme.blue : Theme.overlay0
                            value: Bluetooth.enabled ? "on" : "off"
                            label: ""
                        }
                        StatusRow {
                            glyph: Audio.micMuted ? "mic_off" : "mic"
                            glyphColor: Audio.micMuted ? Theme.red : Theme.green
                            value: Math.round(Audio.micVolume * 100) + "%"
                            label: Audio.micMuted ? "mic off" : "mic on"
                        }
                        StatusRow {
                            glyph: "notifications"
                            glyphColor: Theme.subtext
                            value: Notifs.count > 0 ? ("" + Notifs.count) : "No"
                            label: "notifications"
                        }
                        Row {
                            spacing: 6
                            topPadding: 2
                            PillButton {
                                glyph: "dark_mode"
                                label: "Night light"
                                on: island.nightLight
                                onToggled: {
                                    island.nightLight = !island.nightLight;
                                    Hyprland.dispatch("exec " + (island.nightLight ? "hyprsunset -t 4000" : "pkill hyprsunset"));
                                }
                            }
                            PillButton {
                                glyph: "sports_esports"
                                label: "Game mode"
                                on: island.gameMode
                                onToggled: island.gameMode = !island.gameMode
                            }
                        }
                    }
                }

                // ===== Reproductor (abajo-centro, bajo el calendario) =====
                Row {
                    id: mediaRow
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    // Carátula
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 9
                        color: Theme.surface0
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
                            px: 17
                            color: Theme.overlay0
                            visible: !(Media.active?.trackArtUrl)
                        }
                    }

                    // Título + artista
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        spacing: 0

                        Text {
                            width: parent.width
                            text: Media.title || "Sin reproducción"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: Media.artist
                            color: Theme.subtext
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            visible: Media.artist !== ""
                        }
                    }

                    // Progreso: tiempo · barra · tiempo
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: island.fmt(island.mediaPos)
                            color: Theme.subtext
                            font.pixelSize: 9
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            height: 4
                            radius: 2
                            color: Theme.surface0

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height
                                radius: 2
                                width: parent.width * (Media.active && Media.active.length > 0 ? Math.min(1, island.mediaPos / Media.active.length) : 0)
                                color: Theme.green
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: island.fmt(Media.active?.length ?? 0)
                            color: Theme.subtext
                            font.pixelSize: 9
                        }
                    }

                    // Controles
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        IslandButton {
                            glyph: "skip_previous"
                            useIconFont: true
                            size: 22
                            onTapped: Media.prev()
                        }
                        IslandButton {
                            glyph: Media.isPlaying ? "pause" : "play_arrow"
                            useIconFont: true
                            size: 22
                            onTapped: Media.toggle()
                        }
                        IslandButton {
                            glyph: "skip_next"
                            useIconFont: true
                            size: 22
                            onTapped: Media.next()
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
                        duration: 160
                    }
                }

                Rectangle {
                    id: mediaDot
                    width: 10
                    height: 10
                    radius: 5
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Media.isPlaying ? Theme.green : Theme.overlay0
                }

                Column {
                    anchors.left: mediaDot.right
                    anchors.leftMargin: 10
                    anchors.right: mediaControls.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        text: Media.title || "Sin reproducción"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Media.artist
                        color: Theme.subtext
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        visible: Media.artist !== ""
                    }
                }

                Row {
                    id: mediaControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

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
                        duration: 120
                    }
                }

                Text {
                    id: volIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.muted ? "🔇" : "🔊"
                    font.pixelSize: 14
                }
                Rectangle {
                    anchors.left: volIcon.right
                    anchors.right: volPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Theme.surface0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, Audio.volume)
                        radius: 3
                        color: Audio.muted ? Theme.overlay0 : Theme.sapphire
                    }
                }
                Text {
                    id: volPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Audio.volume * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: 12
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
                        duration: 160
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
                        width: parent.width
                        text: island.notifApp || "Notificación"
                        color: Theme.mauve
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: island.notifText
                        color: "#ffffff"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Hover: expande (NoButton => no roba los clics a los botones internos)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
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
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsCell.wsId)
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
            text: parent.label
            color: Theme.subtext
            font.pixelSize: 10
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
        font.family: "Material Symbols Rounded"
        font.pixelSize: px
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
            text: parent.value
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: parent.label
            color: Theme.subtext
            font.pixelSize: 12
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
                color: parent.parent.on ? Theme.yellow : Theme.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: parent.parent.label
                color: Theme.text
                font.pixelSize: 11
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
