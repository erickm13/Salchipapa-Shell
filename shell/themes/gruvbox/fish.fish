# Resaltado de fish con gruvbox, como gruvbox.nvim: comandos = Function (verde negrita), palabras
# clave = rojo, argumentos y opciones = @variable.parameter (azul), cadenas = verde, símbolos y $ =
# naranja, comentarios = gris cursiva, selección = Visual (bg3), menú = Pmenu/PmenuSel.
# apply-colors.sh lo copia a ~/.local/state/salchipapa-shell/fish-colors.fish (lo carga config.fish).
set -g fish_color_normal ebdbb2
set -g fish_color_command b8bb26 --bold
set -g fish_color_keyword fb4934
set -g fish_color_param 83a598
set -g fish_color_option 83a598
set -g fish_color_quote b8bb26
set -g fish_color_redirection fe8019
set -g fish_color_end fe8019
set -g fish_color_operator fe8019
set -g fish_color_escape fe8019
set -g fish_color_error fb4934
set -g fish_color_comment 928374 --italics
set -g fish_color_autosuggestion 7c6f64
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=665c54
set -g fish_color_search_match fabd2f --background=504945
set -g fish_color_history_current --bold
set -g fish_color_cancel -r
set -g fish_pager_color_prefix fabd2f --bold
set -g fish_pager_color_completion ebdbb2
set -g fish_pager_color_description 928374 --italics
set -g fish_pager_color_progress 928374
set -g fish_pager_color_selected_background --background=83a598
set -g fish_pager_color_selected_completion 504945 --bold
set -g fish_pager_color_selected_prefix 504945 --bold
set -g fish_pager_color_selected_description 504945
