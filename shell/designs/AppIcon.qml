// Icono de una app (el campo Icon= de su .desktop). Primero el del tema por Qt; si Qt no lo
// encuentra, el archivo directamente en las carpetas de iconos.
// Por qué: Qt (con qtengine + Papirus) no resuelve algunos iconos que sí existen
// (system-file-manager de Nemo, preferences-system-network…), y recuerda como "no existe" lo que
// buscó antes de que una app se instalara. La búsqueda por archivo no tiene esos problemas.
import QtQuick
import Quickshell

Item {
    id: root

    property string icon: ""
    property int size: 30

    implicitWidth: size
    implicitHeight: size

    readonly property string home: Quickshell.env("HOME")
    readonly property var candidates: {
        if (icon === "")
            return [];
        if (icon.startsWith("/"))
            return ["file://" + icon];
        const themed = Quickshell.iconPath(icon, true);
        const list = themed !== "" ? [themed] : [];
        const dirs = [
            "/usr/share/icons/Papirus-Dark/64x64/apps", "/usr/share/icons/Papirus-Dark/48x48/apps",
            home + "/.local/share/icons/hicolor/scalable/apps", home + "/.local/share/icons/hicolor/256x256/apps",
            "/usr/share/icons/hicolor/scalable/apps", "/usr/share/icons/hicolor/256x256/apps",
            "/usr/share/icons/hicolor/128x128/apps", "/usr/share/icons/hicolor/64x64/apps",
            "/usr/share/icons/hicolor/48x48/apps"
        ];
        for (const d of dirs)
            for (const ext of ["svg", "png"])
                list.push("file://" + d + "/" + icon + "." + ext);
        for (const ext of ["png", "svg", "xpm"])
            list.push("file:///usr/share/pixmaps/" + icon + "." + ext);
        return list;
    }
    property int index: 0
    onCandidatesChanged: index = 0

    Image {
        anchors.fill: parent
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        source: root.index < root.candidates.length ? root.candidates[root.index] : Quickshell.iconPath("application-x-executable", "image-missing")
        // Si un candidato no existe, probar el siguiente
        onStatusChanged: if (status === Image.Error && root.index < root.candidates.length)
            root.index++
    }
}
