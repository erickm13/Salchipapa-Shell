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
        objects: [root.sink, root.source].filter(n => n)
    }
}
