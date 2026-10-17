-- Arranque automático
-- Notificaciones: las gestiona la barra (Quickshell es el servidor). NO lanzar dunst.
-- Fondo de pantalla: lo renderiza la shell (Background.qml) desde el estado; sin hyprpaper.
hl.on("hyprland.start", function()
    -- Autenticación (polkit) y llavero de secretos
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
    -- Historial de portapapeles (texto + imágenes) para cliphist
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Controles multimedia por bluetooth (MPRIS) y vaciar papelera de +30 días
    hl.exec_cmd("mpris-proxy")
    hl.exec_cmd("trash-empty 30")
    -- La shell (isla / barra / fondo)
    hl.exec_cmd("qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml")
end)
