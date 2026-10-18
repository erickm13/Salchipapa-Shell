pragma Singleton
// Reproductor multimedia activo vía MPRIS.
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    // El que esté reproduciendo; si ninguno, el primero disponible
    readonly property MprisPlayer active: {
        const playing = players.find(p => p.isPlaying);
        return playing ?? players[0] ?? null;
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    // Algunos reproductores publican la letra como metadato MPRIS opcional.
    readonly property string lyrics: {
        const metadata = active?.metadata ?? ({});
        return metadata["xesam:asText"] ?? metadata["lyrics"] ?? "";
    }

    function toggle(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next(): void {
        if (active?.canGoNext)
            active.next();
    }
    function prev(): void {
        if (active?.canGoPrevious)
            active.previous();
    }
}
