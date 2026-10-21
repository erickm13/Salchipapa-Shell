// La foto de perfil (~/.face) con su encuadre: cubre el área (como PreserveAspectCrop) ampliada
// `zoom` veces, con el punto (cx, cy) de la foto (0..1) en el centro y sin dejar huecos (se ajusta
// a los bordes). Lo usan la pantalla de bloqueo, la miniatura de Ajustes y el editor de encuadre,
// así los tres muestran lo mismo. No recorta: va dentro de un ClippingRectangle o como fillItem.
import QtQuick
import Quickshell

Item {
    id: fp
    property real zoom: Config.lockAvatarZoom
    property real cx: Config.lockAvatarCropX
    property real cy: Config.lockAvatarCropY

    readonly property real natW: img.implicitWidth
    readonly property real natH: img.implicitHeight
    readonly property real scaleFactor: natW > 0 && natH > 0 ? Math.max(width / natW, height / natH) * zoom : 1
    // Geometría de la foto dentro del área (el editor la usa para dibujar el resto atenuado)
    readonly property real photoW: natW * scaleFactor
    readonly property real photoH: natH * scaleFactor
    readonly property real photoX: Math.max(width - photoW, Math.min(0, width / 2 - cx * photoW))
    readonly property real photoY: Math.max(height - photoH, Math.min(0, height / 2 - cy * photoH))
    readonly property bool ready: img.status === Image.Ready

    Image {
        id: img
        x: fp.photoX
        y: fp.photoY
        width: fp.photoW
        height: fp.photoH
        source: "file://" + Quickshell.env("HOME") + "/.face?v=" + Overlay.faceVersion
        cache: false
        // Suficiente para el zoom máximo en la pantalla de bloqueo; las fotos más pequeñas no se amplían
        sourceSize.width: 1600
        mipmap: true
        asynchronous: true
    }
}
