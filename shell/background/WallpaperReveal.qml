pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Dos imágenes alternan sus papeles: nunca se cambia la imagen que aún se está mostrando.
// Una máscara circular revela la siguiente; al terminar no quedan efectos renderizándose.
Item {
    id: root

    property url source
    property int duration: 500
    property bool reduceMotion: false
    // Coordenadas normalizadas; fuera de [0,1] elige un origen aleatorio en cada cambio.
    property point origin: Qt.point(-1, -1)

    readonly property url displayedSource: currentImage.source
    readonly property bool transitioning: reveal.running
    readonly property real radius: progress * Math.hypot(Math.max(center.x, width - center.x), Math.max(center.y, height - center.y))

    property int currentIndex: 0
    property real progress: 0
    property point center: Qt.point(0, 0)
    property bool ready: false
    readonly property Image currentImage: currentIndex === 0 ? first : second
    readonly property Image nextImage: currentIndex === 0 ? second : first

    function loadLatest(): void {
        if (!ready || transitioning || source.toString() === "")
            return;
        if (source.toString() === displayedSource.toString()) {
            // Cancela una carga pendiente si el usuario vuelve al fondo que ya ve.
            nextImage.source = "";
            return;
        }
        nextImage.source = source;
        if (nextImage.status === Image.Ready)
            imageReady(nextImage);
    }

    function imageReady(image: Image): void {
        if (image !== nextImage || transitioning || image.status !== Image.Ready
            || image.source.toString() !== source.toString())
            return;
        if (currentImage.status !== Image.Ready || reduceMotion || duration <= 0 || !visible) {
            finish();
            return;
        }
        center = Qt.point(
            (origin.x >= 0 && origin.x <= 1 ? origin.x : Math.random()) * width,
            (origin.y >= 0 && origin.y <= 1 ? origin.y : Math.random()) * height
        );
        progress = 0;
        reveal.start();
    }

    function finish(): void {
        currentIndex = 1 - currentIndex;
        progress = 0;
        // Si hubo más selecciones durante la animación, carga únicamente la última.
        Qt.callLater(root.loadLatest);
    }

    onSourceChanged: loadLatest()
    onReduceMotionChanged: {
        if (reduceMotion && transitioning) {
            reveal.stop();
            finish();
        }
    }
    Component.onCompleted: {
        ready = true;
        loadLatest();
    }

    Image {
        id: first
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.currentIndex === 0
        onStatusChanged: root.imageReady(first)
    }
    Image {
        id: second
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.currentIndex === 1
        onStatusChanged: root.imageReady(second)
    }

    Item {
        id: circleMask
        anchors.fill: parent
        visible: root.transitioning

        Rectangle {
            x: root.center.x - root.radius
            y: root.center.y - root.radius
            width: root.radius * 2
            height: width
            radius: width / 2
            color: "white"
            antialiasing: true
        }
    }

    ShaderEffectSource {
        id: maskTexture
        sourceItem: circleMask
        hideSource: true
        live: root.transitioning
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: root.nextImage
        maskEnabled: true
        maskSource: maskTexture
        autoPaddingEnabled: false
        visible: root.transitioning
    }

    NumberAnimation {
        id: reveal
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.duration
        easing.type: Easing.InOutCubic
        onFinished: root.finish()
    }
}
