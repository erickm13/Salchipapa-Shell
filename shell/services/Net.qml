pragma Singleton
// Estado de red vía nmcli (simple y predecible). Sondea cada 5 s.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string type: "none"   // "wifi" | "ethernet" | "none"
    property string name: ""       // SSID o nombre de conexión
    property int wifiSignal: 100    // intensidad del AP conectado (0–100)
    property string connectedSsid: ""
    property string connectedSecurity: ""
    property var networks: []
    property bool scanning: false
    property bool connectionPending: false
    property string requestedSsid: ""
    signal connectionFinished(string ssid, bool success)
    readonly property bool online: type !== "none"
    property bool wifiEnabled: true // estado de la radio wifi (nmcli radio wifi)

    function refresh(): void {
        proc.running = true;
        radioProc.running = true;
        signalProc.running = true;
    }
    function toggleWifi(): void {
        wifiProc.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
        wifiProc.running = true;
    }
    function scanNetworks(): void {
        if (scanning)
            return;
        scanning = true;
        scanProc.running = true;
    }
    function connectTo(ssid: string, password): void {
        if (password === undefined)
            password = "";
        requestedSsid = ssid;
        connectionPending = true;
        connectProc.command = password.length > 0
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }
    function disconnectWifi(): void {
        if (name.length === 0)
            return;
        disconnectProc.command = ["nmcli", "connection", "down", "id", name];
        disconnectProc.running = true;
    }
    function parseNmcliFields(line: string): var {
        const fields = [];
        let field = "";
        let escaped = false;
        for (let i = 0; i < line.length; ++i) {
            const ch = line[i];
            if (escaped) {
                field += ch === "n" ? "\n" : (ch === "t" ? "\t" : ch);
                escaped = false;
            } else if (ch === "\\") {
                escaped = true;
            } else if (ch === ":") {
                fields.push(field);
                field = "";
            } else {
                field += ch;
            }
        }
        fields.push(field);
        return fields;
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

    // Intensidad de señal del AP conectado (porcentaje de NetworkManager).
    Process {
        id: signalProc
        running: true
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no | awk -F: '$1 == \"*\" {print $2; exit}'"]
        stdout: StdioCollector {
            id: signalOut
            onStreamFinished: {
                const value = Number.parseInt(signalOut.text.trim(), 10);
                if (Number.isFinite(value) && value >= 0)
                    root.wifiSignal = value;
            }
        }
    }

    // Lista redes cercanas y toma de ahí el SSID activo (el nombre del perfil
    // de NetworkManager no siempre coincide con el SSID).
    Process {
        id: scanProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SECURITY,SIGNAL", "device", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: {
                const found = [];
                root.connectedSsid = "";
                root.connectedSecurity = "";
                const lines = scanOut.text.trim().split("\n");
                for (const line of lines) {
                    if (!line)
                        continue;
                    const fields = root.parseNmcliFields(line);
                    if (fields.length < 4 || fields[1].length === 0)
                        continue;
                    const item = {
                        ssid: fields[1],
                        security: fields[2],
                        signal: Number.parseInt(fields[3], 10) || 0,
                        active: fields[0] === "*"
                    };
                    if (item.active) {
                        root.connectedSsid = item.ssid;
                        root.connectedSecurity = item.security;
                    }
                    const existing = found.findIndex(n => n.ssid === item.ssid);
                    if (existing < 0)
                        found.push(item);
                    else if (item.active || (!found[existing].active && item.signal > found[existing].signal))
                        found[existing] = item;
                }
                root.networks = found;
                root.scanning = false;
            }
        }
        onExited: root.scanning = false
    }

    Process {
        id: connectProc
        onExited: (exitCode, exitStatus) => {
            const ssid = root.requestedSsid;
            root.connectionPending = false;
            root.connectionFinished(ssid, exitCode === 0);
            connectProc.command = ["true"];
            root.refresh();
            delayedScan.start();
        }
    }

    Process {
        id: disconnectProc
        onExited: {
            root.refresh();
            delayedScan.start();
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
        onExited: {
            root.refresh();
            delayedScan.start();
        }
    }

    Timer {
        id: delayedScan
        interval: 1200
        onTriggered: {
            if (root.wifiEnabled)
                root.scanNetworks();
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
