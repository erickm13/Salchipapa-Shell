pragma ComponentBehavior: Bound
// Página "Rendimiento", DENTRO de la isla (modo "perf", Super+Shift+Esc). Indicadores de CPU, GPU,
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

    readonly property var nvidia: d ? (d.gpus.find(g => g.kind === "nvidia") ?? null) : null
    readonly property var igpu: d ? (d.gpus.find(g => g.kind !== "nvidia") ?? null) : null
    readonly property real memUsed: d ? d.mem.MemTotal - d.mem.MemAvailable : 0
    readonly property real swapUsed: d ? d.mem.SwapTotal - d.mem.SwapFree : 0
    readonly property var rootDisk: d ? (d.disks.find(x => x.mount === "/") ?? d.disks[0] ?? null) : null

    function gb(bytes: real): string {
        return bytes >= 1e12 ? (bytes / 1e12).toFixed(1) + " TB" : (bytes / 1073741824).toFixed(bytes >= 1e11 ? 0 : 1) + " GB";
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
        height: 40
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Rendimiento"
            color: Theme.text
            font.family: Theme.displayFontFamily
            font.pixelSize: Theme.fontPx(15)
            font.bold: true
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.d ? root.d.cpu.model.replace(/\(R\)|\(TM\)/g, "").replace(/\s+/g, " ") + " · " + root.d.cpu.threads + " hilos" : ""
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
    }

    // ---- Indicadores ----
    Row {
        id: gauges
        anchors.top: header.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 18
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
            sub: sleeping ? "En reposo" : (root.nvidia && root.nvidia.temp !== undefined ? root.nvidia.temp + " °C" : "")
            subColor: root.nvidia && root.nvidia.temp !== undefined ? root.heat(root.nvidia.temp) : Theme.secondaryText
        }
        Gauge {
            label: "RAM"
            value: root.d ? root.memUsed / root.d.mem.MemTotal : 0
            big: root.d ? Math.round(root.memUsed / root.d.mem.MemTotal * 100) + "%" : "—"
            sub: root.d ? root.gb(root.memUsed) : ""
        }
        Gauge {
            label: "Disco /"
            value: root.rootDisk ? root.rootDisk.used / root.rootDisk.size : 0
            big: root.rootDisk ? Math.round(root.rootDisk.used / root.rootDisk.size * 100) + "%" : "—"
            sub: root.rootDisk ? root.gb(root.rootDisk.size - root.rootDisk.used) + " libres" : ""
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

        Card {
            width: parent.cellW
            title: "GPU"
            icon: "memory"
            InfoLine {
                visible: root.nvidia !== null
                label: root.nvidia ? root.nvidia.name.replace("NVIDIA GeForce ", "").replace(" Laptop GPU", "") : ""
                value: !root.nvidia ? "" : root.nvidia.state === "suspended" ? "En reposo (no se consulta para no despertarla)"
                    : (root.nvidia.memUsed !== undefined ? root.gb(root.nvidia.memUsed) + " / " + root.gb(root.nvidia.memTotal) + " VRAM" : "")
                    + (root.nvidia.power ? " · " + Math.round(root.nvidia.power) + " W" : "")
            }
            InfoLine {
                visible: root.igpu !== null
                label: root.igpu ? root.igpu.name : ""
                value: root.igpu && root.igpu.freq !== null ? root.igpu.freq + " / " + root.igpu.maxFreq + " MHz" : ""
            }
        }
        Card {
            width: parent.cellW
            title: "Memoria"
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
        }
        Card {
            width: parent.cellW
            title: "Discos"
            icon: "hard_drive"
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
            width: parent.cellW
            title: "Ventiladores y red"
            icon: "mode_fan"
            Repeater {
                model: root.d ? root.d.fans : []
                delegate: InfoLine {
                    required property var modelData
                    label: ({ cpu_fan: "Ventilador CPU", gpu_fan: "Ventilador GPU", mid_fan: "Ventilador central" })[modelData.label] ?? modelData.label
                    value: modelData.rpm > 0 ? modelData.rpm + " rpm" : "Parado"
                }
            }
            InfoLine {
                visible: root.d !== null && root.d.net.iface !== ""
                label: root.d ? "Red (" + root.d.net.iface + ")" : ""
                value: "↓ " + root.rate(root.rxRate) + "   ↑ " + root.rate(root.txRate)
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        text: "Se actualiza cada 2 s · Esc: cerrar"
        color: Theme.overlay1
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(10)
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
        width: 116
        height: 124
        Shape {
            id: arc
            width: 96
            height: 96
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            layer.enabled: true
            layer.samples: 4
            ShapePath {
                strokeColor: Theme.panelCardHi
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 48; centerY: 48; radiusX: 42; radiusY: 42; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
                strokeColor: g.accent
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 48; centerY: 48; radiusX: 42; radiusY: 42; startAngle: 135
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
                font.pixelSize: Theme.fontPx(18)
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: g.sub
                color: g.subColor
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(9)
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: g.label
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(11)
            font.bold: true
        }
    }

    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias rows: rowsCol.data
        height: rowsCol.implicitHeight + 40
        radius: Theme.radiusMedium
        color: Theme.panelCard
        Row {
            x: 12
            y: 9
            spacing: 6
            Text {
                text: card.icon
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
                color: Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.title
                color: Theme.secondaryText
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Column {
            id: rowsCol
            x: 12
            y: 32
            width: card.width - 24
            spacing: 6
        }
    }

    component InfoLine: Item {
        id: il
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: 16
        Text {
            anchors.left: parent.left
            anchors.right: ilValue.left
            anchors.rightMargin: 6
            text: il.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            elide: Text.ElideRight
        }
        Text {
            id: ilValue
            anchors.right: parent.right
            text: il.value
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
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
        height: 26
        Text {
            anchors.left: parent.left
            text: bar.label
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
        Text {
            anchors.right: parent.right
            text: bar.detail
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 5
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
