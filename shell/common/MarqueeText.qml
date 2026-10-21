// Texto de una línea que, si no cabe, se desplaza en bucle (con una copia detrás para que el
// bucle no tenga salto y una pausa al principio de cada vuelta). Si cabe, queda quieto (a la
// izquierda o centrado con `centered`). Lo usan MediaCard y el panel de música.
import QtQuick

Item {
    id: mq
    property string text: ""
    property alias font: label.font
    property alias color: label.color
    property bool centered: false
    readonly property bool overflowing: label.implicitWidth > width
    readonly property real gap: 40
    property real shift: 0 // desplazamiento de la animación
    height: label.implicitHeight
    clip: true

    Row {
        id: track
        x: (mq.centered && !mq.overflowing ? (mq.width - label.implicitWidth) / 2 : 0) + mq.shift
        spacing: mq.gap
        Text {
            id: label
            text: mq.text
            color: "#f5f7f6"
            font.bold: true
        }
        Text {
            visible: mq.overflowing
            text: mq.text
            color: label.color
            font: label.font
        }
    }
    SequentialAnimation {
        running: mq.overflowing && mq.visible && !Theme.reduceMotion
        loops: Animation.Infinite
        onRunningChanged: if (!running) mq.shift = 0
        PauseAnimation { duration: 1500 }
        NumberAnimation {
            target: mq
            property: "shift"
            from: 0
            to: -(label.implicitWidth + mq.gap)
            duration: (label.implicitWidth + mq.gap) * 28 // ~36 px/s
        }
    }
    onTextChanged: shift = 0
}
