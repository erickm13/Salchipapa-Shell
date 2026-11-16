pragma Singleton
// Bloqueo real de la sesión Wayland con autenticación PAM.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Services.Pam
import "../common"
import "../designs"

Singleton {
    id: root

    readonly property bool locked: sessionLock.locked
    property string errorText: ""
    property string passwordText: ""
    property var passwordField: null
    property var mediaService: null
    property string powerAction: ""
    property bool revealPassword: false
    readonly property string pamError: pam.messageIsError ? pam.message : ""
    // Vista previa del diseño sin bloquear la sesión (Ajustes > Lock Screen > Preview, o
    // `qs ipc call salchipapa-lock preview`): la misma página a pantalla completa, sin contraseña
    // ni acciones; se cierra con un clic.
    property bool previewing: false
    LazyLoader {
        active: root.previewing && !sessionLock.locked
        PanelWindow {
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "#000000"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "salchipapa-lock-preview"
            LockPage {
                anchors.fill: parent
                lock: root
                active: true
                preview: true
            }
        }
    }
    // Bloq Mayús: se lee del LED del teclado mientras la sesión está bloqueada
    property bool capsLock: false
    Timer {
        interval: 700
        repeat: true
        triggeredOnStart: true
        running: sessionLock.locked
        onTriggered: capsProc.running = true
    }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = parseInt(text.trim() || "0") > 0
        }
    }
    readonly property string networkGlyph: Net.type === "ethernet" ? "lan" : Net.type === "wifi" ? (Net.wifiSignal >= 80 ? "signal_wifi_4_bar" : Net.wifiSignal >= 60 ? "network_wifi_3_bar" : Net.wifiSignal >= 35 ? "network_wifi_2_bar" : Net.wifiSignal >= 10 ? "network_wifi_1_bar" : "signal_wifi_0_bar") : "wifi_off"
    readonly property string batteryGlyph: Battery.percent >= 95 ? "battery_android_full" : Battery.percent >= 80 ? "battery_android_6" : Battery.percent >= 65 ? "battery_android_5" : Battery.percent >= 50 ? "battery_android_4" : Battery.percent >= 35 ? "battery_android_3" : Battery.percent >= 20 ? "battery_android_2" : Battery.percent >= 5 ? "battery_android_1" : "battery_android_0"
    FontLoader {
        id: outlinedSymbols
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/SalchipapaShell/MaterialSymbolsOutlined.ttf"
    }
    readonly property string outlinedFamily: outlinedSymbols.name !== "" ? outlinedSymbols.name : "Material Symbols Outlined"
    property bool suspending: false

    function lock(): void {
        if (sessionLock.locked)
            return;

        errorText = "";
        passwordText = "";
        revealPassword = false;
        previewing = false;
        sessionLock.locked = true;
        Qt.callLater(() => {
            if (!pam.start())
                errorText = "No se pudo iniciar la autenticación";
        });
    }

    function submitPassword(): void {
        if (!pam.responseRequired || passwordText.length === 0)
            return;

        const response = passwordText;
        passwordText = "";
        pam.respond(response);
    }

    function confirmPowerAction(): void {
        if (powerAction !== "") {
            powerProc.command = ["systemctl", powerAction];
            powerProc.running = true;
            powerAction = "";
        }
    }

    // La sesión queda protegida antes de pedir a logind que suspenda el equipo.
    // WlSessionLock permanece activo al reanudar, así PAM vuelve a pedir la clave.
    function suspend(): void {
        suspending = false;
        suspending = true;
        suspendLockTimer.restart();
    }

    Process {
        id: powerProc
    }

    Process {
        id: suspendProc
        onExited: root.suspending = false
    }

    IpcHandler {
        target: "salchipapa-lock"
        function activate(): void {
            root.lock();
        }
        function preview(): void {
            root.previewing = !root.previewing;
        }
        function reveal(): void {
            // Recuperación visual: conserva el bloqueo PAM y solo quita la capa negra.
            root.suspending = false;
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: lockSurface
            color: "#000000"

            // Todo lo que se ve está en LockPage.qml (también lo usa la vista previa)
            LockPage {
                width: lockSurface.width
                height: lockSurface.height
                lock: root
                active: sessionLock.locked
            }
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: {
            if (responseRequired)
                root.passwordField?.forceActiveFocus();
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                errorText = "";
                passwordText = "";
                sessionLock.locked = false;
            } else {
                errorText = result === PamResult.MaxTries ? "Se alcanzó el límite de intentos. Inténtalo de nuevo." : "Contraseña incorrecta. Inténtalo de nuevo.";
                passwordText = "";
                active = false;
                retryAuth.restart();
            }
        }

        onError: error => {
            errorText = PamError.toString(error);
        }
    }

    Timer {
        id: retryAuth
        interval: 900
        repeat: false
        onTriggered: {
            if (sessionLock.locked) {
                if (!pam.start())
                    root.errorText = "No se pudo reiniciar la autenticación";
            }
        }
    }

    Timer {
        id: suspendLockTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!sessionLock.locked)
                root.lock();
            if (sessionLock.locked)
                suspendCommandTimer.restart();
        }
    }

    Timer {
        id: suspendCommandTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (root.suspending && sessionLock.locked) {
                suspendProc.command = ["systemctl", "suspend"];
                suspendProc.running = true;
            }
        }
    }
}
