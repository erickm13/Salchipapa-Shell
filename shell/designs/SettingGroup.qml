// Tarjeta que agrupa filas de ajustes (SettingToggleRow, SettingSliderRow…) una debajo de otra,
// con un título opcional encima (mismo estilo que los títulos de sección de Settings.qml).
// La usan las páginas de Ajustes que viven en su propio archivo (Notifications, Lock Screen…).
import QtQuick
import "../common"

Item {
    id: group
    property string title: ""
    // Plegable: el título pasa a ser una cabecera dentro de la tarjeta (con `hint` debajo y una
    // flecha); al pulsarla aparecen las filas. Plegada al abrir, salvo `expanded: true`.
    property bool collapsible: false
    property bool expanded: false
    property string hint: ""
    readonly property bool open: !collapsible || expanded || Overlay.settingsRevealAll
    default property alias rows: rowsColumn.data

    implicitHeight: card.y + card.height
    height: implicitHeight

    Text {
        id: titleText
        visible: group.title !== "" && !group.collapsible
        width: parent.width
        text: group.title
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(11)
        font.bold: true
        font.letterSpacing: 0.8
        font.capitalization: Font.AllUppercase
        leftPadding: 4
        topPadding: 6
    }

    Rectangle {
        id: card
        y: titleText.visible ? titleText.height + 8 : 0
        width: parent.width
        height: (group.collapsible ? header.height : 0) + (group.open ? rowsColumn.implicitHeight : 0)
        radius: Theme.radiusMedium
        color: Theme.panelCard
        clip: true

        // Cabecera de la subsección
        Rectangle {
            id: header
            visible: group.collapsible
            width: parent.width
            height: 58
            color: headerMouse.containsMouse ? Qt.tint(Theme.panelCard, Theme.hoverFill) : "transparent"
            // `label`: el buscador de Ajustes la encuentra por su nombre
            readonly property string label: group.collapsible ? group.title : ""
            border.width: activeFocus ? 2 : 0
            border.color: Theme.green
            radius: Theme.radiusMedium

            activeFocusOnTab: group.collapsible
            onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(header)
            Keys.onUpPressed: KeyNav.move(header, false)
            Keys.onDownPressed: KeyNav.move(header, true)
            Keys.onSpacePressed: group.expanded = !group.expanded
            Keys.onReturnPressed: group.expanded = !group.expanded
            Keys.onEnterPressed: group.expanded = !group.expanded

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: chevron.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: group.title
                    color: "#ffffff"
                    elide: Text.ElideRight
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(14)
                }
                Text {
                    width: parent.width
                    visible: group.hint !== ""
                    text: group.hint
                    color: Theme.secondaryText
                    elide: Text.ElideRight
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                }
            }
            Text {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_right"
                color: Theme.secondaryText
                font.family: "Material Symbols Rounded"
                font.pixelSize: Theme.iconPx(20)
                rotation: group.open ? 90 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: group.expanded = !group.expanded
            }
        }

        Column {
            id: rowsColumn
            y: group.collapsible ? header.height : 0
            width: parent.width
            visible: group.open
            spacing: 0
        }
    }
}
