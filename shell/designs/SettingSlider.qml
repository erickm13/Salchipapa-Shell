pragma ComponentBehavior: Bound
// Slider en píldora reutilizable: icono + relleno arrastrable + porcentaje.
// Lo usan el centro de control (Sound/Display) y las subpáginas (brillo/volumen).
import QtQuick
import "../common"

Item {
    id: sr

    property string glyph: ""
    property real value: 0 // 0..1
    property color accent: Theme.green
    property bool enabled: true
    signal moved(real v)
    signal iconTapped

    implicitHeight: 30

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: trackMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard
        opacity: sr.enabled ? 1 : 0.5
        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: parent.radius
            // Se anima el nivel, no el ancho: si se animara el ancho, al encogerse el panel (la
            // isla cambia de tamaño al abrirlo) el relleno iba con retraso y se salía de la barra
            property real shown: Math.max(0, Math.min(1, sr.value))
            Behavior on shown {
                NumberAnimation {
                    duration: Theme.reduceMotion ? 0 : 90
                }
            }
            width: Math.min(parent.width, Math.max(height, parent.width * shown))
            color: sr.accent
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: sr.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: Theme.iconPx(20)
            font.weight: Theme.iconWeight
            color: Theme.islandBg
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: sr.iconTapped()
            }
        }

        Text {
            font.family: Theme.bodyFontFamily
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(sr.value * 100) + "%"
            color: fill.width > parent.width - 44 ? Theme.islandBg : Theme.secondaryText
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
        }

        MouseArea {
            id: trackMouse
            anchors.fill: parent
            enabled: sr.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function setFromX(x) {
                sr.moved(Math.max(0, Math.min(1, x / width)));
            }
            onPressed: mouse => setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x);
            }
        }
    }
}
