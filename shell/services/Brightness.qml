pragma Singleton
// Brillo de la pantalla vía brightnessctl (backlight). Si no hay backlight, available=false.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 1 // 0..1
    property bool available: false

    function refresh(): void {
        getProc.running = true;
    }
    function setValue(v: real): void {
        value = Math.max(0.01, Math.min(1, v));
        setProc.command = ["brightnessctl", "-q", "set", Math.round(value * 100) + "%"];
        setProc.running = true;
    }
    function add(d: real): void {
        setValue(value + d);
    }

    Component.onCompleted: refresh()

    Process {
        id: getProc
        command: ["sh", "-c", "echo $(brightnessctl g) $(brightnessctl m)"]
        stdout: StdioCollector {
            id: getOut
            onStreamFinished: {
                const p = getOut.text.trim().split(/\s+/).map(Number);
                if (p.length === 2 && p[1] > 0) {
                    root.value = p[0] / p[1];
                    root.available = true;
                }
            }
        }
    }

    Process {
        id: setProc
    }
}
