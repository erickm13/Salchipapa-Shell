pragma Singleton
// Servidor de notificaciones. OJO: sustituye a dunst (no pueden correr los dos).
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Emite cuando llega una notificación nueva (para el "peek" de la isla)
    signal received(string appName, string summary, string body)

    // Contador "reciente" para el panel Status (vuelve a 0 tras un rato de calma)
    property int count: 0

    // Notificaciones activas (tracked) para el centro de control
    readonly property var list: server.trackedNotifications
    readonly property int activeCount: server.trackedNotifications?.values?.length ?? 0

    function clearAll(): void {
        const vs = server.trackedNotifications.values.slice();
        for (const n of vs)
            n.dismiss();
    }

    Timer {
        id: resetTimer
        interval: 8000
        onTriggered: root.count = 0
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.count += 1;
            resetTimer.restart();
            root.received(notif.appName ?? "", notif.summary ?? "", notif.body ?? "");
        }
    }
}
