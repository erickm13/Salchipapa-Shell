-- Variables y colores compartidos entre los módulos de la config.
-- Se requiere con: local v = require("lua.vars")

-- Lee el esquema de color activo (lo escribe `caelestia scheme set`, formato `$clave = hex`).
-- En Lua no hay sustitución hyprlang, así que lo leemos nosotros. Fallback si no existe.
local function read_scheme()
	local colors = {}
	local ok, f = pcall(io.open, (os.getenv("HOME") or "") .. "/.local/state/salchipapa-shell/colors.conf", "r")
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
-- Carpeta del repo (padre de lua/), esté donde esté clonado o enlazado
local repo
pcall(function()
	repo = debug.getinfo(1, "S").source:match("^@(.*)/lua/[^/]*$")
end)
repo = repo or ((os.getenv("HOME") or "") .. "/.config/hypr")
local scripts = repo .. "/scripts"

return {
	-- Programas
	mod = "SUPER",
	terminal = "foot",
	menu = "fuzzel",
	browser = "firefox",
	fileManager = "kitty -e yazi",
	-- Scripts
	repo = repo,
	scripts = scripts,
	screenshot = scripts .. "/screenshot.sh",
	scratch = scripts .. "/scratch.sh",
	-- Colores del tema (hex sin #)
	primary = scheme.primary or "a6e3a1",
	shadow = scheme.shadow or "000000",
	tertiary = scheme.tertiary or "94e2d5",
	secondary = scheme.secondary or "f9e2af",
	onPrimary = scheme.onPrimary or "11111b",
	onSurfaceVariant = scheme.onSurfaceVariant or "bac2de",
	outline = scheme.outline or "6c7086",
	outlineVariant = scheme.outlineVariant or "45475a",
	surfaceContainer = scheme.surfaceContainer or "1e1e2e",
}
