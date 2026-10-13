-- Variables y colores compartidos entre los módulos de la config.
-- Se requiere con: local v = require("lua.vars")

-- Lee el esquema de color activo (lo escribe `caelestia scheme set`, formato `$clave = hex`).
-- En Lua no hay sustitución hyprlang, así que lo leemos nosotros. Fallback si no existe.
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
local scripts = "~/proyects/Salchipapa-Shell/scripts"

return {
    -- Programas
    mod = "SUPER",
    terminal = "kitty",
    menu = "fuzzel",
    browser = "firefox",
    fileManager = "kitty -e yazi",
    -- Scripts
    scripts = scripts,
    screenshot = scripts .. "/screenshot.sh",
    scratch = scripts .. "/scratch.sh",
    -- Colores del tema (hex sin #)
    primary = scheme.primary or "a6e3a1",
    tertiary = scheme.tertiary or "94e2d5",
}
