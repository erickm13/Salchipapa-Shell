-- Arranque automático
local v = require("lua.vars")
-- Notificaciones: las gestiona la barra (Quickshell es el servidor). NO lanzar dunst.
-- Fondo de pantalla: lo renderiza la shell (Background.qml) desde el estado; sin hyprpaper.
hl.on("hyprland.start", function()
    -- Llavero de secretos; PolicyKit lo gestiona la propia Salchipapa Shell.
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
    -- Historial de portapapeles (texto + imágenes) para cliphist
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Controles multimedia por bluetooth (MPRIS) y vaciar papelera de +30 días
    hl.exec_cmd("mpris-proxy")
    hl.exec_cmd("trash-empty 30")
    -- Tras install.sh: aplica el fondo y el tema guardados (solo la primera vez)
    hl.exec_cmd(v.scripts .. "/first-run.sh")
    -- Perfiles de monitor al conectar/desconectar pantallas (display-profiles.json)
    hl.exec_cmd(v.scripts .. "/monitor-autodetect")
    -- La shell (isla / barra / fondo)
    hl.exec_cmd("qs -p " .. v.repo .. "/shell/shell.qml")
end)
