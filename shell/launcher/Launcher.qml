pragma ComponentBehavior: Bound
// Lanzador de aplicaciones (Super+R). Buscador + lista de apps filtrable.
// Se abre/cierra con un GlobalShortcut de Hyprland: bind = $mod, R, global, salchipapa:launcher
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../common"

Scope {
    id: root

    property bool active: false
    property int sel: 0
    property string query: ""

    // Progreso de apertura (0 cerrado, 1 abierto): la ventana "emerge" de la isla
    // (misma curva y duración que la expansión de la isla al hover)
    property real t: active ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: 480
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.spring
        }
    }

    readonly property var results: {
        const all = DesktopEntries.applications.values;
        const q = query.trim().toLowerCase();
        const list = q === "" ? all.slice() : all.filter(a => {
            return (a.name ?? "").toLowerCase().includes(q) || (a.genericName ?? "").toLowerCase().includes(q) || (a.comment ?? "").toLowerCase().includes(q);
        });
        return list.sort((x, y) => (x.name ?? "").localeCompare(y.name ?? ""));
    }

    function open(): void {
        query = "";
        sel = 0;
        active = true;
    }
    function close(): void {
        active = false;
    }
    function toggle(): void {
        if (active)
            close();
        else
            open();
    }
    function launch(): void {
        const app = results[sel];
        if (app) {
            app.execute();
            close();
        }
    }

    GlobalShortcut {
        appid: "salchipapa"
        name: "launcher"
        description: "Abrir/cerrar el lanzador de apps"
        onPressed: root.toggle()
    }

    PanelWindow {
        id: win

        visible: root.active || root.t > 0.01
        color: "transparent" // sin atenuado: solo se ve el panel (como caelestia)
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        onVisibleChanged: if (visible)
            searchInput.forceActiveFocus()

        // Clic fuera del panel = cerrar
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // ===== Panel =====
        Rectangle {
            id: panel

            readonly property real fullW: 560
            readonly property real fullH: 440
            // El contenido aparece cuando el panel ya ha crecido
            readonly property real contentOpacity: Math.max(0, (root.t - 0.5) / 0.5)

            anchors.horizontalCenter: parent.horizontalCenter
            y: Config.topMargin // mismo origen que la isla: emerge de ella, no de arriba
            // Semilla = píldora de la isla (mismo alto/radio); crece a panel completo
            width: 320 + (fullW - 320) * root.t
            height: 30 + (fullH - 30) * root.t
            radius: 15 + (24 - 15) * root.t
            opacity: Math.min(1, root.t * 3)
            clip: true
            color: Theme.islandBg
            border.color: Theme.islandBorder
            border.width: 1

            MouseArea {
                anchors.fill: parent
            } // traga clics dentro del panel

            // --- Buscador ---
            Item {
                id: search
                opacity: panel.contentOpacity
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 22
                    color: Theme.overlay1
                }
                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: 17
                    clip: true
                    onTextChanged: {
                        root.query = text;
                        root.sel = 0;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        text: "Buscar…"
                        color: Theme.overlay0
                        font: parent.font
                        visible: parent.text.length === 0
                    }

                    Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.results.length - 1)
                    Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
                    Keys.onReturnPressed: root.launch()
                    Keys.onEnterPressed: root.launch()
                    Keys.onEscapePressed: root.close()
                }
            }

            Rectangle {
                id: divider
                opacity: panel.contentOpacity
                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Theme.surface0
            }

            // --- Lista de apps ---
            ListView {
                id: list
                opacity: panel.contentOpacity
                anchors.top: divider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                clip: true
                spacing: 2
                model: root.results
                currentIndex: root.sel
                highlightMoveDuration: 120
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: item
                    required property int index
                    required property var modelData

                    width: ListView.view.width
                    height: 52
                    radius: 12
                    color: index === root.sel ? Theme.surface0 : "transparent"

                    // Barra de acento a la izquierda del seleccionado
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 26
                        radius: 2
                        color: Theme.green
                        visible: index === root.sel
                    }

                    IconImage {
                        id: appIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 34
                        asynchronous: true
                        source: Quickshell.iconPath(item.modelData.icon, "image-missing")
                    }

                    Column {
                        anchors.left: appIcon.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            width: parent.width
                            text: item.modelData.name ?? ""
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: item.modelData.comment || item.modelData.genericName || ""
                            color: Theme.subtext
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = item.index
                        onClicked: {
                            root.sel = item.index;
                            root.launch();
                        }
                    }
                }
            }
        }
    }
}
