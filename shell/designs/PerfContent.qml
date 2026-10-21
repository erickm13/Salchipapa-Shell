pragma ComponentBehavior: Bound
// Página "Performance", DENTRO de la isla (modo "perf", Super+Shift+Esc). Indicadores de CPU, GPU,
// RAM y disco, y el detalle de GPUs, memoria, discos, ventiladores y red. Los datos salen de
// scripts/perf.sh (solo se consulta mientras la página está abierta); el % de CPU, de services/Sys.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../common"
import "../services"

Item {
    id: root

    readonly property bool active: Overlay.mode === "perf"
    property var d: null // último JSON de perf.sh
    property real rxRate: 0 // bytes/s
    property real txRate: 0
    property var _lastNet: null
    property real readRate: 0 // bytes/s del disco de /
    property real writeRate: 0
    property var _lastIo: null

    readonly property var nvidia: d ? (d.gpus.find(g => g.kind === "nvidia") ?? null) : null
    readonly property var igpu: d ? (d.gpus.find(g => g.kind !== "nvidia") ?? null) : null
    readonly property real memUsed: d ? d.mem.MemTotal - d.mem.MemAvailable : 0
    readonly property real swapUsed: d ? d.mem.SwapTotal - d.mem.SwapFree : 0
    readonly property var rootDisk: d ? (d.disks.find(x => x.mount === "/") ?? d.disks[0] ?? null) : null

    function gb(bytes: real): string {
        return bytes >= 1e12 ? (bytes / 1e12).toFixed(1) + " TB" : (bytes / 1073741824).toFixed(bytes >= 1e11 ? 0 : 1) + " GB";
    }
    // Como gb() pero con MB para cantidades pequeñas (tráfico de red)
    function size(bytes: real): string {
        return bytes >= 1073741824 ? gb(bytes) : (bytes / 1048576).toFixed(0) + " MB";
    }
    function rate(bps: real): string {
        return bps >= 1048576 ? (bps / 1048576).toFixed(1) + " MB/s" : (bps / 1024).toFixed(0) + " KB/s";
    }
    // Verde / amarillo / rojo según la carga
    function load(v: real): color {
        return v >= 0.85 ? Theme.red : v >= 0.6 ? Theme.yellow : Theme.green;
    }
    function heat(t: real): color {
        return t >= 90 ? Theme.red : t >= 75 ? Theme.yellow : Theme.secondaryText;
    }

    onActiveChanged: if (active) {
        _lastNet = null;
        _lastIo = null;
        perfProc.running = true;
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: perfProc.running = true
    }
    Process {
        id: perfProc
        command: [Quickshell.shellDir + "/../scripts/perf.sh"]
        stdout: StdioCollector {
            id: perfOut
            onStreamFinished: {
                let next = null;
                try {
                    next = JSON.parse(perfOut.text);
                } catch (e) {
                    return;
                }
                const now = Date.now();
                if (root._lastNet && next.net.iface === root._lastNet.iface) {
                    const dt = (now - root._lastNet.t) / 1000;
                    root.rxRate = Math.max(0, (next.net.rx - root._lastNet.rx) / dt);
                    root.txRate = Math.max(0, (next.net.tx - root._lastNet.tx) / dt);
                }
                root._lastNet = { iface: next.net.iface, rx: next.net.rx, tx: next.net.tx, t: now };
                const io = next.io ?? {};
                if (root._lastIo && io.dev === root._lastIo.dev) {
                    const dt = (now - root._lastIo.t) / 1000;
                    root.readRate = Math.max(0, (io.read - root._lastIo.read) / dt);
                    root.writeRate = Math.max(0, (io.write - root._lastIo.write) / dt);
                }
                root._lastIo = { dev: io.dev, read: io.read, write: io.write, t: now };
                root.d = next;
            }
        }
    }

    // ---- Cabecera ----
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 52
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Performance"
            color: Theme.text
            font.family: Theme.displayFontFamily
            font.pixelSize: Theme.fontPx(20)
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.d ? root.d.cpu.model.replace(/\(R\)|\(TM\)/g, "").replace(/\s+/g, " ") + " · " + root.d.cpu.threads + " threads" : ""
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
    }

    // ---- Indicadores ----
    Row {
        id: gauges
        anchors.top: header.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 28
        Gauge {
            label: "CPU"
            value: Sys.cpu
            big: Math.round(Sys.cpu * 100) + "%"
            sub: root.d && root.d.cpu.temp !== null ? root.d.cpu.temp + " °C" : ""
            subColor: root.d && root.d.cpu.temp !== null ? root.heat(root.d.cpu.temp) : Theme.secondaryText
        }
        Gauge {
            label: "GPU"
            readonly property bool sleeping: root.nvidia !== null && root.nvidia.state === "suspended"
            value: root.nvidia && root.nvidia.util !== undefined ? root.nvidia.util / 100 : 0
            big: sleeping ? "zzz" : (root.nvidia && root.nvidia.util !== undefined ? root.nvidia.util + "%" : "—")
            sub: sleeping ? "Asleep" : (root.nvidia && root.nvidia.temp !== undefined ? root.nvidia.temp + " °C" : "")
            subColor: root.nvidia && root.nvidia.temp !== undefined ? root.heat(root.nvidia.temp) : Theme.secondaryText
        }
        Gauge {
            label: "RAM"
            value: root.d ? root.memUsed / root.d.mem.MemTotal : 0
            big: root.d ? Math.round(root.memUsed / root.d.mem.MemTotal * 100) + "%" : "—"
            sub: root.d ? root.gb(root.memUsed) : ""
        }
        Gauge {
            label: "Disk /"
            value: root.rootDisk ? root.rootDisk.used / root.rootDisk.size : 0
            big: root.rootDisk ? Math.round(root.rootDisk.used / root.rootDisk.size * 100) + "%" : "—"
            sub: root.rootDisk ? root.gb(root.rootDisk.size - root.rootDisk.used) + " free" : ""
        }
    }

    // ---- Detalle ----
    Grid {
        anchors.top: gauges.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        readonly property real cellW: (width - columnSpacing) / 2

        // Las dos tarjetas de cada fila con la misma altura (sin huecos negros debajo)
        Card {
            id: gpuCard
            width: parent.cellW
            height: Math.max(naturalHeight, memCard.naturalHeight)
            title: "GPU"
            icon: "memory"
            readonly property bool nvAwake: root.nvidia !== null && root.nvidia.state !== "suspended" && root.nvidia.memUsed !== undefined
            InfoLine {
                visible: root.nvidia !== null
                label: root.nvidia ? root.nvidia.name.replace("NVIDIA GeForce ", "").replace(" Laptop GPU", "") : ""
                value: !root.nvidia ? "" : root.nvidia.state === "suspended" ? "Asleep (not polled so it stays asleep)"
                    : [root.nvidia.temp !== undefined ? root.nvidia.temp + " °C" : "", root.nvidia.power ? Math.round(root.nvidia.power) + " W" : ""].filter(x => x).join(" · ")
            }
            Bar {
                visible: gpuCard.nvAwake
                label: "VRAM"
                value: gpuCard.nvAwake ? root.nvidia.memUsed / root.nvidia.memTotal : 0
                detail: gpuCard.nvAwake ? root.gb(root.nvidia.memUsed) + " / " + root.gb(root.nvidia.memTotal) : ""
            }
            InfoLine {
                visible: gpuCard.nvAwake && root.nvidia.freq != null
                label: "Clocks"
                value: gpuCard.nvAwake && root.nvidia.freq != null ? root.nvidia.freq + " / " + root.nvidia.maxFreq + " MHz" + (root.nvidia.memFreq ? " · mem " + root.nvidia.memFreq + " MHz" : "") : ""
            }
            InfoLine {
                visible: gpuCard.nvAwake && (root.nvidia.pstate ?? "") !== ""
                label: "Power state"
                value: gpuCard.nvAwake ? (root.nvidia.pstate ?? "") + (root.nvidia.pstate === "P0" ? " (max performance)" : root.nvidia.pstate === "P8" ? " (idle)" : "") : ""
            }
            Bar {
                visible: root.igpu !== null && root.igpu.freq != null
                label: root.igpu ? root.igpu.name : ""
                value: root.igpu && root.igpu.freq != null && root.igpu.maxFreq ? root.igpu.freq / root.igpu.maxFreq : 0
                detail: root.igpu && root.igpu.freq != null ? root.igpu.freq + " / " + root.igpu.maxFreq + " MHz" : ""
            }
        }
        Card {
            id: memCard
            width: parent.cellW
            height: Math.max(naturalHeight, gpuCard.naturalHeight)
            title: "Memory"
            icon: "memory_alt"
            Bar {
                label: "RAM"
                value: root.d ? root.memUsed / root.d.mem.MemTotal : 0
                detail: root.d ? root.gb(root.memUsed) + " / " + root.gb(root.d.mem.MemTotal) : ""
            }
            Bar {
                visible: root.d !== null && root.d.mem.SwapTotal > 0
                label: "Swap"
                value: root.d && root.d.mem.SwapTotal > 0 ? root.swapUsed / root.d.mem.SwapTotal : 0
                detail: root.d ? root.gb(root.swapUsed) + " / " + root.gb(root.d.mem.SwapTotal) : ""
            }
            InfoLine {
                visible: root.d !== null
                label: "Available"
                value: root.d ? root.gb(root.d.mem.MemAvailable) : ""
            }
            InfoLine {
                visible: root.d !== null && root.d.mem.Cached !== undefined
                label: "Cache & buffers"
                value: root.d && root.d.mem.Cached !== undefined ? root.gb(root.d.mem.Cached + root.d.mem.Buffers) : ""
            }
            InfoLine {
                visible: root.d !== null && root.d.mem.Committed_AS !== undefined
                label: "Committed"
                value: root.d && root.d.mem.Committed_AS !== undefined ? root.gb(root.d.mem.Committed_AS) + " of " + root.gb(root.d.mem.MemTotal + root.d.mem.SwapTotal) : ""
            }
        }
        Card {
            id: diskCard
            width: parent.cellW
            height: Math.max(naturalHeight, fanCard.naturalHeight)
            title: "Disks"
            icon: "hard_drive"
            readonly property var io: root.d && root.d.io && root.d.io.dev ? root.d.io : null
            InfoLine {
                visible: diskCard.io !== null
                label: diskCard.io ? (diskCard.io.model || diskCard.io.dev).replace(/_/g, " ") : ""
                value: diskCard.io && diskCard.io.temp !== null ? diskCard.io.temp + " °C" : ""
            }
            InfoLine {
                visible: diskCard.io !== null
                label: "Read / Write"
                value: "↓ " + root.rate(root.readRate) + "   ↑ " + root.rate(root.writeRate)
            }
            Repeater {
                model: root.d ? root.d.disks : []
                delegate: Bar {
                    required property var modelData
                    label: modelData.mount
                    value: modelData.used / modelData.size
                    detail: root.gb(modelData.used) + " / " + root.gb(modelData.size)
                }
            }
        }
        Card {
            id: fanCard
            width: parent.cellW
            height: Math.max(naturalHeight, diskCard.naturalHeight)
            title: "Fans & Network"
            icon: "mode_fan"
            Repeater {
                model: root.d ? root.d.fans : []
                delegate: InfoLine {
                    required property var modelData
                    label: ({ cpu_fan: "CPU fan", gpu_fan: "GPU fan", mid_fan: "Middle fan" })[modelData.label] ?? modelData.label
                    value: modelData.rpm > 0 ? modelData.rpm + " rpm" : "Stopped"
                }
            }
            InfoLine {
                visible: root.d !== null && root.d.net.iface !== ""
                label: root.d ? "Network (" + root.d.net.iface + ")" : ""
                value: "↓ " + root.rate(root.rxRate) + "   ↑ " + root.rate(root.txRate)
            }
            InfoLine {
                visible: root.d !== null && root.d.net.iface !== ""
                label: "Since boot"
                value: root.d ? "↓ " + root.size(root.d.net.rx) + "   ↑ " + root.size(root.d.net.tx) : ""
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: "Updates every 2 s · Esc: close"
        color: Theme.overlay1
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(11)
    }

    focus: active
    Keys.onEscapePressed: Overlay.close()

    // Indicador circular (arco de 270°)
    component Gauge: Item {
        id: g
        property string label: ""
        property real value: 0
        property string big: ""
        property string sub: ""
        property color subColor: Theme.secondaryText
        readonly property color accent: root.load(value)
        width: 164
        height: 168
        Shape {
            id: arc
            width: 136
            height: 136
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Theme.panelCardHi
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 68; centerY: 68; radiusX: 60; radiusY: 60; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                strokeColor: g.accent
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 68; centerY: 68; radiusX: 60; radiusY: 60; startAngle: 135
                    sweepAngle: 270 * Math.max(0.001, Math.min(1, g.value))
                    Behavior on sweepAngle {
                        NumberAnimation { duration: Theme.movementDuration; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        Column {
            anchors.centerIn: arc
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.big
                color: Theme.text
                font.family: Theme.displayFontFamily
                font.pixelSize: Theme.fontPx(28)
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.sub
                color: g.subColor
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(13)
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: g.label
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(15)
            font.bold: true
        }
    }

    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias rows: rowsCol.data
        readonly property real naturalHeight: rowsCol.implicitHeight + 50
        radius: Theme.radiusMedium
        color: Theme.panelCard
        Row {
            x: 12
            y: 9
            spacing: 8
            Text {
                text: card.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20
                color: Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.title
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(14)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Column {
            id: rowsCol
            x: 12
            y: 40
            width: card.width - 24
            spacing: 8
        }
    }

    component InfoLine: Item {
        id: il
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: 22
        Text {
            anchors.left: parent.left
            anchors.right: ilValue.left
            anchors.rightMargin: 6
            text: il.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
            elide: Text.ElideRight
        }
        Text {
            id: ilValue
            anchors.right: parent.right
            text: il.value
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
            elide: Text.ElideLeft
            width: Math.min(implicitWidth, il.width * 0.68)
            horizontalAlignment: Text.AlignRight
        }
    }

    component Bar: Item {
        id: bar
        property string label: ""
        property real value: 0
        property string detail: ""
        width: parent ? parent.width : 0
        height: 36
        Text {
            anchors.left: parent.left
            text: bar.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
        Text {
            anchors.right: parent.right
            text: bar.detail
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(14)
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 6
            radius: 3
            color: Theme.panelCardHi
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, bar.value))
                height: parent.height
                radius: 3
                color: root.load(bar.value)
                Behavior on width {
                    NumberAnimation { duration: Theme.movementDuration; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
