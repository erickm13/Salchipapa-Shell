// Valor de un deslizador con botones − / + a los lados, para ajustarlo de uno en uno (mantener
// pulsado repite). Lo usan PxSlider (Settings.qml) y SettingSliderRow.
import QtQuick
import "../common"

Row {
    id: stepper
    property string text: ""
    signal step(int dir)

    spacing: 4
    height: 24

    component StepButton: Rectangle {
        id: btn
        property string glyph: ""
        property int dir: 1
        width: 24
        height: 24
        radius: 12
        color: btnMouse.pressed ? Theme.green : (btnMouse.containsMouse ? Theme.panelCardHi : Qt.rgba(1, 1, 1, 0.05))
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btnMouse.pressed ? Theme.crust : Theme.secondaryText
            font.family: "Material Symbols Rounded"
            font.pixelSize: Theme.iconPx(16)
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                stepper.step(btn.dir);
                holdTimer.interval = 380;
                holdTimer.start();
            }
            onReleased: holdTimer.stop()
            onCanceled: holdTimer.stop()
        }
        Timer {
            id: holdTimer
            repeat: true
            onTriggered: {
                interval = 60;
                stepper.step(btn.dir);
            }
        }
    }

    StepButton {
        glyph: "remove"
        dir: -1
    }
    Text {
        width: Math.max(implicitWidth + 8, 58)
        height: parent.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: stepper.text
        color: Theme.text
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(13)
    }
    StepButton {
        glyph: "add"
        dir: 1
    }
}
