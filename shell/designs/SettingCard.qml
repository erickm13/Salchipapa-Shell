pragma ComponentBehavior: Bound
// Card del centro de control: etiqueta + chevron + slider. Toda la card abre su subpágina
// (señal opened); el slider captura su propio arrastre, así que arrastrarlo no navega.
// Grande (rowSize 2): etiqueta arriba y slider debajo. Compacta: todo en una fila centrada.
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

    // Geometría explícita (sin anclajes condicionales: al cambiar de modo en vivo, los anclajes
    // que pasan a `undefined` dejaban el slider con medidas viejas)
    readonly property bool compact: rowSize < 2
    readonly property real labelW: compact ? 62 : cardLabel.implicitWidth

    Text {
        font.family: Theme.bodyFontFamily
        id: cardLabel
        x: 16
        y: card.compact ? (card.height - height) / 2 : 12
        width: card.labelW
        elide: Text.ElideRight
        text: card.label
        color: Theme.secondaryText
        font.pixelSize: Theme.fontPx(11)
        font.bold: true
    }
    Text {
        id: chevron
        x: card.width - width - 14
        y: cardLabel.y + (cardLabel.height - height) / 2
        text: "chevron_right"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 18
        color: cardMouse.containsMouse ? Theme.text : Theme.tertiaryText
    }

    SettingSlider {
        x: card.compact ? cardLabel.x + card.labelW + 8 : 14
        y: card.compact ? (card.height - height) / 2 : cardLabel.y + cardLabel.height + 8
        width: card.compact ? chevron.x - 8 - x : card.width - 28
        height: 30
        glyph: card.sliderGlyph
        value: card.sliderValue
        accent: card.sliderAccent
        enabled: card.sliderEnabled
        onMoved: v => card.sliderMoved(v)
        onIconTapped: card.sliderIconTapped()
    }
}
