import QtQuick
import Quickshell
import "../common"
import "../services"

Item {
    id: root
    property string confirmAction: ""
    focus: Overlay.mode === "power"

    Keys.onEscapePressed: {
        if (root.confirmAction !== "") {
            root.confirmAction = "";
            LockScreen.powerAction = "";
        } else {
            Overlay.close();
        }
    }

    Connections {
        target: Overlay
        function onModeChanged(): void {
            if (Overlay.mode !== "power") {
                root.confirmAction = "";
                LockScreen.powerAction = "";
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: Theme.radiusLarge
        color: Theme.panelBg
        visible: root.confirmAction === ""

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 6

            Repeater {
                model: [
                    { id: "lock", label: "Lock", glyph: "lock" },
                    { id: "suspend", label: "Suspend", glyph: "bedtime" },
                    { id: "logout", label: "Log Out", glyph: "logout" },
                    { id: "reboot", label: "Reboot", glyph: "restart_alt" },
                    { id: "poweroff", label: "Power Off", glyph: "power_settings_new" }
                ]

                delegate: Rectangle {
                    id: actionButton
                    required property var modelData
                    width: (parent.width - parent.spacing * 4) / 5
                    height: parent.height
                    radius: 18
                    color: actionMouse.containsMouse ? Theme.green : Theme.panelCard
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.glyph
                            color: actionMouse.containsMouse ? Theme.panelBg : Theme.text
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Theme.iconPx(18)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.label
                            color: actionMouse.containsMouse ? Theme.panelBg : Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(9)
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const action = actionButton.modelData.id;
                            if (action === "lock") {
                                Overlay.close();
                                LockScreen.lock();
                            } else if (action === "suspend") {
                                Overlay.close();
                                LockScreen.suspend();
                            } else if (action === "logout") {
                                Overlay.close();
                                // Detiene la sesión administrada por UWSM para que SDDM
                                // vuelva a mostrar el greeter al cerrar sesión.
                                Quickshell.execDetached(["/usr/bin/uwsm", "stop"]);
                            } else {
                                root.confirmAction = action;
                                LockScreen.powerAction = action;
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: Theme.radiusLarge
        color: "#d9000000"
        visible: root.confirmAction !== ""

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(290, parent.width - 24)
            height: 150
            radius: 20
            color: Theme.panelCard

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text {
                    width: parent.width
                    text: root.confirmAction === "reboot" ? "Restart the computer?" : "Power off the computer?"
                    color: Theme.text
                    font.family: Theme.displayFontFamily
                    font.pixelSize: Theme.fontPx(15)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 100
                        height: 36
                        radius: 18
                        color: Theme.surface0
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.confirmAction = "";
                                LockScreen.powerAction = "";
                            }
                        }
                    }
                    Rectangle {
                        width: 100
                        height: 36
                        radius: 18
                        color: Theme.red
                        Text {
                            anchors.centerIn: parent
                            text: root.confirmAction === "reboot" ? "Reboot" : "Power Off"
                            color: Theme.panelBg
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LockScreen.confirmPowerAction();
                                Overlay.close();
                                root.confirmAction = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
