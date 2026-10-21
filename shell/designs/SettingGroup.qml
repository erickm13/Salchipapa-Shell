// Tarjeta que agrupa filas de ajustes (SettingToggleRow, SettingSliderRow…) una debajo de otra,
// con un título opcional encima (mismo estilo que los títulos de sección de Settings.qml).
// La usan las páginas de Ajustes que viven en su propio archivo (Notifications, Lock Screen…).
import QtQuick
import "../common"

Item {
    id: group
    property string title: ""
    default property alias rows: rowsColumn.data

    implicitHeight: card.y + card.height
    height: implicitHeight

    Text {
        id: titleText
        visible: group.title !== ""
        width: parent.width
        text: group.title
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(12)
        font.capitalization: Font.AllUppercase
        leftPadding: 2
    }

    Rectangle {
        id: card
        y: group.title !== "" ? titleText.height + 8 : 0
        width: parent.width
        height: rowsColumn.implicitHeight
        radius: Theme.radiusMedium
        color: Theme.panelCard
        clip: true

        Column {
            id: rowsColumn
            width: parent.width
            spacing: 0
        }
    }
}
