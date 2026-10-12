pragma Singleton
// Servidor de notificaciones. OJO: sustituye a dunst (no pueden correr los dos).
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Emite cuando llega una notificación nueva (para el "peek" de la isla)
    signal received(string appName, string summary, string body)

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.received(notif.appName ?? "", notif.summary ?? "", notif.body ?? "");
        }
    }
}
