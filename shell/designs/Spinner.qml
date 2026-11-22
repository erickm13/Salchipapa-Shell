// Indicador de carga: un arco que gira (icono progress_activity de Material Symbols).
// Uso: Spinner { size: 18; color: Theme.green; running: algoPendiente }
import QtQuick
import "../common"

Text {
    id: spin
    property real size: 18
    property bool running: true

    visible: running
    text: "progress_activity"
    font.family: "Material Symbols Rounded"
    font.pixelSize: Theme.iconPx(size)
    font.weight: Theme.iconWeight
    color: Theme.green
    width: font.pixelSize
    height: font.pixelSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    RotationAnimator on rotation {
        running: spin.running && spin.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
