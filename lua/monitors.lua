-- Monitores — nombre, resolución@refresco, posición, escala (lista: hyprctl monitors)
hl.monitor({ output = "eDP-2", mode = "1920x1200@165", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" }) -- fallback
