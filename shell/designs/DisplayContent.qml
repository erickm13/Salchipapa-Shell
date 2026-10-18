pragma ComponentBehavior: Bound
// Subpágina "Display" del centro de control: por cada monitor, brillo + escala +
// resolución (aplicados con `hyprctl keyword monitor`), y una card de Night Light.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../common"
import "../services"

Item {
    id: root

    focus: Overlay.mode === "display"
    Keys.onEscapePressed: Overlay.mode = "control"

    // Hyprland solo acepta escalas que dejen dimensiones lógicas enteras (si no, avisa y
    // redondea). De esta lista mostramos solo las válidas para la resolución de cada monitor.
    readonly property var scaleCandidates: [1.0, 1.25, 1.5, 1.6, 1.75, 2.0]
    function validScales(w: int, h: int): var {
        return scaleCandidates.filter(s => {
            const lw = w / s;
            const lh = h / s;
            return Math.abs(lw - Math.round(lw)) < 0.002 && Math.abs(lh - Math.round(lh)) < 0.002;
        });
    }

    // El parser no-legacy (Lua) de Hyprland rechaza `hyprctl keyword`; el monitor se configura
    // con hl.monitor({...}). Como hl.dispatch evalúa su argumento primero, el cambio se aplica
    // como efecto; encadenamos un dispatcher no-op para que hl.dispatch no dé error.
    function applyMonitor(name: string, mode: string, pos: string, scale: real): void {
        Hyprland.dispatch('hl.monitor({output="' + name + '", mode="' + mode + '", position="' + pos + '", scale=' + scale + '}) or hl.dsp.exec_cmd("true")');
        refreshTimer.restart();
    }

    // Hyprland no siempre notifica el cambio de monitor a Quickshell; forzamos el refresco
    Timer {
        id: refreshTimer
        interval: 200
        onTriggered: Hyprland.refreshMonitors()
    }

    // ===== Cabecera =====
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: backMouse.containsMouse ? Theme.panelCard : "transparent"
                Icon {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    px: 22
                    color: Theme.text
                }
                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Overlay.mode = "control"
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Display"
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    // ===== Lista de monitores + Night Light =====
    Column {
        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10

        Repeater {
            model: Hyprland.monitors ? Hyprland.monitors.values : []

            delegate: Rectangle {
                id: mon
                required property var modelData
                readonly property real rr: (mon.modelData.refreshRate ?? mon.modelData.lastIpcObject?.refreshRate) ?? 0
                readonly property string curMode: mon.modelData.width + "x" + mon.modelData.height + "@" + mon.rr.toFixed(2)
                readonly property string pos: mon.modelData.x + "x" + mon.modelData.y
                readonly property var modes: mon.modelData.lastIpcObject?.availableModes ?? []

                width: parent.width
                height: 176
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.04)

                // --- Nombre + resumen + "focused" ---
                Icon {
                    id: monIcon
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: 12
                    anchors.leftMargin: 14
                    text: "desktop_windows"
                    px: 18
                    color: Theme.subtext
                }
                Column {
                    anchors.left: monIcon.right
                    anchors.verticalCenter: monIcon.verticalCenter
                    anchors.leftMargin: 10
                    spacing: 1
                    Text {
                        text: mon.modelData.name
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        text: mon.modelData.width + "×" + mon.modelData.height + " · " + Math.round(mon.rr) + " Hz · " + mon.modelData.scale + "×"
                        color: Theme.subtext
                        font.pixelSize: 10
                    }
                }
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 14
                    anchors.rightMargin: 14
                    text: "focused"
                    color: Theme.green
                    font.pixelSize: 10
                    font.bold: true
                    visible: mon.modelData.focused
                }

                // --- Brillo ---
                SettingSlider {
                    id: monBright
                    anchors.top: monIcon.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 28
                    glyph: "brightness_6"
                    accent: Theme.peach
                    value: Brightness.value
                    enabled: Brightness.available
                    onMoved: v => Brightness.setValue(v)
                }

                // --- Botones de escala ---
                Row {
                    id: scaleRow
                    anchors.top: monBright.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 6

                    Repeater {
                        model: root.validScales(mon.modelData.width, mon.modelData.height)
                        delegate: Rectangle {
                            id: sc
                            required property var modelData
                            readonly property bool active: Math.abs(mon.modelData.scale - sc.modelData) < 0.01
                            width: scLabel.width + 18
                            height: 26
                            radius: 13
                            color: sc.active ? Theme.green : (scMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Text {
                                id: scLabel
                                anchors.centerIn: parent
                                text: sc.modelData + "×"
                                color: sc.active ? Theme.islandBg : Theme.text
                                font.pixelSize: 11
                                font.bold: sc.active
                            }
                            MouseArea {
                                id: scMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyMonitor(mon.modelData.name, mon.curMode, mon.pos, sc.modelData)
                            }
                        }
                    }
                }

                // --- Resolución (cicla los modos disponibles) ---
                Rectangle {
                    anchors.top: scaleRow.bottom
                    anchors.topMargin: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    height: 28
                    radius: 10
                    color: resMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Resolution"
                        color: Theme.subtext
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: resChevron.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: mon.modelData.width + "×" + mon.modelData.height + " @ " + Math.round(mon.rr) + " Hz"
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Icon {
                        id: resChevron
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: "chevron_right"
                        px: 16
                        color: Theme.overlay0
                    }
                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: mon.modes.length > 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Siguiente modo disponible (quita " Hz" -> "WxH@rr")
                            const list = mon.modes.map(m => m.replace("Hz", "").trim());
                            let i = list.findIndex(m => m === mon.curMode);
                            if (i < 0)
                                i = 0;
                            const next = list[(i + 1) % list.length];
                            root.applyMonitor(mon.modelData.name, next, mon.pos, mon.modelData.scale);
                        }
                    }
                }
            }
        }

        // --- Night Light ---
        Rectangle {
            width: parent.width
            height: 56
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)

            Rectangle {
                id: nlBadge
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 18
                color: Quick.nightLight ? Theme.mauve : Theme.panelCardHi
                Icon {
                    anchors.centerIn: parent
                    text: "dark_mode"
                    px: 18
                    color: Quick.nightLight ? Theme.islandBg : Theme.subtext
                }
            }
            Column {
                anchors.left: nlBadge.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: "Night Light"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    text: Quick.nightLight ? "On" : "Off"
                    color: Theme.subtext
                    font.pixelSize: 10
                }
            }

            // Interruptor
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 24
                radius: 12
                color: Quick.nightLight ? Theme.mauve : Theme.panelCardHi
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: Quick.nightLight ? parent.width - width - 3 : 3
                    color: "#ffffff"
                    Behavior on x {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quick.toggleNightLight()
                }
            }
        }
    }

    component Icon: Text {
        property real px: 18
        font.family: "Material Symbols Rounded"
        font.pixelSize: px
        verticalAlignment: Text.AlignVCenter
    }
}
