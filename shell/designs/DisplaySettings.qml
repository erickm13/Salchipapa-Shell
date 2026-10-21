pragma ComponentBehavior: Bound
// Ajustes > Display: colocación de monitores (arrastrar), resolución, frecuencia, orientación,
// encendido y monitor principal. Cada cambio se guarda como perfil de esa combinación de
// monitores en display-profiles.json, que scripts/monitor-autodetect reaplica al reconectar.
//
// Los monitores se aplican con `hyprctl eval 'hl.monitor({...})'` (con la config en Lua
// `hyprctl keyword` no vale) y siempre con `disabled = false` explícito al encender.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"

Item {
    id: root
    implicitHeight: content.implicitHeight

    readonly property string profilesPath: Quickshell.env("HOME") + "/.config/salchipapa-shell/display-profiles.json"
    readonly property var orientationLabels: ["Landscape", "Portrait", "Landscape (flipped)", "Portrait (flipped)"]

    // Todos los monitores (incluidos los apagados), de `hyprctl monitors all -j`
    property var monitors: []
    readonly property var enabledMonitors: monitors.filter(m => !m.disabled)
    readonly property var disabledMonitors: monitors.filter(m => m.disabled)
    property string selectedName: ""
    readonly property var selected: monitors.find(m => m.name === selectedName) ?? null
    property int primaryWorkspaceMonitorId: -1

    // Posiciones arrastradas sin aplicar, y las anteriores para revertir
    property var pendingPositions: ({})
    property var previousPositions: ({})
    property bool hasUnsavedPositions: false
    property int countdown: 0
    property bool saveAfterRefresh: false

    // Tamaño lógico (lo que ocupa en el escritorio): con giro de 90° se intercambian lados
    function logicalW(m: var): real {
        const rotated = (m.transform % 2) === 1;
        return (rotated ? m.height : m.width) / (m.scale || 1);
    }
    function logicalH(m: var): real {
        const rotated = (m.transform % 2) === 1;
        return (rotated ? m.width : m.height) / (m.scale || 1);
    }
    function posX(m: var): real { return pendingPositions[m.name]?.x ?? m.x; }
    function posY(m: var): real { return pendingPositions[m.name]?.y ?? m.y; }

    function resolutions(m: var): var {
        if (!m)
            return [];
        const seen = {};
        const list = [];
        for (const mode of (m.availableModes ?? [])) {
            const r = mode.replace(/@.*/, "");
            if (!seen[r]) {
                seen[r] = true;
                list.push(r);
            }
        }
        return list.sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number);
            const [bw, bh] = b.split("x").map(Number);
            return bw * bh - aw * ah;
        });
    }
    function rates(m: var, res: string): var {
        if (!m)
            return [];
        return (m.availableModes ?? []).filter(mode => mode.startsWith(res + "@")).map(mode => mode.replace(/^.*@/, "").replace("Hz", "")).sort((a, b) => parseFloat(b) - parseFloat(a));
    }
    function currentRes(m: var): string { return m ? m.width + "x" + m.height : ""; }
    // La frecuencia de la lista de modos más cercana a la actual (165.015 -> "165.02")
    function currentRate(m: var): string {
        const list = rates(m, currentRes(m));
        let best = list[0] ?? String(Math.round(m?.refreshRate ?? 60));
        for (const r of list)
            if (Math.abs(parseFloat(r) - m.refreshRate) < Math.abs(parseFloat(best) - m.refreshRate))
                best = r;
        return best;
    }

    function monitorLua(m: var, o: var): string {
        const mode = (o.res ?? currentRes(m)) + "@" + (o.hz ?? currentRate(m));
        const x = o.x ?? m.x;
        const y = o.y ?? m.y;
        const position = o.position ?? (Math.round(x) + "x" + Math.round(y));
        const transform = o.transform ?? m.transform;
        return 'hl.monitor({ output = "' + m.name + '", disabled = false, mode = "' + mode + '", position = "' + position + '", scale = ' + (m.scale || 1) + ', transform = ' + transform + ' })';
    }

    function apply(lua: string): void {
        applyProc.exec(["hyprctl", "eval", lua]);
        saveAfterRefresh = true;
        refreshTimer.restart();
    }

    function refresh(): void {
        monitorsQuery.exec(["hyprctl", "monitors", "all", "-j"]);
        workspacesQuery.exec(["hyprctl", "workspaces", "-j"]);
    }

    function readMonitors(text: string): void {
        let list = [];
        try {
            list = JSON.parse(text).filter(m => m.name && m.name !== "FALLBACK" && !m.name.startsWith("HEADLESS"));
        } catch (e) {
            return;
        }
        monitors = list;
        if (!monitors.find(m => m.name === selectedName))
            selectedName = (enabledMonitors[0] ?? monitors[0])?.name ?? "";
        if (!hasUnsavedPositions && countdown === 0)
            pendingPositions = ({});
        if (saveAfterRefresh) {
            saveAfterRefresh = false;
            saveProfile();
        }
    }

    // Perfil de la combinación actual (misma clave que scripts/monitor-autodetect)
    function saveProfile(): void {
        const key = monitors.map(m => m.name).sort().join("|");
        if (key === "")
            return;
        let profiles = {};
        try {
            const t = profilesFile.text();
            profiles = t && t.trim() ? JSON.parse(t) : {};
        } catch (e) {
            profiles = {};
        }
        profiles[key] = monitors.map(m => m.disabled ? { name: m.name, disabled: true } : {
            name: m.name,
            res: currentRes(m),
            hz: String(Math.round(m.refreshRate)),
            x: m.x,
            y: m.y,
            scale: m.scale || 1,
            transform: m.transform,
            disabled: false
        });
        profilesFile.setText(JSON.stringify(profiles, null, 2) + "\n");
    }

    // Imán: al soltar, pega el monitor a los bordes de los demás si está a menos de 80 px
    function snap(name: string, x: real, y: real): point {
        const SNAP = 80;
        const mon = monitors.find(m => m.name === name);
        if (!mon)
            return Qt.point(x, y);
        const w = logicalW(mon);
        const h = logicalH(mon);
        let bestX = x, dx = SNAP, bestY = y, dy = SNAP;
        for (const o of enabledMonitors) {
            if (o.name === name)
                continue;
            const ox = posX(o), oy = posY(o), ow = logicalW(o), oh = logicalH(o);
            for (const c of [{ v: ox - w, d: Math.abs(x + w - ox) }, { v: ox + ow, d: Math.abs(x - ox - ow) }, { v: ox, d: Math.abs(x - ox) }])
                if (c.d < dx) { dx = c.d; bestX = c.v; }
            for (const c of [{ v: oy, d: Math.abs(y - oy) }, { v: oy + oh - h, d: Math.abs(y + h - oy - oh) }, { v: oy - h, d: Math.abs(y + h - oy) }, { v: oy + oh, d: Math.abs(y - oy - oh) }])
                if (c.d < dy) { dy = c.d; bestY = c.v; }
        }
        return Qt.point(bestX, bestY);
    }

    function applyPositions(positions: var): void {
        let minX = Infinity, minY = Infinity;
        for (const m of enabledMonitors) {
            minX = Math.min(minX, positions[m.name]?.x ?? m.x);
            minY = Math.min(minY, positions[m.name]?.y ?? m.y);
        }
        const lua = enabledMonitors.map(m => monitorLua(m, { x: (positions[m.name]?.x ?? m.x) - minX, y: (positions[m.name]?.y ?? m.y) - minY })).join("\n");
        apply(lua);
    }

    function setEnabled(m: var, on: bool): void {
        if (on)
            apply(monitorLua(m, { res: resolutions(m)[0] ?? currentRes(m), hz: rates(m, resolutions(m)[0] ?? currentRes(m))[0], position: "auto", transform: m.transform ?? 0 }));
        else if (enabledMonitors.length > 1)
            apply('hl.monitor({ output = "' + m.name + '", disabled = true })');
    }

    function makePrimary(m: var): void {
        // Llevar el workspace 1 a ese monitor: enfocarlo y moverlo
        Hyprland.dispatch("hl.dsp.focus({ workspace = 1 })");
        Hyprland.dispatch('hl.dsp.workspace.move({ monitor = "' + m.name + '" })');
        refreshTimer.restart();
    }

    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()

    Process {
        id: monitorsQuery
        stdout: StdioCollector {
            id: monitorsOut
            onStreamFinished: root.readMonitors(monitorsOut.text)
        }
    }
    Process {
        id: workspacesQuery
        stdout: StdioCollector {
            id: workspacesOut
            onStreamFinished: {
                try {
                    const ws = JSON.parse(workspacesOut.text).find(w => w.id === 1);
                    root.primaryWorkspaceMonitorId = ws ? ws.monitorID : -1;
                } catch (e) {}
            }
        }
    }
    Process { id: applyProc }
    FileView {
        id: profilesFile
        path: root.profilesPath
        printErrors: false
    }
    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }
    // Cuenta atrás tras mover monitores: si no se confirma, vuelven a su sitio
    Timer {
        interval: 1000
        repeat: true
        running: root.countdown > 0
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown === 0) {
                root.applyPositions(root.previousPositions);
                root.pendingPositions = ({});
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (root.visible && ["monitoradded", "monitorremoved", "configreloaded"].includes(event.name))
                refreshTimer.restart();
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(4)

        SectionLabel { text: "LAYOUT" }

        // ---- Vista previa: arrastra los monitores para colocarlos ----
        Rectangle {
            width: parent.width
            height: 210
            radius: Theme.radiusMedium
            color: Theme.panelCard

            Item {
                id: preview
                anchors.fill: parent
                anchors.margins: 14

                readonly property real offColW: root.disabledMonitors.length > 0 ? 110 : 0
                readonly property real minX: { let v = Infinity; for (const m of root.enabledMonitors) v = Math.min(v, root.posX(m)); return isFinite(v) ? v : 0; }
                readonly property real minY: { let v = Infinity; for (const m of root.enabledMonitors) v = Math.min(v, root.posY(m)); return isFinite(v) ? v : 0; }
                readonly property real totalW: { let v = 1; for (const m of root.enabledMonitors) v = Math.max(v, root.posX(m) + root.logicalW(m)); return v - minX; }
                readonly property real totalH: { let v = 1; for (const m of root.enabledMonitors) v = Math.max(v, root.posY(m) + root.logicalH(m)); return v - minY; }
                readonly property real k: Math.min((width - offColW) / totalW, height / totalH) * 0.88
                readonly property real ox: offColW + (width - offColW - totalW * k) / 2
                readonly property real oy: (height - totalH * k) / 2

                Repeater {
                    model: root.enabledMonitors
                    delegate: Rectangle {
                        id: box
                        required property var modelData
                        readonly property bool isSelected: modelData.name === root.selectedName
                        property bool dragging: false
                        property real frozenK: 1
                        property real frozenOx: 0
                        property real frozenOy: 0
                        property real frozenMinX: 0
                        property real frozenMinY: 0

                        width: root.logicalW(modelData) * preview.k
                        height: root.logicalH(modelData) * preview.k
                        radius: 6
                        color: isSelected ? Theme.selectedFill : Theme.panelCardHi
                        border.width: isSelected ? 2 : 1
                        border.color: isSelected ? Theme.green : Theme.divider

                        Binding on x {
                            value: preview.ox + (root.posX(box.modelData) - preview.minX) * preview.k
                            when: !box.dragging
                            restoreMode: Binding.RestoreNone
                        }
                        Binding on y {
                            value: preview.oy + (root.posY(box.modelData) - preview.minY) * preview.k
                            when: !box.dragging
                            restoreMode: Binding.RestoreNone
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: box.modelData.name
                                color: Theme.text
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(13)
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.currentRes(box.modelData) + " · " + Math.round(box.modelData.refreshRate) + " Hz"
                                color: Theme.secondaryText
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(11)
                                visible: box.width > 90
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            drag.target: box
                            preventStealing: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: {
                                box.frozenK = preview.k;
                                box.frozenOx = preview.ox;
                                box.frozenOy = preview.oy;
                                box.frozenMinX = preview.minX;
                                box.frozenMinY = preview.minY;
                                box.dragging = true;
                                root.selectedName = box.modelData.name;
                            }
                            onReleased: {
                                const rawX = (box.x - box.frozenOx) / box.frozenK + box.frozenMinX;
                                const rawY = (box.y - box.frozenOy) / box.frozenK + box.frozenMinY;
                                const p = root.snap(box.modelData.name, rawX, rawY);
                                box.dragging = false;
                                const nx = Math.round(p.x), ny = Math.round(p.y);
                                if (nx !== Math.round(root.posX(box.modelData)) || ny !== Math.round(root.posY(box.modelData))) {
                                    const pos = Object.assign({}, root.pendingPositions);
                                    pos[box.modelData.name] = { x: nx, y: ny };
                                    root.pendingPositions = pos;
                                    root.hasUnsavedPositions = true;
                                }
                            }
                        }
                    }
                }

                // Apagados: a la izquierda, clic para seleccionarlos y volver a encenderlos
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: root.disabledMonitors
                        delegate: Rectangle {
                            id: offBox
                            required property var modelData
                            width: 120
                            height: 54
                            radius: 6
                            opacity: 0.6
                            color: Theme.panelCardHi
                            border.width: modelData.name === root.selectedName ? 2 : 1
                            border.color: modelData.name === root.selectedName ? Theme.green : Theme.divider
                            Column {
                                anchors.centerIn: parent
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: offBox.modelData.name
                                    color: Theme.text
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(12)
                                    font.bold: true
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Off"
                                    color: Theme.secondaryText
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedName = offBox.modelData.name
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.monitors.length === 0
                    text: "Reading monitors…"
                    color: Theme.tertiaryText
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(12)
                }
            }
        }

        // ---- Aplicar / revertir posiciones ----
        Row {
            visible: root.hasUnsavedPositions || root.countdown > 0
            spacing: 8
            PillButton {
                visible: root.hasUnsavedPositions
                label: "Apply positions"
                accent: true
                onClicked: {
                    const prev = {};
                    for (const m of root.enabledMonitors)
                        prev[m.name] = { x: m.x, y: m.y };
                    root.previousPositions = prev;
                    root.hasUnsavedPositions = false;
                    root.applyPositions(root.pendingPositions);
                    root.countdown = 10;
                }
            }
            PillButton {
                visible: root.hasUnsavedPositions
                label: "Revert"
                onClicked: {
                    root.pendingPositions = ({});
                    root.hasUnsavedPositions = false;
                }
            }
            PillButton {
                visible: root.countdown > 0
                label: "Keep changes"
                accent: true
                onClicked: {
                    root.countdown = 0;
                    root.pendingPositions = ({});
                }
            }
            PillButton {
                visible: root.countdown > 0
                label: "Revert (" + root.countdown + "s)"
                onClicked: {
                    root.countdown = 0;
                    root.applyPositions(root.previousPositions);
                    root.pendingPositions = ({});
                }
            }
        }

        // ---- Monitor seleccionado ----
        SectionLabel {
            visible: root.selected !== null
            text: root.selected ? (root.selected.name + (root.selected.description ? "  ·  " + root.selected.description : "")).toUpperCase() : ""
        }

        SettingGroup {
            visible: root.selected !== null
            width: parent.width

            SettingToggleRow {
                label: "Enabled"
                sublabel: root.selected && !root.selected.disabled && root.enabledMonitors.length === 1 ? "It's the only screen on: it can't be turned off" : "Turn this monitor on or off"
                checked: root.selected ? !root.selected.disabled : false
                onToggled: root.setEnabled(root.selected, root.selected.disabled)
            }
            SelectRow {
                visible: root.selected !== null && !root.selected.disabled
                label: "Resolution"
                options: root.resolutions(root.selected)
                current: root.currentRes(root.selected)
                onPicked: value => root.apply(root.monitorLua(root.selected, { res: value, hz: root.rates(root.selected, value)[0] }))
            }
            SelectRow {
                visible: root.selected !== null && !root.selected.disabled
                label: "Refresh rate"
                options: root.rates(root.selected, root.currentRes(root.selected))
                current: root.selected ? root.currentRate(root.selected) : ""
                suffix: " Hz"
                onPicked: value => root.apply(root.monitorLua(root.selected, { hz: value }))
            }
            SelectRow {
                visible: root.selected !== null && !root.selected.disabled
                label: "Orientation"
                options: root.orientationLabels
                current: root.selected ? (root.orientationLabels[root.selected.transform] ?? root.orientationLabels[0]) : ""
                onPicked: value => root.apply(root.monitorLua(root.selected, { transform: root.orientationLabels.indexOf(value) }))
            }
            SettingToggleRow {
                visible: root.selected !== null && !root.selected.disabled && root.enabledMonitors.length > 1
                label: "Primary monitor"
                sublabel: "Move workspace 1 to this monitor"
                checked: root.selected ? root.selected.id === root.primaryWorkspaceMonitorId : false
                onToggled: if (!checked) root.makePrimary(root.selected)
            }
        }

        Text {
            width: parent.width
            text: "Saved per set of monitors and reapplied when you reconnect them. After moving monitors, keep the change within 10 s or it reverts."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }

    component SectionLabel: Text {
        width: parent.width
        color: Theme.secondaryText
        font.family: Theme.bodyFontFamily
        font.pixelSize: Theme.fontPx(12)
        leftPadding: 2
        elide: Text.ElideRight
    }

    // Fila con desplegable: el valor actual a la derecha; al pulsar, la lista debajo
    component SelectRow: Item {
        id: row
        property string label: ""
        property var options: []
        property string current: ""
        property string suffix: ""
        property bool open: false
        signal picked(string value)
        width: parent.width
        height: 48 + (open ? list.height + 8 : 0)
        clip: true
        Text {
            anchors.left: parent.left; anchors.leftMargin: 12
            y: 24 - height / 2
            text: row.label; color: Theme.text
            font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(13)
        }
        Rectangle {
            id: field
            anchors.right: parent.right; anchors.rightMargin: 8
            y: 6
            width: 200; height: 36; radius: 8
            color: Theme.panelCardHi
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.right: arrow.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: row.current + row.suffix
                color: Theme.text
                font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(13)
                elide: Text.ElideRight
            }
            Text {
                id: arrow
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.open ? "expand_less" : "expand_more"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: Theme.secondaryText
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.open = !row.open
            }
        }
        ListView {
            id: list
            anchors.top: field.bottom; anchors.topMargin: 4
            anchors.left: field.left; anchors.right: field.right
            height: Math.min(150, contentHeight)
            visible: row.open
            clip: true
            model: row.options
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: opt
                required property string modelData
                width: ListView.view.width
                height: 32
                radius: 6
                color: optMouse.containsMouse || modelData === row.current ? Theme.panelCardHi : "transparent"
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: opt.modelData + row.suffix
                    color: opt.modelData === row.current ? Theme.green : Theme.text
                    font.family: Theme.bodyFontFamily; font.pixelSize: Theme.fontPx(13)
                }
                MouseArea {
                    id: optMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        row.open = false;
                        if (opt.modelData !== row.current)
                            row.picked(opt.modelData);
                    }
                }
            }
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 10; anchors.rightMargin: 10
            height: 1; color: Theme.divider
        }
    }

    component PillButton: Rectangle {
        id: btn
        property string label: ""
        property bool accent: false
        signal clicked
        width: btnText.implicitWidth + 24
        height: 36
        radius: 18
        color: accent ? Theme.green : Theme.panelCardHi
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.accent ? Theme.crust : Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(13)
            font.bold: btn.accent
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
