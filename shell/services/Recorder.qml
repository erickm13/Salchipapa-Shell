pragma Singleton
// Estado de la grabación de pantalla (scripts/record.sh) para el indicador de la isla.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool recording: false
    property bool paused: false
    property real startEpoch: 0
    property int elapsed: 0 // segundos

    readonly property string elapsedText: {
        const h = Math.floor(elapsed / 3600), m = Math.floor(elapsed / 60) % 60, s = elapsed % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(s).padStart(2, "0");
    }

    function stop(): void {
        stopProc.exec([Quickshell.shellDir + "/../scripts/record.sh", "stop"]);
    }
    function togglePause(): void {
        pauseProc.exec([Quickshell.shellDir + "/../scripts/record.sh", "pause"]);
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/salchipapa-shell/recording"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let st = null;
            try {
                st = text().trim() ? JSON.parse(text()) : null;
            } catch (e) {}
            root.recording = st !== null && !!st.pid;
            root.paused = root.recording && !!st.paused;
            root.startEpoch = root.recording ? st.start : 0;
            root.elapsed = root.recording ? Math.max(0, Math.floor(Date.now() / 1000 - root.startEpoch)) : 0;
        }
        onLoadFailed: root.recording = false
    }

    // El contador se congela en pausa (y no cuenta el tiempo pausado al reanudar)
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: {
            if (root.paused)
                root.startEpoch += 1;
            root.elapsed = Math.max(0, Math.floor(Date.now() / 1000 - root.startEpoch));
        }
    }

    Process { id: stopProc }
    Process { id: pauseProc }
}
