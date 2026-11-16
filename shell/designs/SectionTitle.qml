// Título de un bloque de ajustes: mayúsculas, gris secundario (mismo estilo que el de SettingGroup)
import QtQuick
import "../common"

Text {
    width: parent ? parent.width : implicitWidth
    color: Theme.secondaryText
    font.family: Theme.bodyFontFamily
    font.pixelSize: Theme.fontPx(11)
    font.bold: true
    font.letterSpacing: 0.8
    font.capitalization: Font.AllUppercase
    leftPadding: 4
    topPadding: 12
    bottomPadding: 1
}
