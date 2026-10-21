pragma Singleton
// Servidor de notificaciones. OJO: sustituye a dunst (no pueden correr los dos).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../common"

Singleton {
    id: root

    // Emite cuando llega una notificación nueva (para el "peek" de la isla)
    signal received(var notif)
    // Una notificación con progreso (pista "value") llegó al 100 %
    signal progressDone(var notif)

    // Contador "reciente" para el panel Status (vuelve a 0 tras un rato de calma)
    property int count: 0

    // Notificaciones activas (tracked) para el centro de control
    readonly property var list: server.trackedNotifications
    readonly property int activeCount: server.trackedNotifications?.values?.length ?? 0

    // Clic en una notificación: su acción "default" (p.ej. Firefox enfoca la pestaña). Solo esa:
    // las demás ("Marcar como leído"…) van en sus botones. Sin ella, abre la app que la mandó.
    // Al invocar una acción, Quickshell la cierra solo si no es residente.
    function activate(n: var): void {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) {
            def.invoke();
            return;
        }
        openApp(n);
        if (!n.resident)
            n.dismiss();
    }

    // Enfoca la ventana de la app de la notificación o, si no está abierta, la lanza
    function openApp(n: var): void {
        const entry = (n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null) ?? DesktopEntries.heuristicLookup(n.appName);
        const ids = [n.desktopEntry, entry?.id, entry?.startupClass, n.appName].filter(Boolean).map(s => s.toLowerCase());
        const win = ToplevelManager.toplevels.values.find(t => ids.includes((t.appId ?? "").toLowerCase()));
        if (win)
            win.activate();
        else
            entry?.execute();
    }

    // Registro de lo que trae cada notificación (sin título ni texto), para ver qué acciones y
    // pistas mandan las apps de verdad. Se queda con las últimas 300.
    readonly property string logPath: Quickshell.env("HOME") + "/.cache/salchipapa-shell/notifications.log"
    function log(n: var): void {
        const h = n.hints ?? {};
        const hints = {};
        for (const k of Object.keys(h))
            hints[k] = typeof h[k] === "string" || typeof h[k] === "number" || typeof h[k] === "boolean" ? h[k] : typeof h[k];
        const line = JSON.stringify({
            time: new Date().toISOString(),
            app: n.appName,
            desktopEntry: n.desktopEntry,
            appIcon: n.appIcon,
            image: n.image !== "",
            urgency: n.urgency,
            actions: n.actions.map(a => ({ id: a.identifier, text: a.text })),
            inlineReply: n.hasInlineReply,
            resident: n.resident,
            transient: n.transient,
            expireTimeout: n.expireTimeout,
            hints: hints
        });
        pendingLog.push(line);
        logTimer.restart();
    }

    // Se escriben juntas: si llegan varias seguidas, un exec con el proceso en marcha lo cortaría
    property var pendingLog: []
    Timer {
        id: logTimer
        interval: 500
        onTriggered: {
            if (logProc.running) {
                restart();
                return;
            }
            const lines = root.pendingLog.join("\n");
            root.pendingLog = [];
            logProc.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")"; printf "%s\n" "$1" >> "$2"; tail -n 300 "$2" > "$2.tmp" && mv "$2.tmp" "$2"', "sh", lines, root.logPath]);
        }
    }
    Process {
        id: logProc
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
        // Respuesta desde la notificación (Telegram, KDE Connect…) y el historial del centro de control
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.count += 1;
            resetTimer.restart();
            root.playSound(notif);
            root.log(notif);
            root.received(notif);
            // Las apps actualizan el progreso en la misma notificación (no llega otra)
            let done = false;
            notif.hintsChanged.connect(() => {
                const v = notif.hints?.value;
                if (!done && typeof v === "number" && v >= 100) {
                    done = true;
                    root.progressDone(notif);
                }
            });
        }
    }
}
