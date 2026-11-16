// Varios ajustes de sí/no relacionados en una sola fila: un título, una ayuda opcional y una
// pastilla por ajuste (encendida = activo). Sustituye a una lista larga de interruptores sueltos.
// `chips`: [{ label, key }], donde `key` es el nombre del ajuste en Config. Con `card`, la fila
// lleva su propio fondo (suelta en Settings.qml); sin él, va dentro de un SettingGroup.
// Teclado: ←/→ recorren las pastillas, Espacio/Enter cambia la marcada, ↑/↓ van a otra fila.
import QtQuick
import "../common"

Rectangle {
    id: row
    property string label: ""
    property string hint: ""
    property var chips: []
    property bool card: false
    property int cursor: 0

    width: parent ? parent.width : 400
    height: flow.y + flow.height + 14
    radius: Theme.radiusMedium
    color: card ? Theme.panelCard : "transparent"
    border.width: activeFocus ? 2 : 0
    border.color: Theme.green
    opacity: enabled ? 1 : 0.45

    function flip(i: int): void {
        const key = chips[i]?.key;
        if (key)
            Config.opt[key] = !Config[key];
    }
    activeFocusOnTab: true
    onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(row)
    Keys.onUpPressed: KeyNav.move(row, false)
    Keys.onDownPressed: KeyNav.move(row, true)
    Keys.onLeftPressed: cursor = Math.max(0, cursor - 1)
    Keys.onRightPressed: cursor = Math.min(chips.length - 1, cursor + 1)
    Keys.onSpacePressed: flip(cursor)
    Keys.onReturnPressed: flip(cursor)
    Keys.onEnterPressed: flip(cursor)

    Text {
        id: title
        x: 16
        y: 13
        text: row.label
        color: "#ffffff"
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(14)
    }
    Text {
        id: hintText
        visible: row.hint !== ""
        x: 16
        y: title.y + title.height + 2
        width: parent.width - 32
        text: row.hint
        color: Theme.secondaryText
        wrapMode: Text.Wrap
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(11)
    }
    Flow {
        id: flow
        x: 14
        y: (hintText.visible ? hintText.y + hintText.height : title.y + title.height) + 10
        width: parent.width - 28
        spacing: 6
        Repeater {
            model: row.chips
            delegate: Rectangle {
                id: chip
                required property var modelData
                required property int index
                // `label`: así el buscador de Ajustes encuentra cada ajuste por su nombre
                readonly property string label: modelData.label
                readonly property bool on: !!Config[modelData.key]
                width: chipRow.implicitWidth + 24
                height: 30
                radius: 15
                color: on ? Theme.green : (chipMouse.containsMouse ? Theme.panelCardHi : Qt.rgba(1, 1, 1, 0.05))
                border.width: row.activeFocus && row.cursor === index ? 2 : 0
                border.color: on ? "#ffffff" : Theme.green
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: chip.on ? "check" : "add"
                        color: chip.on ? Theme.crust : Theme.secondaryText
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Theme.iconPx(15)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: chip.modelData.label
                        color: chip.on ? Theme.crust : Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(12)
                        font.bold: chip.on
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        row.cursor = chip.index;
                        row.flip(chip.index);
                    }
                }
            }
        }
    }
}
