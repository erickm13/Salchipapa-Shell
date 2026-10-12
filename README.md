# Salchipapa-Shell

Mi configuración de [Hyprland](https://hyprland.org/) desde cero, modular y reutilizable.
Inspirada en la fluidez de [caelestia](https://github.com/caelestia-dots) (curvas Material 3),
pero independiente de su shell.

## Probar sin romper nada

Esta config es solo archivos; **no sustituye** tu sesión actual hasta que tú quieras.
Para probarla en una sesión Hyprland aparte, desde una TTY libre (`Ctrl+Alt+F3`):

```sh
Hyprland -c ~/proyects/Salchipapa-Shell/hyprland.conf
```

`Super + Shift + Q` sale de esa sesión de prueba.

## Instalar de verdad (cuando esté a tu gusto)

```sh
# respalda tu config actual
mv ~/.config/hypr ~/.config/hypr.bak
# enlaza esta
ln -s ~/proyects/Salchipapa-Shell ~/.config/hypr
```

Para volver atrás: borra el symlink y restaura `~/.config/hypr.bak`.

## Estructura

| Archivo | Qué contiene |
|---|---|
| `hyprland.conf` | Entrada: variables (`$mod`, `$terminal`…) y `source` del resto |
| `conf/monitors.conf` | Monitores |
| `conf/env.conf` | Variables de entorno (Wayland, Qt, cursor) |
| `conf/general.conf` | Gaps, borde, layout (dwindle) |
| `conf/decoration.conf` | Redondeo, blur, sombra |
| `conf/animations.conf` | Curvas bezier Material 3 y animaciones |
| `conf/input.conf` | Teclado, touchpad, gestos |
| `conf/windowrules.conf` | Reglas de ventana |
| `conf/keybinds.conf` | Atajos |
| `conf/autostart.conf` | Arranque (polkit, dunst, fondo…) |

## Atajos principales

| Atajo | Acción |
|---|---|
| `Super + Return` | Terminal (kitty) |
| `Super + R` | Lanzador (fuzzel) |
| `Super + B` | Navegador |
| `Super + E` | Archivos (yazi) |
| `Super + Q` | Cerrar ventana |
| `Super + V` / `F` | Flotar / pantalla completa |
| `Super + [1-0]` | Workspace |
| `Super + Shift + [1-0]` | Mover ventana a workspace |
| `Super + S` | Scratchpad |
| `Super + Print` | Captura de región (selección con ratón) |
| `Print` | Captura de pantalla completa |
| `Super + Shift + Print` | Captura del monitor activo |
| `Super + Shift + Q` | Salir de Hyprland |

## Pendiente

- [ ] Esquema de color propio (bordes, blur)
- [ ] Herramienta de fondo de pantalla (hyprpaper o swww)
- [ ] Bloqueo de pantalla (hyprlock + hypridle)
- [ ] Barra propia (Quickshell/Qt o waybar)
