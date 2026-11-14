pragma ComponentBehavior: Bound
// Contenido del lanzador, para mostrarse DENTRO de la Dynamic Island (modo "launcher").
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"

Item {
    id: root
    // Más grande que el resto de la shell (Theme.fontPx con su escala): se lee mejor
    readonly property real uiScale: 1.25

    property int sel: 0
    property string query: ""
    // Última posición del ratón sobre el launcher (ver el MouseArea de cada fila)
    property point mousePos: Qt.point(-1, -1)

    // --- Frecencia: las apps que más usas arriba; las que dejas de usar van bajando ---
    // Por app se guarda { s: puntuación, t: último uso en ms }. Cada lanzamiento suma 1 a la
    // puntuación, que pierde la mitad de su valor cada `halfLifeDays` sin usarse.
    readonly property string usagePath: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/launcher-usage.json"
    readonly property real halfLifeDays: 7
    property var usage: ({})
    // Momento de referencia: se fija al abrir el launcher para que el orden no cambie mientras está abierto
    property real now: Date.now()

    function score(id: string): real {
        const u = usage[id];
        if (!u)
            return 0;
        return u.s * Math.pow(0.5, (now - u.t) / (halfLifeDays * 86400000));
    }

    function recordLaunch(id: string): void {
        const t = Date.now();
        const u = usage[id];
        const s = (u ? u.s * Math.pow(0.5, (t - u.t) / (halfLifeDays * 86400000)) : 0) + 1;
        const next = Object.assign({}, usage);
        next[id] = { s: s, t: t };
        // Olvida las que ya casi no cuentan (y las de apps desinstaladas) para que el archivo no crezca
        for (const k in next)
            if (next[k].s * Math.pow(0.5, (t - next[k].t) / (halfLifeDays * 86400000)) < 0.01)
                delete next[k];
        usage = next;
        usageFile.setText(JSON.stringify(usage));
    }

    FileView {
        id: usageFile
        path: root.usagePath
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    readonly property var results: {
        const all = DesktopEntries.applications.values;
        const q = query.trim().toLowerCase();
        // También por el id del .desktop (p. ej. "baobab" encuentra "Disk Usage Analyzer", que es como se llama en el menú)
        const list = q === "" ? all.slice() : all.filter(a => (a.name ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q) || (a.comment ?? "").toLowerCase().includes(q) || (a.id ?? "").toLowerCase().includes(q));
        // Primero las que EMPIEZAN por la búsqueda, luego las que la tienen en el nombre y al final
        // las que solo coinciden por id/descripción ("thunar" → "Thunar File Manager" antes que "Bulk Rename")
        const rank = a => {
            const n = (a.name ?? "").toLowerCase();
            return n.startsWith(q) ? 0 : n.includes(q) ? 1 : 2;
        };
        // Dentro de cada grupo, las más usadas primero; las nunca usadas, por orden alfabético
        const sc = {};
        for (const a of list)
            sc[a.id] = root.score(a.id ?? "");
        return list.sort((x, y) => (q === "" ? 0 : rank(x) - rank(y)) || sc[y.id] - sc[x.id] || (x.name ?? "").localeCompare(y.name ?? ""));
    }

    function launch(): void {
        const app = results[sel];
        if (app) {
            if (app.id)
                root.recordLaunch(app.id);
            // Con uwsm, la app va en su propia unidad de la sesión (se cierra al salir); ver scripts/app.sh
            if (Quickshell.env("UWSM_FINALIZE_VARNAMES") && app.id)
                Quickshell.execDetached([Quickshell.shellDir + "/../scripts/app.sh", app.id + ".desktop"]);
            else
                app.execute();
            Overlay.close();
        }
    }

    // Al abrir el modo, resetea la búsqueda
    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode === "launcher") {
                root.now = Date.now();
                root.query = "";
                root.sel = 0;
                searchInput.text = "";
                searchInput.forceActiveFocus();
            }
        }
    }

    // --- Buscador ---
    Item {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 62

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "search"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: Theme.overlay1
        }
        TextInput {
            font.family: Theme.bodyFontFamily
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"
            font.pixelSize: Theme.fontPx((15) * root.uiScale)
            clip: true
            focus: Overlay.mode === "launcher"
            onTextChanged: {
                root.query = text;
                root.sel = 0;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search apps…"
                color: Theme.tertiaryText
                font: parent.font
                visible: parent.text.length === 0
            }

            Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
            Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
            // Ctrl+J / Ctrl+K como en vim (j y k a secas se escriben en el buscador)
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier && (event.key === Qt.Key_J || event.key === Qt.Key_K)) {
                    root.sel = Math.max(0, Math.min(root.results.length - 1, root.sel + (event.key === Qt.Key_J ? 1 : -1)));
                    event.accepted = true;
                }
            }
            Keys.onReturnPressed: root.launch()
            Keys.onEnterPressed: root.launch()
            Keys.onEscapePressed: Overlay.close()
        }
    }

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.surface0
    }

    // --- Lista ---
    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        clip: true
        spacing: 2
        model: root.results
        currentIndex: root.sel
        // Duración fija en vez de la velocidad por defecto (400 px/s): con la flecha mantenida
        // la selección avanza más rápido que eso y la lista seguía desplazándose sola al soltar
        highlightMoveVelocity: -1
        highlightMoveDuration: 100
        boundsBehavior: Flickable.StopAtBounds
        // Filas ya creadas por encima y por debajo de lo visible (se crean sin bloquear, al abrir):
        // crear una fila al desplazar busca y rasteriza su icono, y eso daba tirones
        cacheBuffer: 3000

        SmoothWheel {
            flickable: list
        }

        delegate: Rectangle {
            id: item
            required property int index
            required property var modelData

            // Icono y textos crecen con el alto de fila (Ajustes → Launcher); con 50 px, tamaños base
            readonly property real rowScale: Config.launcherRowHeight / 50

            width: ListView.view.width
            height: Config.launcherRowHeight
            radius: 12
            color: index === root.sel ? Theme.surface0 : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: Math.round(24 * item.rowScale)
                radius: 2
                color: Theme.green
                visible: index === root.sel
            }

            AppIcon {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                size: Math.round(30 * item.rowScale)
                icon: item.modelData.icon ?? ""
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: Math.round(12 * item.rowScale)
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: item.modelData.name ?? ""
                    color: "#ffffff"
                    font.pixelSize: Theme.fontPx((13 * item.rowScale) * root.uiScale)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: item.modelData.comment || item.modelData.genericName || ""
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx((10 * item.rowScale) * root.uiScale)
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Solo si el ratón se movió de verdad: al bajar con las flechas la lista se desplaza
                // y la fila que pasa bajo el cursor quieto también recibe hover, robando la selección
                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    if (p.x === root.mousePos.x && p.y === root.mousePos.y)
                        return;
                    root.mousePos = p;
                    root.sel = item.index;
                }
                onClicked: {
                    root.sel = item.index;
                    root.launch();
                }
            }
        }
    }
}
