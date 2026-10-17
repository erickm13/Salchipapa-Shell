-- Decoración: redondeo, blur y sombra (la sombra = "glow" del acento del tema)
local v = require("lua.vars")

hl.config({
	decoration = {
		rounding = 10,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		blur = {
			enabled = true,
			size = 3,
			passes = 2,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
		},
		shadow = {
			enabled = true,
			range = 10,
			render_power = 4,
			color = "rgba(" .. v.primary .. "55)",
			color_inactive = "rgba(0a0a0f99)",
		},
	},
})
