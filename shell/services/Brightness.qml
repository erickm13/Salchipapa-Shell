pragma Singleton
// Brillo por monitor. Pantalla del portátil (eDP): brightnessctl (backlight). Monitores externos:
// DDC/CI con ddcutil (VCP 0x10), buscando el bus i2c de cada conector con `ddcutil detect`.
// `value`/`setValue` actúan sobre el monitor enfocado (centro de control, OSD de la isla);
// `valueFor`/`setValueFor` sobre uno concreto (página Display).
// DDC es lento (0,1–0,5 s por orden): las órdenes van en cola, una por vez, y de cada monitor
// solo se envía el último valor pedido, así arrastrar el slider no atasca el monitor.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var values: ({}) // conector -> 0..1
    property var ddcBus: ({}) // conector -> número de bus i2c (solo los que responden a DDC/CI)
    property string backlightOutput: "" // conector de la pantalla interna, si tiene backlight
    property bool backlightOk: false

    readonly property string target: Hyprland.focusedMonitor?.name ?? ""
    readonly property real value: valueFor(target)
    readonly property bool available: availableFor(target)
    // Cambio hecho por el usuario (slider, teclas): la isla muestra el OSD solo con esto, no al
    // cambiar de monitor enfocado
    signal adjusted

    function isInternal(name: string): bool {
        return name.startsWith("eDP") || name.startsWith("LVDS") || name.startsWith("DSI");
    }
    function availableFor(name: string): bool {
        return isInternal(name) ? backlightOk : ddcBus[name] !== undefined;
    }
    function valueFor(name: string): real {
        return values[name] ?? 1;
    }

    function setValueFor(name: string, v: real): void {
        if (!availableFor(name))
            return;
        const next = Math.max(0.01, Math.min(1, v));
        const vals = Object.assign({}, values);
        vals[name] = next;
        values = vals;
        if (isInternal(name)) {
            setProc.command = ["brightnessctl", "-q", "set", Math.round(next * 100) + "%"];
            setProc.running = true;
        } else {
            const p = Object.assign({}, pending);
            p[name] = Math.round(next * 100);
            pending = p;
            pumpDdc();
        }
        if (name === target)
            adjusted();
    }
    function setValue(v: real): void {
        setValueFor(target, v);
    }
    function add(d: real): void {
        setValue(value + d);
    }

    // ---- Cola DDC ----
    property var pending: ({}) // conector -> 0..100 aún sin enviar
    function pumpDdc(): void {
        if (ddcSet.running)
            return;
        const name = Object.keys(pending)[0];
        if (name === undefined)
            return;
        const p = Object.assign({}, pending);
        const percent = p[name];
        delete p[name];
        pending = p;
        ddcSet.command = ["ddcutil", "--bus", String(ddcBus[name]), "--noverify", "setvcp", "10", String(percent)];
        ddcSet.running = true;
    }
    Process {
        id: ddcSet
        onExited: root.pumpDdc()
    }

    // ---- Detección de monitores DDC y lectura inicial ----
    function detect(): void {
        detectProc.running = true;
    }
    Process {
        id: detectProc
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            id: detectOut
            onStreamFinished: {
                // Bloques "Display N" con "I2C bus: /dev/i2c-X" y "DRM connector: cardY-DP-1"
                const buses = {};
                for (const block of detectOut.text.split(/\n(?=\S)/)) {
                    if (!block.startsWith("Display"))
                        continue;
                    const bus = block.match(/\/dev\/i2c-(\d+)/);
                    const conn = block.match(/DRM[_ ]connector:\s+card\d+-(\S+)/);
                    if (bus && conn)
                        buses[conn[1]] = parseInt(bus[1]);
                }
                root.ddcBus = buses;
                root.readQueue = Object.keys(buses);
                root.readNext();
            }
        }
    }
    property var readQueue: []
    property string reading: ""
    function readNext(): void {
        if (ddcGet.running || readQueue.length === 0)
            return;
        reading = readQueue[0];
        readQueue = readQueue.slice(1);
        ddcGet.command = ["ddcutil", "--bus", String(ddcBus[reading]), "getvcp", "10", "--brief"];
        ddcGet.running = true;
    }
    Process {
        id: ddcGet
        stdout: StdioCollector {
            id: getDdcOut
            onStreamFinished: {
                // "VCP 10 C <actual> <máximo>"
                const m = getDdcOut.text.match(/VCP 10 C (\d+) (\d+)/);
                if (m && parseInt(m[2]) > 0) {
                    const vals = Object.assign({}, root.values);
                    vals[root.reading] = parseInt(m[1]) / parseInt(m[2]);
                    root.values = vals;
                }
            }
        }
        onExited: root.readNext()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (["monitoradded", "monitorremoved"].includes(event.name))
                detectTimer.restart();
        }
    }
    // El monitor recién conectado tarda en responder por DDC
    Timer {
        id: detectTimer
        interval: 3000
        onTriggered: root.detect()
    }

    // ---- Backlight de la pantalla interna ----
    Component.onCompleted: {
        backlightProc.running = true;
        detect();
    }
    // Los botones XF86 de Hyprland ajustan brightnessctl directamente. Vigila el backlight
    // para que esos cambios externos también actualicen el OSD y su indicador en la isla.
    Timer {
        interval: 200
        repeat: true
        running: root.backlightOk
        onTriggered: backlightProc.running = true
    }
    Process {
        id: backlightProc
        // Valor, máximo y el conector eDP conectado (aunque esté apagado, Hyprland no lo lista)
        command: ["sh", "-c", "echo $(brightnessctl g) $(brightnessctl m) $(for d in /sys/class/drm/card*-eDP-*; do [ \"$(cat $d/status 2>/dev/null)\" = connected ] && basename $d; done | head -1)"]
        stdout: StdioCollector {
            id: blOut
            onStreamFinished: {
                const parts = blOut.text.trim().split(/\s+/);
                const p = parts.slice(0, 2).map(Number);
                if (!(p[1] > 0))
                    return;
                const internal = (parts[2] ?? "").replace(/^card\d+-/, "") || "eDP-1";
                root.backlightOutput = internal;
                root.backlightOk = true;
                const next = Math.max(0, Math.min(1, p[0] / p[1]));
                if (Math.abs(root.valueFor(internal) - next) > 0.005) {
                    const vals = Object.assign({}, root.values);
                    vals[internal] = next;
                    root.values = vals;
                    if (internal === root.target)
                        root.adjusted();
                }
            }
        }
    }
    Process {
        id: setProc
    }
}
