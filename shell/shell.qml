//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// Barra de Salchipapa-Shell (Quickshell 0.3.2)
// Probar:  qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml
// Recarga sola al guardar este archivo.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    // Una barra por monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData
            screen: modelData

            // Barra superior, pegada a los 3 bordes de arriba
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 34
            color: "#1e1e2e" // Catppuccin Mocha base

            // --- Izquierda: workspaces ---
            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: Hyprland.workspaces

                    delegate: Rectangle {
                        required property var modelData

                        implicitWidth: 28
                        implicitHeight: 24
                        radius: 6
                        color: modelData.focused ? "#89b4fa" : "#313244"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.focused ? "#1e1e2e" : "#cdd6f4"
                            font.pixelSize: 13
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

            // --- Centro: ventana activa ---
            Text {
                anchors.centerIn: parent
                width: bar.width * 0.4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Hyprland.activeToplevel?.title ?? ""
                color: "#bac2de"
                font.pixelSize: 13
            }

            // --- Derecha: reloj ---
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
                color: "#cdd6f4"
                font.pixelSize: 13

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
            }
        }
    }
}
