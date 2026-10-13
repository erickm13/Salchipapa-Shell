# Salchipapa-Shell

Mi configuración de [Hyprland](https://hyprland.org/) desde cero, modular y reutilizable.
Inspirada en la fluidez de [caelestia](https://github.com/caelestia-dots) (curvas Material 3),
pero independiente de su shell.

## Probar sin romper nada

Esta config es solo archivos; **no sustituye** tu sesión actual hasta que tú quieras.
Para probarla en una sesión Hyprland aparte, desde una TTY libre (`Ctrl+Alt+F3`):

```sh
Hyprland -c ~/proyects/Salchipapa-Shell/hyprland.lua
```

> La config está en **Lua** (`hyprland.lua` + módulos en `lua/`), el formato nuevo de Hyprland
> (el `.conf` se elimina en 0.57).

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
| `hyprland.lua` | Entrada: solo hace `require()` de los módulos de `lua/` |
| `lua/vars.lua` | Variables y colores del tema compartidos |
| `lua/monitors.lua` | Monitores |
| `lua/env.lua` | Variables de entorno (Wayland, Qt, cursor) |
| `lua/general.lua` | Gaps, borde (acento del tema), layout (dwindle) |
| `lua/decoration.lua` | Redondeo, blur, sombra/glow del tema |
| `lua/animations.lua` | Curvas bezier Material 3 y animaciones |
| `lua/input.lua` | Teclado, touchpad, gestos |
| `lua/windowrules.lua` | Reglas de ventana y de capas (incl. scratchpads) |
| `lua/keybinds.lua` | Atajos |
| `lua/autostart.lua` | Arranque (polkit, barra Quickshell) |
| `scripts/` | Scripts (capturas, areapicker helper, scratchpads) |
| `shell/` | La shell de Quickshell (isla, launcher, temas, picker) |

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
| `Super + Shift + S` | Captura de región (también `Super + Shift + Alt + S`) |
| `Print` | Captura de pantalla completa |
| `Super + Shift + Print` | Captura del monitor activo |
| `Super + Shift + Q` | Salir de Hyprland |

## Shell (Quickshell) — modular, con diseños intercambiables

La shell está en `shell/`, con **Quickshell** (QML/Qt6). Pensada para tener **varios diseños** de
barra y elegir cuál usar; hoy hay uno: *Dynamic Island*.

```
shell/
├── shell.qml              # entrada: monta 1 barra por monitor con el diseño de Config.design
├── common/                # Config (diseño activo + ajustes) y Theme (paleta + curvas)
├── services/              # singletons compartidos por CUALQUIER diseño:
│   ├── Audio.qml          #   volumen/micro (PipeWire)
│   ├── Media.qml          #   reproductor activo (MPRIS)
│   ├── Battery.qml        #   batería (UPower)
│   ├── Net.qml            #   red (nmcli)
│   ├── Sys.qml            #   CPU/RAM (/proc)
│   └── Notifs.qml         #   servidor de notificaciones
└── designs/
    └── DynamicIsland.qml  # diseño "island"
```

**Cambiar de diseño:** edita `design:` en `shell/common/Config.qml`.
**Añadir un diseño nuevo:** crea `designs/MiBarra.qml` (un `PanelWindow`) y añádelo al `switch` de
`shell.qml`. Reutiliza los servicios con `import "../services"`.

### Diseño Dynamic Island
Píldora flotante centrada arriba (estilo iPhone):
- **Compacta:** workspace activo + reloj, con puntos de *reproduciendo* (verde) y *micro silenciado* (rojo).
- **Al pasar el ratón → expande** (rebote Material 3): workspaces clicables, reloj con fecha, título
  de ventana activa y fila de stats (batería, red, CPU, RAM, volumen).
- **Peeks contextuales** (se asoma sola y vuelve): al cambiar de canción (con controles ◁ ❚❚ ▷|),
  al subir/bajar volumen (barra de volumen) y al llegar una notificación.
- Solo la píldora captura el ratón (`mask`); los clics fuera pasan a las ventanas.

> Notificaciones: la shell **es** el servidor de notificaciones, por eso `autostart.conf` **no**
> lanza dunst (chocarían).

Probar suelta: `qs -p ~/proyects/Salchipapa-Shell/shell/shell.qml` (se recarga sola al guardar).

## Pendiente

- [ ] Ampliar la barra: bandeja, volumen, batería, red, CPU/RAM
- [ ] Esquema de color propio (bordes, blur, barra)
- [ ] Herramienta de fondo de pantalla (hyprpaper o swww)
- [ ] Bloqueo de pantalla (hyprlock + hypridle)
