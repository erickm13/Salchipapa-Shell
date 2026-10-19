# Salchipapa-Shell

Mi configuración de [Hyprland](https://hyprland.org/) desde cero, modular y reutilizable.
Inspirada en la fluidez de [caelestia](https://github.com/caelestia-dots) (curvas Material 3),
pero independiente de su shell.

## Instalar (Arch Linux limpio)

```sh
git clone https://github.com/erickm13/Salchipapa-Shell ~/proyects/Salchipapa-Shell
~/proyects/Salchipapa-Shell/install.sh     # como tu usuario, sin sudo
```

El instalador deja el escritorio igual que en el equipo original:

- **Paquetes**: Hyprland, uwsm, SDDM, Quickshell y todo lo que usan la isla y los scripts
  (oficiales + AUR: qtengine, Bibata, papirus-folders, Geist, Spotify, Vesktop, VS Code; `asusctl`
  solo en equipos ASUS). Instala `yay` si no hay ayudante de AUR.
- **Archivos**: fuentes de `assets/fonts/`, fondos de `wallpapers/` → `~/Pictures/Wallpapers`, avatar
  `~/.face`, ajustes de la shell (`defaults/config.json`), GTK, Qt (`qtengine`), cursor y gsettings.
- **Enlaces**: `~/.config/hypr` → este repo y `~/.config/uwsm` → `uwsm/` (lo que hubiera se
  respalda como `<ruta>.bak-<fecha>`).
- **Sistema**: regla sudoers de `papirus-folders`, tema de SDDM `enfield` (de qylock), sesión por
  defecto *Hyprland (uwsm-managed)* y servicios (NetworkManager, bluetooth, power-profiles, sddm).
- **GRUB** (si el equipo lo usa): temas de `grub/themes/`, tema activo y otros sistemas en el menú.
- **Scripts**: `bin/` enlazado en `~/.local/bin`; perfiles de monitor en `~/.config/salchipapa-shell/`.
- **Primer arranque**: `scripts/first-run.sh` aplica el fondo y el tema de `defaults/theme`.
- Al final ofrece instalar [Salchipapa.Dots](https://github.com/erickm13/Salchipapa.Dots) (fish,
  foot, kitty, nvim…); en *Terminal* elige **Foot**.

Se puede repetir: salta lo ya instalado. Log en `~/.cache/salchipapa-shell/`.

**Guardar tu estado actual en el repo** (antes de formatear): copia
`~/.config/salchipapa-shell/config.json` a `defaults/config.json`, los fondos nuevos a `wallpapers/`
y el tema/fondo activos a `defaults/theme`.

## Probar sin instalar

Desde una TTY libre (`Ctrl+Alt+F3`): `Hyprland -c <repo>/hyprland.lua`. `Super + Shift + Q` sale.

> La config está en **Lua** (`hyprland.lua` + módulos en `lua/`), el formato nuevo de Hyprland
> (el `.conf` se elimina en 0.57).

## Estructura

| Archivo | Qué contiene |
|---|---|
| `hyprland.lua` | Entrada: solo hace `require()` de los módulos de `lua/` |
| `lua/vars.lua` | Variables de programas y colores del tema compartidos |
| `lua/monitors.lua` | Monitores |
| `lua/env.lua` | Variables de entorno (Wayland, Qt, cursor) |
| `lua/general.lua` | Gaps, borde (acento del tema), layout (dwindle) |
| `lua/misc.lua` | VRR, foco, DPMS y otros ajustes de Hyprland |
| `lua/decoration.lua` | Redondeo, blur, sombra/glow del tema |
| `lua/group.lua` | Grupos de ventanas y groupbar |
| `lua/animations.lua` | Curvas bezier Material 3 y animaciones |
| `lua/input.lua` | Teclado, touchpad, gestos |
| `lua/windowrules.lua` | Reglas de ventana y de capas (incl. scratchpads) |
| `lua/keybinds.lua` | Atajos |
| `lua/autostart.lua` | Arranque (polkit, llavero, cursor, cliphist, MPRIS, limpieza de papelera, Quickshell) |
| `scripts/` | Scripts (capturas, areapicker helper, scratchpads, bloqueo, tema y primer arranque) |
| `install.sh` | Instalador para Arch limpio |
| `defaults/` | Ajustes de la shell, GTK, Qt y tema/fondo iniciales que copia el instalador |
| `assets/` | Fuentes (Google Sans Flex, Material Symbols) y avatar |
| `wallpapers/` | Fondos de pantalla (→ `~/Pictures/Wallpapers`) |
| `uwsm/` | Variables de entorno de la sesión (→ `~/.config/uwsm`) |
| `bin/` | Scripts personales (temas de GRUB y SDDM, grabación, revisión de AUR) → `~/.local/bin` |
| `scripts/update-emojis.sh` | Regenera `shell/assets/emojis.json` (emojibase + Nerd Fonts) |
| `scripts/boot-themes.sh` | Temas de SDDM y GRUB (Ajustes > *Login & Boot*) |
| `scripts/animated-wallpaper.sh` | Fondos animados de Wallpaper Engine (pestaña *Animados* de `Super+W`) |
| `grub/themes/` | Temas de GRUB (el activo: `minegrub-world-selection`) → `/boot/grub/themes` |
| `scripts/monitor-autodetect` | Perfil de monitores al conectar/desconectar (`~/.config/salchipapa-shell/display-profiles.json`) |
| `shell/services/LockScreen.qml` | Pantalla de bloqueo segura vía sesión Wayland y autenticación PAM |
| `shell/` | La shell de Quickshell (isla, launcher, temas, picker) |

## Atajos principales

| Atajo | Acción |
|---|---|
| `Super + Return` | Terminal (foot) |
| `Super + R` | Lanzador de la isla |
| `Super + B` | Navegador |
| `Super + E` | Archivos (yazi) |
| `Super + Q` | Cerrar ventana |
| `Super + Backspace` | Bloquear pantalla (Quickshell + PAM) |
| `Super + Alt + P` | Menú de energía de la isla |
| `Super + V` | Historial del portapapeles (en la isla; Enter copia, Supr borra) |
| `Super + .` | Selector de emojis (en la isla; español o inglés) |
| `Super + Alt + Space` / `Super + F` | Flotar / pantalla completa |
| `Super + [1-0]` | Workspace |
| `Super + Shift + [1-0]` | Mover ventana a workspace |
| `Super + Alt + [1-0]` | Mover ventana al índice indicado del grupo actual de diez |
| `Ctrl + Super + [1-0]` | Cambiar al grupo de diez, conservando el índice actual |
| `Ctrl + Super + Alt + [1-0]` | Mover ventana al grupo de diez indicado, conservando el índice |
| `Super + Alt + Page Up/Down` | Mover ventana al workspace anterior/siguiente |
| `Ctrl + Super + ←/→` | Workspace anterior/siguiente |
| `Super + S` | Scratchpad |
| `Super + Shift + S` | Captura congelada: previsualizar ventana al pasar el cursor, clic para capturar o arrastrar región |
| `Super + Shift + Alt + S` | Captura de región |
| `Print` | Captura de pantalla completa |
| `Super + Shift + Print` | Captura del monitor activo |
| `Super + Alt + R` | Grabar el monitor enfocado con sonido (otra vez = parar) |
| `Ctrl + Alt + R` | Grabar el monitor enfocado sin sonido |
| `Super + Shift + Alt + R` | Grabar una región con sonido |
| `Super + Shift + Alt + P` | Pausar/reanudar la grabación |
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

> Notificaciones: la shell **es** el servidor de notificaciones, por eso `lua/autostart.lua` **no**
> lanza dunst (chocarían).

Probar suelta: `qs -p <repo>/shell/shell.qml` (se recarga sola al guardar).

## Pendiente

- [ ] Ampliar la barra: bandeja, volumen, batería, red, CPU/RAM
- [ ] Esquema de color propio (bordes, blur, barra)
- [ ] Herramienta de fondo de pantalla (hyprpaper o swww)
