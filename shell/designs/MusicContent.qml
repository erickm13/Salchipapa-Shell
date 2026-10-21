pragma ComponentBehavior: Bound
// Panel de música DENTRO de la isla (modo "music", Super+A). Izquierda: portada en círculo con el
// visualizador de cava alrededor. Centro: título, álbum, artista, controles, progreso ondulado con
// tiempos y selector de reproductor. Derecha: letra sincronizada (LRCLIB) si "Lyrics" está activo.
// Teclado: Espacio reproducir/pausar · ←/→ anterior/siguiente · Shift+←/→ ±5 s · S aleatorio ·
// R repetir · L letra · Esc cerrar.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../common"
import "../services"

Item {
    id: root

    readonly property bool active: Overlay.mode === "music"
    readonly property var player: Media.active
    readonly property real length: player?.length ?? 0
    property real position: 0
    readonly property bool showLyrics: Config.mediaShowLyrics

    function fmt(sec: real): string {
        const s = Math.max(0, Math.floor(sec));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function seekBy(delta: real): void {
        if (!player?.canSeek)
            return;
        position = Math.max(0, Math.min(length, position + delta));
        player.position = position;
    }
    function cycleLoop(): void {
        if (!player?.loopSupported)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    focus: active
    onActiveChanged: if (active) {
        Qt.callLater(() => root.forceActiveFocus());
        root.loadLyrics();
        syncTimer.restart();
    }
    // Segundo intento tras el fundido de entrada, cuando la lista ya está colocada
    Timer {
        id: syncTimer
        interval: 200
        onTriggered: root.syncLyric()
    }
    Component.onCompleted: Qt.callLater(syncLyric)
    Keys.onEscapePressed: Overlay.close()
    Keys.onSpacePressed: player?.togglePlaying()
    Keys.onLeftPressed: event => (event.modifiers & Qt.ShiftModifier) ? root.seekBy(-5) : Media.prev()
    Keys.onRightPressed: event => (event.modifiers & Qt.ShiftModifier) ? root.seekBy(5) : Media.next()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_S && player?.shuffleSupported) {
            player.shuffle = !player.shuffle;
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            root.cycleLoop();
            event.accepted = true;
        } else if (event.key === Qt.Key_L) {
            Config.opt.mediaShowLyrics = !Config.mediaShowLyrics;
            event.accepted = true;
        }
    }

    // MPRIS no notifica la posición sola: se pide mientras el panel está abierto
    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: root.active && !!root.player
        onTriggered: {
            root.player?.positionChanged();
            root.position = root.player?.position ?? 0;
        }
    }

    // ---- Letra: se pide al abrir el panel y al cambiar de canción ----
    function loadLyrics(): void {
        if (active && showLyrics && player)
            Lyrics.load(Media.artist, Media.title, Media.album, length);
    }
    onShowLyricsChanged: loadLyrics()
    // Al cambiar de canción el reproductor no actualiza todo a la vez (primero el título, luego
    // artista, álbum y duración): se pide la letra cuando los datos llevan 600 ms sin cambiar
    Timer {
        id: lyricsDebounce
        interval: 600
        onTriggered: root.loadLyrics()
    }
    Connections {
        target: Media
        function onTitleChanged(): void {
            lyricsDebounce.restart();
        }
        function onArtistChanged(): void {
            lyricsDebounce.restart();
        }
        function onAlbumChanged(): void {
            lyricsDebounce.restart();
        }
    }
    onLengthChanged: lyricsDebounce.restart()
    readonly property int lyricIndex: Lyrics.synced ? Lyrics.indexAt(position + 0.3) : -1
    // La lista no se enlaza a lyricIndex: ListView reinicia currentIndex al cambiar el modelo y
    // rompería el enlace, así que se fija a mano (también al llegar una letra nueva)
    // La línea actual se centra moviendo contentY a mano (el rango de resaltado de ListView no
    // respetaba el espacio de arriba y dejaba las primeras líneas pegadas al borde)
    function syncLyric(): void {
        const i = Math.max(0, lyricIndex);
        lyricList.currentIndex = i;
        const item = lyricList.itemAtIndex(i);
        if (item)
            lyricList.contentY = item.y + item.height / 2 - lyricList.height / 2;
        else
            lyricList.positionViewAtIndex(i, ListView.Center);
    }
    onLyricIndexChanged: syncLyric()
    Connections {
        target: Lyrics
        function onLinesChanged(): void {
            Qt.callLater(root.syncLyric);
        }
    }

    // ---- Visualizador: cava en salida cruda (48 barras, 0..100) solo con el panel abierto ----
    property var bars: []
    Process {
        running: root.active && (root.player?.isPlaying ?? false)
        command: ["sh", "-c", 'conf="${XDG_RUNTIME_DIR:-/tmp}/salchipapa-cava.conf"; printf "[general]\\nbars = 48\\nframerate = 30\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n[smoothing]\\nnoise_reduction = 70\\n" > "$conf"; exec cava -p "$conf"']
        stdout: SplitParser {
            onRead: data => root.bars = data.split(";").filter(v => v !== "").map(v => parseInt(v) / 100)
        }
        onRunningChanged: if (!running) root.bars = []
    }

    // ================= Izquierda: portada + visualizador =================
    Item {
        id: artArea
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 200

        Item {
            id: ring
            anchors.centerIn: parent
            width: 176
            height: 176
            Repeater {
                model: 48
                delegate: Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 360 / 48
                    Rectangle {
                        readonly property real level: root.bars[parent.index] ?? 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: 4
                        height: 5 + level * 18
                        radius: 2
                        color: Theme.green
                        opacity: 0.45 + level * 0.55
                        Behavior on height {
                            NumberAnimation { duration: 60 }
                        }
                    }
                }
            }
        }
        ClippingRectangle {
            anchors.centerIn: parent
            width: 124
            height: 124
            radius: 62
            color: Theme.panelCardHi
            Image {
                anchors.fill: parent
                source: Media.artPath
                sourceSize.width: 300
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "music_note"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 48
                color: Theme.green
                visible: Media.artPath === ""
            }
        }
    }

    // ================= Centro: datos, controles, progreso y reproductores =================
    Column {
        id: centerCol
        // Centrada en el panel: portada y letra miden lo mismo a cada lado, así los huecos son
        // iguales. Sin letra, centrada en el espacio a la derecha de la portada.
        width: 280
        x: root.showLyrics ? (root.width - width) / 2 : artArea.width + (root.width - artArea.width - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        MarqueeText {
            width: parent.width
            centered: true
            text: root.player ? (Media.title || "Unknown title") : "Nothing playing"
            color: Theme.text
            font.family: Theme.displayFontFamily
            font.pixelSize: Theme.fontPx(26)
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Media.album
            visible: text !== ""
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(16)
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Media.artist
            visible: text !== ""
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(16)
            elide: Text.ElideRight
        }

        // Simétrica: reproducir en el centro, anterior/siguiente a los lados y luego aleatorio/repetir
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            topPadding: 4
            CtrlButton {
                glyph: "shuffle"
                enabled: root.player?.shuffleSupported ?? false
                on: root.player?.shuffle ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            CtrlButton {
                glyph: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: Media.prev()
            }
            CtrlButton {
                big: true
                glyph: root.player?.isPlaying ? "pause" : "play_arrow"
                enabled: !!root.player
                onClicked: root.player?.togglePlaying()
            }
            CtrlButton {
                glyph: "skip_next"
                enabled: root.player?.canGoNext ?? false
                onClicked: Media.next()
            }
            CtrlButton {
                glyph: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                enabled: root.player?.loopSupported ?? false
                on: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onClicked: root.cycleLoop()
            }
        }

        WavyProgress {
            width: parent.width
            height: 26
            color: Theme.green
            trackColor: Theme.panelCardHi
            value: root.length > 0 ? root.position / root.length : 0
            animating: root.active && (root.player?.isPlaying ?? false) && !Theme.reduceMotion
            seekable: root.player?.canSeek ?? false
            onSeeked: v => {
                root.position = v * root.length;
                if (root.player)
                    root.player.position = root.position;
            }
        }
        Item {
            width: parent.width
            height: timeLeft.implicitHeight
            Text {
                id: timeLeft
                x: 8
                text: root.fmt(root.position)
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                text: root.length > 0 ? root.fmt(root.length) : "--:--"
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
            }
        }

        // Reproductores abiertos (el marcado es el que controla el panel y la isla) y el botón de letra
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            topPadding: 2
            Repeater {
                model: Media.players.length > 1 ? Media.players : []
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool current: modelData === root.player
                    width: chipRow.implicitWidth + 28
                    height: 36
                    radius: 18
                    color: current ? Theme.green : (chipMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        Image {
                            width: 20
                            height: 20
                            sourceSize: Qt.size(40, 40)
                            anchors.verticalCenter: parent.verticalCenter
                            source: Quickshell.iconPath(chip.modelData.desktopEntry || (chip.modelData.identity ?? "").toLowerCase(), "audio-x-generic")
                        }
                        Text {
                            text: chip.modelData.identity || "Player"
                            color: chip.current ? Theme.crust : Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(13)
                            font.bold: chip.current
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.select(chip.modelData)
                    }
                }
            }
            CtrlButton {
                glyph: "lyrics"
                on: root.showLyrics
                onClicked: Config.opt.mediaShowLyrics = !Config.mediaShowLyrics
            }
        }
    }

    // ================= Derecha: letra =================
    Item {
        id: lyricsArea
        visible: root.showLyrics
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: 200

        // Las líneas se desvanecen al acercarse a los bordes de arriba y abajo: máscara de
        // transparencia (vale con cualquier fondo de la isla, también el del notch)
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: lyricsFade
            // Umbral a la mitad con la máxima suavidad: el degradado de la máscara se respeta
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Item {
            id: lyricsFade
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.22; color: "white" }
                    GradientStop { position: 0.78; color: "white" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }

        // Sincronizada: la línea actual centrada y resaltada. El espacio vacío de media altura
        // arriba y abajo deja que la primera (y la última) línea queden en el centro
        ListView {
            id: lyricList
            anchors.fill: parent
            anchors.margins: 12
            visible: Lyrics.synced
            clip: true
            model: Lyrics.lines
            spacing: 12
            interactive: false
            highlightFollowsCurrentItem: false
            // Al abrir el panel la lista aún está oculta y sin colocar: se centra al hacerse
            // visible o cambiar de tamaño (en pausa la línea no cambia y no habría otro intento)
            onVisibleChanged: if (visible) Qt.callLater(root.syncLyric)
            onHeightChanged: Qt.callLater(root.syncLyric)
            onCountChanged: Qt.callLater(root.syncLyric)
            Behavior on contentY {
                enabled: !Theme.reduceMotion
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }
            header: Item {
                width: 1
                height: lyricList.height / 2
            }
            footer: Item {
                width: 1
                height: lyricList.height / 2
            }
            delegate: Text {
                required property int index
                required property var modelData
                width: ListView.view.width
                text: modelData.text || "♪"
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: index === root.lyricIndex ? Theme.text : Theme.tertiaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(index === root.lyricIndex ? 22 : 17)
                font.bold: index === root.lyricIndex
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }

        // Sin sincronizar: el texto entero, con scroll
        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            visible: !Lyrics.synced && Lyrics.plain !== ""
            clip: true
            contentHeight: plainText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Text {
                id: plainText
                width: parent.width
                text: Lyrics.plain
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(17)
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 32
            visible: !Lyrics.synced && Lyrics.plain === ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Lyrics.loading ? "Looking for lyrics…" : Lyrics.instrumental ? "Instrumental" : root.player ? "No lyrics found" : ""
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }

    // Botón redondo de icono; `big` = reproducir/pausa, `on` = resaltado (aleatorio, repetir, letra)
    component CtrlButton: Rectangle {
        id: cb
        property string glyph: ""
        property bool big: false
        property bool on: false
        signal clicked
        width: big ? 48 : 32
        height: big ? 44 : 32
        radius: big ? 14 : 16
        opacity: enabled ? 1 : 0.35
        color: big ? Theme.green : (on ? Theme.selectedFill : (cbMouse.containsMouse ? Theme.panelCardHi : "transparent"))
        anchors.verticalCenter: parent.verticalCenter
        Text {
            anchors.centerIn: parent
            text: cb.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: cb.big ? 26 : 20
            color: cb.big ? Theme.crust : (cb.on ? Theme.green : Theme.text)
        }
        MouseArea {
            id: cbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }
}
