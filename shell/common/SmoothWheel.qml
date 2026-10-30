// Rueda del ratón con desplazamiento suave para una lista (ListView/Flickable). Sin esto, cada
// muesca salta de golpe y en un monitor de 165 Hz se ve a tirones. El touchpad ya manda
// desplazamientos finos, así que lo sigue llevando el propio Flickable.
// Uso: `SmoothWheel { flickable: miLista }` dentro de la lista.
import QtQuick

WheelHandler {
    id: h

    required property Flickable flickable
    property real step: 120 // px por muesca
    property real dest: 0

    acceptedDevices: PointerDevice.Mouse
    target: null

    onWheel: event => {
        const f = flickable;
        const min = f.originY;
        const max = f.originY + Math.max(0, f.contentHeight - f.height);
        // Varias muescas seguidas se suman al destino en curso, no a la posición del momento
        const from = anim.running ? dest : f.contentY;
        dest = Math.max(min, Math.min(max, from - event.angleDelta.y / 120 * step));
        anim.to = dest;
        anim.restart();
        event.accepted = true;
    }

    property NumberAnimation anim: NumberAnimation {
        target: h.flickable
        property: "contentY"
        duration: Theme.reduceMotion ? 0 : 180
        easing.type: Easing.OutCubic
    }
}
