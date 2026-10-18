pragma Singleton
// Perfiles térmicos ASUS combinados con los perfiles CPU de power-profiles-daemon.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // turbo = ASUS Performance + PPD performance
    // rendimiento = ASUS Balanced + PPD balanced
    // silencioso = ASUS Quiet + PPD power-saver
    property string mode: "balanced"
    property string ppdMode: "balanced"
    property bool asusAvailable: false

    function refresh(): void {
        ppdQuery.exec(["powerprofilesctl", "get"]);
        asusQuery.exec(["asusctl", "profile", "get"]);
    }

    function setMode(value: string): void {
        if (["turbo", "balanced", "silent"].indexOf(value) < 0)
            return;
        mode = value;
        const ppd = value === "turbo" ? "performance" : value === "silent" ? "power-saver" : "balanced";
        ppdMode = ppd;
        ppdSet.exec(["powerprofilesctl", "set", ppd]);
        if (asusAvailable) {
            const asus = value === "turbo" ? "Performance" : value === "silent" ? "Quiet" : "Balanced";
            asusSet.exec(["asusctl", "profile", "set", asus]);
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: ppdQuery
        stdout: StdioCollector {
            id: ppdOutput
            onStreamFinished: {
                const value = ppdOutput.text.trim();
                if (["performance", "balanced", "power-saver"].indexOf(value) < 0)
                    return;
                root.ppdMode = value;
                if (!root.asusAvailable)
                    root.mode = value === "performance" ? "turbo" : value === "power-saver" ? "silent" : "balanced";
            }
        }
    }

    Process {
        id: asusQuery
        stdout: StdioCollector {
            id: asusOutput
            onStreamFinished: {
                const output = asusOutput.text;
                const active = output.match(/Active profile:\s*(Quiet|Balanced|Performance)/i);
                root.asusAvailable = active !== null || /\b(Quiet|Balanced|Performance)\b/i.test(output);
                if (!active)
                    return;
                const value = active[1].toLowerCase();
                root.mode = value === "performance" ? "turbo" : value === "quiet" ? "silent" : "balanced";
            }
        }
    }

    Process { id: ppdSet }
    Process { id: asusSet }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
