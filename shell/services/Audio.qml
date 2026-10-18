pragma Singleton
// Volumen y micrófono vía PipeWire. Reutilizable por cualquier diseño.
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0      // 0..1(+)
    readonly property bool muted: !!sink?.audio?.muted
    readonly property bool micMuted: !!source?.audio?.muted
    readonly property real micVolume: source?.audio?.volume ?? 0

    // Dispositivos de salida (para la página de Sound)
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !n.name.toLowerCase().includes("monitor"))
    // Quickshell marca algunos Stream/Output/Audio también como isSink; isStream
    // ya distingue los nodos de aplicación de los dispositivos físicos.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream && n.audio)
    readonly property var apps: {
        const groups = {};
        for (const node of root.streams) {
            const name = node.properties["application.name"] || node.description || node.name || "Application";
            if (!groups[name])
                groups[name] = [];
            groups[name].push(node);
        }
        return Object.keys(groups).sort().map(name => ({ name: name, nodes: groups[name] }));
    }

    function setDefaultSink(node): void {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node): void {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }
    function setNodeVolume(node, v: real): void {
        if (node?.ready && node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function appVolume(nodes): real {
        if (!nodes || nodes.length === 0)
            return 0;
        return nodes.reduce((sum, node) => sum + (node.audio?.volume ?? 0), 0) / nodes.length;
    }
    function setAppVolume(nodes, v: real): void {
        for (const node of nodes ?? [])
            setNodeVolume(node, v);
    }
    function appMuted(nodes): bool {
        return !!nodes && nodes.length > 0 && nodes.every(node => !!node.audio?.muted);
    }
    function toggleAppMute(nodes): void {
        const shouldMute = !appMuted(nodes);
        for (const node of nodes ?? []) {
            if (node.audio)
                node.audio.muted = shouldMute;
        }
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    function addVolume(d: real): void {
        setVolume(volume + d);
    }
    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function toggleMic(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Mantiene vivos los nodos para que emitan cambios de volumen/mute
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks, root.sources, root.streams).filter(n => n)
    }
}
