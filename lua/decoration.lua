-- Decoración: redondeo, blur y sombra oscura según el rol shadow del tema.
local v = require("lua.vars")

hl.config({
	decoration = {
		rounding = 10,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		blur = {
			enabled = true,
			special = true,
			size = 5,
			passes = 2,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
		},
		shadow = {
			enabled = true,
			range = 24,
			render_power = 3,
			color = "rgba(" .. v.shadow .. "ee)",
			color_inactive = "rgba(" .. v.shadow .. "ee)",
		},
	},
})
