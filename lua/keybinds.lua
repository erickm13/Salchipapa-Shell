-- Atajos de teclado
local v = require("lua.vars")
local mod = v.mod

-- Apps y shell
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(v.terminal))
hl.bind(mod .. " + R", hl.dsp.global("salchipapa:launcher"))
hl.bind(mod .. " + T", hl.dsp.global("salchipapa:themes"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(v.browser))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(v.fileManager))
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

-- Scratchpad propio (magic)
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Apps en scratchpad (como caelestia): lanzan la app si no está, o alternan su special
hl.bind(mod .. " + M", hl.dsp.exec_cmd(v.scratch .. " music 'Spotify|spotify' spotify"))           -- música (Spotify)
hl.bind(mod .. " + D", hl.dsp.exec_cmd(v.scratch .. " comms 'vesktop|discord' vesktop"))           -- comunicación (vesktop)
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(v.scratch .. " sysmon btop 'kitty --class btop -e btop'")) -- monitor (btop)

-- Apps y utilidades
hl.bind(mod .. " + C", hl.dsp.exec_cmd("code"))                  -- editor (VS Code)
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a")) -- selector de color
hl.bind(mod .. " + BackSpace", hl.dsp.exec_cmd("loginctl lock-session")) -- bloquear
hl.bind(mod .. " + W", hl.dsp.global("salchipapa:wallpaper")) -- selector de fondos (en la isla)

-- Scroll sobre el escritorio
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Ratón: mover/redimensionar
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Capturas (estilo caelestia)
hl.bind("Print", hl.dsp.exec_cmd(v.screenshot .. " screen"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.global("salchipapa:screenshot"))
hl.bind(mod .. " + SHIFT + ALT + S", hl.dsp.exec_cmd(v.screenshot .. " region"))

-- Volumen / micro
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
