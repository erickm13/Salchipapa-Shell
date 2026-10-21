// Barra de progreso ondulada (Material 3): lo reproducido es una onda que avanza mientras
// `animating`; lo que falta, una línea recta más tenue, y un indicador vertical en medio.
// Si `seekable`, se arrastra y al soltar emite seeked(valor 0..1). La usan MediaCard y el panel
// de música de la isla.
import QtQuick
import QtQuick.Shapes

Item {
    id: wp
    property real value: 0 // 0..1
    property bool animating: false
    property bool seekable: false
    property color color: "#f5f7f6"
    property color trackColor: "#40ffffff"
    signal seeked(real value)

    // Mientras se arrastra se muestra la posición del dedo, no la del reproductor
    property real dragValue: -1
    readonly property bool dragging: seekMouse.pressed
    readonly property real shown: Math.max(0, Math.min(1, dragValue >= 0 ? dragValue : value))
    implicitHeight: 24

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: 16
        readonly property real split: width * wp.shown
        property real phase: 0
        NumberAnimation on phase {
            from: 0
            to: -2 * Math.PI
            duration: 1600
            loops: Animation.Infinite
            running: wp.animating && wp.visible
        }
        readonly property var wave: {
            const pts = [], amp = 3, wavelength = 18, mid = height / 2;
            const end = Math.max(0, split - 6);
            for (let x = 0; x <= end; x += 1.5)
                pts.push(Qt.point(x, mid + amp * Math.sin(2 * Math.PI * x / wavelength + phase)));
            if (pts.length === 0)
                pts.push(Qt.point(0, mid));
            return pts;
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: wp.color
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: track.wave }
            }
            ShapePath {
                strokeColor: wp.trackColor
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: Math.min(track.width, track.split + 6)
                startY: track.height / 2
                PathLine { x: track.width; y: track.height / 2 }
            }
        }
        Rectangle {
            x: track.split - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 18
            radius: 3
            color: wp.color
        }
    }

    MouseArea {
        id: seekMouse
        anchors.fill: parent
        enabled: wp.seekable
        preventStealing: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, (x - track.x) / track.width));
        }
        onPressed: mouse => wp.dragValue = at(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                wp.dragValue = at(mouse.x);
        }
        onReleased: {
            wp.seeked(wp.dragValue);
            wp.dragValue = -1;
        }
    }
}
