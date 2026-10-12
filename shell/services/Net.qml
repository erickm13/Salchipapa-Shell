pragma Singleton
// Estado de red vía nmcli (simple y predecible). Sondea cada 5 s.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string type: "none"   // "wifi" | "ethernet" | "none"
    property string name: ""       // SSID o nombre de conexión
    readonly property bool online: type !== "none"

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc
        running: true
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device status | grep ':connected:' | head -1"]

        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                const line = out.text.trim();
                const parts = line.split(":");
                if (parts.length >= 3 && parts[1] === "connected") {
                    root.type = parts[0] === "wifi" ? "wifi" : (parts[0] === "ethernet" ? "ethernet" : parts[0]);
                    root.name = parts.slice(2).join(":");
                } else {
                    root.type = "none";
                    root.name = "";
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
