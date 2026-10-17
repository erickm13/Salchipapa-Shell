-- Varios ajustes (misc): VRR, sin logo, foco, DPMS, color de fondo. Portado de caelestia.
local v = require("lua.vars")

hl.config({
	debug = {
		error_position = 1,
	},
	misc = {
		vrr = 1, -- refresco variable donde el monitor lo soporte
		disable_hyprland_logo = true, -- sin logo en workspace vacío
		force_default_wallpaper = 0,
		focus_on_activate = true, -- enfocar la ventana que pide atención
		on_focus_under_fullscreen = 2, -- al abrir bajo una ventana en fullscreen, cerrar el fullscreen
		animate_manual_resizes = false,
		animate_mouse_windowdragging = false,
		middle_click_paste = false,
		allow_session_lock_restore = true,
		session_lock_xray = true,
		mouse_move_enables_dpms = true, -- despertar la pantalla al mover el ratón
		key_press_enables_dpms = true,
		background_color = "rgb(" .. v.surfaceContainer .. ")",
	},
})
