pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../common"
import "../services"

Item {
    id: root
    property bool active: Overlay.mode === "power"
    property string confirmAction: ""
    property int selectedIndex: 0
    property int confirmationIndex: 0
    readonly property var actions: [
        { id: "lock", label: "Lock", glyph: "lock" },
        { id: "suspend", label: "Suspend", glyph: "bedtime" },
        { id: "logout", label: "Log Out", glyph: "logout" },
        { id: "reboot", label: "Reboot", glyph: "restart_alt" },
        { id: "poweroff", label: "Power Off", glyph: "power_settings_new" }
    ]
    enabled: active
    focus: active

    onActiveChanged: {
        if (active) {
            selectedIndex = 0;
            confirmationIndex = 0;
            // Esperar a que la isla sea visible y la capa solicite el teclado.
            Qt.callLater(() => {
                if (root.active)
                    root.forceActiveFocus();
            });
        }
    }

    function moveSelection(delta: int): void {
        if (confirmAction !== "")
            confirmationIndex = (confirmationIndex + delta + 2) % 2;
        else
            selectedIndex = (selectedIndex + delta + actions.length) % actions.length;
    }

    function cancelConfirmation(): void {
        confirmAction = "";
        LockScreen.powerAction = "";
    }

    function confirm(): void {
        LockScreen.confirmPowerAction();
        Overlay.close();
        confirmAction = "";
    }

    function activateAction(action: string): void {
        if (action === "lock") {
            Overlay.close();
            LockScreen.lock();
        } else if (action === "suspend") {
            Overlay.close();
            LockScreen.suspend();
        } else if (action === "logout") {
            Overlay.close();
            // Detiene la sesión UWSM y devuelve el control al greeter de SDDM.
            Quickshell.execDetached(["/usr/bin/uwsm", "stop"]);
        } else {
            confirmAction = action;
            LockScreen.powerAction = action;
            confirmationIndex = 0;
        }
    }

    function activateSelection(): void {
        if (confirmAction === "")
            activateAction(actions[selectedIndex].id);
        else if (confirmationIndex === 0)
            cancelConfirmation();
        else
            confirm();
    }

    Keys.onLeftPressed: root.moveSelection(-1)
    Keys.onRightPressed: root.moveSelection(1)
    Keys.onUpPressed: root.moveSelection(-1)
    Keys.onDownPressed: root.moveSelection(1)
    Keys.onTabPressed: root.moveSelection(1)
    Keys.onBacktabPressed: root.moveSelection(-1)
    Keys.onReturnPressed: event => {
        if (!event.isAutoRepeat)
            root.activateSelection();
    }
    Keys.onEnterPressed: event => {
        if (!event.isAutoRepeat)
            root.activateSelection();
    }
    Keys.onSpacePressed: event => {
        if (!event.isAutoRepeat)
            root.activateSelection();
    }

    Keys.onEscapePressed: {
        if (root.confirmAction !== "") {
            root.cancelConfirmation();
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
            id: actionsRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 6

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: actionButton
                    required property int index
                    required property var modelData
                    readonly property bool selected: root.selectedIndex === index
                    width: (actionsRow.width - actionsRow.spacing * (root.actions.length - 1)) / root.actions.length
                    height: actionsRow.height
                    radius: 22
                    color: selected ? Theme.green : Theme.panelCard
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverDuration }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.glyph
                            color: actionButton.selected ? Theme.panelBg : Theme.text
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Theme.iconPx(32)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: actionButton.modelData.label
                            color: actionButton.selected ? Theme.panelBg : Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(14)
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = actionButton.index
                        onClicked: root.activateAction(actionButton.modelData.id)
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
                        border.width: root.confirmationIndex === 0 ? 2 : 0
                        border.color: Theme.green
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(12)
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.confirmationIndex = 0
                            onClicked: root.cancelConfirmation()
                        }
                    }
                    Rectangle {
                        width: 100
                        height: 36
                        radius: 18
                        color: Theme.red
                        border.width: root.confirmationIndex === 1 ? 2 : 0
                        border.color: Theme.text
                        Text {
                            anchors.centerIn: parent
                            text: root.confirmAction === "reboot" ? "Reboot" : "Power Off"
                            color: Theme.panelBg
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: Theme.fontPx(12)
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.confirmationIndex = 1
                            onClicked: root.confirm()
                        }
                    }
                }
            }
        }
    }
}
