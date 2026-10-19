-- Atajos de teclado
local v = require("lua.vars")
local mod = v.mod

-- Caelestia organiza los workspaces en grupos de diez y conserva la posición
-- al cambiar de grupo (p. ej. 21 → 31). Reproducimos esa lógica sin wsaction.fish.
local function activeWorkspaceId()
	local workspace = hl.get_active_workspace()
	local id = workspace and workspace.id
	return id and id > 0 and id or 1
end

local function bindWorkspaceGroup(key, index, action)
	hl.bind(key, function()
		local id = activeWorkspaceId()
		local slot = (id - 1) % 10 + 1
		local target
		if action == "switch-group" or action == "move-group" then
			target = (index - 1) * 10 + slot
		else
			target = math.floor((id - 1) / 10) * 10 + index
		end

		if action == "move-current-group" or action == "move-group" then
			hl.dispatch(hl.dsp.window.move({ workspace = target }))
		else
			hl.dispatch(hl.dsp.focus({ workspace = target }))
		end
	end)
end

-- Apps y shell
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(v.terminal))
hl.bind(mod .. " + Space", hl.dsp.global("salchipapa:launcher"))
hl.bind(mod .. " + T", hl.dsp.global("salchipapa:themes"))
hl.bind(mod .. " + N", hl.dsp.global("salchipapa:control")) -- centro de control (en la isla)
hl.bind(mod .. " + ALT + P", hl.dsp.global("salchipapa:power")) -- menú de energía (en la isla)
hl.bind(mod .. " + I", hl.dsp.global("salchipapa:settings")) -- panel de ajustes
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
hl.bind(mod .. " + SHIFT + h", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + l", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + k", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + j", hl.dsp.window.move({ direction = "d" }))

-- Workspaces 1..10 (Super+Shift+numero mueve a ese ID exacto)
for i = 1, 10 do
	local key = i % 10 -- 10 -> tecla 0
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
	-- Super+Alt+numero: mover al número dentro del grupo actual de diez.
	bindWorkspaceGroup(mod .. " + ALT + " .. key, i, "move-current-group")
	-- Ctrl+Super+numero: cambiar de grupo manteniendo el índice final.
	bindWorkspaceGroup("CTRL + " .. mod .. " + " .. key, i, "switch-group")
	-- Ctrl+Super+Alt+numero: mover la ventana al grupo indicado, mismo índice final.
	bindWorkspaceGroup("CTRL + " .. mod .. " + ALT + " .. key, i, "move-group")
end

-- Workspaces anterior/siguiente y salto entre grupos de diez
hl.bind("CTRL + " .. mod .. " + left", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + right", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind(mod .. " + Page_Up", hl.dsp.focus({ workspace = "-1" }), { repeating = true })
hl.bind(mod .. " + Page_Down", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + " .. mod .. " + mouse_up", hl.dsp.focus({ workspace = "+10" }))

-- Mover ventana al workspace anterior/siguiente
hl.bind(mod .. " + ALT + Page_Up", hl.dsp.window.move({ workspace = "-1" }), { repeating = true })
hl.bind(mod .. " + ALT + Page_Down", hl.dsp.window.move({ workspace = "+1" }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + SHIFT + h", hl.dsp.window.move({ workspace = "-1" }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + SHIFT + l", hl.dsp.window.move({ workspace = "+1" }), { repeating = true })
hl.bind(mod .. " + ALT + mouse_down", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mod .. " + ALT + mouse_up", hl.dsp.window.move({ workspace = "+1" }))

-- Mover la ventana al scratchpad y devolverla al workspace visible
hl.bind("CTRL + " .. mod .. " + SHIFT + k", hl.dsp.window.move({ workspace = "special:agents" }))
hl.bind("CTRL + " .. mod .. " + SHIFT + j", hl.dsp.window.move({ workspace = "e+0" }))

-- Scratchpad propio para agentes
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("agents"))
hl.bind(mod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:agents" }))

-- Grupos de ventanas (pestañas)
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { repeating = true })
hl.bind("SHIFT + ALT + Tab", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind("CTRL + ALT + Tab", hl.dsp.group.next(), { repeating = true })
hl.bind("CTRL + SHIFT + ALT + Tab", hl.dsp.group.prev(), { repeating = true })
hl.bind(mod .. " + Comma", hl.dsp.group.toggle())
hl.bind(mod .. " + SHIFT + Comma", hl.dsp.group.lock({ action = "toggle" }))
hl.bind(mod .. " + U", hl.dsp.window.move({ out_of_group = true }))

-- Mover foco/ventana entre monitores
hl.bind("CTRL + " .. mod .. " + h", hl.dsp.focus({ monitor = "l" }))
hl.bind("CTRL + " .. mod .. " + l", hl.dsp.focus({ monitor = "r" }))
hl.bind("CTRL + ALT + " .. mod .. " + h", hl.dsp.window.move({ monitor = "l" }))
hl.bind("CTRL + ALT + " .. mod .. " + l", hl.dsp.window.move({ monitor = "r" }))

-- Redimensionar y centrar ventanas
hl.bind(mod .. " + MINUS", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + EQUAL", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + MINUS", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + EQUAL", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
hl.bind(mod .. " + ALT + j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
hl.bind("CTRL + " .. mod .. " + BACKSLASH", hl.dsp.window.center())

-- Arrastre/redimensionado del ratón también con teclas, como en Caelestia
hl.bind(mod .. " + z", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + x", hl.dsp.window.resize(), { mouse = true })

-- Apps en scratchpad (como caelestia): lanzan la app si no está, o alternan su special
hl.bind(mod .. " + M", hl.dsp.exec_cmd(v.scratch .. " music 'Spotify|spotify' spotify")) -- música (Spotify)
hl.bind(mod .. " + D", hl.dsp.exec_cmd(v.scratch .. " comms 'vesktop|discord' vesktop")) -- comunicación (vesktop)
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(v.scratch .. " sysmon btop 'foot --class btop -e btop'")) -- monitor (btop)

-- Apps y utilidades
hl.bind(mod .. " + C", hl.dsp.exec_cmd("code")) -- editor (VS Code)
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a")) -- selector de color
hl.bind(mod .. " + BackSpace", hl.dsp.exec_cmd(v.scripts .. "/lock-screen.sh")) -- bloquear
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
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
-- Grabar pantalla (scripts/record.sh): la misma tecla para; la isla muestra el tiempo
hl.bind(mod .. " + ALT + R", hl.dsp.exec_cmd(v.scripts .. "/record.sh screen sound")) -- monitor + sonido
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd(v.scripts .. "/record.sh screen nosound")) -- monitor, sin sonido
hl.bind(mod .. " + SHIFT + ALT + R", hl.dsp.exec_cmd(v.scripts .. "/record.sh region sound")) -- región + sonido
hl.bind(mod .. " + SHIFT + ALT + P", hl.dsp.exec_cmd(v.scripts .. "/record.sh pause")) -- pausar/reanudar

-- Tecla del touchpad (keycode 199 = XF86TouchpadToggle): la shell lo activa/desactiva y guarda el estado
hl.bind("XF86TouchpadToggle", hl.dsp.global("salchipapa:touchpad"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Brillo
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
