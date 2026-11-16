pragma Singleton
// Aviso de descargas terminadas: los navegadores no lo mandan (Firefox solo lo muestra en su
// panel). Vigila la carpeta de descargas y junta los archivos nuevos (no los
// temporales .part de Firefox ni .crdownload de Chrome) que llegan con menos de 2 s entre sí; luego
// lanza scripts/download-done.sh con todos, que espera a que terminen de escribirse, descarta los
// de fecha vieja (lo que sale de un zip) y manda un solo aviso.
// No se mira cuánto vivió el temporal: Firefox baja algunas (iCloud, blobs) a memoria y las
// guarda de golpe, con un .part de décimas de segundo que a veces ni se llega a ver.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../common"

Singleton {
    id: root

    property string dir: ""
    // Archivos ya vistos. En la primera pasada solo se apuntan (no se avisa de lo que ya estaba al
    // arrancar la shell). Cuentan también los vacíos: Firefox crea el nombre final vacío al empezar,
    // y uno que se está escribiendo puede verse vacío; el script espera a que tengan contenido.
    property var known: ({})
    property bool scanned: false

    function isTemp(name: string): bool {
        return name.endsWith(".part") || name.endsWith(".crdownload");
    }

    function scan(): void {
        const seen = {};
        for (let i = 0; i < model.count; i++) {
            const name = model.get(i, "fileName");
            if (isTemp(name))
                continue;
            seen[name] = true;
            if (scanned && !known[name] && Config.notificationDownloads && !pending.includes(dir + "/" + name)) {
                pending.push(dir + "/" + name);
                batchTimer.restart();
            }
        }
        known = seen;
        scanned = true;
        let temps = 0;
        for (let i = 0; i < model.count; i++)
            if (isTemp(model.get(i, "fileName")))
                temps++;
        tempCount = temps;
        if (temps === 0)
            activeCount = 0;
    }

    // Descargas en curso, para el indicador de la isla. Un temporal puede quedarse huérfano si se
    // cancela la descarga, así que solo cuentan los que se han escrito en los últimos 20 s; eso no
    // cambia el listado de la carpeta, por lo que se consulta con find mientras haya temporales.
    property int tempCount: 0
    property int activeCount: 0
    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.tempCount > 0 && root.dir !== ""
        onTriggered: activeProc.running = true
    }
    Process {
        id: activeProc
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "(", "-name", "*.part", "-o", "-name", "*.crdownload", ")", "-newermt", "-20 seconds"]
        stdout: StdioCollector {
            onStreamFinished: root.activeCount = root.tempCount > 0 ? text.split("\n").filter(l => l !== "").length : 0
        }
    }

    property var pending: []
    Timer {
        id: batchTimer
        interval: 2000
        onTriggered: {
            Quickshell.execDetached([Quickshell.shellDir + "/../scripts/download-done.sh"].concat(root.pending));
            root.pending = [];
        }
    }

    FolderListModel {
        id: model
        folder: root.dir !== "" ? "file://" + root.dir : ""
        showDirs: false
        showHidden: true
        // Crear, borrar o renombrar (.part → final) cambia el número de archivos
        onCountChanged: scanTimer.restart()
        onStatusChanged: if (status === FolderListModel.Ready)
            scanTimer.restart()
    }
    Timer {
        id: scanTimer
        interval: 300
        onTriggered: root.scan()
    }

    Process {
        running: true
        command: ["xdg-user-dir", "DOWNLOAD"]
        stdout: StdioCollector {
            onStreamFinished: root.dir = text.trim() || Quickshell.env("HOME") + "/Downloads"
        }
    }
}
