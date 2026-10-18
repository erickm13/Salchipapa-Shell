pragma ComponentBehavior: Bound

import QtQuick
import "../common"
import "../services"

Item {
    id: root

    property bool active: false
    readonly property var flow: PolicyAuth.flow

    visible: active
    focus: active

    onActiveChanged: {
        if (active)
            Qt.callLater(() => passwordInput.forceActiveFocus());
    }

    Timer {
        // La capa Wayland necesita un instante para entregar el foco exclusivo al abrirse.
        interval: 120
        repeat: false
        running: root.active
        onTriggered: passwordInput.forceActiveFocus()
    }

    Keys.onEscapePressed: PolicyAuth.cancel()

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Row {
            width: parent.width
            height: 28
            spacing: 9

            Rectangle {
                width: 25
                height: 25
                radius: 13
                color: Theme.green
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "lock"
                    color: Theme.panelBg
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Authentication required"
                color: Theme.text
                font.family: Theme.displayFontFamily
                font.pixelSize: 16
                font.bold: true
            }
        }

        Rectangle {
            width: parent.width
            height: 60
            radius: 14
            color: Theme.surface0

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 7
                anchors.bottomMargin: 6
                spacing: 2

                Text {
                    width: parent.width
                    height: 30
                    text: root.flow?.message ?? "An application needs administrator permission."
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: parent.width
                    text: root.flow?.actionId ?? ""
                    color: Theme.tertiaryText
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }

        Text {
            width: parent.width
            text: root.flow?.inputPrompt || "Password"
            color: Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Rectangle {
            id: inputBox
            width: parent.width
            height: 40
            radius: 20
            color: Theme.panelBg
            border.color: passwordInput.activeFocus ? Theme.green : Theme.surface1
            border.width: 1

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                color: Theme.secondaryText
                font.family: "Material Symbols Rounded"
                    font.pixelSize: 17
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 36
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                focus: root.active
                color: Theme.text
                selectionColor: Theme.green
                selectedTextColor: Theme.panelBg
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                text: PolicyAuth.responseText
                onTextChanged: {
                    if (PolicyAuth.responseText !== text)
                        PolicyAuth.responseText = text;
                }
                onAccepted: PolicyAuth.submit(text)
            }

            Text {
                anchors.left: passwordInput.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter your password"
                color: Theme.text
                font.family: Theme.bodyFontFamily
                font.pixelSize: 12
                visible: passwordInput.text.length === 0
                enabled: false
            }
        }

        Text {
            width: parent.width
            text: root.flow?.supplementaryMessage ?? ""
            color: root.flow?.supplementaryIsError ? Theme.red : Theme.secondaryText
            font.family: Theme.bodyFontFamily
            font.pixelSize: 11
            height: text.length > 0 ? 14 : 0
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            Rectangle {
                width: 86
                height: 31
                radius: 16
                color: Theme.surface0

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Theme.text
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PolicyAuth.cancel()
                }
            }

            Rectangle {
                width: 112
                height: 31
                radius: 16
                color: Theme.green

                Text {
                    anchors.centerIn: parent
                    text: "Authenticate"
                    color: Theme.panelBg
                    font.family: Theme.bodyFontFamily
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PolicyAuth.submit(passwordInput.text)
                }
            }
        }
    }
}
