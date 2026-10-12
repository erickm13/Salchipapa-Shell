pragma Singleton
// Uso de CPU y RAM leyendo /proc (sin lanzar procesos). Refresca cada 2 s.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0   // 0..1
    property real mem: 0   // 0..1

    property int _lastTotal: 0
    property int _lastIdle: 0

    function _tick(): void {
        statFile.reload();
        memFile.reload();
    }

    Component.onCompleted: _tick()

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root._tick()
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const line = statFile.text().split("\n")[0]; // "cpu  u n s idle iowait irq softirq steal..."
            const v = line.trim().split(/\s+/).slice(1).map(Number);
            const idle = (v[3] ?? 0) + (v[4] ?? 0);
            const total = v.reduce((a, b) => a + b, 0);
            const dt = total - root._lastTotal;
            const di = idle - root._lastIdle;
            if (dt > 0)
                root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
            root._lastTotal = total;
            root._lastIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const t = memFile.text();
            const total = parseInt((t.match(/MemTotal:\s+(\d+)/) || [])[1] ?? 0);
            const avail = parseInt((t.match(/MemAvailable:\s+(\d+)/) || [])[1] ?? 0);
            if (total > 0)
                root.mem = (total - avail) / total;
        }
    }
}
