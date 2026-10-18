pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

Item {
    id: root
    implicitHeight: content.implicitHeight
    property var processes: []
    property string processFilter: ""
    property int pendingPid: 0

    function refreshProcesses(): void {
        const user = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
        if (user.length === 0) {
            processes = [];
            return;
        }
        processQuery.exec(["ps", "-u", user, "-o", "pid=,%cpu=,%mem=,comm=", "--sort=-%cpu"]);
    }

    function readProcesses(output: string): void {
        const protectedNames = ["qs", "quickshell", "Hyprland", "hyprland", "systemd", "salchipapa-shell", "ps", "kill"];
        const rows = [];
        const lines = output.trim().split("\n");
        for (let i = 0; i < lines.length; ++i) {
            const fields = lines[i].trim().split(/\s+/);
            if (fields.length < 4)
                continue;
            const pid = Number(fields[0]);
            const name = fields.slice(3).join(" ");
            if (!Number.isFinite(pid) || pid <= 0 || protectedNames.includes(name))
                continue;
            rows.push({ pid: pid, name: name, cpu: fields[1], memory: fields[2] });
        }
        processes = rows;
    }

    function endProcess(pid: int): void {
        if (pid <= 0)
            return;
        processTerminator.exec(["kill", "-TERM", String(pid)]);
        pendingPid = 0;
        refreshTimer.restart();
    }

    onVisibleChanged: if (visible) refreshProcesses()

    Process {
        id: processQuery
        stdout: StdioCollector {
            id: processOutput
            onStreamFinished: root.readProcesses(processOutput.text)
        }
    }
    Process { id: processTerminator }
    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refreshProcesses()
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.visible
        onTriggered: root.refreshProcesses()
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(4)

        SettingsGroup {
            width: parent.width
            ToggleRow {
                label: "Window blur"
                checked: Config.windowBlurEnabled
                onToggled: Config.opt.windowBlurEnabled = !Config.windowBlurEnabled
            }
            SliderRow {
                label: "Blur size"
                value: Config.windowBlurSize
                from: 1; to: 20; unit: ""
                enabled: Config.windowBlurEnabled
                onMoved: v => Config.opt.windowBlurSize = v
            }
            SliderRow {
                label: "Blur passes"
                value: Config.windowBlurPasses
                from: 1; to: 6; unit: ""
                enabled: Config.windowBlurEnabled
                onMoved: v => Config.opt.windowBlurPasses = v
            }
        }

        Text {
            width: parent.width
            text: "These are Hyprland's global blur settings for eligible windows. Per-application exceptions require window rules."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }

        Text {
            width: parent.width
            text: "TASK MANAGER"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            leftPadding: 2
        }

        Rectangle {
            width: parent.width
            height: processGroup.implicitHeight
            radius: Theme.radiusMedium
            color: Theme.panelCard
            Column {
                id: processGroup
                width: parent.width
                spacing: 8
                Item {
                    width: parent.width
                    height: 38
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Running applications"
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(12)
                        font.bold: true
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "refresh"
                        color: refreshMouse.containsMouse ? Theme.text : Theme.secondaryText
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Theme.iconPx(18)
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent; anchors.margins: -6
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshProcesses()
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 30; radius: 10; color: Theme.panelCardHi
                    TextInput {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.processFilter
                        onTextChanged: root.processFilter = text
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(11)
                        clip: true
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Filter processes"
                            color: Theme.tertiaryText
                            font: parent.font
                            visible: parent.text.length === 0
                        }
                    }
                }
                Flickable {
                    width: parent.width
                    height: Math.min(260, Math.max(42, processList.implicitHeight))
                    contentHeight: processList.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: processList
                        width: parent.width
                        spacing: 4
                        Repeater {
                            model: root.processes.filter(p => root.processFilter.trim() === "" || p.name.toLowerCase().includes(root.processFilter.trim().toLowerCase()))
                            delegate: Rectangle {
                                id: processRow
                                required property var modelData
                                width: processList.width - 20
                                height: 38
                                x: 10
                                radius: 10
                                color: Theme.panelCardHi
                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    anchors.right: endButton.left; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: processRow.modelData.name + "  ·  PID " + processRow.modelData.pid + "  ·  " + processRow.modelData.cpu + "% CPU  ·  " + processRow.modelData.memory + "% RAM"
                                    color: Theme.text
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(10)
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    id: endButton
                                    anchors.right: parent.right; anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: endLabel.implicitWidth + 16; height: 26; radius: 13
                                    color: processRow.modelData.pid === root.pendingPid ? Theme.red : Theme.panelCard
                                    Text {
                                        id: endLabel
                                        anchors.centerIn: parent
                                        text: processRow.modelData.pid === root.pendingPid ? "Confirm" : "End"
                                        color: Theme.text
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: Theme.fontPx(9)
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (processRow.modelData.pid === root.pendingPid)
                                                root.endProcess(processRow.modelData.pid);
                                            else
                                                root.pendingPid = processRow.modelData.pid;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "No matching processes"
                        color: Theme.tertiaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                        visible: root.processes.filter(p => root.processFilter.trim() === "" || p.name.toLowerCase().includes(root.processFilter.trim().toLowerCase())).length === 0
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: "Only processes owned by your user are listed. Ending a process sends SIGTERM; core session processes are hidden."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }

        SettingsGroup {
            width: parent.width
            SliderRow {
                label: "Hyprland workspaces shown"
                value: Config.workspaceCount
                from: 1; to: 10; unit: ""
                onMoved: v => Config.opt.workspaceCount = v
            }
        }

        Rectangle {
            width: parent.width
            height: infoColumn.implicitHeight + 24
            radius: Theme.radiusMedium
            color: Theme.panelCard
            Column {
                id: infoColumn
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12
                spacing: 8
                Text {
                    text: "System information"
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                }
                InfoRow { label: "Compositor"; value: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland" }
                InfoRow { label: "Session"; value: Quickshell.env("XDG_SESSION_TYPE") || "Wayland" }
                InfoRow { label: "Settings file"; value: "~/.config/salchipapa-shell/config.json" }
            }
        }

        Text {
            width: parent.width
            text: "Workspace count controls the workspace indicators in the island. Other system services are managed by Hyprland and your user session."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
    }

    component SettingsGroup: Rectangle {
        default property alias rows: rowsColumn.data
        implicitHeight: rowsColumn.implicitHeight
        height: implicitHeight
        radius: Theme.radiusMedium
        color: Theme.panelCard
        clip: true
        Column { id: rowsColumn; width: parent.width; spacing: 0 }
    }

    component ToggleRow: Item {
        id: row
        property string label: ""
        property bool checked: false
        signal toggled
        width: parent.width
        height: 42
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.label; color: Theme.text
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(11)
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 18; radius: 9
            color: row.checked ? Theme.green : Theme.panelCardHi
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? parent.width - width - 2 : 2
                color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 10; anchors.rightMargin: 10
            height: 1; color: Theme.divider
        }
    }

    component SliderRow: Item {
        id: row
        property string label: ""
        property int value: 0
        property int from: 0
        property int to: 100
        property string unit: ""
        signal moved(int value)
        width: parent.width
        height: 48
        opacity: enabled ? 1 : 0.45
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12; anchors.top: parent.top; anchors.topMargin: 5
            text: row.label; color: Theme.text
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(11)
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 5
            text: String(row.value) + row.unit; color: Theme.secondaryText
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(10)
        }
        Rectangle {
            id: track
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            anchors.leftMargin: 12; anchors.rightMargin: 12
            height: 4; radius: 2; color: Theme.panelCardHi
            Rectangle {
                id: fill
                width: track.width * Math.max(0, Math.min(1, (row.value - row.from) / Math.max(1, row.to - row.from)))
                height: parent.height; radius: 2; color: Theme.green
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter; color: Theme.text
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -15; anchors.bottomMargin: -12
                cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: row.enabled
                function setAt(x: real): void {
                    row.moved(Math.round(row.from + Math.max(0, Math.min(1, x / track.width)) * (row.to - row.from)));
                }
                onPressed: mouse => setAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) setAt(mouse.x); }
            }
        }
    }

    component InfoRow: Row {
        id: row
        property string label: ""
        property string value: ""
        width: parent.width
        spacing: 8
        Text {
            width: row.width * 0.32
            text: row.label
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
        Text {
            width: row.width * 0.68 - row.spacing
            text: row.value
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
            elide: Text.ElideMiddle
        }
    }
}
