pragma ComponentBehavior: Bound
// Panel de ajustes de la shell. Ventana propia (modal, centrada): sidebar de categorías +
// buscador + contenido. Fase 1: "Bar & Island" funcional (escribe en Config, persistente);
// el resto de categorías son marcadores por ahora.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../common"

PanelWindow {
    id: win

    visible: Overlay.settings
    color: "transparent"
    exclusiveZone: 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Overlay.settings ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var categories: [
        {
            name: "Bar & Island",
            icon: "crop_16_9",
            desc: "Forma y tamaño de la isla, el notch y la barra de Game Mode."
        },
        {
            name: "Media",
            icon: "music_note",
            desc: "Reproductor y controles multimedia."
        },
        {
            name: "Clock & Date",
            icon: "schedule",
            desc: "Reloj, formato de hora y calendario."
        },
        {
            name: "Appearance",
            icon: "palette",
            desc: "Colores, tema y wallpaper."
        },
        {
            name: "Motion",
            icon: "animation",
            desc: "Animaciones y transiciones."
        },
        {
            name: "Launcher",
            icon: "search",
            desc: "Lanzador de aplicaciones."
        },
        {
            name: "Notifications",
            icon: "notifications",
            desc: "Notificaciones y modo No molestar."
        },
        {
            name: "Control Center",
            icon: "tune",
            desc: "Interruptores rápidos y páginas del centro de control."
        },
        {
            name: "Lock Screen",
            icon: "lock",
            desc: "Pantalla de bloqueo."
        },
        {
            name: "System",
            icon: "settings",
            desc: "Ajustes del sistema."
        }
    ]

    property int category: 0
    property string query: ""

    readonly property var filtered: {
        const q = query.trim().toLowerCase();
        return q === "" ? categories : categories.filter(c => c.name.toLowerCase().includes(q));
    }

    // Captura de clics fuera del panel (cierra). Sin oscurecer el fondo.
    MouseArea {
        anchors.fill: parent
        onClicked: Overlay.settings = false
    }

    // ===== Card =====
    Rectangle {
        id: cardBg
        anchors.centerIn: parent
        width: 600
        height: 440
        radius: 20
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.islandBorder

        focus: Overlay.settings
        Keys.onEscapePressed: Overlay.settings = false

        MouseArea {
            anchors.fill: parent // traga clics (no cierra)
        }

        // ---------- Sidebar ----------
        Rectangle {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 198
            radius: 20
            color: Theme.panelBg
            // Cuadra el borde derecho (tapa las esquinas redondeadas de ese lado)
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 20
                color: Theme.panelBg
            }

            Rectangle {
                id: search
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 34
                radius: 10
                color: Theme.panelCard

                Text {
                    id: sIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: Theme.overlay1
                }
                TextInput {
                    id: searchInput
                    anchors.left: sIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ffffff"
                    font.pixelSize: 13
                    clip: true
                    focus: Overlay.settings
                    onTextChanged: win.query = text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search Settings"
                        color: Theme.overlay0
                        font: parent.font
                        visible: parent.text.length === 0
                    }
                    Keys.onEscapePressed: Overlay.settings = false
                }
            }

            ListView {
                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 8
                clip: true
                spacing: 2
                model: win.filtered
                boundsBehavior: Flickable.StopAtBounds

                delegate: NavItem {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    iconName: modelData.icon
                    label: modelData.name
                    active: win.categories[win.category] && win.categories[win.category].name === modelData.name
                    onClicked: win.category = win.categories.findIndex(c => c.name === modelData.name)
                }
            }
        }

        // ---------- Contenido ----------
        Item {
            id: content
            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 18

            readonly property var cat: win.categories[win.category]

            Row {
                id: navArrows
                anchors.top: parent.top
                anchors.left: parent.left
                spacing: 6
                NavArrow {
                    glyph: "arrow_back"
                }
                NavArrow {
                    glyph: "arrow_forward"
                }
            }

            // Header
            Rectangle {
                id: headerCard
                anchors.top: navArrows.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 10
                height: 118
                radius: 16
                color: Theme.panelCard

                Rectangle {
                    id: hIcon
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 14
                    width: 50
                    height: 50
                    radius: 14
                    color: Theme.panelCardHi
                    Text {
                        anchors.centerIn: parent
                        text: content.cat ? content.cat.icon : ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 26
                        color: Theme.green
                    }
                }
                Text {
                    id: hTitle
                    anchors.top: hIcon.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 6
                    text: content.cat ? content.cat.name : ""
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    anchors.top: hTitle.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 2
                    width: parent.width - 48
                    horizontalAlignment: Text.AlignHCenter
                    text: content.cat ? content.cat.desc : ""
                    color: Theme.subtext
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }

            // Controles (scroll)
            Flickable {
                anchors.top: headerCard.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 14
                contentHeight: controlsCol.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: controlsCol
                    width: parent.width
                    spacing: 12

                    // ---- Bar & Island ----
                    ToggleRow {
                        visible: win.category === 0
                        width: parent.width
                        label: "Notch mode"
                        checked: Config.notchMode
                        onToggled: Config.opt.notchMode = !Config.opt.notchMode
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Bar height"
                        from: 20
                        to: 60
                        value: Config.barHeight
                        onMoved: v => Config.opt.barHeight = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Collapsed width"
                        from: 60
                        to: 420
                        value: Config.collapsedWidth
                        onMoved: v => Config.opt.collapsedWidth = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Expanded height"
                        from: 120
                        to: 260
                        value: Config.expandedHeight
                        onMoved: v => Config.opt.expandedHeight = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Gap from screen edge"
                        from: 0
                        to: 40
                        value: Config.topMargin
                        onMoved: v => Config.opt.gapFromEdge = v
                    }
                    PxSlider {
                        visible: win.category === 0
                        width: parent.width
                        label: "Inner padding"
                        from: 4
                        to: 30
                        value: Config.innerPadding
                        onMoved: v => Config.opt.innerPadding = v
                    }

                    // ---- Otras categorías (placeholder) ----
                    Item {
                        visible: win.category !== 0
                        width: parent.width
                        height: 90
                        Text {
                            anchors.centerIn: parent
                            text: "Próximamente"
                            color: Theme.overlay0
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    // ===================== Sub-componentes =====================

    component NavItem: Rectangle {
        id: nav
        property string iconName: ""
        property string label: ""
        property bool active: false
        signal clicked

        height: 40
        radius: 12
        color: active ? Theme.panelCardHi : (navMouse.containsMouse ? Theme.panelCard : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Rectangle {
            id: ic
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 13
            color: nav.active ? Theme.green : Theme.panelCardHi
            Text {
                anchors.centerIn: parent
                text: nav.iconName
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
                color: nav.active ? Theme.islandBg : Theme.subtext
            }
        }
        Text {
            anchors.left: ic.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.active ? "#ffffff" : Theme.text
            font.pixelSize: 13
            font.bold: nav.active
        }
        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    component NavArrow: Rectangle {
        id: arrow
        property string glyph: ""
        signal clicked
        width: 28
        height: 28
        radius: 8
        color: aMouse.containsMouse ? Theme.panelCardHi : Theme.panelCard
        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            color: Theme.subtext
        }
        MouseArea {
            id: aMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }

    component ToggleRow: Rectangle {
        id: tr
        property string label: ""
        property bool checked: false
        signal toggled

        height: 48
        radius: 12
        color: Theme.panelCard

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: tr.label
            color: "#ffffff"
            font.pixelSize: 13
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: 12
            color: tr.checked ? Theme.green : Theme.panelCardHi
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
                x: tr.checked ? parent.width - width - 3 : 3
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
                onClicked: tr.toggled()
            }
        }
    }

    component PxSlider: Rectangle {
        id: ps
        property string label: ""
        property int from: 0
        property int to: 100
        property int value: 0
        property string unit: "px"
        signal moved(int v)

        height: 58
        radius: 12
        color: Theme.panelCard

        Text {
            id: pl
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 14
            text: ps.label
            color: "#ffffff"
            font.pixelSize: 13
        }
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 14
            text: ps.value + " " + ps.unit
            color: Theme.subtext
            font.pixelSize: 12
        }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.top: pl.bottom
            anchors.topMargin: 12
            height: 4
            radius: 2
            color: Theme.panelCardHi

            Rectangle {
                id: fillr
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: 2
                width: parent.width * (ps.value - ps.from) / Math.max(1, ps.to - ps.from)
                color: Theme.green
            }
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, fillr.width - width / 2))
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -18
                anchors.bottomMargin: -18
                cursorShape: Qt.PointingHandCursor
                function setX(mx) {
                    const r = Math.max(0, Math.min(1, mx / track.width));
                    ps.moved(Math.round(ps.from + r * (ps.to - ps.from)));
                }
                onPressed: mouse => setX(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        setX(mouse.x);
                }
            }
        }
    }
}
