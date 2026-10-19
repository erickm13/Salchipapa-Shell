pragma ComponentBehavior: Bound
// Card del centro de control: grabar pantalla (scripts/record.sh). Sin grabar: Pantalla / Región
// y con o sin sonido (se recuerda en config.json). Grabando: tiempo, Pausa y Detener.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../services"

Rectangle {
    id: card

    property int rowSize: 1
    readonly property string script: Quickshell.shellDir + "/../scripts/record.sh"

    // Cierra la isla antes de empezar para que no salga en el vídeo
    function start(mode: string): void {
        Overlay.close();
        startProc.command = [script, mode, Config.recordSound ? "sound" : "nosound"];
        startDelay.restart();
    }

    height: rowSize >= 2 ? 82 : 60
    radius: Theme.radiusLarge
    color: Theme.panelCard

    Timer {
        id: startDelay
        interval: 350
        onTriggered: startProc.running = true
    }
    Process { id: startProc }

    // Icono + título + estado
    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 18
        color: Recorder.recording ? (Recorder.paused ? Theme.yellow : Theme.red) : Theme.panelCardHi
        Text {
            anchors.centerIn: parent
            text: Recorder.recording ? (Recorder.paused ? "pause" : "radio_button_checked") : "screen_record"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Recorder.recording ? Theme.crust : Theme.text
        }
    }
    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: buttons.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            width: parent.width
            text: "Screen recording"
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Recorder.recording ? (Recorder.paused ? "Pausado · " : "Grabando · ") + Recorder.elapsedText : (Config.recordSound ? "Con sonido" : "Sin sonido") + " · ~/Videos/Recordings"
            color: Recorder.recording ? (Recorder.paused ? Theme.yellow : Theme.red) : Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            elide: Text.ElideRight
        }
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Sin grabar
        IconPill {
            visible: !Recorder.recording
            glyph: Config.recordSound ? "volume_up" : "volume_off"
            active: Config.recordSound
            onClicked: Config.opt.recordSound = !Config.recordSound
        }
        TextPill {
            visible: !Recorder.recording
            glyph: "desktop_windows"
            label: "Pantalla"
            onClicked: card.start("screen")
        }
        TextPill {
            visible: !Recorder.recording
            glyph: "crop_free"
            label: "Región"
            onClicked: card.start("region")
        }

        // Grabando
        TextPill {
            visible: Recorder.recording
            glyph: Recorder.paused ? "play_arrow" : "pause"
            label: Recorder.paused ? "Reanudar" : "Pausa"
            onClicked: Recorder.togglePause()
        }
        TextPill {
            visible: Recorder.recording
            glyph: "stop"
            label: "Detener"
            danger: true
            onClicked: Recorder.stop()
        }
    }

    component TextPill: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        property bool danger: false
        signal clicked
        width: pillRow.implicitWidth + 18
        height: 30
        radius: 15
        color: danger ? (pillMouse.containsMouse ? Qt.lighter(Theme.red, 1.15) : Theme.red) : (pillMouse.containsMouse ? Qt.tint(Theme.panelCardHi, Theme.hoverFill) : Theme.panelCardHi)
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: pill.glyph
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: pill.danger ? Theme.crust : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: pill.label
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
                font.bold: pill.danger
                color: pill.danger ? Theme.crust : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component IconPill: Rectangle {
        id: ip
        property string glyph: ""
        property bool active: false
        signal clicked
        width: 30
        height: 30
        radius: 15
        color: active ? Theme.green : (ipMouse.containsMouse ? Qt.tint(Theme.panelCardHi, Theme.hoverFill) : Theme.panelCardHi)
        Text {
            anchors.centerIn: parent
            text: ip.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            color: ip.active ? Theme.crust : Theme.secondaryText
        }
        MouseArea {
            id: ipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ip.clicked()
        }
    }
}
