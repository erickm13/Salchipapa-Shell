//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// Salchipapa-Shell — Dynamic Island (Quickshell 0.3.2)
// Píldora flotante centrada arriba: compacta por defecto, se expande al pasar el ratón.
// Probar:  qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml   (recarga sola al guardar)

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            color: "transparent"
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 130 // alto suficiente para la isla expandida
            WlrLayershell.layer: WlrLayer.Top
            exclusiveZone: 38 // solo reserva el alto de la píldora compacta

            // Solo la isla captura el ratón; el resto deja pasar los clics a las ventanas
            mask: Region {
                x: island.x
                y: island.y
                width: island.width
                height: island.height
            }

            Item {
                id: island

                anchors.horizontalCenter: parent.horizontalCenter
                y: 6

                // Curva "expressive" de Material 3 (overshoot => rebote tipo iPhone)
                readonly property var springCurve: [0.38, 1.21, 0.22, 1, 1, 1]

                // Tamaños: compacto por defecto, expandido en el estado "expanded"
                width: 240
                height: 28
                state: ""

                states: State {
                    name: "expanded"
                    PropertyChanges {
                        target: island
                        width: 470
                        height: 96
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: island.springCurve
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: island.springCurve
                    }
                }

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }

                Rectangle {
                    id: pill

                    anchors.fill: parent
                    radius: height / 2 // píldora completa; se morfea al expandir
                    color: "#0b0b0f"
                    border.color: "#1affffff"
                    border.width: 1

                    // ---------- Contenido COMPACTO ----------
                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        opacity: island.state === "expanded" ? 0 : 1
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: "#89b4fa"

                            Text {
                                anchors.centerIn: parent
                                text: Hyprland.focusedWorkspace?.id ?? "?"
                                color: "#0b0b0f"
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    // ---------- Contenido EXPANDIDO ----------
                    Item {
                        anchors.fill: parent
                        anchors.margins: 14
                        opacity: island.state === "expanded" ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }

                        // Workspaces (arriba-izquierda)
                        Row {
                            id: wsRow

                            anchors.top: parent.top
                            anchors.left: parent.left
                            spacing: 5

                            Repeater {
                                model: Hyprland.workspaces

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: modelData.focused ? "#89b4fa" : "#26263a"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: modelData.focused ? "#0b0b0f" : "#cdd6f4"
                                        font.pixelSize: 12
                                        font.bold: modelData.focused
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                    }
                                }
                            }
                        }

                        // Reloj (arriba-derecha)
                        Text {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 4
                            text: Qt.formatDateTime(clock.date, "ddd d · HH:mm")
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        // Ventana activa (abajo)
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            text: Hyprland.activeToplevel?.title ?? "Escritorio"
                            color: "#bac2de"
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    // Hover: expande/contrae (NoButton => deja pasar los clics a los workspaces)
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: island.state = "expanded"
                        onExited: island.state = ""
                    }
                }
            }
        }
    }
}
