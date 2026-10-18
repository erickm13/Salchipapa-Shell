pragma ComponentBehavior: Bound
// Ala lateral del notch: cuarto de círculo CÓNCAVO que funde el notch con el borde
// superior de la pantalla. `left` = ala izquierda (espejo). Relleno = negro del notch.
import QtQuick
import QtQuick.Shapes

Shape {
    id: wing

    property int size: 18
    property color fill: "#0b0b0e"
    property bool mirror: false

    width: size
    height: size

    // CurveRenderer = curvas suaves con AA por GPU (el renderer por defecto se ve dentado)
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    ShapePath {
        fillColor: wing.fill
        strokeWidth: 0
        startX: wing.mirror ? wing.size : 0
        startY: 0
        PathLine {
            x: wing.mirror ? 0 : wing.size
            y: 0
        }
        PathAngleArc {
            centerX: wing.mirror ? 0 : wing.size
            centerY: wing.size
            radiusX: wing.size
            radiusY: wing.size
            startAngle: -90
            sweepAngle: wing.mirror ? 90 : -90
        }
        PathLine {
            x: wing.mirror ? wing.size : 0
            y: 0
        }
    }
}
