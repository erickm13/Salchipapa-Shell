pragma Singleton
// Reproductor multimedia activo vía MPRIS.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players.values
    // El elegido en el panel de música (mientras exista); si no, el que esté reproduciendo y, si
    // ninguno, el primero disponible
    property string preferred: "" // dbusName
    readonly property MprisPlayer active: {
        const chosen = preferred !== "" ? players.find(p => p.dbusName === preferred) : undefined;
        const playing = players.find(p => p.isPlaying);
        return chosen ?? playing ?? players[0] ?? null;
    }
    function select(player: MprisPlayer): void {
        preferred = player?.dbusName ?? "";
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

    // Portada como archivo local: el cliente HTTP de Qt a veces se atasca ("sendRequest() called
    // without QHttpNetworkReply") y desde entonces ninguna portada de internet carga hasta
    // reiniciar la shell. Se descarga con curl a ~/.cache/salchipapa-shell/art/ (las de más de
    // 30 días se borran) y las tarjetas usan artPath.
    readonly property string artUrl: active?.trackArtUrl ?? ""
    property string artPath: ""
    onArtUrlChanged: fetchArt()
    Component.onCompleted: fetchArt()
    function fetchArt(): void {
        if (artUrl === "") {
            artPath = siteIcon; // sin portada: el icono del sitio, si es uno conocido
            return;
        }
        if (!artUrl.startsWith("http")) {
            artPath = artUrl; // ya local (file://)
            return;
        }
        artPath = "";
        artProc.exec(["sh", "-c", 'd="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/art"; mkdir -p "$d"; f="$d/$(printf %s "$1" | sha1sum | cut -c1-40)"; if [ ! -s "$f" ]; then curl -sfL --max-time 15 -o "$f.tmp" "$1" && mv -f "$f.tmp" "$f"; rm -f "$f.tmp"; fi; find "$d" -type f -mtime +30 -delete 2>/dev/null; [ -s "$f" ] && echo "$f"', "_", artUrl]);
    }
    // Webs que no mandan portada al navegador (Netflix solo manda el título "Netflix"): su icono de
    // Papirus según el dominio de la URL que reproduce
    readonly property string trackUrl: active?.metadata?.["xesam:url"] ?? ""
    readonly property var siteIcons: ({
        "netflix.com": "netflix",
        "primevideo.com": "amazon", // Papirus no trae el de Prime Video
        "amazon.com": "amazon",
        "music.youtube.com": "solstice-google-youtube-music",
        "youtube.com": "youtube",
        "youtu.be": "youtube",
        "crunchyroll.com": "crunchyroll",
        "twitch.tv": "gnome-twitch",
        "open.spotify.com": "spotify",
        "soundcloud.com": "soundcloud",
        "deezer.com": "deezer",
        "tidal.com": "tidal"
    })
    readonly property string siteIcon: {
        const host = (trackUrl.match(/^https?:\/\/([^\/?#]+)/)?.[1] ?? "").replace(/^www\./, "");
        for (const domain in siteIcons)
            if (host === domain || host.endsWith("." + domain))
                return "file:///usr/share/icons/Papirus-Dark/64x64/apps/" + siteIcons[domain] + ".svg";
        return "";
    }
    onSiteIconChanged: if (artUrl === "")
        artPath = siteIcon

    Process {
        id: artProc
        stdout: StdioCollector {
            id: artOut
            onStreamFinished: {
                const path = artOut.text.trim();
                if (path !== "")
                    root.artPath = "file://" + path;
            }
        }
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
    function stop(): void {
        if (active?.canControl)
            active.stop();
    }

    // Teclas multimedia (XF86Audio*, Ctrl+Super+Space/=/-): sin playerctl, directo por MPRIS
    GlobalShortcut {
        appid: "salchipapa"
        name: "mediaToggle"
        description: "Reproducir/pausar"
        onPressed: root.toggle()
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "mediaNext"
        description: "Siguiente pista"
        onPressed: root.next()
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "mediaPrev"
        description: "Pista anterior"
        onPressed: root.prev()
    }
    GlobalShortcut {
        appid: "salchipapa"
        name: "mediaStop"
        description: "Detener la reproducción"
        onPressed: root.stop()
    }
}
