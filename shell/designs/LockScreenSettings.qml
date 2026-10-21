pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../common"

Item {
    id: root
    implicitHeight: content.implicitHeight

    // ---- Editor de encuadre de la foto de perfil ----
    property bool editing: false
    property real editZoom: 1
    property real editCx: 0.5
    property real editCy: 0.5

    // Foto nueva: centrada y sin zoom; si no, parte del encuadre guardado
    function startEdit(fresh: bool): void {
        editZoom = fresh ? 1 : Config.lockAvatarZoom;
        editCx = fresh ? 0.5 : Config.lockAvatarCropX;
        editCy = fresh ? 0.5 : Config.lockAvatarCropY;
        editing = true;
        Qt.callLater(() => stage.forceActiveFocus());
    }
    function saveEdit(): void {
        Config.opt.lockAvatarZoom = editZoom;
        Config.opt.lockAvatarCropX = editCx;
        Config.opt.lockAvatarCropY = editCy;
        editing = false;
    }
    // El punto central solo puede ir donde la foto sigue cubriendo todo el círculo
    function clampCenter(): void {
        const hx = cropCircle.width / 2 / Math.max(1, cropPhoto.photoW);
        const hy = cropCircle.height / 2 / Math.max(1, cropPhoto.photoH);
        editCx = Math.max(hx, Math.min(1 - hx, editCx));
        editCy = Math.max(hy, Math.min(1 - hy, editCy));
    }
    // Arrastrar la foto (dx, dy en píxeles del editor) mueve el punto central al revés
    function pan(dx: real, dy: real): void {
        editCx -= dx / Math.max(1, cropPhoto.photoW);
        editCy -= dy / Math.max(1, cropPhoto.photoH);
        clampCenter();
    }
    function setZoom(z: real): void {
        editZoom = Math.max(1, Math.min(4, z));
        Qt.callLater(clampCenter);
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.space(4)

        SettingGroup {
            title: "Clock & content"
            width: parent.width
            SettingToggleRow { label: "Show date"; checked: Config.lockShowDate; onToggled: Config.opt.lockShowDate = !Config.lockShowDate }
            SettingToggleRow { label: "Show clock"; checked: Config.lockShowClock; onToggled: Config.opt.lockShowClock = !Config.lockShowClock }
            SettingToggleRow { label: "24-hour clock"; checked: Config.lockClock24Hour; onToggled: Config.opt.lockClock24Hour = !Config.lockClock24Hour }
            SettingToggleRow { label: "Music card"; checked: Config.lockShowMusic; onToggled: Config.opt.lockShowMusic = !Config.lockShowMusic }
        }

        // Foto de perfil (~/.face): imagen, encuadre, forma ondulada y animación
        SettingGroup {
            title: "Profile picture"
            width: parent.width
            // Miniatura (con el encuadre guardado) + "Adjust…" (editor de encuadre) + "Change…" (elige
            // una imagen con zenity, la copia a ~/.face —la anterior queda en ~/.face.bak— y abre el editor)
            Item {
                width: parent.width
                height: 64
                ClippingRectangle {
                    id: facePreview
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Theme.panelCardHi
                    FacePhoto {
                        anchors.fill: parent
                    }
                }
                Column {
                    anchors.left: facePreview.right
                    anchors.leftMargin: 12
                    anchors.right: faceButtons.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: "Profile picture"
                        color: Theme.text
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(14)
                    }
                    Text {
                        width: parent.width
                        text: faceProc.running ? "Choosing…" : "~/.face"
                        color: Theme.tertiaryText
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: Theme.fontPx(12)
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: faceButtons
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    PillButton {
                        visible: !root.editing
                        label: "Adjust…"
                        onClicked: root.startEdit(false)
                    }
                    PillButton {
                        label: "Change…"
                        onClicked: if (!faceProc.running) faceProc.running = true
                    }
                }
                Process {
                    id: faceProc
                    command: ["sh", "-c", 'f=$(zenity --file-selection --title="Profile picture" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif") || exit 1; [ -f "$f" ] || exit 1; [ -f "$HOME/.face" ] && cp -f "$HOME/.face" "$HOME/.face.bak"; cp -f -- "$f" "$HOME/.face"']
                    onExited: code => {
                        if (code !== 0)
                            return;
                        Overlay.faceVersion++;
                        root.startEdit(true);
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 1
                    color: Theme.divider
                }
            }

            // ---- Editor de encuadre (como al cambiar la foto en WhatsApp) ----
            // La foto entera atenuada de fondo y, dentro del círculo, lo que se verá. Arrastrar o
            // flechas: mover; rueda, +/− o el slider: zoom. Los cambios se guardan con Save.
            Item {
                width: parent.width
                visible: root.editing
                height: visible ? editorCol.implicitHeight + 16 : 0
                Column {
                    id: editorCol
                    width: parent.width
                    y: 8
                    spacing: 8

                    Rectangle {
                        id: stage
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 28
                        height: 300
                        radius: Theme.radiusMedium
                        color: "#0b0f0e"
                        clip: true
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.green

                        Image {
                            x: cropCircle.x + cropPhoto.photoX
                            y: cropCircle.y + cropPhoto.photoY
                            width: cropPhoto.photoW
                            height: cropPhoto.photoH
                            opacity: 0.35
                            source: "file://" + Quickshell.env("HOME") + "/.face?v=" + Overlay.faceVersion
                            cache: false
                            sourceSize.width: 1600
                            asynchronous: true
                        }
                        ClippingRectangle {
                            id: cropCircle
                            anchors.centerIn: parent
                            width: 240
                            height: 240
                            radius: 120
                            color: "transparent"
                            FacePhoto {
                                id: cropPhoto
                                anchors.fill: parent
                                zoom: root.editZoom
                                cx: root.editCx
                                cy: root.editCy
                            }
                        }
                        Rectangle {
                            anchors.fill: cropCircle
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: "#ccffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            // El arrastre y la rueda mueven la foto, no la página de ajustes (que
                            // también se desplaza arrastrando y le robaba el gesto)
                            preventStealing: true
                            property point last
                            onPressed: mouse => {
                                last = Qt.point(mouse.x, mouse.y);
                                stage.forceActiveFocus();
                            }
                            onPositionChanged: mouse => {
                                root.pan(mouse.x - last.x, mouse.y - last.y);
                                last = Qt.point(mouse.x, mouse.y);
                            }
                            onWheel: wheel => {
                                root.setZoom(root.editZoom * Math.pow(1.1, wheel.angleDelta.y / 120));
                                wheel.accepted = true;
                            }
                        }

                        activeFocusOnTab: true
                        onActiveFocusChanged: if (activeFocus) KeyNav.ensureVisible(stage)
                        Keys.onLeftPressed: root.pan(12, 0)
                        Keys.onRightPressed: root.pan(-12, 0)
                        Keys.onUpPressed: root.pan(0, 12)
                        Keys.onDownPressed: root.pan(0, -12)
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                                root.setZoom(root.editZoom * 1.1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Minus) {
                                root.setZoom(root.editZoom / 1.1);
                                event.accepted = true;
                            }
                        }
                        Keys.onReturnPressed: root.saveEdit()
                    }

                    SettingSliderRow {
                        label: "Zoom"
                        value: Math.round(root.editZoom * 100)
                        from: 100; to: 400; unit: "%"
                        onMoved: v => root.setZoom(v / 100)
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        spacing: 6
                        PillButton {
                            label: "Reset"
                            onClicked: {
                                root.editZoom = 1;
                                root.editCx = 0.5;
                                root.editCy = 0.5;
                            }
                        }
                        PillButton {
                            label: "Cancel"
                            onClicked: root.editing = false
                        }
                        PillButton {
                            label: "Save"
                            accent: true
                            onClicked: root.saveEdit()
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 1
                    color: Theme.divider
                }
            }
            SettingSliderRow {
                label: "Profile picture size"
                value: Config.lockAvatarSize
                from: 120; to: 280; unit: " px"
                onMoved: v => Config.opt.lockAvatarSize = v
            }
            SettingSliderRow {
                label: "Waves"
                value: Config.lockAvatarWaves
                from: 0; to: 16; unit: ""
                onMoved: v => Config.opt.lockAvatarWaves = v
            }
            SettingSliderRow {
                visible: Config.lockAvatarWaves > 0
                label: "Wave depth"
                value: Config.lockAvatarWaveDepth
                from: 2; to: 20; unit: "%"
                onMoved: v => Config.opt.lockAvatarWaveDepth = v
            }
            SettingToggleRow {
                visible: Config.lockAvatarWaves > 0
                label: "Rotate shape"
                checked: Config.lockAvatarSpin
                onToggled: Config.opt.lockAvatarSpin = !Config.lockAvatarSpin
            }
            SettingSliderRow {
                visible: Config.lockAvatarWaves > 0 && Config.lockAvatarSpin
                label: "Rotation time"
                value: Config.lockAvatarSpinSeconds
                from: 6; to: 60; unit: " s per turn"
                onMoved: v => Config.opt.lockAvatarSpinSeconds = v
            }
            SettingSliderRow {
                label: "Breathing"
                value: Config.lockAvatarBreathe
                from: 0; to: 20; unit: "%"
                onMoved: v => Config.opt.lockAvatarBreathe = v
            }
        }

        SettingGroup {
            title: "Background"
            width: parent.width
            SettingSliderRow {
                label: "Background blur"
                value: Config.lockBackgroundBlur
                from: 0; to: 100; unit: "%"
                onMoved: v => Config.opt.lockBackgroundBlur = v
            }
            SettingSliderRow {
                label: "Background dim"
                value: Config.lockBackgroundDim
                from: 0; to: 80; unit: "%"
                onMoved: v => Config.opt.lockBackgroundDim = v
            }
        }

        SettingGroup {
            title: "When idle"
            width: parent.width
            SettingToggleRow { label: "Lock when idle"; checked: Config.idleLockEnabled; onToggled: Config.opt.idleLockEnabled = !Config.idleLockEnabled }
            SettingSliderRow {
                visible: Config.idleLockEnabled
                label: "Lock after"
                value: Config.idleLockMinutes
                from: 1; to: 60; unit: " min"
                onMoved: v => Config.opt.idleLockMinutes = v
            }
            SettingToggleRow { label: "Suspend when idle"; checked: Config.idleSuspendEnabled; onToggled: Config.opt.idleSuspendEnabled = !Config.idleSuspendEnabled }
            SettingSliderRow {
                visible: Config.idleSuspendEnabled
                label: "Suspend after"
                value: Config.idleSuspendMinutes
                from: 5; to: 120; unit: " min"
                onMoved: v => Config.opt.idleSuspendMinutes = v
            }
        }

        Text {
            width: parent.width
            text: "Idle timers pause while an app blocks idle (video, fullscreen)."
            color: Theme.tertiaryText
            wrapMode: Text.Wrap
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
        }
    }


    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property bool accent: false
        signal clicked
        width: pillText.implicitWidth + 28
        height: 32
        radius: 16
        color: accent ? Theme.green : (pillMouse.containsMouse ? Theme.panelCardHi : Qt.rgba(1, 1, 1, 0.06))
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.accent ? Theme.crust : Theme.text
            font.family: Theme.bodyFontFamily
            font.pixelSize: Theme.fontPx(12)
            font.bold: pill.accent
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
        KeyButton {
            radius: pill.radius
            onActivated: pill.clicked()
        }
    }
}
