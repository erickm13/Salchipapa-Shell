pragma Singleton
// Letra de la canción activa para el panel de música (Super+A), desde LRCLIB vía
// scripts/lyrics.sh (con caché en disco). Si es sincronizada, `lines` trae [{ time (s), text }]
// e indexAt(posición) dice qué línea toca; si no, solo `plain`.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var lines: []
    property string plain: ""
    property bool instrumental: false
    property bool loading: false
    property string key: "" // artista + título de la letra cargada (o pedida)
    readonly property bool synced: lines.length > 0

    function load(artist: string, title: string, album: string, length: real): void {
        const k = artist + "\n" + title;
        if (title === "" || k === key)
            return;
        key = k;
        lines = [];
        plain = "";
        instrumental = false;
        loading = true;
        proc.exec([Quickshell.shellDir + "/../scripts/lyrics.sh", artist, title, album, String(Math.round(length))]);
    }

    // Última línea cuyo tiempo ya pasó (-1 antes de la primera)
    function indexAt(position: real): int {
        let lo = 0, hi = lines.length - 1, found = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].time <= position) {
                found = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return found;
    }

    // LRC: cada línea puede llevar varias marcas [mm:ss.xx]; se ignoran las de metadatos ([ar:…])
    function parseLrc(lrc: string): var {
        const out = [];
        // (el motor de QML no tiene String.matchAll: se recorren las marcas con exec)
        const tag = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of lrc.split("\n")) {
            const times = [];
            let m;
            tag.lastIndex = 0;
            while ((m = tag.exec(raw)) !== null)
                times.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            if (times.length === 0)
                continue;
            const text = raw.replace(/\[\d+:\d+(?:\.\d+)?\]/g, "").trim();
            for (const t of times)
                out.push({ time: t, text: text });
        }
        return out.sort((a, b) => a.time - b.time);
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                root.loading = false;
                let data = {};
                try {
                    data = JSON.parse(out.text || "{}");
                } catch (e) {}
                root.instrumental = !!data.instrumental;
                root.lines = data.synced ? root.parseLrc(data.synced) : [];
                root.plain = data.plain ?? "";
                // Sin letra (o servidor saturado): se reintenta la próxima vez que se pida
                if (!root.synced && root.plain === "" && !root.instrumental)
                    root.key = "";
            }
        }
    }
}
