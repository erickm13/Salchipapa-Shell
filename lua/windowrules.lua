-- Reglas de ventana y de capas
-- Flotar apps/diálogos comunes
hl.window_rule({ match = { title = "^Salchipapa Settings$" }, float = true, center = true, border_size = 0 })
hl.window_rule({ match = { class = "pavucontrol|org\\.pulseaudio\\.pavucontrol" }, float = true })
hl.window_rule({ match = { class = "blueman-manager" }, float = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
hl.window_rule({ match = { title = "(Open|Save) (File|Folder).*" }, float = true })
hl.window_rule({ match = { title = "Save As" }, float = true })
hl.window_rule({ match = { float = true, xwayland = false }, center = true })
hl.window_rule({ match = { fullscreen = true }, no_shadow = true })
-- Cualquier app a pantalla completa (Stremio, mpv, juegos…) frena el bloqueo por inactividad,
-- aunque no pida idle-inhibit por su cuenta.
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- El picker no anima al cerrarse: grim debe capturar la ventana sin el freeze superpuesto.
hl.layer_rule({ match = { namespace = "salchipapa-picker" }, no_anim = true })

-- Apps en workspaces especiales (scratchpads, como caelestia)
hl.window_rule({ match = { class = "Spotify|spotify" }, workspace = "special:music" })
hl.window_rule({ match = { initial_title = "Spotify( Free)?" }, workspace = "special:music" }) -- Spotify Wayland no tiene class
hl.window_rule({ match = { class = "vesktop|discord|legcord|equibop|WebCord" }, workspace = "special:comms" })
hl.window_rule({ match = { class = "btop" }, workspace = "special:sysmon" })

-- Juegos: a su propio workspace (Super+G), con tearing y sin blur ni sombra.
-- steam_app_N = cualquier juego de Steam (el cliente de Steam no se mueve); content = "game" =
-- los que se anuncian como juego por el protocolo content-type.
-- WoW (Forever, Retail, Classic) corre con umu-run: su clase es steam_app_default, igual que Battle.net,
-- así que se reconoce por el título (Battle.net se queda donde esté).
local games = "steam_app_\\d+|gamescope|[Mm]inecraft.*"
-- En qué monitor vive el workspace de juegos lo decide la shell (services/GamesWorkspace.qml):
-- el principal de Ajustes > Display > Primary monitor, que existe en cualquier equipo.
for _, m in ipairs({ { class = games }, { content = "game" }, { class = "steam_app_default", initial_title = "World of Warcraft" } }) do
	hl.window_rule({ match = m, workspace = "name:games", immediate = true, no_blur = true, no_shadow = true })
end
