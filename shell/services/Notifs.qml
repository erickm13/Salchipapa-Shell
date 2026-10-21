pragma Singleton
// Servidor de notificaciones. OJO: sustituye a dunst (no pueden correr los dos).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../common"

Singleton {
    id: root

    // Emite cuando llega una notificación nueva (para el "peek" de la isla)
    signal received(var notif, string appName, string summary, string body, bool urgent)

    // Contador "reciente" para el panel Status (vuelve a 0 tras un rato de calma)
    property int count: 0

    // Notificaciones activas (tracked) para el centro de control
    readonly property var list: server.trackedNotifications
    readonly property int activeCount: server.trackedNotifications?.values?.length ?? 0

    // Clic en una notificación: ejecuta su acción por defecto (p.ej. Firefox enfoca la pestaña).
    function activate(n: var): void {
        let action = null;
        for (let i = 0; i < n.actions.length; i++) {
            if (!action || n.actions[i].identifier === "default")
                action = n.actions[i];
        }
        if (action)
            action.invoke();
        else
            n.dismiss();
    }

    // Sonido al llegar (la spec deja el sonido al servidor). Respeta Focus/Game mode, el ajuste
    // y las pistas `suppress-sound`, `sound-file` y `sound-name` que mande la app.
    function playSound(n: var): void {
        const h = n.hints ?? {};
        if (!Config.notificationSound || Quick.silenced || h["suppress-sound"])
            return;
        if (h["sound-file"])
            soundProc.command = ["pw-play", h["sound-file"]];
        else if (h["sound-name"])
            soundProc.command = ["canberra-gtk-play", "-i", h["sound-name"]];
        else
            soundProc.command = ["pw-play", "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"];
        soundProc.running = false;
        soundProc.running = true;
    }

    Process {
        id: soundProc
    }

    function clearAll(): void {
        const vs = server.trackedNotifications.values.slice();
        for (const n of vs)
            n.dismiss();
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "clearNotifs"
        description: "Borrar todas las notificaciones"
        onPressed: root.clearAll()
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
        // Firefox (y otras apps) descartan sus avisos si el servidor no anuncia "actions".
        actionsSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.count += 1;
            resetTimer.restart();
            root.playSound(notif);
            root.received(notif, notif.appName ?? "", notif.summary ?? "", notif.body ?? "", notif.urgency === NotificationUrgency.Critical);
        }
    }
}
