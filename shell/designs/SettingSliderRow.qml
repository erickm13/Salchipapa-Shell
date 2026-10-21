// Fila de ajuste con slider, dentro de un SettingGroup. `unit` se pega tal cual al valor
// (" px", " s", "%"…). Mismas medidas que el PxSlider de Settings.qml.
// Lo guardado no cambia; solo cómo se muestra: valor / `divisor` con `decimals` decimales
// (ms → s con divisor 1000). `snap` redondea los valores a múltiplos suyos.
import QtQuick
import "../common"

Item {
    id: row
    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property string unit: ""
    property real divisor: 1
    property int decimals: 0
    property int snap: 1
    signal moved(int value)

    width: parent.width
    height: 58
    opacity: enabled ? 1 : 0.45

    // ←/→ en pasos de 1/20 del rango; con Shift, de `snap` en `snap`
    readonly property int step: Math.max(snap, Math.round((to - from) / 20 / snap) * snap)
    function nudge(dir: int, fine: bool): void {
        moved(Math.max(from, Math.min(to, value + dir * (fine ? snap : step))));
    }
    activeFocusOnTab: true
    onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(row)
    Keys.onUpPressed: KeyNav.move(row, false)
    Keys.onDownPressed: KeyNav.move(row, true)
    Keys.onLeftPressed: event => row.nudge(-1, event.modifiers & Qt.ShiftModifier)
    Keys.onRightPressed: event => row.nudge(1, event.modifiers & Qt.ShiftModifier)

    // Marco del control enfocado con el teclado
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusMedium
        color: "transparent"
        border.width: 2
        border.color: Theme.green
        visible: row.activeFocus
    }

    Text {
        id: rowLabel
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 12
        text: row.label
        color: Theme.text
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(14)
        elide: Text.ElideRight
    }
    Text {
        id: valueText
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 12
        text: Number((row.value / row.divisor).toFixed(row.decimals)) + row.unit
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(13)
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.top: rowLabel.bottom
        anchors.topMargin: 12
        height: 4
        radius: 2
        color: Theme.panelCardHi
        Rectangle {
            id: fill
            width: track.width * Math.max(0, Math.min(1, (row.value - row.from) / Math.max(1, row.to - row.from)))
            height: parent.height
            radius: 2
            color: Theme.green
        }
        Rectangle {
            width: 14
            height: 14
            radius: 7
            x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -18
            anchors.bottomMargin: -18
            enabled: row.enabled
            cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            function setAt(x: real): void {
                const v = row.from + Math.max(0, Math.min(1, x / track.width)) * (row.to - row.from);
                row.moved(Math.max(row.from, Math.min(row.to, Math.round(v / row.snap) * row.snap)));
            }
            onPressed: mouse => setAt(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    setAt(mouse.x);
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.divider
    }
}
