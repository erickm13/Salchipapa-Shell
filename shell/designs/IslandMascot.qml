// Mascota de la isla: pasea por el hueco libre a un lado de la hora (el lateral más corto reserva
// el mismo ancho que el largo para que la hora quede centrada). Según lo que pase:
//   - sin nada: pasea y de vez en cuando hace una gracia (saltito, voltereta, mirar a los lados);
//     si no pasa nada en un rato, bosteza y se echa a dormir (zzz) hasta que algo la despierta
//   - suena Spotify: alterna paseo y baile, con notas flotando
//   - se reproduce un vídeo de YouTube: se sienta delante de una tele y lo mira
//   - llega una notificación: da un respingo (!)
//   - el hueco cambia de lado: sale volando por encima de la hora, cae tumbada y se levanta
// Con una hoja simple (una fila de fotogramas cuadrados caminando a la derecha) todo son
// transformaciones de ese sprite. Si junto al PNG hay un .json con el mismo nombre, la hoja es una
// rejilla con una animación por fila y se usa la que toque en cada momento:
//   { "frameWidth": 40, "frameHeight": 26,
//     "animations": { "walk": { "row": 0, "frames": 8, "ms": 110 }, "idle": …, "jump": …,
//                     "hit": …, "faint": …, "sleep": … } }
// (solo "walk" es imprescindible). Cualquier otra animación con otro nombre es un "extra": de vez
// en cuando se para y reproduce una al azar. "bodyWidth"/"bodyHeight" (opcionales) dan el tamaño
// del personaje al caminar cuando hay fotogramas más grandes que él.
// Con sprite = "random" va cambiando sola de mascota cada Config.mascotRandomMinutes. Oculta con batería y con animaciones reducidas, para no gastar.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../common"
import "../services"

Item {
    id: mascot

    // Lo que pone la isla: su escala, los bordes libres a cada lado de la hora y si puede verse
    property real scaleFactor: 1
    property real leftGapStart: 0
    property real leftGapEnd: 0
    property real rightGapStart: 0
    property real rightGapEnd: 0
    property bool allowed: true
    property string sprite: "" // ruta a una hoja propia; vacío = defaultSprite; "random" = va cambiando
    // La hoja que se está usando de verdad
    property string activeSprite: sprite === "random" ? "" : sprite
    onSpriteChanged: {
        if (sprite === "random")
            pickRandom();
        else
            activeSprite = sprite;
    }
    function pickRandom(): void {
        if (sprite !== "random" || randomFiles.status !== FolderListModel.Ready)
            return;
        // Una más que archivos: la última es la salchipapa de serie
        const i = Math.floor(Math.random() * (randomFiles.count + 1));
        activeSprite = i < randomFiles.count ? randomFiles.get(i, "filePath") : "";
    }
    FolderListModel {
        id: randomFiles
        folder: mascot.sprite === "random" ? "file://" + Quickshell.env("HOME") + "/.config/salchipapa-shell/mascots" : ""
        nameFilters: ["*.png"]
        showDirs: false
        onStatusChanged: if (status === FolderListModel.Ready) mascot.pickRandom()
    }
    Timer {
        interval: Math.max(1, Config.mascotRandomMinutes) * 60000
        repeat: true
        running: mascot.sprite === "random"
        onTriggered: mascot.pickRandom()
    }
    property url defaultSprite: Qt.resolvedUrl("../assets/mascot/salchipapa.png")

    function s(v: real): int {
        return Math.round(v * scaleFactor);
    }

    // Hueco a cada lado de la hora; pasea por el más grande
    readonly property real pad: s(4)
    readonly property real rightStart: rightGapStart + pad
    readonly property real rightEnd: rightGapEnd - pad - width
    readonly property real leftStart: leftGapStart + pad
    readonly property real leftEnd: leftGapEnd - pad - width
    readonly property bool useLeft: leftEnd - leftStart > rightEnd - rightStart
    readonly property real gapStart: useLeft ? leftStart : rightStart
    readonly property real gapEnd: useLeft ? leftEnd : rightEnd
    // No reserva sitio: aparece solo si cabe en el hueco que ya hay. Con que quepa de pie basta;
    // si además sobra algo, pasea.
    readonly property bool fits: gapEnd >= gapStart
    readonly property bool canWalk: gapEnd - gapStart >= s(8)
    readonly property bool canShow: allowed && Config.mascotEnabled && !Theme.reduceMotion && !Battery.onBattery
    // Mientras vuela en la voltereta no se exige que quepa (la isla está cambiando de ancho); al
    // aterrizar sí (ver `tumble`)
    readonly property bool active: canShow && (fits || tumbling)

    // Hoja con varias animaciones (ver cabecera); null = hoja simple
    property var manifest: null
    readonly property var anims: manifest?.animations ?? null
    function has(a: string): bool {
        return !!(anims && anims[a]);
    }
    // Hasta saber si la hoja trae .json no se conoce el tamaño del fotograma: mientras, oculta
    property bool manifestChecked: !activeSprite.toLowerCase().endsWith(".png")
    onActiveSpriteChanged: {
        manifest = null;
        manifestChecked = !activeSprite.toLowerCase().endsWith(".png");
        if (act === "extra")
            setAct("walk");
    }
    readonly property var extraNames: anims ? Object.keys(anims).filter(k => !["walk", "idle", "jump", "hit", "faint", "sleep"].includes(k)) : []
    property string extraAnim: ""
    FileView {
        path: mascot.activeSprite.toLowerCase().endsWith(".png") ? mascot.activeSprite.slice(0, -4) + ".json" : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                mascot.manifest = JSON.parse(text());
            } catch (e) {
                mascot.manifest = null;
            }
            mascot.manifestChecked = true;
        }
        onLoadFailed: {
            mascot.manifest = null;
            mascot.manifestChecked = true;
        }
    }
    // Animación de la hoja que toca ahora
    readonly property string anim: {
        if (!anims)
            return "";
        let a = "walk";
        if (tumbling)
            a = landed ? "faint" : "jump";
        else if (act === "extra")
            a = extraAnim;
        else if (act === "dance" || act === "hop" || act === "spin")
            a = "jump";
        else if (act === "startle")
            a = "hit";
        else if (act === "sleep")
            a = "sleep";
        else if (act === "yawn" || act === "look" || act === "watch" || rest > 0 || !canWalk)
            a = "idle";
        return has(a) ? a : has("walk") ? "walk" : Object.keys(anims)[0];
    }
    readonly property var animDef: anims ? anims[anim] : null

    readonly property int frameW: !manifestChecked ? 1 : manifest?.frameWidth ?? probe.sourceSize.height
    readonly property int frame: !manifestChecked ? 1 : manifest?.frameHeight ?? probe.sourceSize.height // alto
    // Tamaño del personaje (al caminar): con él se escala y se mide si cabe; los fotogramas más
    // grandes sobresalen por arriba y por los lados
    readonly property int bodyW: manifest?.bodyWidth ?? frameW
    readonly property int bodyH: manifest?.bodyHeight ?? frame
    // Pixel art: escala entera para que no se emborrone; con fotogramas medianos (donde un salto
    // entero se queda corto o se pasa) se admite ×1,5, y los más altos que la isla se encogen
    // (suavizados) hasta caber
    readonly property real zoom: {
        const fit = s(26) / Math.max(1, bodyH);
        if (fit < 1)
            return fit;
        return Math.max(1, bodyH <= 14 ? Math.floor(fit) : Math.floor(fit * 2) / 2);
    }

    // Qué suena
    readonly property bool spotifyPlaying: Media.isPlaying && ((Media.active?.identity ?? "") + (Media.active?.dbusName ?? "") + Media.trackUrl).toLowerCase().includes("spotify")
    readonly property bool watching: Media.isPlaying && !spotifyPlaying && /^https?:\/\/([^\/]*\.)?(youtube\.com|youtu\.be)\//.test(Media.trackUrl)

    // Estado
    property string act: "walk" // walk | dance | hop | spin | look | extra | startle | yawn | sleep | watch
    property real actT: 0 // segundos en la acción actual
    property int dir: 1
    property int lookDir: 1
    property real rest: 0 // pausa que queda al llegar a un extremo
    property real idleFor: 0 // segundos paseando sin que pase nada
    // Con algo de azar para que no sea siempre igual
    property real danceIn: 2 + Math.random() * 5
    property real nextTrick: 4 + Math.random() * 8
    property real sleepAfter: 40 + Math.random() * 30
    property real lift: 0 // desplazamiento vertical del cuerpo (negativo = arriba)
    property real rot: 0
    property real squash: 1

    // Voltereta al cambiar de hueco
    property bool tumbling: false
    property bool landed: false // ya ha caído (tumbada) y aún no se ha levantado
    property real flyT: 0
    property real flyFrom: 0
    property int flySign: 1
    readonly property real flyTarget: useLeft ? gapEnd : gapStart // aterriza pegada a la hora

    readonly property real tvWidth: s(20)
    readonly property bool tvFits: gapEnd - gapStart >= tvWidth + s(4)

    visible: active && manifestChecked && probe.status === Image.Ready && frame > 0
    width: Math.round(bodyW * zoom)
    height: Math.round(bodyH * zoom)
    z: 1 // por delante de la hora cuando vuela

    function setAct(a: string): void {
        act = a;
        actT = 0;
        lift = 0;
        rot = 0;
        squash = 1;
    }

    // Algo ha pasado en la isla: despierta si dormía; con `startle`, además da un respingo
    function poke(startle: bool): void {
        if (!visible || tumbling)
            return;
        idleFor = 0;
        if (act === "sleep" || act === "yawn" || (startle && act === "walk"))
            setAct("startle");
    }

    // Al arrancar los huecos aún se están midiendo: nada de volteretas hasta que se asienten
    property bool settled: false
    Timer {
        interval: 1500
        running: true
        onTriggered: mascot.settled = true
    }
    onUseLeftChanged: {
        if (!canShow || !settled)
            return;
        flyFrom = x;
        flySign = useLeft ? -1 : 1;
        rest = 0;
        idleFor = 0;
        setAct("walk");
        tumbling = true; // antes de arrancar: mantiene visible la mascota
        tumble.restart();
    }
    onVisibleChanged: {
        if (visible && tumbling)
            return;
        tumble.stop();
        tumbling = false;
        landed = false;
        setAct("walk");
        idleFor = 0;
        if (visible) {
            x = gapStart;
            dir = 1;
            rest = 0;
        }
    }

    Connections {
        target: Notifs
        function onReceived(notif: var): void {
            mascot.poke(true);
        }
    }
    Connections {
        target: Media
        function onIsPlayingChanged(): void {
            mascot.poke(false);
        }
        function onTitleChanged(): void {
            mascot.poke(false);
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            mascot.poke(false);
        }
    }

    SequentialAnimation {
        id: tumble
        ScriptAction {
            script: {
                mascot.flyT = 0;
                mascot.landed = false;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: mascot; property: "flyT"; from: 0; to: 1; duration: 600; easing.type: Easing.InOutSine }
            // Con animación de desmayo el sprite ya sale tumbado: acaba la vuelta derecha y a ras de suelo
            NumberAnimation { target: mascot; property: "rot"; from: 0; to: mascot.flySign * (mascot.has("faint") ? 360 : 450); duration: 600 }
            SequentialAnimation {
                NumberAnimation { target: mascot; property: "lift"; to: -mascot.s(5); duration: 280; easing.type: Easing.OutQuad }
                NumberAnimation { target: mascot; property: "lift"; to: mascot.has("faint") ? 0 : mascot.s(3); duration: 320; easing.type: Easing.InQuad }
            }
        }
        ScriptAction { script: mascot.landed = true }
        // Si en el hueco nuevo no cabe, desaparece al aterrizar en vez de quedarse encima de algo
        ScriptAction {
            script: if (!mascot.fits) {
                mascot.rot = 0;
                mascot.lift = 0;
                mascot.tumbling = false;
            }
        }
        // Rebote al caer y un rato tumbada
        NumberAnimation { target: mascot; property: "lift"; to: mascot.has("faint") ? -mascot.s(2) : mascot.s(1); duration: 90 }
        NumberAnimation { target: mascot; property: "lift"; to: mascot.has("faint") ? 0 : mascot.s(3); duration: 90 }
        PauseAnimation { duration: 800 }
        // Se levanta con un saltito
        ParallelAnimation {
            NumberAnimation { target: mascot; property: "rot"; to: mascot.flySign * 360; duration: 320; easing.type: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: mascot; property: "lift"; to: -mascot.s(3); duration: 160; easing.type: Easing.OutQuad }
                NumberAnimation { target: mascot; property: "lift"; to: 0; duration: 160; easing.type: Easing.InQuad }
            }
        }
        ScriptAction {
            script: {
                mascot.rot = 0;
                mascot.dir = mascot.useLeft ? -1 : 1; // se aleja de la hora
                mascot.rest = 0.3;
                mascot.landed = false;
                mascot.tumbling = false;
            }
        }
    }

    function walkStep(dt: real): void {
        if (rest > 0) {
            rest -= dt;
            return;
        }
        if (!canWalk)
            return; // cabe justa: se queda de pie
        x += dir * 22 * dt; // ~22 px/s
        if (dir > 0 && x >= gapEnd) {
            dir = -1;
            rest = 0.9;
        } else if (dir < 0 && x <= gapStart) {
            dir = 1;
            rest = 0.9;
        }
    }

    // Paso a paso en vez de animaciones de punta a punta: el hueco cambia de tamaño y de lado (al
    // empezar música, llegar una notificación…) y así nunca se sale de él.
    FrameAnimation {
        running: mascot.visible
        onTriggered: {
            const m = mascot;
            const dt = frameTime;
            if (m.tumbling) {
                // El destino se lee en vivo: la isla está cambiando de ancho mientras vuela
                m.x = m.flyFrom + (m.flyTarget - m.flyFrom) * m.flyT;
                return;
            }
            m.actT += dt;
            const t = m.actT;

            if (m.watching && m.tvFits) {
                if (m.act !== "watch")
                    m.setAct("watch");
            } else if (m.act === "watch") {
                m.setAct("walk");
            }

            switch (m.act) {
            case "walk":
                m.walkStep(dt);
                if (m.spotifyPlaying) {
                    m.idleFor = 0;
                    m.danceIn -= dt;
                    if (m.danceIn <= 0)
                        m.setAct("dance");
                } else {
                    m.idleFor += dt;
                    m.nextTrick -= dt;
                    if (m.idleFor > m.sleepAfter) {
                        m.sleepAfter = 40 + Math.random() * 30;
                        m.setAct("yawn");
                    } else if (m.nextTrick <= 0) {
                        m.nextTrick = (m.extraNames.length ? 4 : 7) + Math.random() * 8;
                        const r = Math.random();
                        m.lookDir = m.dir;
                        if (m.extraNames.length && Math.random() < 0.7) {
                            // Una de las animaciones extra de la hoja, al azar
                            m.extraAnim = m.extraNames[Math.floor(Math.random() * m.extraNames.length)];
                            m.setAct("extra");
                        } else {
                            m.setAct(r < 0.4 ? "hop" : r < 0.65 ? "spin" : "look");
                        }
                    }
                }
                break;
            case "dance":
                // Botes, balanceo y media vuelta a cada tiempo
                m.lift = -Math.abs(Math.sin(t * Math.PI * 2)) * m.s(4);
                m.rot = Math.sin(t * Math.PI * 2) * 14;
                m.dir = Math.floor(t * 2) % 2 === 0 ? 1 : -1;
                if (!m.spotifyPlaying || t > 4.5) {
                    m.danceIn = 3 + Math.random() * 4;
                    m.setAct("walk");
                }
                break;
            case "hop":
                m.walkStep(dt);
                m.lift = -Math.sin(Math.PI * Math.min(1, t / 0.45)) * m.s(7);
                if (t >= 0.45)
                    m.setAct("walk");
                break;
            case "spin":
                m.lift = -Math.sin(Math.PI * Math.min(1, t / 0.6)) * m.s(7);
                m.rot = m.dir * 360 * Math.min(1, t / 0.6);
                if (t >= 0.6)
                    m.setAct("walk");
                break;
            case "extra": {
                // De pie, reproduce la animación entera (dos veces si es muy corta)
                const def = m.anims ? m.anims[m.extraAnim] : null;
                const once = def ? def.frames * (def.ms ?? 150) / 1000 : 0;
                if (!def || t >= (once < 0.9 ? once * 2 : once))
                    m.setAct("walk");
                break;
            }
            case "look":
                m.dir = Math.floor(t / 0.35) % 2 === 0 ? -m.lookDir : m.lookDir;
                if (t >= 1.4) {
                    m.dir = m.lookDir;
                    m.setAct("walk");
                }
                break;
            case "startle":
                m.lift = -Math.sin(Math.PI * Math.min(1, t / 0.3)) * m.s(6);
                if (t >= 0.9) {
                    m.idleFor = 0;
                    m.setAct("walk");
                }
                break;
            case "yawn":
                m.squash = 1 + 0.2 * Math.sin(Math.PI * Math.min(1, t / 1.0));
                if (t >= 1.0)
                    m.setAct("sleep");
                break;
            case "sleep": {
                // Se tumba boca arriba y respira despacio; se despierta sola al cabo de un rato
                if (m.has("sleep")) {
                    m.squash = 1 + 0.03 * Math.sin(t * Math.PI * 0.8); // la hoja ya trae la postura
                } else {
                    const down = Math.min(1, t / 0.4);
                    m.rot = -90 * m.dir * down;
                    m.lift = m.zoom * 2 * down;
                    m.squash = 1 + 0.06 * Math.sin(t * Math.PI * 0.8);
                }
                if (t > 40)
                    m.setAct("startle");
                break;
            }
            case "watch": {
                // Sentada mirando la tele (a su derecha); de vez en cuando se ríe con unos botes
                m.dir = 1;
                m.squash = 0.92;
                const laugh = t % 7;
                m.lift = laugh > 6.2 ? -Math.abs(Math.sin((laugh - 6.2) / 0.8 * Math.PI * 3)) * m.s(2) : 0;
                const seat = m.gapEnd - m.tvWidth - m.s(4);
                if (m.x > seat)
                    m.x = Math.max(seat, m.x - 60 * dt);
                break;
            }
            }
            m.x = Math.max(m.gapStart, Math.min(m.gapEnd, m.x));
        }
    }

    Image {
        id: probe
        visible: false
        source: mascot.activeSprite !== "" ? "file://" + mascot.activeSprite : mascot.defaultSprite
    }

    // Cuerpo: lo único que gira, bota y se estira (los adornos de alrededor no)
    Item {
        anchors.fill: parent
        transform: [
            Rotation {
                origin.x: mascot.width / 2
                origin.y: mascot.height / 2
                angle: mascot.rot
            },
            Scale {
                origin.x: mascot.width / 2
                origin.y: mascot.height
                yScale: mascot.squash
            },
            Translate {
                y: mascot.lift
            }
        ]
        AnimatedSprite {
            // Con los pies en el suelo y centrado: los fotogramas mayores que el cuerpo sobresalen
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(mascot.frameW * mascot.zoom)
            height: Math.round(mascot.frame * mascot.zoom)
            source: probe.source
            frameX: 0
            frameY: mascot.animDef ? mascot.animDef.row * mascot.frame : 0
            frameWidth: mascot.frameW
            frameHeight: mascot.frame
            frameCount: mascot.animDef ? mascot.animDef.frames : Math.max(1, Math.round(probe.sourceSize.width / Math.max(1, mascot.frameW)))
            frameDuration: mascot.animDef?.ms ?? 150
            interpolate: false
            smooth: mascot.zoom < 1
            // Hoja con animaciones: siempre en marcha (el reposo y el sueño también se animan)
            running: mascot.visible && (mascot.anims ? true : !mascot.tumbling && mascot.rest <= 0 && (mascot.act === "dance" || (mascot.canWalk && ["walk", "hop", "spin"].includes(mascot.act))))
            transform: Scale {
                origin.x: Math.round(mascot.frameW * mascot.zoom) / 2
                xScale: mascot.dir
            }
        }
    }

    // zzz al dormir
    Repeater {
        model: 3
        delegate: Text {
            required property int index
            readonly property real p: (mascot.actT / 2.4 + index / 3) % 1
            visible: mascot.act === "sleep" && mascot.actT > 0.5
            text: "z"
            color: Theme.text
            font.family: Theme.bodyFontFamily
            font.bold: true
            font.pixelSize: mascot.s(7) + p * mascot.s(4)
            x: mascot.width * 0.6 + p * mascot.s(9)
            y: mascot.s(4) - p * mascot.s(9)
            opacity: Math.sin(Math.PI * p)
        }
    }

    // Notas al bailar
    Repeater {
        model: ["♪", "♫"]
        delegate: Text {
            required property int index
            required property string modelData
            readonly property real p: (mascot.actT / 1.2 + index / 2) % 1
            visible: mascot.act === "dance"
            text: modelData
            color: Theme.green
            font.pixelSize: mascot.s(10)
            x: index === 0 ? -mascot.s(7) : mascot.width + mascot.s(1)
            y: mascot.s(6) - p * mascot.s(8)
            opacity: Math.sin(Math.PI * p)
        }
    }

    // Respingo
    Text {
        visible: mascot.act === "startle"
        text: "!"
        color: Theme.yellow
        font.family: Theme.displayFontFamily
        font.bold: true
        font.pixelSize: mascot.s(14)
        x: mascot.dir > 0 ? mascot.width - mascot.s(1) : -mascot.s(5)
        y: -mascot.s(2)
    }

    // Tele (vídeo de YouTube): antena, caja, patas y una pantalla que parpadea
    Item {
        id: tv
        visible: mascot.act === "watch"
        x: mascot.width + mascot.s(4)
        width: mascot.tvWidth
        height: mascot.s(17)
        anchors.bottom: parent.bottom
        readonly property var tints: ["#89b4fa", "#f5c2e7", "#cdd6f4", "#a6e3a1", "#f9e2af", "#94e2d5"]

        Rectangle {
            x: tv.width / 2 - mascot.s(4)
            y: 0
            width: Math.max(1, mascot.s(1))
            height: mascot.s(6)
            rotation: -28
            color: "#7f849c"
        }
        Rectangle {
            x: tv.width / 2 + mascot.s(3)
            y: 0
            width: Math.max(1, mascot.s(1))
            height: mascot.s(6)
            rotation: 28
            color: "#7f849c"
        }
        Rectangle {
            y: mascot.s(4)
            width: parent.width
            height: mascot.s(12)
            radius: mascot.s(2)
            color: "#585b70"
            Rectangle {
                anchors.fill: parent
                anchors.margins: mascot.s(2)
                radius: 1
                color: tv.tints[Math.floor(mascot.actT * 2.5) % tv.tints.length]
                opacity: 0.75 + 0.25 * Math.sin(mascot.actT * 9)
                Behavior on color {
                    ColorAnimation { duration: 250 }
                }
            }
        }
        Rectangle {
            x: mascot.s(3)
            y: mascot.s(16)
            width: mascot.s(3)
            height: Math.max(1, mascot.s(1))
            color: "#7f849c"
        }
        Rectangle {
            x: tv.width - mascot.s(6)
            y: mascot.s(16)
            width: mascot.s(3)
            height: Math.max(1, mascot.s(1))
            color: "#7f849c"
        }
    }
}
