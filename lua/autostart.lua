-- Arranque automático
-- Notificaciones: las gestiona la barra (Quickshell es el servidor). NO lanzar dunst.
-- Fondo de pantalla: aún sin herramienta (hyprpaper/swww) -> pendiente.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml")
end)
