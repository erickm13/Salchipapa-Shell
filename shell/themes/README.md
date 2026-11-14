# Temas

- `schemes.json`: la paleta de cada tema (roles de la shell y `term0`–`term15` de la terminal).
  Los que vienen de una paleta oficial los genera `scripts/build-schemes.py`.
- `<tema>/`: los temas **hechos a mano**, con un archivo por app. `scripts/apply-colors.sh scheme <tema>`
  aplica los que haya; una app sin su archivo usa su estilo por defecto (nombres ANSI: la paleta de
  la terminal). La referencia para repartir los colores es el colorscheme de nvim de ese tema.
- `spicetify/`: diseños de Spotify (Spicetify) que se colorean con cada tema.
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
| `fastfetch` | opciones de color de fastfetch (una por línea: `--color-keys`, `--color-title`…) | `~/.local/state/salchipapa-shell/fastfetch-args` (las pasa la función `fastfetch` de fish) | sí |
| `gtk.css` | GTK 3/4 (Thunar, Nemo, libadwaita): `@define-color` | `~/.config/gtk-3.0/gtk.css` y `gtk-4.0/gtk.css` | sí (GTK3 por gsettings; GTK4 con gtk4-live-css) |
| `papirus` | color de las carpetas de Papirus (uno de `papirus-folders -l`) | iconos del sistema (`papirus-folders`, regla sudo) | sí, en segundo plano (~4 s) |
| `qt.colors` | Qt (qtengine) y apps KDE: grupos `[Colors:*]` de un colorscheme de KDE | `~/.config/qtengine/salchipapa.colors` y `~/.config/kdeglobals` | no: al reabrir la app |
| `spicetify.ini` | Spotify: claves del `color.ini` del diseño *text* de Spicetify (sin cabecera) | tema `Salchipapa` de Spicetify (`spicetify/text/user.css` + esto como esquema `base`) | no: al reabrir Spotify |
| `vscode.json` | ajustes de VS Code (`workbench.colorTheme`, `workbench.colorCustomizations`) | se mezclan en `~/.config/Code/User/settings.json` (`scripts/vscode-settings.py`); sin él vuelve el tema del usuario | sí |
| `surfingkeys.js` | configuración de Surfingkeys (Firefox) con el tema | no se aplica sola: se pega en Surfingkeys > Settings > Advanced mode (Firefox no deja leer archivos) | no |
| `vesktop.css` | Vesktop/Discord: variables de color del tema system24 (`:root`) | bloque marcado en `~/.config/vesktop/settings/quickCss.css` | sí |
| `terminal-bg` | fondo de la terminal (hex sin `#`); sin él, el `background` de la paleta | kitty, foot y las terminales abiertas (OSC 11) | sí |
| `bat` | nombre del tema de bat (de `bat/` o de los que trae bat) | `~/.config/bat/config` | sí |

La terminal (16 casillas) sale de `term0`–`term15` de `schemes.json` si el tema está en
`ANSI_SCHEMES` de `apply-colors.sh`.

El comando `theme <tema>` de fish (Salchipapa.Dots) hace lo mismo que elegirlo con `Super+T`.

## Añadir un tema (p. ej. solarized)

1. Su paleta en `schemes.json` (o en `scripts/build-schemes.py` si tiene paleta oficial).
2. `shell/themes/solarized/` copiando los archivos de `gruvbox/` y cambiando los colores según
   cómo los reparte su colorscheme de nvim.
3. Aplicarlo con `Super+T`.

Temas de apps que hay que instalar aparte: gruvbox en VS Code usa la extensión
`jdinhlife.gruvbox` (`code --install-extension jdinhlife.gruvbox`).
