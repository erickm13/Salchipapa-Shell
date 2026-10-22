pragma ComponentBehavior: Bound
// Diseño "island": Dynamic Island estilo iPhone.
// Una ventana por pantalla. Estados: idle (compacto), expanded (hover) y
// peeks contextuales transitorios (media / volume / notif).
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../common"
import "../services"

PanelWindow {
    id: win

    // Fuente oficial actualizada (más glifos que la del sistema; ojo: se llaman igual y Qt puede
    // usar cualquiera de las dos, así que solo se usan glifos que estén en ambas).
    FontLoader {
        id: batterySymbols
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SalchipapaShell/MaterialSymbolsOutlined.ttf"
    }

    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    // Alto de la ventana: 620 bastan casi siempre; si la isla mide más (centro de control con
    // cards grandes + historial completo) crece, hasta el alto de la pantalla. Se ajusta UNA vez
    // al alto final (no en cada fotograma de la animación: redimensionar la superficie parpadea):
    // crece antes de que la isla se abra y encoge cuando termina de cerrarse.
    readonly property real neededHeight: catchOutside ? (win.screen?.height ?? 1080) : Math.min(win.screen?.height ?? 1080, Math.max(620, island.y + island.targetHeight + 60))
    // Con un modo abierto (launcher, temas, centro de control…) la ventana cubre la pantalla y un
    // clic fuera de la isla lo cierra (opción en Ajustes → Bar & Island)
    readonly property bool catchOutside: Overlay.mode !== "" && Config.islandCloseOnClickOutside
    property real windowHeight: 620
    implicitHeight: windowHeight
    onNeededHeightChanged: {
        if (neededHeight >= windowHeight) {
            shrinkTimer.stop();
            windowHeight = neededHeight;
        } else {
            shrinkTimer.restart();
        }
    }
    Timer {
        id: shrinkTimer
        interval: Theme.movementDuration + 100
        onTriggered: win.windowHeight = win.neededHeight
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: (Overlay.mode !== "" || island.showPolkit || island.notifReplying) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // -10: Hyprland ya deja 10 px de gaps_out arriba (lua/general.lua)
    exclusiveZone: Math.max(0, 34 + Config.topMargin - 10)

    // Solo la píldora captura el ratón; el resto deja pasar los clics (salvo con catchOutside)
    mask: Region {
        x: win.catchOutside ? 0 : island.x
        y: win.catchOutside ? 0 : island.y
        width: win.catchOutside ? win.width : island.width
        height: win.catchOutside ? win.height : island.height
    }

    // Clic fuera de la isla con un modo abierto → cerrarlo. Va antes que la isla (queda debajo), y
    // un clic en un hueco vacío DENTRO de la isla también llega aquí: solo cuenta si cae fuera
    MouseArea {
        anchors.fill: parent
        enabled: win.catchOutside
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            if (mouse.x < island.x || mouse.x > island.x + island.width || mouse.y < island.y || mouse.y > island.y + island.height)
                Overlay.close();
        }
    }

    Item {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        // Notch: pegado al borde superior (el -2 mete el borde de 1px fuera de pantalla para
        // que el cuerpo del pill bese el borde sin dejar línea). Pill: flotando con el gap.
        y: Config.notchMode ? -2 : Config.topMargin
        Behavior on y {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.OutCubic
            }
        }

        property bool ready: false
        property bool hovered: false
        property string peek: "" // "", "media", "volume", "notif", "keys"
        onPeekChanged: if (peek !== "keys")
            KeyCast.clearChips()
        readonly property bool showPolkit: PolicyAuth.active && (Hyprland.focusedMonitor?.name ? Hyprland.focusedMonitor.name === win.screen?.name : Quickshell.screens[0] === win.screen)
        readonly property string focusedApp: {
            const appId = ToplevelManager.activeToplevel?.appId || Hyprland.activeToplevel?.wayland?.appId || Hyprland.activeToplevel?.lastIpcObject?.["class"] || "";
            return String(appId).split(".").filter(Boolean).pop() || "";
        }

        // Una notificación nueva también debe verse si el dashboard está abierto.
        // El resto de overlays conserva prioridad sobre los peeks normales.
        readonly property string mode: showPolkit ? "polkit" : (peek === "notif" ? "notif" : (Overlay.mode !== "" ? Overlay.mode : (hovered ? "expanded" : (peek !== "" ? peek : "idle"))))
        // Nivel con battery_android_* (están en la fuente del sistema y en la de la shell); al cargar
        // se añade un rayo al lado. Los battery_charging_*_2 solo existen en la fuente nueva y, como
        // las dos se llaman igual, tras reiniciar qs a veces se usaba la del sistema y salía "_2".
        readonly property string batteryGlyph: Battery.percent >= 95 ? "battery_android_full" : Battery.percent >= 80 ? "battery_android_6" : Battery.percent >= 65 ? "battery_android_5" : Battery.percent >= 50 ? "battery_android_4" : Battery.percent >= 35 ? "battery_android_3" : Battery.percent >= 20 ? "battery_android_2" : Battery.percent >= 5 ? "battery_android_1" : "battery_android_0"
        readonly property string networkGlyph: Net.type === "ethernet" ? "lan" : Net.type === "wifi" ? (Net.wifiSignal >= 80 ? "signal_wifi_4_bar" : Net.wifiSignal >= 60 ? "network_wifi_3_bar" : Net.wifiSignal >= 35 ? "network_wifi_2_bar" : Net.wifiSignal >= 10 ? "network_wifi_1_bar" : "signal_wifi_0_bar") : "wifi_off"

        // Notch: fondo negro + alas laterales. Solo en reposo/peeks (no expandido/overlay).
        readonly property color notchBg: Theme.panelBg
        readonly property bool notchResting: Config.notchMode && (mode === "idle" || mode === "media" || mode === "volume" || mode === "brightness" || mode === "notif" || mode === "keys")

        // ¿Hay un scratchpad (workspace especial) mostrándose ahora?
        readonly property bool inSpecial: (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "") !== ""

        // Datos del peek de notificación
        // Cola de notificaciones por prioridad (críticas, normales, bajas) y, dentro de cada una, la
        // más nueva primero: la primera en grande, las siguientes en filas compactas (hasta
        // Config.notificationMaxVisible en total) y el resto en el "+N". Al acabar su tiempo, la
        // de arriba se va y sube la siguiente. Sin notificationQueueHidden, las del "+N" no
        // esperan en la cola: solo se cuentan (notifDropped) y siguen en el historial.
        // Se conserva al ocultarse para que no se vacíe mientras se desvanece.
        property var notifQueue: []
        property int notifSeq: 0
        readonly property var notifTop: notifQueue.length > 0 ? notifQueue[0] : null
        // La de arriba se lee en vivo de la notificación: las apps la actualizan en el sitio
        // (descargas: mismo id, otro "value"). Si ya se cerró, queda la copia de la cola.
        readonly property var notifObj: notifTop?.obj ?? null
        readonly property string notifApp: notifObj ? notifObj.appName : (notifTop?.app ?? "")
        readonly property string notifSummary: notifObj ? summaryOf(notifObj.summary, notifObj.body) : (notifTop?.summary ?? "")
        readonly property string notifBody: notifObj ? bodyOf(notifObj.summary, notifObj.body) : (notifTop?.body ?? "")
        readonly property string notifIcon: notifTop?.icon ?? ""
        readonly property string notifImage: notifTop?.image ?? ""
        readonly property bool notifUrgent: notifTop?.urgency === NotificationUrgency.Critical
        // Botones: las acciones que no son la del clic (como mucho 3) y "Reply" si admite respuesta
        readonly property var notifActions: notifObj ? notifObj.actions.filter(a => a.identifier !== "default").slice(0, 3) : []
        readonly property bool notifCanReply: notifObj?.hasInlineReply ?? false
        property bool notifReplying: false
        // Con progreso en marcha, la de arriba espera a que termine (hasta notificationProgressWait)
        property bool notifWaiting: false
        property bool notifWaitDone: false
        onNotifTopChanged: {
            notifWaiting = false;
            notifWaitDone = false;
            progressWaitTimer.stop();
        }
        onNotifValueChanged: checkProgress()
        // Progreso (pista "value", 0-100) o -1 si no trae
        readonly property int notifValue: {
            const v = notifObj?.hints?.value;
            return typeof v === "number" ? Math.max(0, Math.min(100, Math.round(v))) : -1;
        }
        property int notifDropped: 0
        readonly property var notifOlder: notifQueue.slice(1, Config.notificationMaxVisible)
        readonly property int notifExtra: Math.max(0, notifQueue.length - Config.notificationMaxVisible) + notifDropped
        property real notifShift: 0 // desplazamiento al subir la siguiente (anima a 0)
        // Sin la barra de tiempo, la parte de arriba se encoge lo que ocupaba (si no, los botones
        // quedan separados del texto)
        readonly property int notifHeadHeight: (notifBody !== "" ? 104 : 86) - (Config.notificationTimeoutBar ? 0 : 14)
        // Sin la barra de tiempo, los botones y el progreso suben a ocupar su sitio
        readonly property int notifExtrasLift: Config.notificationTimeoutBar ? 0 : 10
        readonly property int notifExtrasHeight: (notifValue >= 0 ? 22 : 0) + (notifActions.length > 0 || notifCanReply ? 46 : 0)
        readonly property int notifMainHeight: notifHeadHeight + Math.max(0, notifExtrasHeight - (notifExtrasHeight > 0 ? notifExtrasLift : 0))
        readonly property int notifRowHeight: 50
        property real notifProgress: 1 // barra de tiempo restante del peek
        readonly property color notifAccent: notifUrgent ? Theme.red : Theme.mauve

        // Estado del dashboard (expandido). Night light / Game mode viven en Quick (compartidos
        // con el centro de control).
        property real mediaPos: 0
        property var calendarMonth: new Date()
        property var selectedDate: new Date()
        readonly property var calendarMonthDate: new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1)
        readonly property int calendarFirstDayOffset: (calendarMonthDate.getDay() - Config.clockWeekStart + 7) % 7
        readonly property int calendarDaysInMonth: new Date(calendarMonthDate.getFullYear(), calendarMonthDate.getMonth() + 1, 0).getDate()

        function fmt(s: real): string {
            s = Math.max(0, Math.floor(s));
            const m = Math.floor(s / 60);
            const sec = s % 60;
            return m + ":" + (sec < 10 ? "0" + sec : sec);
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: island.mediaPos = Media.active?.position ?? 0
        }

        Component.onCompleted: ready = true

        function showPeek(name: string): void {
            peek = name;
            peekTimer.interval = name === "notif" ? (notifUrgent ? Config.notificationUrgentTimeout : Config.notificationPopupTimeout) : (name === "volume" || name === "brightness") ? Config.osdOnScreenTime : name === "keys" ? 2000 : (name === "media" ? 3000 : 1400);
            peekTimer.restart();
            if (name === "notif") {
                notifProgressAnim.duration = peekTimer.interval;
                notifProgressAnim.restart();
                if (notifWaiting)
                    pauseNotif();
                else
                    checkProgress();
            }
        }

        // Mientras la de arriba avanza (0-99 %), su tiempo se para; al llegar al 100 % se ve con su
        // tiempo completo. Si tarda más del límite, sigue el tiempo normal y se irá: volverá a salir
        // al terminar (Notifs.progressDone).
        function checkProgress(): void {
            if (peek !== "notif")
                return;
            const busy = notifValue >= 0 && notifValue < 100 && Config.notificationProgressWait > 0;
            if (busy && !notifWaiting && !notifWaitDone) {
                notifWaiting = true;
                pauseNotif();
                progressWaitTimer.restart();
            } else if (!busy && notifWaiting) {
                notifWaiting = false;
                progressWaitTimer.stop();
                peekTimer.interval = notifUrgent ? Config.notificationUrgentTimeout : Config.notificationPopupTimeout;
                notifProgressAnim.duration = peekTimer.interval;
                notifProgressAnim.restart();
                peekTimer.restart();
                if (hovered || notifReplying)
                    pauseNotif();
            }
        }

        Timer {
            id: progressWaitTimer
            interval: Config.notificationProgressWait * 1000
            onTriggered: {
                island.notifWaiting = false;
                island.notifWaitDone = true;
                island.resumeNotif();
            }
        }

        NumberAnimation {
            id: notifProgressAnim
            target: island
            property: "notifProgress"
            from: 1
            to: 0
        }

        Timer {
            id: peekTimer
            onTriggered: {
                if (island.peek === "notif")
                    island.removeEntry(island.notifTop, false);
                else
                    island.peek = "";
            }
        }

        function summaryOf(summary: string, body: string): string {
            // Sin título, el cuerpo hace de título
            return summary.length > 0 ? summary : cleanBody(body);
        }
        function bodyOf(summary: string, body: string): string {
            return Config.notificationShowBody && summary.length > 0 ? cleanBody(body) : "";
        }
        function cleanBody(body: string): string {
            return body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
        }

        // Críticas primero y, con la misma urgencia, la más nueva primero
        function sortNotifs(q: var): var {
            return q.slice().sort((a, b) => (b.urgency - a.urgency) || (b.seq - a.seq));
        }

        // Quita una de la cola (por la propia entrada: al invocar una acción, la app puede cerrar la
        // notificación y quitarla antes, y por índice se llevaría otra). Si era la de arriba, sube
        // la siguiente con su tiempo completo. Las transitorias (las que piden no quedarse en el
        // historial) se cierran al quitarlas; `closed`: ya la cerró la app.
        function removeEntry(entry: var, closed: bool): void {
            const i = notifQueue.indexOf(entry);
            if (i < 0)
                return;
            if (i === 0)
                notifReplying = false;
            if (notifQueue.length <= 1) {
                // La última se queda en la cola mientras se desvanece, pero sin el objeto si ya se
                // cerró: leer uno destruido daba "undefined"
                if (closed)
                    notifQueue = [Object.assign({}, entry, { obj: null })];
                peek = "";
            } else {
                notifQueue = notifQueue.filter(e => e !== entry);
            }
            if (!closed && entry.obj?.transient)
                entry.obj.expire();
            if (i === 0 && peek === "notif" && notifQueue.length > 0) {
                notifRiseAnim.restart();
                showPeek("notif");
                if (hovered)
                    pauseNotif();
            }
        }

        // Con el ratón encima (o escribiendo una respuesta) el tiempo se para; al salir sigue
        // con lo que le quedaba.
        function pauseNotif(): void {
            peekTimer.stop();
            notifProgressAnim.pause();
        }
        function resumeNotif(): void {
            if (peek !== "notif" || notifReplying || hovered || notifWaiting)
                return;
            peekTimer.interval = Math.max(800, notifProgressAnim.duration * notifProgress);
            peekTimer.restart();
            notifProgressAnim.resume();
        }
        onHoveredChanged: {
            if (peek !== "notif")
                return;
            if (hovered)
                pauseNotif();
            else
                resumeNotif();
        }

        function startReply(): void {
            notifReplying = true;
            pauseNotif();
        }
        function sendReply(text: string): void {
            if (text.trim() === "")
                return;
            const entry = notifTop;
            notifObj?.sendInlineReply(text);
            removeEntry(entry, false);
        }
        function cancelReply(): void {
            notifReplying = false;
            resumeNotif();
        }

        NumberAnimation {
            id: notifRiseAnim
            target: island
            property: "notifShift"
            from: island.notifRowHeight
            to: 0
            duration: Theme.movementDuration
            easing.type: Easing.OutCubic
        }

        // Tamaños por modo. Los paneles usan solo tres anchos (pequeño, mediano, grande) para que
        // no cambie de tamaño a cada paso; el launcher sigue su ajuste (por defecto el mediano).
        readonly property int widthSmall: 480
        readonly property int widthMedium: 600
        readonly property int widthLarge: 760
        width: ["power", "polkit", "control", "display", "sound", "media"].includes(mode) ? widthSmall : ["clipboard", "emoji", "expanded"].includes(mode) ? widthMedium : ["themes", "wallpaper", "perf", "music"].includes(mode) ? widthLarge : mode === "launcher" ? Config.launcherWidth : mode === "notif" ? Config.notificationWidth : mode === "calendar" || mode === "volume" || mode === "brightness" ? 300 : mode === "keys" ? Math.max(160, keysRow.implicitWidth + 40) : Math.max(Config.collapsedWidth, idleRow.implicitWidth + Config.innerPadding * 2)
        // Alto final del modo (sin animar): la ventana se ajusta a él una sola vez
        readonly property real targetHeight: mode === "power" ? (powerMenu.confirmAction === "" ? 110 : 200) : mode === "polkit" ? 250 : mode === "control" ? Math.min(controlContent.preferredHeight + 32, (win.screen?.height ?? 1080) - Config.topMargin - 60) : mode === "display" ? (142 + (Hyprland.monitors?.values?.length ?? 1) * 206) : mode === "sound" ? (213 + Math.min(Audio.sinks?.length ?? 1, 5) * 42 + Math.min(Audio.sources?.length ?? 1, 4) * 42 + Math.max(1, Math.min(Audio.apps?.length ?? 0, 4)) * 62) : mode === "launcher" ? (85 + Config.launcherRowsBeforeScrolling * Config.launcherRowHeight + (Config.launcherRowsBeforeScrolling - 1) * 2) : mode === "clipboard" ? 470 : mode === "emoji" ? 440 : mode === "perf" ? 704 : mode === "music" ? 300 : mode === "themes" ? 210 : mode === "wallpaper" ? 250 : mode === "calendar" ? 250 : mode === "expanded" ? 149 : mode === "notif" ? notifMainHeight + notifOlder.length * notifRowHeight : mode === "media" ? (Config.mediaShowControls ? 124 : 80) : mode === "volume" || mode === "brightness" ? 42 : mode === "keys" ? 56 : Config.barHeight
        height: targetHeight

        Behavior on width {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Theme.movementDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.spring
            }
        }

        SystemClock {
            id: clock
            precision: Config.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        // --- Disparadores de peeks contextuales ---
        Connections {
            target: KeyCast
            // Las teclas no tapan una notificación
            function onPressed(): void {
                if (island.peek !== "notif")
                    island.showPeek("keys");
            }
        }
        Connections {
            target: Audio
            function onVolumeChanged(): void {
                if (island.ready)
                    island.showPeek("volume");
            }
            function onMutedChanged(): void {
                if (island.ready)
                    island.showPeek("volume");
            }
        }
        Connections {
            target: Media
            function onTitleChanged(): void {
                if (island.ready && Media.hasPlayer)
                    island.showPeek("media");
            }
        }
        Connections {
            target: Brightness
            // Solo cambios del usuario: el valor también cambia al pasar a otro monitor
            function onAdjusted(): void {
                if (island.ready && Brightness.available)
                    island.showPeek("brightness");
            }
        }
        Connections {
            target: Notifs
            function onReceived(notif: var): void {
                if (!Quick.silenced) // Focus / Game mode: no molestar
                    island.addNotif(notif);
            }
            // La cerró la app (Firefox, p. ej., cierra las de una web que las reemplaza o ya se leyeron)
            function onNotifClosed(notif: var): void {
                const entry = island.notifQueue.find(e => e.obj === notif);
                if (entry)
                    island.removeEntry(entry, true);
            }
            // Una descarga que se dejó de mostrar antes de acabar vuelve a salir al terminar
            function onProgressDone(notif: var): void {
                if (Quick.silenced || (island.peek === "notif" && island.notifQueue.some(e => e.obj === notif)))
                    return;
                island.addNotif(notif);
            }
        }

        function addNotif(notif: var): void {
            const entry = {
                obj: notif,
                app: notif.appName,
                summary: summaryOf(notif.summary, notif.body),
                body: bodyOf(notif.summary, notif.body),
                // Un nombre de icono (notify-send -i firefox) llega como imagen "image://icon/…": se
                // busca como icono de app, que prueba Papirus y otras carpetas antes de rendirse
                // (el proveedor de Qt devuelve un cuadro magenta si no lo encuentra).
                icon: (notif?.image ?? "").startsWith("image://icon/") ? notif.image.slice(13) : (notif?.appIcon ?? ""),
                image: (notif?.image ?? "").startsWith("image://icon/") ? "" : (notif?.image ?? ""),
                urgency: notif?.urgency ?? NotificationUrgency.Normal,
                seq: ++notifSeq
            };
            // Si ya se está viendo alguna, la nueva entra en su sitio por prioridad. Mientras se
            // escribe una respuesta, la de arriba no cambia.
            const showing = peek === "notif";
            const prevTop = showing ? notifQueue[0] : null;
            let queue = showing ? notifQueue.concat([entry]) : [entry];
            queue = notifReplying && prevTop ? [prevTop].concat(sortNotifs(queue.slice(1))) : sortNotifs(queue);
            if (!showing)
                notifDropped = 0;
            if (!Config.notificationQueueHidden && queue.length > Config.notificationMaxVisible) {
                notifDropped += queue.length - Config.notificationMaxVisible;
                queue = queue.slice(0, Config.notificationMaxVisible);
            }
            notifQueue = queue;
            // Solo si cambia la de arriba se reinicia su tiempo
            if (queue[0] !== prevTop) {
                notifShift = 0;
                showPeek("notif");
                if (hovered)
                    pauseNotif();
            }
        }

        // ================= Píldora =================
        Item {
            id: pillShadow
            // Match Hyprland's effective pixel range and leave room for its offset.
            readonly property int pad: Math.max(2, WindowShadowSync.quickshellRange * 2 + Math.abs(Config.appearanceShadowOffset) + 2)
            x: -pad
            y: -pad
            width: island.width + pad * 2
            height: island.height + pad * 2
            layer.enabled: !Config.gameMode && WindowShadowSync.quickshellBlurRadius > 0 && WindowShadowSync.quickshellOpacity > 0
            layer.effect: MultiEffect {
                shadowEnabled: !Config.gameMode && WindowShadowSync.quickshellBlurRadius > 0 && WindowShadowSync.quickshellOpacity > 0
                shadowColor: Theme.shadow
                shadowOpacity: WindowShadowSync.quickshellOpacity
                // blurMax is the radius; use the already-combined range once.
                shadowBlur: WindowShadowSync.quickshellBlur
                blurMax: Math.max(2, WindowShadowSync.quickshellRange)
                shadowVerticalOffset: Config.appearanceShadowOffset
                // pillShadow.pad provides explicit padding, including offset.
                autoPaddingEnabled: false
            }

            Rectangle {
                x: pillShadow.pad
                y: pillShadow.pad
                width: pillShadow.width - pillShadow.pad * 2
                height: pillShadow.height - pillShadow.pad * 2
                readonly property real uni: (island.mode === "power" || island.mode === "media" || island.mode === "music" || island.mode === "polkit" || island.mode === "expanded" || island.mode === "calendar" || island.mode === "launcher" || island.mode === "clipboard" || island.mode === "emoji" || island.mode === "perf" || island.mode === "themes" || island.mode === "wallpaper" || island.mode === "control" || island.mode === "display" || island.mode === "sound") ? Theme.radiusLarge : (Config.notchMode ? Theme.radiusMedium : height / 2)
                topLeftRadius: Config.notchMode ? 0 : uni
                topRightRadius: Config.notchMode ? 0 : uni
                bottomLeftRadius: uni
                bottomRightRadius: uni
                color: Config.notchMode ? island.notchBg : Theme.islandBg

                NotchWing {
                    anchors.right: parent.left
                    anchors.top: parent.top
                    size: 24
                    fill: island.notchBg
                    mirror: true
                    visible: Config.notchMode
                }
                NotchWing {
                    anchors.left: parent.right
                    anchors.top: parent.top
                    size: 24
                    fill: island.notchBg
                    mirror: false
                    visible: Config.notchMode
                }
            }
        }
        Rectangle {
            id: pill
            anchors.fill: parent
            // Radio base (uniforme). En notch, las esquinas superiores van rectas (pegadas al borde).
                readonly property real uni: (island.mode === "power" || island.mode === "media" || island.mode === "music" || island.mode === "polkit" || island.mode === "expanded" || island.mode === "calendar" || island.mode === "launcher" || island.mode === "clipboard" || island.mode === "emoji" || island.mode === "perf" || island.mode === "themes" || island.mode === "wallpaper" || island.mode === "control" || island.mode === "display" || island.mode === "sound") ? Theme.radiusLarge : (Config.notchMode ? Theme.radiusMedium : height / 2)
            topLeftRadius: Config.notchMode ? 0 : uni
            topRightRadius: Config.notchMode ? 0 : uni
            bottomLeftRadius: uni
            bottomRightRadius: uni
            color: Config.notchMode ? island.notchBg : Theme.islandBg
            border.color: Theme.islandBorder
            border.width: Config.notchMode ? 0 : 1

            Behavior on topLeftRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on topRightRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on bottomLeftRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on bottomRightRadius {
                NumberAnimation {
                    duration: Theme.movementDuration
                    easing.type: Easing.OutCubic
                }
            }

            // Alas laterales cóncavas: funden el notch con el borde superior de la pantalla
            NotchWing {
                anchors.right: parent.left
                anchors.top: parent.top
                size: 24
                fill: island.notchBg
                mirror: true
                visible: Config.notchMode
            }
            NotchWing {
                anchors.left: parent.right
                anchors.top: parent.top
                size: 24
                fill: island.notchBg
                mirror: false
                visible: Config.notchMode
            }

            // ---------- idle (compacto) ----------
            Item {
                anchors.fill: parent
                opacity: island.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                // En reposo, los laterales se anclan por separado y el reloj queda centrado.
                Item {
                    id: idleRow
                    anchors.fill: parent
                    // Reserva espacio simétrico según el lateral más ancho para que los
                    // scratchpads (p. ej. Spotify) no queden debajo del reloj centrado.
                    implicitWidth: Math.max(leftStatus.implicitWidth, rightStatus.implicitWidth) * 2 + idleClock.contentWidth + 100 - Config.innerPadding * 2

                    // Izquierda: workspaces + estado
                    Row {
                        id: leftStatus
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: !Quick.gameMode

                        // Mostrando teclas (KeyCast): está leyendo el teclado
                        Text {
                            visible: KeyCast.active
                            anchors.verticalCenter: parent.verticalCenter
                            text: "keyboard"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Theme.fontPx(15)
                            color: Theme.red
                        }

                        // Grabando (scripts/record.sh): punto rojo que late + tiempo
                        Row {
                            visible: Recorder.recording
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                id: recDot
                                width: 8
                                height: 8
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Recorder.paused ? Theme.yellow : Theme.red
                                SequentialAnimation on opacity {
                                    running: Recorder.recording && !Recorder.paused && !Theme.reduceMotion
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) recDot.opacity = 1
                                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                                }
                            }
                            Text {
                                text: Recorder.elapsedText
                                color: Recorder.paused ? Theme.yellow : Theme.red
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        WsRow {
                            barWidth: 7
                            baseLen: 7
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.clockShowWorkspaceDots && !island.inSpecial // ocultar ws normales si estás en un scratchpad
                            layer.enabled: Config.notchMode && !Config.gameMode
                            layer.effect: MultiEffect {
                                shadowEnabled: !Config.gameMode
                                shadowColor: Theme.green
                                shadowBlur: 1.0
                                blurMax: 18
                                shadowOpacity: 0.8
                                autoPaddingEnabled: true
                            }
                        }
                        // Scratchpads con ventanas; el activo se resalta al mostrarse.
                        SpecialRow {
                            cell: 22
                            anchors.verticalCenter: parent.verticalCenter
                            visible: island.inSpecial
                        }
                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.red
                            visible: Audio.micMuted
                            layer.enabled: Config.notchMode && !Config.gameMode
                            layer.effect: MultiEffect {
                                shadowEnabled: !Config.gameMode
                                shadowColor: Theme.green
                                shadowBlur: 1.0
                                blurMax: 18
                                shadowOpacity: 0.8
                                autoPaddingEnabled: true
                            }
                        }
                    }

                    // Hora estática centrada en la cápsula, independientemente de los laterales.
                    Text {
                        id: idleClock
                        font.family: Theme.displayFontFamily
                        anchors.fill: parent
                        text: Qt.formatDateTime(clock.date, Config.clock24Hour ? (Config.clockShowSeconds ? "HH:mm:ss" : "HH:mm") : (Config.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                        color: "#ffffff"
                        font.pixelSize: Theme.fontPx(16)
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: !Quick.gameMode
                    }

                    // Indicador persistente para que Game Mode siga visible
                    // cuando la isla vuelve a su estado compacto.
                    Row {
                        id: gameModeStatus
                        anchors.centerIn: parent
                        spacing: 4
                        visible: Quick.gameMode

                        Icon {
                            text: "sports_esports"
                            px: 18
                            color: Theme.yellow
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "GAME MODE"
                            color: Theme.yellow
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Derecha: wifi + batería
                    Row {
                        id: rightStatus
                        anchors.right: parent.right
                        anchors.rightMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        visible: Config.clockShowBatteryWifi && !Quick.gameMode

                        // Glow en el color principal sobre wifi/batería (solo en notch)
                        layer.enabled: Config.notchMode && !Config.gameMode
                        layer.effect: MultiEffect {
                            shadowEnabled: !Config.gameMode
                            shadowColor: Theme.green
                            shadowBlur: 1.0
                            blurMax: 18
                            shadowOpacity: 0.8
                            autoPaddingEnabled: true
                        }

                        Icon {
                            text: island.networkGlyph
                            iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                            px: 18
                            color: Net.online ? Theme.green : Theme.surface1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Battery.available
                            spacing: 4

                            // Batería y, si carga, el rayo pegado a su derecha
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -2
                                Icon {
                                    text: island.batteryGlyph
                                    iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                                    px: 22
                                    color: Theme.green
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Icon {
                                    visible: Battery.charging
                                    text: "bolt"
                                    iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                                    px: 15
                                    color: Theme.green
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                visible: Config.clockShowBatteryPercent
                                text: Battery.percent + "%"
                                color: Theme.text
                                font.family: Theme.displayFontFamily
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: 600
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            // ---------- expanded (hover): isla compacta horizontal ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                opacity: island.mode === "expanded" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }

                // Marca y escritorios a la izquierda.
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 6
                        Icon {
                            text: "window"
                            px: 17
                            color: Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            width: parent.width - 25
                            text: island.focusedApp
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(13)
                            font.bold: true
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    WsRow {
                        barWidth: 7
                        baseLen: 8
                        visible: Config.clockExpandedWorkspaces && Config.clockShowWorkspaceDots && !island.inSpecial
                    }
                    SpecialRow {
                        cell: 16
                        visible: Config.clockExpandedWorkspaces
                    }
                }

                // Hora y fecha apiladas en el centro, con el reproductor debajo.
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    width: 310

                    Item {
                        id: clockDateTarget
                        width: parent.width
                        height: clockDateColumn.implicitHeight

                        Column {
                            id: clockDateColumn
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            y: 0
                            spacing: 1
                            Text {
                                font.family: Theme.displayFontFamily
                                width: parent.width
                                text: Qt.formatDateTime(clock.date, Config.clock24Hour ? (Config.clockShowSeconds ? "HH:mm:ss" : "HH:mm") : (Config.clockShowSeconds ? "h:mm:ss AP" : "h:mm AP"))
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(23)
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                font.family: Theme.bodyFontFamily
                                width: parent.width
                                text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                                color: Theme.secondaryText
                                font.pixelSize: Theme.fontPx(13)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                island.calendarMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
                                island.selectedDate = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
                                Overlay.mode = "calendar";
                            }
                        }
                    }

                    // Música: la misma tarjeta que la pantalla de bloqueo, en una fila (variante mini)
                    Item {
                        width: parent.width
                        height: 50
                        visible: Config.clockExpandedMedia
                        MediaCard {
                            anchors.fill: parent
                            mini: true
                            radius: 14
                            player: Media.active
                            art: Media.artPath
                            title: Media.title
                            artist: Media.artist || Media.album
                        }
                        WheelHandler {
                            enabled: Config.mediaScrollToChangeTrack
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                if (event.angleDelta.y > 0) Media.prev();
                                else if (event.angleDelta.y < 0) Media.next();
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Notificaciones y estado de red/energía a la derecha.
                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: Config.clockExpandedStatus

                    Row {
                        anchors.right: parent.right
                        spacing: 6
                        Text {
                            font.family: Theme.bodyFontFamily
                            text: Notifs.count > 0 ? (Notifs.count + " notifications") : "All caught up"
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(12)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            text: "notifications"
                            px: 15
                            color: Notifs.count > 0 ? Theme.green : Theme.secondaryText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 7
                        Icon {
                            text: island.networkGlyph
                            iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                            px: 20
                            color: Net.online ? Theme.green : Theme.tertiaryText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -2
                            Icon {
                                text: island.batteryGlyph
                                iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                                px: 21
                                color: Battery.percent <= 20 && !Battery.charging ? Theme.red : Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Icon {
                                visible: Battery.charging
                                text: "bolt"
                                iconFontFamily: batterySymbols.name !== "" ? batterySymbols.name : "Material Symbols Outlined"
                                px: 15
                                color: Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // ---------- calendario (clic en la fecha) ----------
            Item {
                id: calendarPopup
                anchors.fill: parent
                opacity: island.mode === "calendar" ? 1 : 0
                visible: opacity > 0
                focus: island.mode === "calendar"
                Keys.onEscapePressed: Overlay.close()
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 22
                        spacing: 8
                        IslandButton {
                            glyph: "‹"
                            size: 22
                            onTapped: island.calendarMonth = new Date(island.calendarMonth.getFullYear(), island.calendarMonth.getMonth() - 1, 1)
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            width: parent.width - 60
                            text: Qt.formatDateTime(island.calendarMonthDate, "MMMM yyyy")
                            color: Theme.secondaryText
                            font.pixelSize: Theme.fontPx(14)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        IslandButton {
                            glyph: "›"
                            size: 22
                            onTapped: island.calendarMonth = new Date(island.calendarMonth.getFullYear(), island.calendarMonth.getMonth() + 1, 1)
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 3
                        columnSpacing: 2

                        Repeater {
                            model: 7
                            delegate: Text {
                                required property int index
                                width: (parent.width - 12) / 7
                                height: 20
                                text: ["S", "M", "T", "W", "T", "F", "S"][(index + Config.clockWeekStart) % 7]
                                color: Theme.tertiaryText
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(10)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                id: calendarCell
                                required property int index
                                readonly property int dayNumber: index - island.calendarFirstDayOffset + 1
                                readonly property bool inMonth: dayNumber >= 1 && dayNumber <= island.calendarDaysInMonth
                                readonly property var cellDate: new Date(island.calendarMonthDate.getFullYear(), island.calendarMonthDate.getMonth(), dayNumber)
                                readonly property bool selected: inMonth && island.selectedDate.getFullYear() === cellDate.getFullYear() && island.selectedDate.getMonth() === cellDate.getMonth() && island.selectedDate.getDate() === cellDate.getDate()
                                width: (parent.width - 12) / 7
                                height: 25
                                radius: 10
                                color: selected ? Theme.green : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: calendarCell.inMonth || Config.clockShowNeighbouringMonths ? calendarCell.cellDate.getDate() : ""
                                    color: calendarCell.selected ? Theme.islandBg : (calendarCell.inMonth ? Theme.secondaryText : Theme.tertiaryText)
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: calendarCell.inMonth || Config.clockShowNeighbouringMonths
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        island.selectedDate = calendarCell.cellDate;
                                        if (!calendarCell.inMonth)
                                            island.calendarMonth = new Date(calendarCell.cellDate.getFullYear(), calendarCell.cellDate.getMonth(), 1);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- media (peek) ----------
            // La misma tarjeta que la pantalla de bloqueo, en versión compacta
            MediaCard {
                anchors.fill: parent
                anchors.margins: 6
                radius: Theme.radiusLarge - 6
                compact: true
                player: Media.active
                art: Media.artPath
                title: Media.title
                artist: [Config.mediaShowArtist ? Media.artist : "", Config.mediaShowAlbum ? Media.album : ""].filter(x => x !== "").join(" · ")
                showControls: Config.mediaShowControls
                opacity: island.mode === "media" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- keys (peek): teclas pulsadas ----------
            Row {
                id: keysRow
                anchors.centerIn: parent
                spacing: 8
                opacity: island.mode === "keys" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Repeater {
                    model: KeyCast.chips
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool latest: index === KeyCast.chips.length - 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: keyText.implicitWidth + 22
                        height: 40
                        radius: 11
                        color: modelData.kind === "combo" ? Theme.panelCardHi : "transparent"
                        border.width: modelData.kind === "combo" ? 1 : 0
                        border.color: Theme.alpha(Theme.green, latest ? 60 : 20)
                        opacity: latest ? 1 : 0.55
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.text + (modelData.count > 1 ? "  ×" + modelData.count : "")
                            textFormat: Text.PlainText
                            color: "#ffffff"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(20)
                            font.bold: modelData.kind === "combo"
                            // Lo escrito, con las letras bien separadas para leer cada tecla
                            font.letterSpacing: modelData.kind === "text" ? 8 : 2
                        }
                    }
                }
            }

            // ---------- volume (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "volume" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                Text {
                    id: volIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.muted ? "volume_off" : Audio.volume < 0.35 ? "volume_down" : "volume_up"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Theme.fontPx(17)
                    color: Audio.muted ? Theme.tertiaryText : Theme.sapphire
                }
                Rectangle {
                    anchors.left: volIcon.right
                    anchors.right: volPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: Config.osdLevelBarThickness
                    radius: height / 2
                    color: Theme.surface0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, Audio.volume)
                        radius: height / 2
                        color: Audio.muted ? Theme.tertiaryText : Theme.sapphire
                    }
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    id: volPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Audio.volume * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                }
            }

            // ---------- brightness (peek) ----------
            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                opacity: island.mode === "brightness" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }
                Text {
                    id: brightnessIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Brightness.value < 0.34 ? "brightness_low" : Brightness.value < 0.67 ? "brightness_6" : "brightness_7"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Theme.fontPx(16)
                    color: Theme.peach
                }
                Rectangle {
                    anchors.left: brightnessIcon.right
                    anchors.right: brightnessPct.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: Config.osdLevelBarThickness
                    radius: height / 2
                    color: Theme.surface0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        width: parent.width * Math.min(1, Brightness.value)
                        radius: height / 2
                        color: Theme.peach
                    }
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    id: brightnessPct
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Brightness.value * 100) + "%"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                }
            }

            // ---------- notif (peek) ----------
            // La última arriba en grande y hasta 2 anteriores debajo en filas compactas; las demás
            // cuentan en el "+N" (ver notifQueue). Icono (imagen de la notificación > icono de la app > inicial),
            // cabecera con app y hora, título y cuerpo, y una barra con el tiempo que le queda.
            // Clic: su acción por defecto y la quita; clic derecho: solo la quita.
            Item {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 22
                opacity: island.mode === "notif" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                // La última, en grande
                Item {
                    id: notifMain
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: island.notifHeadHeight
                    opacity: 1 - island.notifShift / island.notifRowHeight * 0.6
                    transform: Translate {
                        y: island.notifShift
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const entry = island.notifTop;
                            if (mouse.button === Qt.LeftButton && island.notifObj)
                                Notifs.activate(island.notifObj);
                            island.removeEntry(entry, false);
                        }
                    }

                    ClippingRectangle {
                        id: notifIconBox
                        width: 54
                        height: 54
                        radius: 15
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -2
                        color: Theme.alpha(island.notifAccent, 16)
                        border.width: island.notifUrgent ? 1 : 0
                        border.color: Theme.alpha(Theme.red, 70)

                        Image {
                            id: notifImg
                            anchors.fill: parent
                            visible: island.notifImage !== "" && status === Image.Ready
                            source: island.notifImage
                            sourceSize: Qt.size(108, 108)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            size: 36
                            icon: island.notifIcon
                            visible: !notifImg.visible && island.notifIcon !== ""
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !notifImg.visible && island.notifIcon === ""
                            text: (island.notifApp || "?").charAt(0).toUpperCase()
                            color: island.notifAccent
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(24)
                            font.bold: true
                        }
                    }

                    Column {
                        anchors.left: notifIconBox.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.verticalCenter: notifIconBox.verticalCenter
                        spacing: 2

                        Item {
                            width: parent.width
                            height: notifAppText.implicitHeight
                            Text {
                                id: notifAppText
                                anchors.left: parent.left
                                anchors.right: notifMeta.left
                                anchors.rightMargin: 8
                                font.family: Theme.bodyFontFamily
                                text: island.notifUrgent ? (island.notifApp || "Notification") + "  ·  urgent" : (island.notifApp || "Notification")
                                color: island.notifAccent
                                font.pixelSize: Theme.fontPx(13)
                                font.bold: true
                                font.letterSpacing: 0.3
                                elide: Text.ElideRight
                            }
                            Row {
                                id: notifMeta
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // "+N": clic abre el historial (centro de control)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: island.notifExtra > 0
                                    width: notifExtraText.implicitWidth + 14
                                    height: notifExtraText.implicitHeight + 4
                                    radius: height / 2
                                    color: Theme.alpha(island.notifAccent, 18)
                                    Text {
                                        id: notifExtraText
                                        anchors.centerIn: parent
                                        font.family: Theme.bodyFontFamily
                                        text: "+" + island.notifExtra
                                        color: island.notifAccent
                                        font.pixelSize: Theme.fontPx(12)
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            island.peek = "";
                                            Overlay.mode = "control";
                                        }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: Theme.bodyFontFamily
                                    text: "now"
                                    color: Theme.tertiaryText
                                    font.pixelSize: Theme.fontPx(13)
                                }
                            }
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            width: parent.width
                            text: island.notifSummary
                            textFormat: Text.PlainText
                            color: "#ffffff"
                            font.pixelSize: Theme.fontPx(18)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            font.family: Theme.bodyFontFamily
                            width: parent.width
                            visible: island.notifBody !== ""
                            text: island.notifBody
                            textFormat: Text.PlainText
                            color: Theme.secondaryText
                            font.pixelSize: Theme.fontPx(15)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Tiempo restante
                    Rectangle {
                        visible: Config.notificationTimeoutBar
                        anchors.left: notifIconBox.right
                        anchors.leftMargin: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: (parent.width - notifIconBox.width - 14) * island.notifProgress
                        height: 3
                        radius: 1.5
                        color: Theme.alpha(island.notifAccent, 55)
                    }
                }

                // Progreso y botones (acciones y respuesta) de la de arriba, alineados con su texto
                Column {
                    id: notifExtras
                    anchors.top: notifMain.bottom
                    anchors.topMargin: island.notifExtrasHeight > 0 ? -island.notifExtrasLift : 0
                    anchors.left: parent.left
                    anchors.leftMargin: 68
                    anchors.right: parent.right
                    height: island.notifExtrasHeight
                    opacity: notifMain.opacity
                    transform: Translate {
                        y: island.notifShift
                    }

                    Item {
                        width: parent.width
                        height: 22
                        visible: island.notifValue >= 0
                        Rectangle {
                            id: valueTrack
                            anchors.left: parent.left
                            anchors.right: valueText.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            radius: 3
                            color: Theme.panelCardHi
                            Rectangle {
                                width: parent.width * Math.max(0, island.notifValue) / 100
                                height: parent.height
                                radius: 3
                                color: island.notifAccent
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.movementDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                        Text {
                            id: valueText
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Theme.bodyFontFamily
                            text: island.notifValue + "%"
                            color: Theme.secondaryText
                            font.pixelSize: Theme.fontPx(13)
                            font.bold: true
                        }
                    }

                    Item {
                        width: parent.width
                        height: 46
                        visible: island.notifActions.length > 0 || island.notifCanReply

                        // Pegados arriba (al texto); el hueco sobrante queda como margen inferior
                        Row {
                            id: actionRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 8
                            visible: !island.notifReplying
                            readonly property int count: island.notifActions.length + (island.notifCanReply ? 1 : 0)
                            readonly property real maxButton: (width - spacing * (count - 1)) / Math.max(1, count)

                            NotifButton {
                                visible: island.notifCanReply
                                icon: "reply"
                                text: "Reply"
                                accent: island.notifAccent
                                maxWidth: actionRow.maxButton
                                onClicked: {
                                    island.startReply();
                                    replyInput.text = "";
                                    replyInput.forceActiveFocus();
                                }
                            }
                            Repeater {
                                model: island.notifActions
                                NotifButton {
                                    required property var modelData
                                    text: modelData.text
                                    maxWidth: actionRow.maxButton
                                    onClicked: {
                                        const entry = island.notifTop;
                                        modelData.invoke();
                                        island.removeEntry(entry, false);
                                    }
                                }
                            }
                        }

                        // Respuesta: Enter envía, Esc cancela
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 34
                            radius: 10
                            visible: island.notifReplying
                            color: Theme.panelCardHi
                            border.width: 1
                            border.color: Theme.alpha(island.notifAccent, 60)

                            TextInput {
                                id: replyInput
                                anchors.left: parent.left
                                anchors.right: sendButton.left
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(14)
                                color: "#ffffff"
                                selectionColor: Theme.alpha(island.notifAccent, 50)
                                clip: true
                                Keys.onReturnPressed: island.sendReply(text)
                                Keys.onEnterPressed: island.sendReply(text)
                                Keys.onEscapePressed: island.cancelReply()

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: replyInput.text === ""
                                    font: replyInput.font
                                    text: island.notifObj?.inlineReplyPlaceholder || "Reply…"
                                    color: Theme.tertiaryText
                                }
                            }
                            NotifButton {
                                id: sendButton
                                anchors.right: parent.right
                                anchors.rightMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                height: 28
                                icon: "send"
                                text: "Send"
                                accent: island.notifAccent
                                onClicked: island.sendReply(replyInput.text)
                            }
                        }
                    }
                }

                // Anteriores: fila compacta con icono, app y título. Clic: su acción; clic derecho: quitarla.
                Column {
                    anchors.top: notifExtras.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    transform: Translate {
                        y: island.notifShift
                    }

                    Repeater {
                        model: island.notifOlder

                        Item {
                            id: olderRow
                            required property var modelData
                            required property int index
                            readonly property color accent: modelData.urgency === NotificationUrgency.Critical ? Theme.red : Theme.mauve
                            width: parent.width
                            height: island.notifRowHeight

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.divider
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    const entry = olderRow.modelData;
                                    if (mouse.button === Qt.LeftButton && entry.obj)
                                        Notifs.activate(entry.obj);
                                    island.removeEntry(entry, false);
                                }
                            }
                            ClippingRectangle {
                                id: olderIcon
                                width: 32
                                height: 32
                                radius: 9
                                anchors.left: parent.left
                                anchors.leftMargin: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alpha(olderRow.accent, 16)

                                Image {
                                    id: olderImg
                                    anchors.fill: parent
                                    visible: olderRow.modelData.image !== "" && status === Image.Ready
                                    source: olderRow.modelData.image
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                AppIcon {
                                    anchors.centerIn: parent
                                    size: 22
                                    icon: olderRow.modelData.icon
                                    visible: !olderImg.visible && olderRow.modelData.icon !== ""
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !olderImg.visible && olderRow.modelData.icon === ""
                                    text: (olderRow.modelData.app || "?").charAt(0).toUpperCase()
                                    color: olderRow.accent
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(15)
                                    font.bold: true
                                }
                            }
                            Text {
                                id: olderApp
                                anchors.left: olderIcon.right
                                anchors.leftMargin: 25
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 140)
                                font.family: Theme.bodyFontFamily
                                text: olderRow.modelData.app || "Notification"
                                color: olderRow.accent
                                font.pixelSize: Theme.fontPx(13)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            // Título y, en gris, el cuerpo: en las de webs el título es solo el sitio
                            // ("Instagram") y lo que importa va en el cuerpo
                            Text {
                                id: olderSummary
                                anchors.left: olderApp.right
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, parent.width - x)
                                font.family: Theme.bodyFontFamily
                                text: olderRow.modelData.summary
                                textFormat: Text.PlainText
                                color: "#ffffff"
                                font.pixelSize: Theme.fontPx(14)
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.left: olderSummary.right
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: olderRow.modelData.body !== ""
                                font.family: Theme.bodyFontFamily
                                text: olderRow.modelData.body
                                textFormat: Text.PlainText
                                color: Theme.secondaryText
                                font.pixelSize: Theme.fontPx(14)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ---------- launcher (modo overlay dentro de la isla) ----------
            LauncherContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "launcher" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- themes (selector de temas dentro de la isla) ----------
            ThemeContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "themes" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- wallpaper (selector de fondos dentro de la isla) ----------
            // ---------- music (panel de música, Super+A) ----------
            MusicContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "music" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            PerfContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "perf" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            EmojiContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "emoji" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            ClipboardContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "clipboard" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            WallpaperContent {
                anchors.fill: parent
                anchors.margins: 8
                opacity: island.mode === "wallpaper" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- control (centro de control dentro de la isla) ----------
            ControlContent {
                id: controlContent
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "control" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- menú de energía ----------
            PowerMenu {
                id: powerMenu
                anchors.fill: parent
                active: island.mode === "power"
                opacity: island.mode === "power" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }
            }

            // ---------- display (ajustes de pantalla) ----------
            DisplayContent {
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "display" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- sound (ajustes de sonido) ----------
            SoundContent {
                anchors.fill: parent
                anchors.margins: 16
                opacity: island.mode === "sound" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // ---------- solicitud de permisos de administrador (PolicyKit) ----------
            PolkitPrompt {
                anchors.fill: parent
                active: island.showPolkit
                opacity: island.mode === "polkit" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.fadeDuration }
                }
            }

            // Hover: expande (NoButton => no roba los clics a los botones internos).
            // Desactivado en modos overlay para que el launcher/temas reciban hover y clics.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: Overlay.mode === ""
                onEntered: island.hovered = true
                onExited: island.hovered = false
            }
        }
    }

    // --- Componentes internos reutilizables ---

    // Botón de una notificación (acciones, Reply, Send). Con `accent`, relleno de ese color.
    component NotifButton: Rectangle {
        id: nb
        property string text: ""
        property string icon: ""
        property color accent: "transparent"
        property real maxWidth: 1000
        signal clicked
        readonly property bool filled: accent.a > 0
        // Medidas a mano (no con implicitWidth de la Row: el texto se recorta según el ancho del botón)
        readonly property real iconWidth: icon !== "" ? Theme.iconPx(16) + 6 : 0

        width: Math.min(maxWidth, iconWidth + nbLabel.implicitWidth + 24)
        height: 32
        radius: height / 2
        color: filled ? Theme.alpha(accent, nbMouse.containsMouse ? 32 : 20) : (nbMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: nb.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: nb.icon
                font.family: "Material Symbols Outlined"
                font.pixelSize: Theme.iconPx(16)
                color: nb.filled ? nb.accent : "#ffffff"
            }
            Text {
                id: nbLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, nb.width - 24 - nb.iconWidth)
                text: nb.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(13)
                font.bold: true
                color: nb.filled ? nb.accent : "#ffffff"
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: nbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nb.clicked()
        }
    }

    // Workspaces persistentes 1..N como barras de carga VERTICALES (sin número).
    // Activo = barra alta (acento); ocupado = barra media; vacío = corta.
    component WsRow: Row {
        property int barWidth: 6
        property int baseLen: 8 // alto de un ws vacío
        spacing: 6

        Repeater {
            model: Config.workspaceCount
            delegate: Rectangle {
                id: wsCell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                anchors.verticalCenter: parent.verticalCenter
                width: barWidth
                height: wsCell.focused ? baseLen * 2.0 : (wsCell.occupied ? baseLen * 1.7 : baseLen * 1.3)
                radius: width / 2
                color: wsCell.focused ? Theme.green : (wsCell.occupied ? Theme.overlay2 : Theme.surface0)

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.movementDuration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + wsCell.wsId + "})")
                }
            }
        }
    }

    // Scratchpads activos (workspaces especiales con ventanas): icono por cada uno,
    // resaltado si está mostrándose; clic = mostrar/ocultar (como caelestia).
    component SpecialRow: Row {
        property int cell: 16
        property bool onlyActive: false
        spacing: 4

        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.name.startsWith("special:") && (!onlyActive || w.name === (Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name ?? "")))
            delegate: Rectangle {
                id: sp
                required property var modelData
                readonly property string sname: modelData.name.slice(8) // quita "special:"
                // Resaltado si ese scratchpad se está MOSTRANDO en el monitor (se refresca
                // en shell.qml al recibir 'activespecial'; si no, lastIpcObject no es reactivo)
                readonly property bool shown: Hyprland.focusedMonitor?.lastIpcObject?.specialWorkspace?.name === modelData.name
                // Colores vivos por app (fijos, para que resalten con cualquier tema)
                readonly property color accent: {
                    switch (sp.sname) {
                    case "music":
                        return "#1ed760"; // verde Spotify
                    case "comms":
                        return "#5865f2"; // azul Discord
                    case "sysmon":
                        return "#fab387"; // melocotón
                    case "agents":
                        return "#DE7356"; // Claude Code
                    default:
                        return "#89b4fa";
                    }
                }

                width: cell + 6
                height: cell
                radius: height / 2
                color: "transparent"

                Image {
                    id: brandIcon
                    anchors.centerIn: parent
                    width: Math.round(cell * (sp.sname === "music" ? 0.72 : 0.92) * (sp.shown ? 1.18 : 1))
                    height: width
                    visible: ["music", "comms", "communication", "agents"].includes(sp.sname)
                    source: {
                        switch (sp.sname) {
                        case "music":
                            return Qt.resolvedUrl("../assets/icons/spotify.svg");
                        case "comms":
                        case "communication":
                            return Qt.resolvedUrl("../assets/icons/discord.svg");
                        case "agents":
                            return Qt.resolvedUrl("../assets/icons/claudecode.svg");
                        default:
                            return "";
                        }
                    }
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        colorization: 1
                        colorizationColor: sp.shown ? sp.accent : "#858585"
                    }
                }

                Text {
                    anchors.centerIn: parent
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(cell * 0.92 * (sp.shown ? 1.18 : 1))
                    color: sp.shown ? sp.accent : "#858585"
                    visible: !brandIcon.visible
                    text: {
                        switch (sp.sname) {
                        case "sysmon":
                            return "monitoring";
                        default:
                            return "star";
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special('" + sp.sname + "')")
                }
            }
        }
    }

    component IslandStat: Row {
        property string label: ""
        property real value: 0
        property color barColor: "#ffffff"
        spacing: 5
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.label
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(10)
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 34
            height: 5
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surface0
            Rectangle {
                anchors.left: parent.left
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, parent.parent.value))
                radius: 3
                color: parent.parent.barColor
            }
        }
    }

    component IslandButton: Rectangle {
        property string glyph: ""
        property bool useIconFont: false
        property int size: 26
        signal tapped
        width: size
        height: size
        radius: size / 2
        color: tapArea.containsMouse ? Theme.surface0 : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: "#ffffff"
            font.pixelSize: parent.useIconFont ? Math.round(parent.size * 0.68) : 12
            font.family: parent.useIconFont ? "Material Symbols Rounded" : Qt.application.font.family
        }
        MouseArea {
            id: tapArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.tapped()
        }
    }

    // Icono (Material Symbols Rounded; el texto es el nombre del icono, ej. "wifi")
    component Icon: Text {
        property real px: 18
        property string iconFontFamily: "Material Symbols Rounded"
        font.family: iconFontFamily
        font.pixelSize: Theme.iconPx(px)
        font.weight: Theme.iconWeight
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
    }

    // Fila del panel Status: icono + valor + etiqueta
    component StatusRow: Row {
        property string glyph: ""
        property string value: ""
        property string label: ""
        property color glyphColor: Theme.text
        spacing: 8
        height: 20

        Icon {
            text: parent.glyph
            color: parent.glyphColor
            px: 17
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.value
            color: "#ffffff"
            font.pixelSize: Theme.fontPx(12)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            font.family: Theme.bodyFontFamily
            text: parent.label
            color: Theme.secondaryText
            font.pixelSize: Theme.fontPx(12)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Botón tipo píldora (Night light / Game mode)
    component PillButton: Rectangle {
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal toggled

        height: 24
        radius: 12
        implicitWidth: pbRow.implicitWidth + 18
        width: implicitWidth
        color: on ? Theme.surface1 : Theme.surface0

        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 5
            Icon {
                text: parent.parent.glyph
                px: 14
                color: parent.parent.on ? Theme.yellow : Theme.secondaryText
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                font.family: Theme.bodyFontFamily
                text: parent.parent.label
                color: Theme.text
                font.pixelSize: Theme.fontPx(11)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

}
