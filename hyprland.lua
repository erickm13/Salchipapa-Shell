-- Salchipapa-Shell — entrada de la config de Hyprland (Lua, Hyprland 0.55+).
-- La configuración está dividida en módulos dentro de lua/. Este archivo solo los importa.
-- Probar:  Hyprland -c ~/proyects/Salchipapa-Shell/hyprland.lua
-- API `hl.*` (ver /usr/share/hypr/hyprland.lua y /usr/share/hypr/stubs/hl.meta.lua).

-- Asegura que `require` encuentre los módulos de lua/ (añade la carpeta de este
-- archivo a package.path; funciona esté donde esté el repo o el symlink).
pcall(function()
    local dir = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")
    if dir then
        package.path = package.path .. ";" .. dir .. "/?.lua"
    end
end)

require("lua.monitors")
require("lua.env")
require("lua.general")
require("lua.decoration")
require("lua.animations")
require("lua.input")
require("lua.windowrules")
require("lua.keybinds")
require("lua.autostart")
