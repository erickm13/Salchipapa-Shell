pragma ComponentBehavior: Bound
// Ajustes > Login & Boot: tema de la pantalla de login (SDDM) y del arranque (GRUB).
// Lista y aplica con scripts/boot-themes.sh (sudo sin contraseña para los dos helpers de
// /usr/local/bin, o pkexec con la contraseña en la isla).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"

Item {
    id: root
    implicitHeight: content.implicitHeight

    readonly property string script: Quickshell.shellDir + "/../scripts/boot-themes.sh"
    property string kind: "sddm" // "sddm" | "grub"
    property var info: ({ sddm: { current: "", themes: [] }, grub: { current: "", themes: [] } })
    property string filter: ""
    property string selected: ""
    property string status: "" // "", "applying", "ok", "error"
    property string statusText: ""
    property bool loading: false

    readonly property var section: info[kind] ?? { current: "", themes: [] }
    readonly property var themes: section.themes.filter(t => filter.trim() === "" || t.name.toLowerCase().includes(filter.trim().toLowerCase()))

    function refresh(): void {
        loading = true;
        listProc.exec([script, "list"]);
    }

    function apply(): void {
        if (selected === "" || status === "applying")
            return;
        status = "applying";
        statusText = kind === "grub" ? "Aplicando " + selected + " (regenerando la config de GRUB)…" : "Aplicando " + selected + "…";
        applyProc.exec([script, "apply", kind, selected]);
    }

    onVisibleChanged: if (visible && section.themes.length === 0) refresh()
    onKindChanged: {
        selected = "";
        status = "";
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    root.info = JSON.parse(listOut.text);
                } catch (e) {}
                root.loading = false;
            }
        }
    }
    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErr }
        onExited: code => {
            if (code === 0) {
                root.status = "ok";
                root.statusText = (root.kind === "grub" ? "Tema de GRUB aplicado: " : "Tema de SDDM aplicado: ") + root.selected + (root.kind === "grub" ? ". Se verá al reiniciar." : ". Se verá al cerrar sesión.");
                root.selected = "";
            } else {
                root.status = "error";
                root.statusText = "No se pudo aplicar: " + (applyErr.text.trim().split("\n").pop() || "código " + code);
            }
            root.refresh();
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(3)

        // ---- SDDM / GRUB + buscador ----
        Item {
            width: parent.width
            height: 32

            Rectangle {
                id: segment
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: segRow.implicitWidth + 6
                height: 30
                radius: 15
                color: Theme.panelCard
                Row {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [{ key: "sddm", label: "Login (SDDM)", icon: "login" }, { key: "grub", label: "Arranque (GRUB)", icon: "power_settings_new" }]
                        delegate: Rectangle {
                            id: seg
                            required property var modelData
                            readonly property bool on: root.kind === modelData.key
                            width: segContent.implicitWidth + 18
                            height: 24
                            radius: 12
                            color: on ? Theme.green : "transparent"
                            Row {
                                id: segContent
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: seg.modelData.icon
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 14
                                    color: seg.on ? Theme.crust : Theme.secondaryText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: seg.modelData.label
                                    font.family: Theme.bodyFontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                    font.bold: seg.on
                                    color: seg.on ? Theme.crust : Theme.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.kind = seg.modelData.key
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: segment.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                radius: 15
                color: Theme.panelCard
                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                    clip: true
                    onTextChanged: root.filter = text
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Buscar tema (" + root.section.themes.length + ")"
                        color: Theme.tertiaryText
                        font: parent.font
                        visible: parent.text.length === 0
                    }
                }
            }
        }

        // ---- Aplicar el seleccionado / estado ----
        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.radiusMedium
            color: Theme.panelCard
            visible: root.selected !== "" || root.status !== ""

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: applyBtn.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.status !== "" && root.selected === "" || root.status === "applying" ? root.statusText : "Seleccionado: " + root.selected
                color: root.status === "error" ? Theme.red : root.status === "ok" ? Theme.green : Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(11)
                elide: Text.ElideRight
            }
            Rectangle {
                id: applyBtn
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: root.selected !== "" && root.status !== "applying"
                width: applyText.implicitWidth + 24
                height: 28
                radius: 14
                color: Theme.green
                Text {
                    id: applyText
                    anchors.centerIn: parent
                    text: "Aplicar"
                    color: Theme.crust
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: Theme.fontPx(11)
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.apply()
                }
            }
        }

        // ---- Cuadrícula de temas ----
        Grid {
            id: grid
            width: parent.width
            columns: 3
            spacing: 10
            readonly property real cellW: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: root.themes
                delegate: Item {
                    id: card
                    required property var modelData
                    readonly property bool isCurrent: modelData.name === root.section.current
                    readonly property bool isSelected: modelData.name === root.selected
                    width: grid.cellW
                    height: thumb.height + 26

                    Rectangle {
                        id: thumb
                        width: parent.width
                        height: Math.round(width * 9 / 16)
                        radius: 12
                        color: card.isSelected || card.isCurrent ? Theme.green : "transparent"
                        border.width: card.isSelected || card.isCurrent ? 0 : 1
                        border.color: Theme.divider

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: card.isSelected ? 3 : card.isCurrent ? 2 : 0
                            radius: 10
                            color: Theme.panelCardHi
                            Image {
                                anchors.fill: parent
                                visible: card.modelData.preview !== ""
                                source: card.modelData.preview !== "" ? "file://" + card.modelData.preview : ""
                                sourceSize: Qt.size(400, 225)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: card.modelData.preview === ""
                                text: "image_not_supported"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 28
                                color: Theme.tertiaryText
                            }
                        }

                        // Activo / vídeo
                        Rectangle {
                            visible: card.isCurrent || card.modelData.video !== ""
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: badge.implicitWidth + 12
                            height: 18
                            radius: 9
                            color: "#b3000000"
                            Text {
                                id: badge
                                anchors.centerIn: parent
                                text: card.isCurrent ? "● Activo" : "Vídeo"
                                color: card.isCurrent ? Theme.green : "#ffffff"
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: Theme.fontPx(9)
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.status !== "applying") {
                                    root.selected = card.isCurrent ? "" : card.modelData.name;
                                    root.status = "";
                                }
                            }
                        }
                    }

                    Text {
                        anchors.top: thumb.bottom
                        anchors.topMargin: 5
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: card.modelData.name
                        color: card.isCurrent || card.isSelected ? Theme.text : Theme.secondaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.bold: card.isCurrent || card.isSelected
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.themes.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 20
            text: root.loading ? "Leyendo temas…" : root.section.themes.length === 0 ? (root.kind === "grub" ? "No hay temas en /boot/grub/themes (¿el equipo arranca con GRUB?)" : "No hay temas en /usr/share/sddm/themes") : "Ningún tema coincide"
            color: Theme.tertiaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }

        Text {
            width: parent.width
            text: "Elige un tema y pulsa Aplicar. SDDM se ve al cerrar sesión; GRUB al reiniciar (aplicarlo regenera /boot/grub/grub.cfg y tarda unos segundos)."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(10)
        }
    }
}
