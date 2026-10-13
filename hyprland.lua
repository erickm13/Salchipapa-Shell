-- Salchipapa-Shell — config de Hyprland en formato Lua (Hyprland 0.55+).
-- Reemplaza a hyprland.conf (que se queda como respaldo). Hyprland usa el .lua si existe.
-- Probar:  Hyprland -c ~/proyects/Salchipapa-Shell/hyprland.lua
-- La API es `hl.*` (ver /usr/share/hypr/hyprland.lua y /usr/share/hypr/stubs/hl.meta.lua).

----------------------------------------------------------------------
-- Variables
----------------------------------------------------------------------
local mod = "SUPER"
local terminal = "kitty"
local menu = "fuzzel"
local browser = "firefox"
local fileManager = terminal .. " -e yazi"
local scripts = "~/proyects/Salchipapa-Shell/scripts"
local screenshot = scripts .. "/screenshot.sh"

----------------------------------------------------------------------
-- Colores del TEMA activo
-- Lee ~/.config/hypr/scheme/current.conf (lo escribe `caelestia scheme set`,
-- formato `$clave = hex`). En Lua no hay sustitución hyprlang, así que lo leemos
-- nosotros. Fallback a verde/teal si no existe. (Se relee en cada hyprctl reload.)
----------------------------------------------------------------------
local function read_scheme()
    local colors = {}
    local ok, f = pcall(io.open, (os.getenv("HOME") or "") .. "/.config/hypr/scheme/current.conf", "r")
    if ok and f then
        for line in f:lines() do
            local k, v = line:match("^%$([%w_]+)%s*=%s*(%x+)")
            if k and v then
                colors[k] = v
            end
        end
        f:close()
    end
    return colors
end

local scheme = read_scheme()
local primary = scheme.primary or "a6e3a1"
local tertiary = scheme.tertiary or "94e2d5"

----------------------------------------------------------------------
-- Monitores
----------------------------------------------------------------------
hl.monitor({ output = "eDP-2", mode = "1920x1200@165", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

----------------------------------------------------------------------
-- Variables de entorno
----------------------------------------------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- Platform theme: Qt (incl. Quickshell) usa el tema de iconos de qtengine (Papirus-Dark)
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

----------------------------------------------------------------------
-- Look & feel
----------------------------------------------------------------------
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        -- Borde con gradiente: sigue el acento del tema ($primary / $tertiary)
        col = {
            active_border = { colors = { "rgba(" .. primary .. "ee)", "rgba(" .. tertiary .. "ee)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
        },
        -- Sombra como "glow" del acento del tema
        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "rgba(" .. primary .. "55)",
            color_inactive = "rgba(0a0a0f99)",
        },
    },

    dwindle = {
        preserve_split = true, -- pseudotile ya no existe: se usa el dispatcher 'pseudo' (Super+P)
    },

    master = {
        new_status = "master",
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0, -- -1.0 a 1.0 (0 = sin aceleración)
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Gesto: 3 dedos = cambiar workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

----------------------------------------------------------------------
-- Animaciones — curvas Material 3 (la "fluidez")
----------------------------------------------------------------------
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("expressive", { type = "bezier", points = { { 0.38, 1.21 }, { 0.22, 1 } } })
hl.curve("specialWorkSwitch", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "expressive", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "specialWorkSwitch", style = "slidevert" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "standard" })

----------------------------------------------------------------------
-- Reglas de ventana / capas
----------------------------------------------------------------------
hl.window_rule({ match = { class = "pavucontrol|org\\.pulseaudio\\.pavucontrol" }, float = true })
hl.window_rule({ match = { class = "blueman-manager" }, float = true })
hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
hl.window_rule({ match = { title = "(Open|Save) (File|Folder).*" }, float = true })
hl.window_rule({ match = { title = "Save As" }, float = true })
hl.window_rule({ match = { float = true, xwayland = false }, center = true })
hl.window_rule({ match = { fullscreen = true }, no_shadow = true })

-- El areapicker (freeze) aparece desde el CENTRO con escala (popin), no deslizando
hl.layer_rule({ match = { namespace = "salchipapa-picker" }, animation = "popin 80%" })

----------------------------------------------------------------------
-- Keybinds
----------------------------------------------------------------------
-- Apps y shell
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + R", hl.dsp.global("salchipapa:launcher"))
hl.bind(mod .. " + T", hl.dsp.global("salchipapa:themes"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.exit())

-- Estado de ventana
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

-- Foco (flechas y vim)
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + semicolon", hl.dsp.focus({ direction = "down" }))

-- Mover ventana
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

-- Workspaces 1..10
for i = 1, 10 do
    local key = i % 10 -- 10 -> tecla 0
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll sobre el escritorio
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Ratón: mover/redimensionar
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Capturas (estilo caelestia)
hl.bind("Print", hl.dsp.exec_cmd(screenshot .. " screen"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.global("salchipapa:screenshot"))
hl.bind(mod .. " + SHIFT + ALT + S", hl.dsp.exec_cmd(screenshot .. " region"))

-- Volumen / micro
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

----------------------------------------------------------------------
-- Autostart
----------------------------------------------------------------------
-- Notificaciones: las gestiona la barra (Quickshell es el servidor). NO lanzar dunst.
-- Fondo de pantalla: aún sin herramienta (hyprpaper/swww) -> pendiente.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml")
end)
