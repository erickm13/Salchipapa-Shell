pragma ComponentBehavior: Bound
// Tarjeta de música (estilo Android): portada desenfocada de fondo, icono de la app y salida de
// audio arriba, título/artista y reproducir/pausa, y abajo anterior, progreso ondulado (arrastrable
// si el reproductor deja buscar), siguiente, aleatorio y repetir (MPRIS no tiene "me gusta").
// Variantes: grande (pantalla de bloqueo), `compact` (aviso de música de la isla) y `mini` (una
// fila: vista expandida de la isla). El título se desplaza en bucle si no cabe. No importa
// servicios: el reproductor y los textos se le pasan desde fuera.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item {
    id: card
    property var player: null // MprisPlayer
    property string title: ""
    property string artist: ""
    property string sinkName: "" // salida de audio (pastilla de arriba a la derecha; no en compact)
    property bool compact: false
    property bool mini: false
    property bool showControls: true
    property real radius: 24
    // Medidas de la versión compacta (isla) y de la grande (pantalla de bloqueo)
    readonly property real buttonSize: compact ? 32 : 36

    readonly property string art: player?.trackArtUrl ?? ""
    readonly property real length: player?.length ?? 0
    property real position: 0
    // MPRIS no notifica la posición sola: se pide cada segundo mientras suena
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: card.visible && !!card.player
        onTriggered: {
            card.player?.positionChanged();
            card.position = card.player?.position ?? 0;
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: card.radius
        color: "#1b2422"
        // Portada desenfocada y oscurecida
        Image {
            id: musicArt
            anchors.fill: parent
            source: card.art
            sourceSize.width: 600
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: musicArt
            visible: musicArt.status === Image.Ready
            blurEnabled: true
            blur: 0.45
            blurMax: 32
            saturation: 0.15
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#8c000000" }
                GradientStop { position: 0.55; color: "#66000000" }
                GradientStop { position: 1; color: "#b3000000" }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.color: "#30ffffff"
    }

    // ---- Arriba: app y salida de audio ----
    Image {
        id: appIcon
        visible: !card.mini
        x: card.compact ? 16 : 20
        y: card.compact ? playBtn.y + (playBtn.height - height) / 2 : 18
        width: card.compact ? 22 : 26
        height: width
        sourceSize: Qt.size(52, 52)
        source: Quickshell.iconPath(card.player?.desktopEntry || (card.player?.identity ?? "").toLowerCase(), "audio-x-generic")
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 16
        width: Math.min(sinkRow.implicitWidth + 24, parent.width / 2)
        height: 30
        radius: 15
        color: "#40ffffff"
        visible: !card.compact && !card.mini && sinkText.text !== ""
        Row {
            id: sinkRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: "speaker"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: "#f5f7f6"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: sinkText
                width: Math.min(implicitWidth, card.width / 2 - 52)
                text: card.sinkName
                color: "#f5f7f6"
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- Centro: título, artista y reproducir/pausa ----
    Column {
        visible: !card.mini
        anchors.left: card.compact ? appIcon.right : parent.left
        anchors.leftMargin: card.compact ? 10 : 22
        anchors.right: playBtn.left
        anchors.rightMargin: 16
        anchors.verticalCenter: playBtn.verticalCenter
        spacing: 4
        MarqueeText {
            width: parent.width
            text: card.title || "Nothing playing"
            font.family: Theme.displayFontFamily
            font.pixelSize: card.compact ? 15 : 20
        }
        Text {
            width: parent.width
            text: card.artist
            color: "#c8d2cf"
            font.family: Theme.bodyFontFamily
            font.pixelSize: card.compact ? 12 : 14
            elide: Text.ElideRight
            visible: text.length > 0
        }
    }
    Rectangle {
        id: playBtn
        visible: !card.mini
        anchors.right: parent.right
        anchors.rightMargin: card.compact ? 12 : 18
        y: card.compact ? 12 : 66
        width: card.compact ? 44 : 58
        height: width
        radius: card.compact ? 14 : 18
        color: playMouse.containsMouse ? "#66ffffff" : "#4dffffff"
        Text {
            anchors.centerIn: parent
            text: card.player?.isPlaying ? "pause" : "play_arrow"
            font.family: "Material Symbols Rounded"
            font.pixelSize: card.compact ? 24 : 30
            color: "#f5f7f6"
        }
        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.player?.togglePlaying()
        }
    }

    // ---- Mini: miniatura, título/artista y anterior/pausa/siguiente en una fila ----
    Row {
        visible: card.mini
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 9
        ClippingRectangle {
            width: 34
            height: 34
            radius: 9
            color: "#33ffffff"
            anchors.verticalCenter: parent.verticalCenter
            Image {
                anchors.fill: parent
                source: card.art
                sourceSize.width: 68
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "music_note"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: Theme.green
                visible: card.art === ""
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - (card.showControls ? 3 * 28 : 0) - 2 * parent.spacing
            spacing: 1
            MarqueeText {
                width: parent.width
                text: card.title || "Nothing playing"
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(13)
            }
            Text {
                width: parent.width
                text: card.artist
                color: "#c8d2cf"
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }
        Row {
            visible: card.showControls
            anchors.verticalCenter: parent.verticalCenter
            MusicButton {
                size: 28
                glyph: "skip_previous"
                enabled: card.player?.canGoPrevious ?? false
                onClicked: card.player?.previous()
            }
            MusicButton {
                size: 28
                glyph: card.player?.isPlaying ? "pause" : "play_arrow"
                onClicked: card.player?.togglePlaying()
            }
            MusicButton {
                size: 28
                glyph: "skip_next"
                enabled: card.player?.canGoNext ?? false
                onClicked: card.player?.next()
            }
        }
    }

    // ---- Abajo: anterior, progreso, siguiente, aleatorio, repetir ----
    Row {
        id: controlsRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.compact ? 8 : 14
        anchors.rightMargin: card.compact ? 8 : 14
        anchors.bottomMargin: card.compact ? 8 : 14
        height: card.buttonSize
        spacing: 4
        visible: card.showControls && !card.mini

        MusicButton {
            glyph: "skip_previous"
            enabled: card.player?.canGoPrevious ?? false
            onClicked: card.player?.previous()
        }
        Item {
            id: seekBar
            width: controlsRow.width - 4 * card.buttonSize - 4 * controlsRow.spacing
            height: card.buttonSize
            WavyProgress {
                anchors.fill: parent
                value: card.length > 0 ? card.position / card.length : 0
                animating: card.visible && (card.player?.isPlaying ?? false) && !Theme.reduceMotion
                seekable: card.player?.canSeek ?? false
                onSeeked: v => {
                    card.position = v * card.length;
                    if (card.player)
                        card.player.position = card.position;
                }
            }
        }
        MusicButton {
            glyph: "skip_next"
            enabled: card.player?.canGoNext ?? false
            onClicked: card.player?.next()
        }
        MusicButton {
            glyph: "shuffle"
            enabled: card.player?.shuffleSupported ?? false
            active: card.player?.shuffle ?? false
            onClicked: card.player.shuffle = !card.player.shuffle
        }
        MusicButton {
            glyph: card.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            enabled: card.player?.loopSupported ?? false
            active: (card.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
            // Sin repetir → lista → canción → sin repetir
            onClicked: {
                const p = card.player;
                p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
            }
        }
    }

    // Botón de icono de la fila de abajo; `active` lo resalta (aleatorio/repetir encendidos)
    component MusicButton: Item {
        id: mb
        property string glyph: ""
        property bool active: false
        property real size: card.buttonSize
        signal clicked
        width: size
        height: size
        opacity: enabled ? 1 : 0.35
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: mbMouse.containsMouse ? "#33ffffff" : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: mb.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: mb.size * 0.62
            color: mb.active ? Theme.green : "#f5f7f6"
        }
        MouseArea {
            id: mbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }
}
