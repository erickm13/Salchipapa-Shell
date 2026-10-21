pragma ComponentBehavior: Bound
// Contenido del lanzador, para mostrarse DENTRO de la Dynamic Island (modo "launcher").
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../common"

Item {
    id: root

    property int sel: 0
    property string query: ""
    // Última posición del ratón sobre el launcher (ver el MouseArea de cada fila)
    property point mousePos: Qt.point(-1, -1)

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
        return list.sort((x, y) => rank(x) - rank(y) || (x.name ?? "").localeCompare(y.name ?? ""));
    }

    function launch(): void {
        const app = results[sel];
        if (app) {
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
        height: 52

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
            font.pixelSize: Theme.fontPx(15)
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
                    font.pixelSize: Theme.fontPx(13 * item.rowScale)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    font.family: Theme.bodyFontFamily
                    width: parent.width
                    text: item.modelData.comment || item.modelData.genericName || ""
                    color: Theme.secondaryText
                    font.pixelSize: Theme.fontPx(10 * item.rowScale)
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
