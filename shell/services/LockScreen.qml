pragma Singleton
// Bloqueo real de la sesión Wayland con autenticación PAM.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Services.Pam
import "../common"

Singleton {
    id: root

    readonly property bool locked: sessionLock.locked
    property string errorText: ""
    property string passwordText: ""
    property var passwordField: null
    property var mediaService: null
    property string powerAction: ""
    property bool suspending: false

    function lock(): void {
        if (sessionLock.locked)
            return;

        errorText = "";
        passwordText = "";
        sessionLock.locked = true;
        Qt.callLater(() => {
            if (!pam.start())
                errorText = "No se pudo iniciar la autenticación";
        });
    }

    function submitPassword(): void {
        if (!pam.responseRequired || passwordText.length === 0)
            return;

        const response = passwordText;
        passwordText = "";
        pam.respond(response);
    }

    function confirmPowerAction(): void {
        if (powerAction !== "") {
            powerProc.command = ["systemctl", powerAction];
            powerProc.running = true;
            powerAction = "";
        }
    }

    // La sesión queda protegida antes de pedir a logind que suspenda el equipo.
    // WlSessionLock permanece activo al reanudar, así PAM vuelve a pedir la clave.
    function suspend(): void {
        suspending = false;
        suspending = true;
        suspendLockTimer.restart();
    }

    Process {
        id: powerProc
    }

    Process {
        id: suspendProc
        onExited: root.suspending = false
    }

    IpcHandler {
        target: "salchipapa-lock"
        function activate(): void {
            root.lock();
        }
        function reveal(): void {
            // Recuperación visual: conserva el bloqueo PAM y solo quita la capa negra.
            root.suspending = false;
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: lockSurface
            color: "#000000"

            Item {
                id: page
                width: lockSurface.width
                height: lockSurface.height

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: Wallpaper.current ? "file://" + Wallpaper.current : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                MultiEffect {
                    anchors.fill: wallpaper
                    source: wallpaper
                    blurEnabled: Config.lockBackgroundBlur > 0
                    blur: Config.lockBackgroundBlur / 100
                    blurMax: 48
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, Config.lockBackgroundDim / 100)
                }

                SystemClock {
                    id: lockClock
                    precision: SystemClock.Minutes
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.max(52, parent.height * 0.075)
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(lockClock.date, "dddd, MMMM d")
                        color: "#e8f1f0"
                        opacity: 0.9
                        font.family: Theme.displayFontFamily
                        font.pixelSize: 18
                        visible: Config.lockShowDate
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(lockClock.date, Config.lockClock24Hour ? "HH:mm" : "h:mm AP")
                        color: "#f5f7f6"
                        font.family: Theme.displayFontFamily
                        font.pixelSize: Math.min(100, Math.max(68, page.width * 0.055))
                        font.weight: Font.DemiBold
                        visible: Config.lockShowClock
                    }
                }

                MediaCard {
                    id: musicCard
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(460, parent.width - 48)
                    height: 200
                    visible: Config.lockShowMusic && !!player
                    player: root.mediaService?.active ?? null
                    art: root.mediaService?.artPath ?? ""
                    title: root.mediaService?.title ?? ""
                    artist: root.mediaService?.artist || root.mediaService?.album || ""
                    sinkName: Audio.sink?.description || Audio.sink?.nickname || ""
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.max(72, parent.height * 0.095)
                    width: Math.min(360, parent.width * 0.8)
                    spacing: 12

                    // Foto de ~/.face con forma ondulada suave (N ondas, una centrada arriba; 0 = círculo):
                    // el radio oscila entre `inner` y `outer` con (1 + cos N(θ + 90°)) / 2. La forma se
                    // rellena con la foto (fillItem, sin máscara: un MultiEffect con maskSource fuera de
                    // la escena la dejaba transparente).
                    Item {
                        id: avatarFrame
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Tamaño, ondas, encuadre y animación: Ajustes > Lock Screen > Profile picture
                        width: Config.lockAvatarSize
                        height: Config.lockAvatarSize

                        // Animación: la forma gira y "respira" (crece lockAvatarBreathe %); la foto no gira
                        // ni se amplía, la forma deja ver más o menos de ella. En reposo la forma mide
                        // 1/breatheTo del cuadro para que al crecer no se salga. Sin animación con Reduce motion.
                        property real spin: 0 // radianes que gira la forma
                        NumberAnimation on spin {
                            from: 0
                            to: 2 * Math.PI
                            duration: Config.lockAvatarSpinSeconds * 1000
                            loops: Animation.Infinite
                            running: !Theme.reduceMotion && Config.lockAvatarSpin && Config.lockAvatarWaves > 0
                        }
                        readonly property real breatheTo: 1 + Config.lockAvatarBreathe / 100
                        property real breathe: 1
                        SequentialAnimation on breathe {
                            loops: Animation.Infinite
                            running: !Theme.reduceMotion && Config.lockAvatarBreathe > 0
                            NumberAnimation { from: 1; to: avatarFrame.breatheTo; duration: 2500; easing.type: Easing.InOutSine }
                            NumberAnimation { from: avatarFrame.breatheTo; to: 1; duration: 2500; easing.type: Easing.InOutSine }
                        }

                        readonly property var outline: {
                            const pts = [];
                            const c = width / 2, outer = (width / 2 - 2) / breatheTo * breathe, steps = 240;
                            const waves = Config.lockAvatarWaves, inner = outer * (1 - Config.lockAvatarWaveDepth / 100);
                            for (let i = 0; i <= steps; i++) {
                                const t = 2 * Math.PI * i / steps;
                                const r = waves > 0 ? inner + (outer - inner) * (1 + Math.cos(waves * (t + Math.PI / 2 - spin))) / 2 : outer;
                                pts.push(Qt.point(c + r * Math.cos(t), c + r * Math.sin(t)));
                            }
                            return pts;
                        }

                        // Textura de la foto ya recortada al cuadrado de la forma. Al doble de
                        // resolución y suavizada: al "respirar" se agranda y a 1× se veían los píxeles
                        Item {
                            id: avatarPhoto
                            width: avatarFrame.width
                            height: avatarFrame.height
                            visible: false
                            layer.enabled: true
                            layer.smooth: true
                            layer.textureSize: Qt.size(width * 2, height * 2)
                            Rectangle {
                                anchors.fill: parent
                                color: "#334b4a" // si la foto no carga
                            }
                            // Encuadre de Ajustes > Lock Screen (zoom y punto central)
                            FacePhoto {
                                anchors.fill: parent
                            }
                        }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillItem: avatarPhoto
                                // La textura es del doble de tamaño (nitidez al "respirar") y fillItem
                                // la pega píxel a píxel: sin escalarla a la mitad solo se veía su
                                // esquina superior izquierda
                                fillTransform: PlanarTransform.fromScale(0.5, 0.5)
                                strokeColor: "#80ffffff"
                                strokeWidth: 2
                                PathPolyline { path: avatarFrame.outline }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Quickshell.env("USER") || "user"
                        color: "#f5f7f6"
                        font.family: Theme.displayFontFamily
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 48
                        radius: 12
                        color: "#44101816"
                        border.color: passwordInput.activeFocus ? "#99ffffff" : "#44ffffff"
                        border.width: 1

                        TextInput {
                            id: passwordInput
                            text: root.passwordText
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "#f5f7f6"
                            selectionColor: Theme.green
                            selectedTextColor: "#06120f"
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 15
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            focus: sessionLock.locked
                            enabled: sessionLock.locked
                            Component.onCompleted: root.passwordField = passwordInput
                            Component.onDestruction: {
                                if (root.passwordField === passwordInput)
                                    root.passwordField = null;
                            }
                            onTextChanged: {
                                if (root.passwordText !== text)
                                    root.passwordText = text;
                            }
                            onAccepted: root.submitPassword()
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    event.accepted = true;
                                    passwordInput.clear();
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: passwordInput.text.length === 0
                            text: passwordInput.activeFocus ? "Escribe tu contraseña y presiona Enter" : "Presiona una tecla para ingresar la contraseña"
                            color: "#d9e4e2"
                            opacity: 0.8
                            font.family: Theme.bodyFontFamily
                            font.pixelSize: 14
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: root.errorText || (pam.messageIsError ? pam.message : "")
                        visible: text.length > 0
                        color: "#ffb4ab"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        font.family: Theme.bodyFontFamily
                        font.pixelSize: 13
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 22
                    spacing: 12

                    Repeater {
                        model: [
                            { label: "Reiniciar", action: "reboot", glyph: "↻" },
                            { label: "Apagar", action: "poweroff", glyph: "⏻" }
                        ]

                        Rectangle {
                            required property var modelData
                            width: 170
                            height: 54
                            radius: 18
                            color: powerMouse.containsMouse ? "#d0101816" : "#b8101816"
                            border.color: powerMouse.containsMouse ? "#75ffffff" : "#35ffffff"
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                height: parent.height
                                spacing: 9
                                Text {
                                    text: parent.parent.modelData.glyph
                                    color: Theme.green
                                    font.pixelSize: 18
                                    height: parent.height
                                    y: 3
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    text: parent.parent.modelData.label
                                    color: "#f5f7f6"
                                    font.family: Theme.displayFontFamily
                                    font.pixelSize: 13
                                    font.bold: true
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.powerAction = parent.modelData.action
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    z: 20
                    visible: root.powerAction !== ""
                    color: "#bb000000"

                    MouseArea { anchors.fill: parent }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 360
                        height: 184
                        radius: 20
                        color: "#f00d1513"
                        border.color: "#55ffffff"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 14

                            Text {
                                width: parent.width
                                text: root.powerAction === "reboot" ? "¿Reiniciar el equipo?" : "¿Apagar el equipo?"
                                color: "#f5f7f6"
                                font.family: Theme.displayFontFamily
                                font.pixelSize: 19
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                width: parent.width
                                text: "La sesión actual se cerrará."
                                color: "#c0cfcc"
                                font.family: Theme.bodyFontFamily
                                font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 10
                                Rectangle {
                                    width: 132
                                    height: 40
                                    radius: 20
                                    color: "#342b29"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancelar"
                                        color: "#e2e9e7"
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 13
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.powerAction = "" }
                                }
                                Rectangle {
                                    width: 132
                                    height: 40
                                    radius: 20
                                    color: Theme.red
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.powerAction === "reboot" ? "Reiniciar" : "Apagar"
                                        color: "#160908"
                                        font.family: Theme.bodyFontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: root.confirmPowerAction() }
                                }
                            }
                        }
                    }
                }

                // Fundir a negro antes de suspender evita el corte brusco del wallpaper.
                Rectangle {
                    anchors.fill: parent
                    z: 100
                    color: "black"
                    opacity: root.suspending ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 550
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
            }
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: {
            if (responseRequired)
                root.passwordField?.forceActiveFocus();
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                errorText = "";
                passwordText = "";
                sessionLock.locked = false;
            } else {
                errorText = result === PamResult.MaxTries ? "Se alcanzó el límite de intentos. Inténtalo de nuevo." : "Contraseña incorrecta. Inténtalo de nuevo.";
                passwordText = "";
                active = false;
                retryAuth.restart();
            }
        }

        onError: error => {
            errorText = PamError.toString(error);
        }
    }

    Timer {
        id: retryAuth
        interval: 900
        repeat: false
        onTriggered: {
            if (sessionLock.locked) {
                if (!pam.start())
                    root.errorText = "No se pudo reiniciar la autenticación";
            }
        }
    }

    Timer {
        id: suspendLockTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!sessionLock.locked)
                root.lock();
            if (sessionLock.locked)
                suspendCommandTimer.restart();
        }
    }

    Timer {
        id: suspendCommandTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (root.suspending && sessionLock.locked) {
                suspendProc.command = ["systemctl", "suspend"];
                suspendProc.running = true;
            }
        }
    }
}
