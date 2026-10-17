-- Reglas de ventana y de capas
-- Flotar apps/diálogos comunes
hl.window_rule({ match = { class = "pavucontrol|org\\.pulseaudio\\.pavucontrol" }, float = true })
hl.window_rule({ match = { class = "blueman-manager" }, float = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
hl.window_rule({ match = { title = "(Open|Save) (File|Folder).*" }, float = true })
hl.window_rule({ match = { title = "Save As" }, float = true })
hl.window_rule({ match = { float = true, xwayland = false }, center = true })
hl.window_rule({ match = { fullscreen = true }, no_shadow = true })

-- El picker no anima al cerrarse: grim debe capturar la ventana sin el freeze superpuesto.
hl.layer_rule({ match = { namespace = "salchipapa-picker" }, no_anim = true })

-- Apps en workspaces especiales (scratchpads, como caelestia)
hl.window_rule({ match = { class = "Spotify|spotify" }, workspace = "special:music" })
hl.window_rule({ match = { initial_title = "Spotify( Free)?" }, workspace = "special:music" }) -- Spotify Wayland no tiene class
hl.window_rule({ match = { class = "vesktop|discord|legcord|equibop|WebCord" }, workspace = "special:comms" })
hl.window_rule({ match = { class = "btop" }, workspace = "special:sysmon" })
