-- Layout, gaps, borde (el borde sigue el acento del tema: $primary / $tertiary)
local v = require("lua.vars")

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(" .. v.primary .. "ee)", "rgba(" .. v.tertiary .. "ee)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
    dwindle = {
        preserve_split = true, -- pseudotile ya no existe: se usa el dispatcher 'pseudo' (Super+P)
    },
    master = {
        new_status = "master",
    },
})
