-- Grupos de ventanas (pestañas): borde y groupbar siguen el acento del tema. Portado de caelestia.
local v = require("lua.vars")
local inactive = "rgba(" .. v.onSurfaceVariant .. "11)"

hl.config({
	group = {
		col = {
			border_active = { colors = { "rgba(" .. v.primary .. "ee)", "rgba(" .. v.tertiary .. "ee)" }, angle = 45 },
			border_inactive = inactive,
			border_locked_active = "rgba(" .. v.primary .. "ee)",
			border_locked_inactive = inactive,
		},
		groupbar = {
			font_family = "JetBrains Mono NF",
			font_size = 15,
			gradients = true,
			gradient_round_only_edges = false,
			gradient_rounding = 5,
			height = 25,
			indicator_height = 0,
			gaps_in = 3,
			gaps_out = 3,
			text_color = "rgb(" .. v.onPrimary .. ")",
			col = {
				active = "rgba(" .. v.primary .. "d4)",
				inactive = "rgba(" .. v.outlineVariant .. "d4)",
				locked_active = "rgba(" .. v.primary .. "d4)",
				locked_inactive = "rgba(" .. v.secondary .. "d4)",
			},
		},
	},
})
