// Hace usable con teclado un control que solo tenía MouseArea: se pone dentro del control
// (ocupa todo su área y no tapa los clics), recibe el foco con Tab o con las flechas, dibuja el
// marco verde y Espacio/Enter emiten `activated`. ←/→ pasan al control anterior/siguiente, que
// es lo natural en filas de chips, colores o tarjetas.
import QtQuick
import "../common"

Item {
    id: kb
    property real radius: Theme.radiusMedium
    // Controles con dos acciones (p. ej. Wi‑Fi: el icono enciende, el resto abre detalles):
    // Espacio = activated, Enter = altActivated
    property bool hasAlt: false
    signal activated
    signal altActivated

    anchors.fill: parent
    activeFocusOnTab: true
    onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(kb)
    Keys.onUpPressed: KeyNav.move(kb, false)
    Keys.onDownPressed: KeyNav.move(kb, true)
    Keys.onLeftPressed: KeyNav.move(kb, false)
    Keys.onRightPressed: KeyNav.move(kb, true)
    Keys.onSpacePressed: kb.activated()
    Keys.onReturnPressed: kb.hasAlt ? kb.altActivated() : kb.activated()
    Keys.onEnterPressed: kb.hasAlt ? kb.altActivated() : kb.activated()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: kb.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.green
        visible: kb.activeFocus
    }
}
