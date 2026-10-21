-- Monitores — nombre, resolución@refresco, posición, escala (lista: hyprctl monitors)
-- eDP-2 en "auto" y no en 0x0: con pantallas externas, al iniciar sesión o con `hyprctl reload`
-- se montaba encima de ellas (aviso "overlaps") hasta que monitor-autodetect aplica el perfil.
-- Sola, "auto" la deja en 0x0 igual.
hl.monitor({ output = "eDP-2", mode = "1920x1200@165", position = "auto", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" }) -- fallback
