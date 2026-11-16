// Página de la pantalla de bloqueo: lo que se dibuja en cada monitor (services/LockScreen.qml la
// pone en la superficie de bloqueo) y también en la vista previa (`qs ipc call salchipapa-lock
// preview`, o Ajustes > Lock Screen > Preview), que no bloquea nada.
// Sobre el fondo desenfocado: en el centro, sin tarjeta, el reloj, la mascota, la foto y la
// contraseña; a la izquierda, las tarjetas de conexión y batería, sistema y reproductor; a la
// derecha, uso del equipo y notificaciones. En pantallas estrechas solo queda el centro.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"
import "../designs"

Item {
    id: page

    required property var lock // el singleton LockScreen (contraseña, errores, apagado…)
    property bool active: true // sesión bloqueada
    property bool preview: false // vista previa: ni contraseña ni acciones

    readonly property bool wide: Config.lockShowSystemCards && width >= 1280 && height >= 700
    readonly property color ink: "#f5f7f6"
    readonly property color inkDim: "#c0cfcc"
    readonly property color cardColor: Qt.rgba(1, 1, 1, 0.07) // el mismo tono que el campo de contraseña y los botones

    // ---- Datos del equipo (cada 30 s mientras se ve) ----
    property string host: ""
    property string osName: ""
    property string kernel: ""
    property string osLogo: "" // nombre de icono de la distribución (LOGO= de /etc/os-release)
    property real uptimeSecs: 0
    property int diskPct: 0
    property int tempC: 0
    readonly property string uptimeText: {
        const m = Math.floor(uptimeSecs / 60), h = Math.floor(m / 60), d = Math.floor(h / 24);
        return d > 0 ? d + " d " + (h % 24) + " h" : h > 0 ? h + " h " + (m % 60) + " min" : m + " min";
    }
    Process {
        id: sysProc
        command: ["sh", "-c", "uname -n; (. /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\"); uname -r; cut -d' ' -f1 /proc/uptime; df --output=pcent / | tail -n1 | tr -dc 0-9; echo; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -n1; echo; (. /etc/os-release 2>/dev/null; echo \"$LOGO\")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                page.host = l[0] ?? "";
                page.osName = l[1] ?? "";
                page.kernel = l[2] ?? "";
                page.uptimeSecs = parseFloat(l[3] ?? "0") || 0;
                page.diskPct = parseInt(l[4] ?? "0") || 0;
                page.tempC = Math.round((parseInt(l[5] ?? "0") || 0) / 1000);
                page.osLogo = (l[l.length - 2] ?? "").trim();
            }
        }
    }
    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: page.active && page.visible
        onTriggered: sysProc.running = true
    }

    // ---- Fondo ----
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Wallpaper.current ? "file://" + Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: Config.lockBackgroundBlur > 0
        blur: Config.lockBackgroundBlur / 100
        blurMax: 48
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Config.lockBackgroundDim / 100)
    }

    SystemClock {
        id: lockClock
        precision: SystemClock.Minutes
    }

    // ---- Estado del equipo, arriba a la derecha ----
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 22
        anchors.rightMargin: 28
        spacing: 14
        // Con columnas laterales, esto va en la tarjeta de conexión y batería (arriba a la izquierda)
        visible: Config.lockShowStatus && !page.wide

        Text {
            visible: Audio.muted
            text: "volume_off"
            color: Theme.red
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: Bluetooth.enabled
            text: Bluetooth.connectedCount > 0 ? "bluetooth_connected" : "bluetooth"
            color: "#e8f1f0"
            opacity: Bluetooth.connectedCount > 0 ? 1 : 0.6
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: page.lock.networkGlyph
                color: "#e8f1f0"
                opacity: Net.online ? 1 : 0.6
                font.family: page.lock.outlinedFamily
                font.pixelSize: 22
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: Net.type === "wifi" && text !== ""
                text: Net.connectedSsid || Net.name
                color: "#e8f1f0"
                font.family: Theme.bodyFontFamily
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            visible: Battery.available
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: page.lock.batteryGlyph
                color: Battery.percent <= 20 && !Battery.charging ? Theme.red : "#e8f1f0"
                font.family: page.lock.outlinedFamily
                font.pixelSize: 24
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: Battery.charging
                text: "bolt"
                color: Theme.green
                font.family: page.lock.outlinedFamily
                font.pixelSize: 17
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Battery.percent + "%"
                color: "#e8f1f0"
                font.family: Theme.bodyFontFamily
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- Panel ----
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: page.wide ? Math.min(1400, page.width - 100) : Math.min(480, page.width - 32)
        height: Math.min(800, page.height - (page.wide ? 110 : 90))
        // Sin marco: solo ordena las piezas sobre el fondo desenfocado; cada sección lleva su tarjeta
        color: "transparent"

        readonly property real pad: 16
        readonly property real gap: 22 // entre tarjetas
        readonly property real colGap: 36 // entre las columnas de tarjetas y el centro
        readonly property real sideWidth: Math.min(380, (width - pad * 2 - colGap * 2) * 0.29)
        readonly property real colH: height - pad * 2
        readonly property real statusH: 136
        readonly property real statsH: 164
        readonly property real playerH: Config.lockShowMusic ? Math.min(236, colH * 0.33) : 0

        // ===== Izquierda: conexión y batería, sistema y reproductor =====
        Column {
            id: leftCol
            visible: page.wide
            x: panel.pad
            y: panel.pad
            width: panel.sideWidth
            height: panel.colH
            spacing: panel.gap

            // Conexión y batería (donde otros shells ponen el clima): una fila para cada una, con su
            // icono en un círculo, el dato principal y un indicador a la derecha
            Rectangle {
                id: statusCard
                visible: Config.lockShowStatus
                width: panel.sideWidth
                height: panel.statusH
                radius: 26
                color: page.cardColor

                readonly property bool lowBattery: Battery.available && Battery.percent <= 20 && !Battery.charging

                Column {
                    id: statusRows
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32
                    spacing: 10

                    // Red
                    Item {
                        width: parent.width
                        height: 48
                        Rectangle {
                            id: netChip
                            width: 48
                            height: 48
                            radius: 24
                            color: Net.online ? Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: page.lock.networkGlyph
                                color: Net.online ? Theme.green : page.inkDim
                                font.family: page.lock.outlinedFamily
                                font.pixelSize: 26
                            }
                        }
                        Column {
                            anchors.left: netChip.right
                            anchors.leftMargin: 12
                            anchors.right: signalBars.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                text: Net.type === "wifi" ? (Net.connectedSsid || Net.name || "Wi-Fi") : Net.type === "ethernet" ? "Ethernet" : "Sin conexión"
                                color: page.ink
                                elide: Text.ElideRight
                                font.family: Theme.displayFontFamily
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: Net.type === "wifi" ? "Wi-Fi · señal " + Net.wifiSignal + "%" : Net.type === "ethernet" ? "Conectado por cable" : (Net.wifiEnabled ? "Wi-Fi sin red" : "Wi-Fi apagado")
                                color: page.inkDim
                                elide: Text.ElideRight
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 12
                            }
                        }
                        // Barras de señal
                        Row {
                            id: signalBars
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Net.type === "wifi"
                            width: visible ? implicitWidth : 0
                            height: 22
                            spacing: 3
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    required property int index
                                    width: 5
                                    height: 7 + index * 5
                                    radius: 2.5
                                    anchors.bottom: parent.bottom
                                    color: Net.wifiSignal >= [10, 35, 60, 80][index] ? Theme.green : Qt.rgba(1, 1, 1, 0.14)
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: Battery.available
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Batería
                    Item {
                        visible: Battery.available
                        width: parent.width
                        height: 48
                        Rectangle {
                            id: battChip
                            width: 48
                            height: 48
                            radius: 24
                            color: statusCard.lowBattery ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.2) : Qt.rgba(Theme.green.r, Theme.green.g, Theme.green.b, 0.18)
                            Text {
                                anchors.centerIn: parent
                                text: Battery.charging ? "bolt" : page.lock.batteryGlyph
                                color: statusCard.lowBattery ? Theme.red : Theme.green
                                font.family: page.lock.outlinedFamily
                                font.pixelSize: 26
                            }
                        }
                        Column {
                            anchors.left: battChip.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: Battery.percent + "%"
                                color: statusCard.lowBattery ? Theme.red : page.ink
                                font.family: Theme.displayFontFamily
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: Battery.charging ? "Cargando" : statusCard.lowBattery ? "Batería baja" : "Con batería"
                                color: page.inkDim
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 12
                            }
                        }
                        // Nivel
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(130, parent.width * 0.38)
                            height: 10
                            radius: 5
                            color: Qt.rgba(1, 1, 1, 0.1)
                            Rectangle {
                                width: Math.max(height, parent.width * Math.max(0, Math.min(100, Battery.percent)) / 100)
                                height: parent.height
                                radius: 5
                                color: statusCard.lowBattery ? Theme.red : Theme.green
                                Behavior on width {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            // Sistema: logo de la distribución y cuatro datos, grandes y centrados, con la paleta del tema
            Rectangle {
                id: fetchCard
                width: panel.sideWidth
                height: panel.colH - (statusCard.visible ? panel.statusH + panel.gap : 0) - (musicSlot.visible ? panel.playerH + panel.gap : 0)
                radius: 26
                color: page.cardColor

                Column {
                    id: fetchBody
                    anchors.centerIn: parent
                    spacing: Math.max(14, Math.min(30, (fetchCard.height - 190) / 3))

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 18
                        // Logo de la distribución (si está)
                        Image {
                            id: distroLogo
                            visible: status === Image.Ready
                            width: visible ? Math.min(110, fetchCard.height * 0.4) : 0
                            height: Math.min(110, fetchCard.height * 0.4)
                            anchors.verticalCenter: parent.verticalCenter
                            // Primero el de /usr/share/pixmaps; si no está, el del tema de iconos
                            property bool fromTheme: false
                            source: page.osLogo === "" ? "" : fromTheme ? Quickshell.iconPath(page.osLogo, true) : "file:///usr/share/pixmaps/" + page.osLogo + ".svg"
                            onStatusChanged: if (status === Image.Error && !fromTheme) fromTheme = true
                            sourceSize.width: 256
                            sourceSize.height: 256
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Repeater {
                                model: [
                                    { k: "OS", v: page.osName },
                                    { k: "WM", v: "Hyprland" },
                                    { k: "USER", v: Quickshell.env("USER") || "user" },
                                    { k: "UP", v: page.uptimeText }
                                ]
                                delegate: Row {
                                    required property var modelData
                                    visible: modelData.v !== ""
                                    Text {
                                        width: 62
                                        text: modelData.k
                                        color: Theme.green
                                        font.family: "monospace"
                                        font.pixelSize: 16
                                        font.bold: true
                                    }
                                    Text {
                                        width: Math.min(implicitWidth, fetchCard.width - 62 - distroLogo.width - 18 - 36)
                                        text: modelData.v
                                        color: page.ink
                                        elide: Text.ElideRight
                                        font.family: "monospace"
                                        font.pixelSize: 16
                                    }
                                }
                            }
                        }
                    }
                    // Paleta del tema
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 11
                        Repeater {
                            model: [Theme.surface1, Theme.red, Theme.orange, Theme.yellow, Theme.green, Theme.aqua, Theme.blue, Theme.purple]
                            delegate: Rectangle {
                                required property color modelData
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData
                            }
                        }
                    }
                }
            }

            // Música (o aviso de que no suena nada): tarjeta apaisada
            Item {
                id: musicSlot
                width: panel.sideWidth
                height: panel.playerH
                visible: Config.lockShowMusic

                // Reproductor. Dos estilos (Ajustes > Lock Screen > Player cover as background):
                // con la carátula de fondo, o con la carátula en un cuadro a la izquierda.
                ClippingRectangle {
                    id: playerCard
                    anchors.fill: parent
                    visible: !!player
                    radius: 26
                    color: page.cardColor

                    readonly property var media: page.lock.mediaService
                    readonly property var player: media?.active ?? null
                    readonly property real length: player?.length ?? 0
                    readonly property string art: media?.artPath ?? ""
                    readonly property bool artBg: Config.lockPlayerArtBackground && bgArt.status === Image.Ready
                    property real position: 0
                    function clock(secs: real): string {
                        const t = Math.max(0, Math.floor(secs));
                        return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
                    }
                    Timer {
                        interval: 500
                        repeat: true
                        triggeredOnStart: true
                        running: playerCard.visible && page.active && page.visible
                        onTriggered: playerCard.position = playerCard.player?.position ?? 0
                    }

                    // Carátula de fondo, oscurecida hacia abajo para que se lea el texto
                    Image {
                        id: bgArt
                        anchors.fill: parent
                        visible: playerCard.artBg
                        source: Config.lockPlayerArtBackground ? playerCard.art : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 800
                        sourceSize.height: 800
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: playerCard.artBg
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.25) }
                            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.55) }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.88) }
                        }
                    }

                    // Carátula en un cuadro (estilo sin fondo)
                    ClippingRectangle {
                        id: artBox
                        visible: !playerCard.artBg
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: visible ? Math.min(parent.height - 36, parent.width * 0.4) : 0
                        height: width
                        radius: 20
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            visible: boxArt.status !== Image.Ready
                            text: "music_note"
                            color: page.inkDim
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: parent.width * 0.4
                        }
                        Image {
                            id: boxArt
                            anchors.fill: parent
                            source: Config.lockPlayerArtBackground ? "" : playerCard.art
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 400
                            sourceSize.height: 400
                        }
                    }

                    // Título, progreso y controles: abajo sobre el fondo, o a la derecha del cuadro
                    Column {
                        anchors.left: artBox.visible ? artBox.right : parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: artBox.visible ? 16 : 20
                        anchors.rightMargin: 20
                        // (con y, no con anclas: cambiar de ancla vertical al cargar la carátula las dejaba sin efecto)
                        y: playerCard.artBg ? parent.height - height - 16 : (parent.height - height) / 2
                        spacing: 10

                        Column {
                            width: parent.width
                            spacing: 2
                            MarqueeText {
                                width: parent.width
                                text: playerCard.media?.title || "Sin título"
                                color: page.ink
                                font.family: Theme.displayFontFamily
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: playerCard.media?.artist || playerCard.media?.album || ""
                                color: playerCard.artBg ? "#d9e4e2" : page.inkDim
                                elide: Text.ElideRight
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 13
                            }
                        }

                        // Progreso con tiempos
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: playerCard.length > 0
                            Rectangle {
                                width: parent.width
                                height: 6
                                radius: 3
                                color: Qt.rgba(1, 1, 1, 0.18)
                                Rectangle {
                                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, playerCard.position / Math.max(1, playerCard.length))))
                                    height: parent.height
                                    radius: 3
                                    color: Theme.green
                                }
                            }
                            Item {
                                width: parent.width
                                height: 13
                                Text {
                                    text: playerCard.clock(playerCard.position)
                                    color: playerCard.artBg ? "#d9e4e2" : page.inkDim
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 11
                                }
                                Text {
                                    anchors.right: parent.right
                                    text: playerCard.clock(playerCard.length)
                                    color: playerCard.artBg ? "#d9e4e2" : page.inkDim
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12
                            Repeater {
                                model: [
                                    { glyph: "skip_previous", main: false, act: "prev" },
                                    { glyph: playerCard.player?.isPlaying ? "pause" : "play_arrow", main: true, act: "toggle" },
                                    { glyph: "skip_next", main: false, act: "next" }
                                ]
                                delegate: Rectangle {
                                    id: mediaButton
                                    required property var modelData
                                    width: modelData.main ? 68 : 42
                                    height: 42
                                    radius: 21
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.main ? Theme.green : (mediaMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.13))
                                    scale: mediaMouse.pressed ? 0.94 : 1
                                    Behavior on scale {
                                        NumberAnimation { duration: 90 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: mediaButton.modelData.glyph
                                        color: mediaButton.modelData.main ? Theme.crust : page.ink
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: mediaButton.modelData.main ? 26 : 22
                                    }
                                    MouseArea {
                                        id: mediaMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const m = playerCard.media;
                                            if (mediaButton.modelData.act === "toggle")
                                                m?.toggle();
                                            else if (mediaButton.modelData.act === "next")
                                                m?.next();
                                            else
                                                m?.prev();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !page.lock.mediaService?.active
                    radius: 26
                    color: page.cardColor
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "music_off"
                            color: Theme.green
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 34
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nada sonando"
                            color: page.ink
                            font.family: Theme.displayFontFamily
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Pon algo de música"
                            color: page.inkDim
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        // ===== Derecha: uso del equipo y notificaciones =====
        Column {
            id: rightCol
            visible: page.wide
            x: panel.width - panel.pad - width
            y: panel.pad
            width: panel.sideWidth
            height: panel.colH
            spacing: panel.gap

            // Uso del equipo: un anillo por métrica, con el porcentaje dentro
            Rectangle {
                id: statsCard
                width: panel.sideWidth
                height: panel.statsH
                radius: 26
                color: page.cardColor
                Row {
                    anchors.fill: parent
                    anchors.margins: 16
                    Repeater {
                        model: [
                            { glyph: "memory", label: "CPU", value: Sys.cpu, tint: Theme.blue, note: page.tempC > 0 ? page.tempC + "°C" : "", hot: page.tempC >= 85 },
                            { glyph: "memory_alt", label: "RAM", value: Sys.mem, tint: Theme.purple, note: "", hot: false },
                            { glyph: "hard_drive", label: "Disco", value: page.diskPct / 100, tint: Theme.aqua, note: "", hot: false }
                        ]
                        delegate: Item {
                            id: gauge
                            required property var modelData
                            readonly property real level: Math.max(0, Math.min(1, modelData.value))
                            property real shown: level // animado
                            Behavior on shown {
                                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                            }
                            width: parent.width / 3
                            height: parent.height

                            Item {
                                id: ring
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(90, parent.width - 10)
                                height: width
                                readonly property real stroke: 8
                                Shape {
                                    anchors.fill: parent
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        strokeColor: Qt.rgba(1, 1, 1, 0.09)
                                        strokeWidth: ring.stroke
                                        fillColor: "transparent"
                                        PathAngleArc {
                                            centerX: ring.width / 2
                                            centerY: ring.height / 2
                                            radiusX: ring.width / 2 - ring.stroke / 2
                                            radiusY: ring.height / 2 - ring.stroke / 2
                                            startAngle: 0
                                            sweepAngle: 360
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: gauge.modelData.hot ? Theme.red : gauge.modelData.tint
                                        strokeWidth: ring.stroke
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: ring.width / 2
                                            centerY: ring.height / 2
                                            radiusX: ring.width / 2 - ring.stroke / 2
                                            radiusY: ring.height / 2 - ring.stroke / 2
                                            startAngle: -90
                                            sweepAngle: Math.max(0.01, 360 * gauge.shown)
                                        }
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: -2
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(gauge.level * 100) + "%"
                                        color: page.ink
                                        font.family: Theme.displayFontFamily
                                        font.pixelSize: 23
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        visible: gauge.modelData.note !== ""
                                        text: gauge.modelData.note
                                        color: gauge.modelData.hot ? Theme.red : page.inkDim
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 12
                                    }
                                }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                spacing: 5
                                Text {
                                    text: gauge.modelData.glyph
                                    color: gauge.modelData.tint
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: gauge.modelData.label
                                    color: page.inkDim
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: panel.sideWidth
                height: panel.colH - panel.statsH - panel.gap
                radius: 26
                color: page.cardColor
                visible: Config.lockShowNotifications

                readonly property var notifs: (Notifs.list?.values ?? []).slice().reverse()

                Text {
                    id: notifHeader
                    x: 18
                    y: 16
                    text: Notifs.activeCount === 0 ? "Sin notificaciones" : Notifs.activeCount === 1 ? "1 notificación" : Notifs.activeCount + " notificaciones"
                    color: page.inkDim
                    font.family: "monospace"
                    font.pixelSize: 13
                    font.bold: true
                }
                ListView {
                    anchors.fill: parent
                    anchors.topMargin: 44
                    anchors.margins: 12
                    clip: true
                    spacing: 8
                    interactive: false
                    model: parent.notifs
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 56
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            id: notifIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "notifications"
                            color: Theme.green
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                        }
                        Column {
                            x: 44
                            width: parent.width - 56
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.appName || "Notificación"
                                color: page.ink
                                elide: Text.ElideRight
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 13
                                font.bold: true
                            }
                            // El texto del aviso solo si se permite (Ajustes > Lock Screen)
                            Text {
                                width: parent.width
                                text: Config.lockNotificationContent ? (modelData.summary || "") : "Contenido oculto"
                                color: page.inkDim
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                maximumLineCount: 1
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 13
                            }
                        }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    visible: Notifs.activeCount === 0
                    spacing: 8
                    opacity: 0.55
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "notifications_off"
                        color: page.inkDim
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 96
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Todo al día"
                        color: page.inkDim
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 15
                    }
                }
            }
        }

        // ===== Reloj, mascota, foto y contraseña: en el centro (solos en pantallas estrechas) =====
        Item {
            id: centerCol
            x: page.wide ? panel.pad + panel.sideWidth + panel.colGap : panel.pad
            y: panel.pad
            width: panel.width - x * 2
            height: panel.colH

            Column {
                id: clockBlock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(lockClock.date, Config.lockClock24Hour ? "HH:mm" : "h:mm AP")
                    color: Theme.green
                    font.family: Theme.displayFontFamily
                    font.pixelSize: Math.min(104, centerCol.width * 0.2)
                    font.weight: Font.Bold
                    visible: Config.lockShowClock
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(lockClock.date, "dddd • d MMM").toUpperCase()
                    color: page.inkDim
                    font.family: Theme.displayFontFamily
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    visible: Config.lockShowDate
                }

                // Sin columnas laterales, las notificaciones se quedan en un contador
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6
                    spacing: 6
                    visible: !page.wide && Config.lockShowNotifications && Notifs.activeCount > 0
                    Text {
                        text: "notifications"
                        color: Theme.green
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Notifs.activeCount === 1 ? "1 notificación" : Notifs.activeCount + " notificaciones"
                        color: "#e8f1f0"
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // La mascota de la isla (Ajustes > Bar & Island > Mascot), paseando bajo el reloj
                Item {
                    id: mascotStrip
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(420, centerCol.width - 40)
                    height: 64
                    visible: Config.lockShowMascot
                    IslandMascot {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        scaleFactor: 2
                        // Un solo tramo: todo el ancho de la franja
                        leftGapStart: 0
                        leftGapEnd: 0
                        rightGapStart: 0
                        rightGapEnd: mascotStrip.width
                        allowed: page.active && page.visible && Config.lockShowMascot && !page.lock.suspending
                        sprite: Config.mascotSprite
                    }
                }
            }

            // Botones de energía, abajo
            Row {
                id: powerRow
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 10

                Repeater {
                    model: [
                        { label: "Suspender", action: "suspend", glyph: "bedtime" },
                        { label: "Reiniciar", action: "reboot", glyph: "restart_alt" },
                        { label: "Apagar", action: "poweroff", glyph: "power_settings_new" }
                    ]

                    Rectangle {
                        id: powerButton
                        required property var modelData
                        width: Math.min(150, (centerCol.width - 20) / 3)
                        height: 46
                        radius: 23
                        color: powerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                        scale: powerMouse.pressed ? 0.96 : 1
                        Behavior on scale {
                            NumberAnimation { duration: 90 }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: powerButton.modelData.glyph
                                color: powerButton.modelData.action === "poweroff" ? Theme.red : Theme.green
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: powerButton.modelData.label
                                color: page.ink
                                font.family: Theme.displayFontFamily
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Suspender no cierra nada: va directo, sin confirmación
                            onClicked: {
                                if (page.preview)
                                    return;
                                if (powerButton.modelData.action === "suspend")
                                    page.lock.suspend();
                                else
                                    page.lock.powerAction = powerButton.modelData.action;
                            }
                        }
                    }
                }
            }

            // Foto, nombre y contraseña: centrados en el hueco entre el reloj y los botones
            Column {
                id: authBlock
                anchors.horizontalCenter: parent.horizontalCenter
                y: clockBlock.y + clockBlock.height + Math.max(0, (powerRow.y - (clockBlock.y + clockBlock.height) - height) / 2)
                width: Math.min(360, centerCol.width - 24)
                spacing: 12

                // Foto de ~/.face con forma ondulada suave (N ondas, una centrada arriba; 0 = círculo):
                // el radio oscila entre `inner` y `outer` con (1 + cos N(θ + 90°)) / 2. La forma se
                // rellena con la foto (fillItem, sin máscara: un MultiEffect con maskSource fuera de
                // la escena la dejaba transparente).
                Item {
                    id: avatarFrame
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Tamaño, ondas, encuadre y animación: Ajustes > Lock Screen > Profile picture.
                    // Se encoge si el panel no da para tanto.
                    readonly property real room: powerRow.y - (clockBlock.y + clockBlock.height) - 150
                    width: Math.max(72, Math.min(Config.lockAvatarSize, room))
                    height: width

                    // Animación: la forma gira y "respira" (crece lockAvatarBreathe %); la foto no gira
                    // ni se amplía, la forma deja ver más o menos de ella. En reposo la forma mide
                    // 1/breatheTo del cuadro para que al crecer no se salga. Sin animación con Reduce motion.
                    property real spin: 0 // radianes que gira la forma
                    NumberAnimation on spin {
                        from: 0
                        to: 2 * Math.PI
                        duration: Config.lockAvatarSpinSeconds * 1000
                        loops: Animation.Infinite
                        running: !Theme.reduceMotion && Config.lockAvatarSpin && Config.lockAvatarWaves > 0
                    }
                    readonly property real breatheTo: 1 + Config.lockAvatarBreathe / 100
                    property real breathe: 1
                    SequentialAnimation on breathe {
                        loops: Animation.Infinite
                        running: !Theme.reduceMotion && Config.lockAvatarBreathe > 0
                        NumberAnimation { from: 1; to: avatarFrame.breatheTo; duration: 2500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: avatarFrame.breatheTo; to: 1; duration: 2500; easing.type: Easing.InOutSine }
                    }

                    readonly property var outline: {
                        const pts = [];
                        const c = width / 2, outer = (width / 2 - 2) / breatheTo * breathe, steps = 240;
                        const waves = Config.lockAvatarWaves, inner = outer * (1 - Config.lockAvatarWaveDepth / 100);
                        for (let i = 0; i <= steps; i++) {
                            const t = 2 * Math.PI * i / steps;
                            const r = waves > 0 ? inner + (outer - inner) * (1 + Math.cos(waves * (t + Math.PI / 2 - spin))) / 2 : outer;
                            pts.push(Qt.point(c + r * Math.cos(t), c + r * Math.sin(t)));
                        }
                        return pts;
                    }

                    // Textura de la foto ya recortada al cuadrado de la forma. Al doble de
                    // resolución y suavizada: al "respirar" se agranda y a 1× se veían los píxeles
                    Item {
                        id: avatarPhoto
                        width: avatarFrame.width
                        height: avatarFrame.height
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(width * 2, height * 2)
                        Rectangle {
                            anchors.fill: parent
                            color: "#334b4a" // si la foto no carga
                        }
                        // Encuadre de Ajustes > Lock Screen (zoom y punto central)
                        FacePhoto {
                            anchors.fill: parent
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillItem: avatarPhoto
                            // La textura es del doble de tamaño (nitidez al "respirar") y fillItem
                            // la pega píxel a píxel: sin escalarla a la mitad solo se veía su
                            // esquina superior izquierda
                            fillTransform: PlanarTransform.fromScale(0.5, 0.5)
                            strokeColor: "#80ffffff"
                            strokeWidth: 2
                            PathPolyline { path: avatarFrame.outline }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Quickshell.env("USER") || "user"
                    color: page.ink
                    font.family: Theme.displayFontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 48
                    radius: 24
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.color: passwordInput.activeFocus ? "#99ffffff" : "#33ffffff"
                    border.width: 1

                    Text {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lock"
                        color: page.inkDim
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 19
                    }

                    TextInput {
                        id: passwordInput
                        text: page.lock.passwordText
                        anchors.fill: parent
                        anchors.leftMargin: 46
                        anchors.rightMargin: 80
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        color: page.ink
                        selectionColor: Theme.green
                        selectedTextColor: "#06120f"
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 15
                        clip: true
                        echoMode: page.lock.revealPassword ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        focus: page.active && !page.preview
                        enabled: page.active && !page.preview
                        Component.onCompleted: {
                            if (!page.preview)
                                page.lock.passwordField = passwordInput;
                        }
                        Component.onDestruction: {
                            if (page.lock.passwordField === passwordInput)
                                page.lock.passwordField = null;
                        }
                        onTextChanged: {
                            if (!page.preview && page.lock.passwordText !== text)
                                page.lock.passwordText = text;
                        }
                        onAccepted: page.lock.submitPassword()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                event.accepted = true;
                                passwordInput.clear();
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: passwordInput.text.length === 0
                        text: page.preview ? "Vista previa" : "Escribe tu contraseña"
                        color: "#d9e4e2"
                        opacity: 0.75
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 14
                    }

                    // Ver/ocultar lo escrito
                    Text {
                        anchors.right: submitButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length > 0
                        text: page.lock.revealPassword ? "visibility_off" : "visibility"
                        color: "#d9e4e2"
                        opacity: eyeMouse.containsMouse ? 1 : 0.7
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        MouseArea {
                            id: eyeMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.lock.revealPassword = !page.lock.revealPassword;
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }

                    // Enviar (igual que Enter)
                    Rectangle {
                        id: submitButton
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 18
                        color: passwordInput.text.length > 0 ? Theme.green : Qt.rgba(1, 1, 1, 0.08)
                        Text {
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            color: passwordInput.text.length > 0 ? Theme.crust : page.inkDim
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!page.preview)
                                    page.lock.submitPassword();
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    visible: page.lock.capsLock
                    Text {
                        text: "keyboard_capslock"
                        color: Theme.yellow
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 17
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Bloq Mayús activado"
                        color: Theme.yellow
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: page.lock.errorText || page.lock.pamError
                    visible: text.length > 0
                    color: "#ffb4ab"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 13
                }
            }
        }
    }

    // ---- Confirmación de reiniciar / apagar ----
    Rectangle {
        anchors.fill: parent
        z: 20
        visible: page.lock.powerAction !== "" && !page.preview
        color: "#bb000000"

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 184
            radius: 20
            color: "#f00d1513"
            border.color: "#55ffffff"

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                Text {
                    width: parent.width
                    text: page.lock.powerAction === "reboot" ? "¿Reiniciar el equipo?" : "¿Apagar el equipo?"
                    color: page.ink
                    font.family: Theme.displayFontFamily
                    font.pixelSize: 19
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: "La sesión actual se cerrará."
                    color: page.inkDim
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Rectangle {
                        width: 132
                        height: 40
                        radius: 20
                        color: "#342b29"
                        Text {
                            anchors.centerIn: parent
                            text: "Cancelar"
                            color: "#e2e9e7"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 13
                        }
                        MouseArea { anchors.fill: parent; onClicked: page.lock.powerAction = "" }
                    }
                    Rectangle {
                        width: 132
                        height: 40
                        radius: 20
                        color: Theme.red
                        Text {
                            anchors.centerIn: parent
                            text: page.lock.powerAction === "reboot" ? "Reiniciar" : "Apagar"
                            color: "#160908"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: page.lock.confirmPowerAction() }
                    }
                }
            }
        }
    }

    // Fundir a negro antes de suspender evita el corte brusco del wallpaper.
    Rectangle {
        anchors.fill: parent
        z: 100
        color: "black"
        opacity: page.lock.suspending && !page.preview ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 550
                easing.type: Easing.InOutCubic
            }
        }
    }

    // Vista previa: clic en cualquier parte para cerrarla
    MouseArea {
        anchors.fill: parent
        z: 200
        enabled: page.preview
        visible: page.preview
        onClicked: page.lock.previewing = false
    }
}
