-- Entrada: teclado, ratón, touchpad y gestos
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0, -- -1.0 a 1.0 (0 = sin aceleración)
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        },
    },
})

-- Gesto: deslizar 3 dedos = cambiar workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
