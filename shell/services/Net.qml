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
    property bool wifiEnabled: true // estado de la radio wifi (nmcli radio wifi)

    function refresh(): void {
        proc.running = true;
        radioProc.running = true;
    }
    function toggleWifi(): void {
        wifiProc.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
        wifiProc.running = true;
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

    // Estado de la radio wifi (encendida/apagada), independiente de si hay conexión
    Process {
        id: radioProc
        running: true
        command: ["nmcli", "-t", "radio", "wifi"]
        stdout: StdioCollector {
            id: radioOut
            onStreamFinished: root.wifiEnabled = radioOut.text.trim() === "enabled"
        }
    }

    // Enciende/apaga la radio wifi; luego refresca el estado
    Process {
        id: wifiProc
        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
