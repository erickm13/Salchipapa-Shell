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
    implicitHeight: 150
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
        width: mode === "expanded" ? 520 : mode === "notif" ? 430 : mode === "media" ? 370 : mode === "volume" ? 300 : 460
        height: mode === "expanded" ? 112 : mode === "notif" ? 74 : mode === "media" ? 58 : mode === "volume" ? 42 : 30

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
            radius: height / 2
            color: Theme.islandBg
            border.color: Theme.islandBorder
            border.width: 1

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

                // Izquierda: workspaces + puntos de estado
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    WsRow {
                        cell: 18
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
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                // Derecha: wifi + batería
                Row {
                    anchors.right: parent.right
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

                    // Batería (barra + %)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: Battery.available
                        Rectangle {
                            width: 20
                            height: 11
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"
                            border.color: Theme.overlay0
                            border.width: 1
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                height: 7
                                width: Math.max(1, (parent.width - 3) * Battery.percent / 100)
                                radius: 1
                                color: Battery.charging ? Theme.green : (Battery.percent <= 20 ? Theme.red : Theme.text)
                            }
                        }
                        Text {
                            text: Battery.percent + "%"
                            color: Theme.subtext
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ---------- expanded (hover) ----------
            Item {
                anchors.fill: parent
                anchors.margins: 14
                opacity: island.mode === "expanded" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                // Workspaces (arriba-izquierda)
                WsRow {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    cell: 24
                }

                // Reloj (arriba-derecha)
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 3
                    text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                // Título de la ventana activa (centro)
                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    text: Hyprland.activeToplevel?.title ?? "Escritorio"
                    color: Theme.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                // Fila de stats (abajo): batería, red, CPU, RAM, volumen
                Row {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 14

                    // Batería
                    Row {
                        spacing: 4
                        visible: Battery.available
                        Rectangle {
                            width: 20
                            height: 11
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: "transparent"
                            border.color: Theme.overlay0
                            border.width: 1
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                height: 7
                                width: Math.max(1, (parent.width - 3) * Battery.percent / 100)
                                radius: 1
                                color: Battery.charging ? Theme.green : (Battery.percent <= 20 ? Theme.red : Theme.text)
                            }
                        }
                        Text {
                            text: Battery.percent + "%"
                            color: Theme.subtext
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Red
                    Text {
                        text: Net.type === "wifi" ? ("Wi-Fi " + Net.name) : (Net.type === "ethernet" ? "Ethernet" : "Sin red")
                        color: Net.online ? Theme.subtext : Theme.red
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: 120
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // CPU
                    IslandStat {
                        label: "CPU"
                        value: Sys.cpu
                        barColor: Theme.peach
                    }
                    // RAM
                    IslandStat {
                        label: "RAM"
                        value: Sys.mem
                        barColor: Theme.mauve
                    }
                    // Volumen
                    IslandStat {
                        label: Audio.muted ? "MUT" : "VOL"
                        value: Math.min(1, Audio.volume)
                        barColor: Audio.muted ? Theme.overlay0 : Theme.sapphire
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

    // Workspaces persistentes 1..N (siempre visibles; resalta activo y ocupados)
    component WsRow: Row {
        property int cell: 20
        spacing: 4

        Repeater {
            model: Config.workspaceCount
            delegate: Rectangle {
                id: wsCell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                width: wsCell.focused ? cell * 1.4 : cell // el activo un poco más ancho
                height: cell
                radius: cell * 0.3
                color: wsCell.focused ? Theme.blue : (wsCell.occupied ? Theme.surface1 : Theme.surface0)

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsCell.wsId
                    color: wsCell.focused ? Theme.islandBg : (wsCell.occupied ? Theme.text : Theme.overlay0)
                    font.pixelSize: Math.round(cell * 0.55)
                    font.bold: wsCell.focused
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
        signal tapped
        width: 24
        height: 24
        radius: 12
        color: tapArea.containsMouse ? Theme.surface0 : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: "#ffffff"
            font.pixelSize: 12
        }
        MouseArea {
            id: tapArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.tapped()
        }
    }
}
