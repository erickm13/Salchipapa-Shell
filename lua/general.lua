-- Layout y espacios de ventanas.

hl.config({
	general = {
		gaps_in = 5,
		-- Menos espacio arriba para acercar las ventanas a la Dynamic Island.
		-- Arriba también 10: en los monitores sin isla las ventanas no quedan pegadas al borde.
		-- La isla reserva 10 px menos (DynamicIsland.qml) para que bajo ella quede igual.
		gaps_out = { top = 10, right = 10, bottom = 10, left = 10 },
		border_size = 2,
		col = {
			active_border = "rgba(00000000)",
			inactive_border = "rgba(00000000)",
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
