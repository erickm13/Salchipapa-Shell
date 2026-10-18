pragma ComponentBehavior: Bound
// Card del centro de control: etiqueta + chevron + slider. Toda la card abre su subpágina
// (señal opened); el slider captura su propio arrastre, así que arrastrarlo no navega.
import QtQuick
import "../common"

Rectangle {
    id: card

    property string label: ""
    property string sliderGlyph: ""
    property real sliderValue: 0
    property color sliderAccent: Theme.green
    property bool sliderEnabled: true
    property int rowSize: 2
    signal opened
    signal sliderMoved(real v)
    signal sliderIconTapped

    height: rowSize >= 2 ? 82 : 60
    radius: Theme.radiusLarge
    color: cardMouse.containsMouse ? Qt.tint(Theme.panelCardHi, Theme.hoverFill) : Theme.panelCard
    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverDuration
        }
    }

    // Clic en la card (abre la página). Debajo del slider, que captura su arrastre.
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.opened()
    }

    Text {
        font.family: Theme.bodyFontFamily
        id: cardLabel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: 16
        text: card.label
        color: Theme.secondaryText
        font.pixelSize: Theme.fontPx(11)
        font.bold: true
    }
    Text {
        anchors.verticalCenter: cardLabel.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 14
        text: "chevron_right"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        color: cardMouse.containsMouse ? Theme.text : Theme.tertiaryText
    }

    SettingSlider {
        anchors.top: cardLabel.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 30
        glyph: card.sliderGlyph
        value: card.sliderValue
        accent: card.sliderAccent
        enabled: card.sliderEnabled
        onMoved: v => card.sliderMoved(v)
        onIconTapped: card.sliderIconTapped()
    }
}
