// Ayuda de teclado al pie de un panel de la isla: cada tecla en una "tecla" pequeña y, al lado,
// lo que hace. `hints`: [{ k: "Enter", t: "copy" }, …] (k puede llevar varias teclas separadas por
// espacios: "Ctrl J"); un elemento sin `k` es solo texto.
import QtQuick
import "../common"

Row {
    id: root
    property var hints: []
    property real size: 11

    spacing: 12
    Repeater {
        model: root.hints
        delegate: Row {
            id: hint
            required property var modelData
            spacing: 5
            Repeater {
                model: (hint.modelData.k ?? "").split(" ").filter(k => k !== "")
                delegate: Rectangle {
                    required property string modelData
                    width: Math.max(height, cap.implicitWidth + 10)
                    height: Math.round(root.size * 1.7)
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.09)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: cap
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(root.size - 1)
                        font.bold: true
                    }
                }
            }
            Text {
                text: hint.modelData.t ?? ""
                color: Theme.overlay1
                font.family: Theme.bodyFontFamily
                font.pixelSize: Theme.fontPx(root.size)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
