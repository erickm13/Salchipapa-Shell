# Temas

- `schemes.json`: la paleta de cada tema (roles de la shell y `term0`–`term15` de la terminal).
  Los que vienen de una paleta oficial los genera `scripts/build-schemes.py`.
- `<tema>/`: los temas **hechos a mano**, con un archivo por app. `scripts/apply-colors.sh scheme <tema>`
  aplica los que haya; una app sin su archivo usa su estilo por defecto (nombres ANSI: la paleta de
  la terminal). La referencia para repartir los colores es el colorscheme de nvim de ese tema.
- `bat/`: temas y sintaxis de bat generados por `scripts/build-bat-theme.py` (originales en `bat/upstream/`).

## Archivos de un tema

| Archivo | App | Dónde acaba | Cambia en vivo |
|---|---|---|---|
| `nvim` | nombre del colorscheme de nvim | `~/.local/state/salchipapa-shell/nvim-colorscheme` (lo lee `colorscheme.lua` de los dotfiles) | sí: los nvim abiertos lo cambian por su socket |
| `yazi.toml` | yazi | `~/.config/yazi/theme.toml` | no: al reabrir yazi |
| `fish.fish` | resaltado de fish (`set -g fish_color_*`) | `~/.local/state/salchipapa-shell/fish-colors.fish` | sí |
| `fzf` | opciones `--color` de fzf | `~/.local/state/salchipapa-shell/fzf-colors` | sí (al abrir fzf) |
| `eza.yml` | `ls` (eza) | `~/.config/eza/theme.yml` | sí |
| `starship.toml` | tabla `[palettes.theme]` del prompt | copia de `~/.config/starship.toml` con `palette = "theme"` | sí |
| `btop.theme` | btop | `~/.config/btop/themes/salchipapa.theme` (+ `color_theme` en `btop.conf`) | no: al reabrir btop |
| `lazygit.yml` | lazygit (`gui.theme`) | `~/.local/state/salchipapa-shell/lazygit-theme.yml` (fish lo añade a `LG_CONFIG_FILE`) | no: al reabrir lazygit |
| `delta.gitconfig` | diffs de git y lazygit (delta) | `~/.local/state/salchipapa-shell/delta.gitconfig` (incluido por `~/.gitconfig`; el `syntax-theme` es el de bat) | sí |
| `herdr.toml` | sección `[theme]` de herdr (`name`, `[theme.custom]`) | `~/.config/herdr/config.toml`: copia del de los dotfiles con esta sección | sí |
| `bat` | nombre del tema de bat (de `bat/` o de los que trae bat) | `~/.config/bat/config` | sí |

La terminal (16 casillas) sale de `term0`–`term15` de `schemes.json` si el tema está en
`ANSI_SCHEMES` de `apply-colors.sh`.

El comando `theme <tema>` de fish (Salchipapa.Dots) hace lo mismo que elegirlo con `Super+T`.

## Añadir un tema (p. ej. solarized)

1. Su paleta en `schemes.json` (o en `scripts/build-schemes.py` si tiene paleta oficial).
2. `shell/themes/solarized/` copiando los archivos de `gruvbox/` y cambiando los colores según
   cómo los reparte su colorscheme de nvim.
3. Aplicarlo con `Super+T`.
