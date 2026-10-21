pragma Singleton
// Navegación con teclado en el panel de ajustes: las filas pasan el foco con ↑/↓ y la que lo
// recibe se desplaza a la vista dentro de su Flickable.
import QtQuick
import Quickshell

Singleton {
    // Siguiente/anterior control enfocable (los ocultos o desactivados se saltan solos)
    function move(item: Item, forward: bool): void {
        const next = item.nextItemInFocusChain(forward);
        if (next)
            next.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
    }

    function ensureVisible(item: Item): void {
        for (let p = item.parent; p; p = p.parent) {
            if (p.contentY === undefined || p.contentItem === undefined)
                continue;
            const y = item.mapToItem(p.contentItem, 0, 0).y;
            const margin = 12;
            if (y - margin < p.contentY)
                p.contentY = Math.max(0, y - margin);
            else if (y + item.height + margin > p.contentY + p.height)
                p.contentY = Math.min(Math.max(0, p.contentHeight - p.height), y + item.height + margin - p.height);
            return;
        }
    }
}
