// Tarjeta que agrupa filas de ajustes (SettingToggleRow, SettingSliderRow…) una debajo de otra.
// La usan las páginas de Ajustes que viven en su propio archivo (Notifications, Lock Screen…).
import QtQuick
import "../common"

Rectangle {
    default property alias rows: rowsColumn.data
    implicitHeight: rowsColumn.implicitHeight
    height: implicitHeight
    radius: Theme.radiusMedium
    color: Theme.panelCard
    clip: true

    Column {
        id: rowsColumn
        width: parent.width
        spacing: 0
    }
}
