-- Variables de entorno (Wayland)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- Platform theme KDE (plasma-integration): las apps Qt/KF6 (Dolphin…) leen colores de
-- kdeglobals y se SUSCRIBEN a las señales de KDE -> recarga de colores/iconos EN VIVO.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
