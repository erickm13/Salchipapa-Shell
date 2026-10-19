#!/usr/bin/env bash
# Salchipapa-Shell — instalador para un Arch Linux limpio.
# Deja el escritorio como en el equipo original: Hyprland + Quickshell, fuentes, fondos, tema,
# GTK/Qt, SDDM y servicios. Al final ofrece instalar Salchipapa.Dots (fish, foot, kitty, nvim…).
#
# Uso:  ./install.sh      (como tu usuario, NO con sudo: pedirá la contraseña cuando haga falta)
# Se puede repetir: lo ya instalado se salta y lo que reemplaza se respalda como <ruta>.bak-<fecha>.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTS_DIR="${SALCHIPAPA_DOTS:-$HOME/Documents/Salchipapa.Dots}"
DOTS_URL="https://github.com/erickm13/Salchipapa.Dots.git"
QYLOCK_URL="https://github.com/Darkkal44/qylock.git"
QYLOCK_REV="db61a972b4b23728d9944a906e70029ca8a5899d" # versión probada del tema de SDDM
SDDM_THEME="enfield"
GRUB_THEME_NAME="minegrub-world-selection" # de grub/themes/
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell"
LOG="$LOG_DIR/install-$STAMP.log"
STATE="$HOME/.local/state/salchipapa-shell"
FAILED=()

# Paquetes de los repos oficiales
PKGS=(
    base-devel git curl rsync
    # Compositor, sesión y shell
    hyprland uwsm sddm quickshell polkit xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt6-wayland qt6-5compat qt6-svg qt6-imageformats qt6-multimedia qt6-multimedia-ffmpeg qt5-wayland
    # Vídeo del tema de SDDM
    gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly
    # Gráficos comunes (los drivers de cada GPU se añaden en detect_gpu)
    mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader libva-utils
    # Audio (sof-firmware: micro y altavoces de portátiles Intel), red, bluetooth, energía, brillo
    pipewire pipewire-pulse pipewire-audio pipewire-alsa pipewire-jack wireplumber libcanberra
    sof-firmware alsa-ucm-conf xdg-user-dirs
    networkmanager bluez bluez-utils upower power-profiles-daemon brightnessctl
    # Lo que usan los scripts y la isla
    matugen jq python imagemagick grim slurp swappy wl-clipboard cliphist hyprpicker
    libnotify gnome-keyring trash-cli glib2 dconf
    fish # varios scripts de bin/ son de fish
    # Apps de los atajos
    foot kitty fuzzel yazi btop firefox pavucontrol thunar nemo
    gpu-screen-recorder # grabar pantalla (scripts/record.sh)
    hyprsunset # luz nocturna del centro de control
    qps showmethekey # Ctrl+Alt+Esc, Super+Alt+Shift+K
    wtype # el selector de emojis escribe el elegido en la ventana
    # Thunar: miniaturas, montaje de USB/móvil (MTP, iPhone) y discos NTFS
    tumbler ffmpegthumbnailer thunar-volman gvfs gvfs-mtp gvfs-afc ntfs-3g xdg-utils
    # Temas e iconos
    papirus-icon-theme adw-gtk-theme
    # Fuentes
    noto-fonts noto-fonts-emoji adwaita-fonts inter-font ttf-cascadia-code-nerd ttf-material-symbols-variable
    ttf-jetbrains-mono-nerd # la de foot
)
# Paquetes de AUR (se instalan de uno en uno: si falla uno, siguen los demás)
AUR_PKGS=(qtengine bibata-cursor-theme-bin papirus-folders otf-geist ttf-rubik-vf spotify vesktop-bin visual-studio-code-bin
    linux-wallpaperengine-git) # fondos animados de Wallpaper Engine (necesita Steam + la Workshop)

# ── Salida ────────────────────────────────────────────────────────
BOLD=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' CYAN=$'\e[36m' RESET=$'\e[0m'
section() { echo -e "\n${CYAN}${BOLD}▌ $1${RESET}"; }
ok() { echo -e "  ${GREEN}✔${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✖${RESET} $1"; }

# step "descripción" comando...: lo ejecuta con la salida al log y anota si falla
step() {
    local desc="$1"
    shift
    echo "── $desc" >>"$LOG"
    # Subshell fuera de un `if`: así `set -e` sí corta el paso en el primer error
    set +e
    (
        set -e
        "$@"
    ) >>"$LOG" 2>&1
    local rc=$?
    set -e
    if [ $rc -eq 0 ]; then
        ok "$desc"
    else
        fail "$desc ${DIM}(ver log)${RESET}"
        FAILED+=("$desc")
    fi
}

ask() { # ask "pregunta" -> 0 si responde sí
    local r
    while true; do
        read -rp "  $1 [s/n]: " r </dev/tty || return 1 # sin terminal: no
        case "${r,,}" in
        s | si | sí | y | yes) return 0 ;;
        n | no) return 1 ;;
        esac
    done
}

# Respaldar <ruta> si existe y no es ya lo que queremos poner
backup() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        mv "$1" "$1.bak-$STAMP"
        echo "respaldado: $1 -> $1.bak-$STAMP"
    fi
}

# Enlazar <destino> -> <origen> (respaldando lo que hubiera)
link() {
    local src="$1" dst="$2"
    [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ] && return 0
    mkdir -p "$(dirname "$dst")"
    backup "$dst"
    ln -s "$src" "$dst"
}

# Copiar <origen> a <destino> si cambia (respaldando la versión anterior)
put() {
    local src="$1" dst="$2"
    [ -f "$dst" ] && cmp -s "$src" "$dst" && return 0
    mkdir -p "$(dirname "$dst")"
    backup "$dst"
    cp "$src" "$dst"
}

# ── Pasos ─────────────────────────────────────────────────────────
# multilib (paquetes lib32-*: drivers de 32 bits para Steam/Wine) viene desactivado en Arch
enable_multilib() {
    grep -q '^\[multilib\]' /etc/pacman.conf && return 0
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    else
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    grep -q '^\[multilib\]' /etc/pacman.conf
}

# Drivers según las GPU que haya (por PCI: clase 0x03 = pantalla; 8086 Intel, 1002 AMD, 10de NVIDIA)
GPUS=()
detect_gpu() {
    local d vendor
    for d in /sys/bus/pci/devices/*; do
        [[ "$(cat "$d/class")" == 0x03* ]] || continue
        vendor="$(cat "$d/vendor")"
        case "$vendor" in
        0x8086) GPUS+=(intel) ;;
        0x1002) GPUS+=(amd) ;;
        0x10de) GPUS+=(nvidia) ;;
        esac
    done
    if [[ " ${GPUS[*]} " == *" intel "* ]]; then
        PKGS+=(intel-media-driver vulkan-intel lib32-vulkan-intel)
    fi
    if [[ " ${GPUS[*]} " == *" amd "* ]]; then
        PKGS+=(vulkan-radeon lib32-vulkan-radeon)
    fi
    if [[ " ${GPUS[*]} " == *" nvidia "* ]]; then
        # nvidia-open es para el kernel `linux`; con otros kernels (zen, lts…) hace falta la versión dkms
        local kernels
        # (pacman -Qq falla si alguno no está instalado: || true para que set -e no corte el script)
        kernels="$( (pacman -Qq linux linux-lts linux-zen linux-hardened 2>/dev/null || true) | tr '\n' ' ')"
        if [ -z "$kernels" ] || [ "$kernels" = "linux " ]; then
            PKGS+=(nvidia-open)
        else
            PKGS+=(nvidia-open-dkms)
            for k in $kernels; do PKGS+=("$k-headers"); done
        fi
        PKGS+=(nvidia-utils lib32-nvidia-utils libva-nvidia-driver egl-wayland nvidia-prime)
    fi
}

# NVIDIA: cargar sus módulos al arrancar (KMS temprano, evita pantalla negra al iniciar Hyprland)
setup_nvidia_initramfs() {
    local conf=/etc/mkinitcpio.conf.d/nvidia.conf
    [ -f "$conf" ] && return 0
    grep -q '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf && return 0
    echo 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' | sudo tee "$conf" >/dev/null
    sudo mkinitcpio -P
}

install_pacman() {
    local missing
    mapfile -t missing < <(pacman -T "${PKGS[@]}" || true)
    sudo pacman -Syu --noconfirm ${missing[@]+"${missing[@]}"}
}

install_aur_helper() {
    if command -v paru >/dev/null || command -v yay >/dev/null; then return 0; fi
    # sin `local`: el trap EXIT del paso (subshell) se ejecuta cuando la función ya terminó
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
}

mark_explicit() {
    local p names=()
    for p in "${PKGS[@]}" "${AUR_PKGS[@]}"; do
        # el nombre exacto o su variante -git/-bin (quickshell-git cubre quickshell)
        for q in "$p" "${p%-bin}" "$p-git" "$p-bin"; do
            if pacman -Qq "$q" >/dev/null 2>&1; then
                names+=("$q")
                break
            fi
        done
    done
    sudo pacman -D --asexplicit "${names[@]}"
}

aur_install() {
    # Ya instalado (también su variante sin -bin/-git, p. ej. vesktop en vez de vesktop-bin)
    if [ -z "$(pacman -T "$1" || true)" ] || [ -z "$(pacman -T "${1%-bin}" || true)" ] ||
        [ -z "$(pacman -T "${1%-git}" || true)" ]; then
        echo "ya instalado: $1"
        return 0
    fi
    # spotify verifica su .deb con la clave del repositorio de Spotify
    if [ "$1" = "spotify" ]; then
        curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg | gpg --import -
    fi
    if command -v paru >/dev/null; then
        paru -S --needed --noconfirm --skipreview "$1"
    else
        yay -S --needed --noconfirm --answerdiff None --answerclean None "$1"
    fi
}

install_fonts() {
    install -Dm644 -t "$HOME/.local/share/fonts/SalchipapaShell" "$REPO"/assets/fonts/*
    fc-cache -f
}

install_wallpapers() {
    local dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"
    mkdir -p "$dir" "${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    rsync -a --ignore-existing "$REPO/wallpapers/" "$dir/"
    [ -e "$HOME/.face" ] || cp "$REPO/assets/face.jpg" "$HOME/.face"
}

install_configs() {
    link "$REPO" "$HOME/.config/hypr"
    link "$REPO/uwsm" "$HOME/.config/uwsm"
    # Ajustes de la shell: solo si no hay unos propios
    [ -f "$HOME/.config/salchipapa-shell/config.json" ] ||
        install -Dm644 "$REPO/defaults/config.json" "$HOME/.config/salchipapa-shell/config.json"
    put "$REPO/defaults/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
    put "$REPO/defaults/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
    put "$REPO/defaults/qtengine/config.json" "$HOME/.config/qtengine/config.json"
    # Apps GTK4/libadwaita con el mismo tema que GTK3
    link /usr/share/themes/adw-gtk3-dark/gtk-4.0/assets "$HOME/.config/gtk-4.0/assets"
    link /usr/share/themes/adw-gtk3-dark/gtk-4.0/gtk-dark.css "$HOME/.config/gtk-4.0/gtk-dark.css"
    # Perfiles de monitor (scripts/monitor-autodetect) y configuraciones guardadas
    for f in display-profiles.json display-setups.json; do
        [ -f "$HOME/.config/salchipapa-shell/$f" ] || install -Dm644 "$REPO/defaults/$f" "$HOME/.config/salchipapa-shell/$f"
    done
    # btop (Ctrl+Shift+Esc): si ~/.config/btop era un enlace a otro escritorio, se respalda entero
    [ -L "$HOME/.config/btop" ] && backup "$HOME/.config/btop"
    [ -f "$HOME/.config/btop/btop.conf" ] || install -Dm644 "$REPO/defaults/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    # Cursor también para apps X11
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Classic\n' >"$HOME/.icons/default/index.theme"
}

# Scripts de bin/ -> ~/.local/bin (enlaces). Si ya hay uno igual se reemplaza sin respaldo.
install_bin() {
    local f dst
    mkdir -p "$HOME/.local/bin"
    for f in "$REPO"/bin/*; do
        dst="$HOME/.local/bin/$(basename "$f")"
        [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$f" "$dst" && rm "$dst"
        link "$f" "$dst"
    done
}

set_gsettings() {
    local s=org.gnome.desktop.interface
    dbus-run-session -- sh -ec "
        gsettings set $s gtk-theme 'adw-gtk3-dark'
        gsettings set $s icon-theme 'Papirus-Dark'
        gsettings set $s cursor-theme 'Bibata-Modern-Classic'
        gsettings set $s cursor-size 24
        gsettings set $s color-scheme 'prefer-dark'
        gsettings set $s font-name 'Adwaita Sans 11'"
}

# Fondo y colores ya escritos para el primer arranque; first-run.sh los reaplica dentro de
# Hyprland (después de que Dots haya enlazado foot/kitty/fish).
prepare_theme() {
    local scheme wallpaper
    scheme=$(sed -n 's/^scheme=//p' "$REPO/defaults/theme")
    wallpaper=$(sed -n 's/^wallpaper=//p' "$REPO/defaults/theme")
    "$REPO/scripts/wallpaper.sh" "${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers/$wallpaper" nocolors
    [ "$scheme" = "dynamic" ] || dbus-run-session -- "$REPO/scripts/apply-colors.sh" scheme "$scheme"
    mkdir -p "$STATE"
    touch "$STATE/first-run"
}

# ASUS: ajustes de asusd (límite de carga, perfiles con/sin cargador). Las curvas de ventilador y
# el RGB del teclado dependen del modelo: solo se copian en la misma placa (defaults/asusd/BOARD).
install_asusd_config() {
    local src="$REPO/defaults/asusd" f
    sudo install -d /etc/asusd
    sudo install -m644 "$src/asusd.ron" /etc/asusd/asusd.ron
    if [ "$(cat /sys/class/dmi/id/board_name)" = "$(cat "$src/BOARD")" ]; then
        for f in "$src"/fan_curves.ron "$src"/aura_*.ron; do
            sudo install -m644 "$f" "/etc/asusd/$(basename "$f")"
        done
    else
        echo "otra placa: se omiten curvas de ventilador y RGB"
    fi
    sudo systemctl try-restart asusd.service
}

install_papirus_rule() {
    sudo bash "$REPO/scripts/instalar-papirus-sudo.sh"
}

install_sddm_theme() {
    # sin `local`: el trap EXIT del paso (subshell) se ejecuta cuando la función ya terminó
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    git clone -q "$QYLOCK_URL" "$tmp/qylock"
    git -C "$tmp/qylock" checkout -q "$QYLOCK_REV"
    sudo rm -rf "/usr/share/sddm/themes/$SDDM_THEME"
    sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
    sudo cp -r "$tmp/qylock/themes/$SDDM_THEME" "/usr/share/sddm/themes/$SDDM_THEME"
    printf '[Theme]\nCurrent=%s\n' "$SDDM_THEME" | sudo tee /etc/sddm.conf.d/theme.conf >/dev/null
}

# Ajustes > Login & Boot: los helpers que cambian el tema de SDDM/GRUB van a /usr/local/bin
# (root) con una regla sudoers acotada a ellos, validada con visudo antes de instalarla.
install_theme_helpers() {
    local f rule=/etc/sudoers.d/salchipapa-boot-themes tmp
    for f in sddm-theme-apply grub-theme-apply; do
        sudo install -m755 -o root -g root "$REPO/bin/$f" "/usr/local/bin/$f"
    done
    tmp="$(mktemp)"
    printf '%s ALL=(root) NOPASSWD: /usr/local/bin/sddm-theme-apply, /usr/local/bin/grub-theme-apply\n' "$USER" >"$tmp"
    sudo visudo -cf "$tmp"
    sudo install -m440 -o root -g root "$tmp" "$rule"
    rm -f "$tmp"
}

# GRUB: temas de grub/themes/, el activo y los otros sistemas (Windows…) en el menú.
# Solo si el equipo arranca con GRUB (con systemd-boot se omite).
install_grub_theme() {
    if [ ! -d /boot/grub ] || ! command -v grub-mkconfig >/dev/null; then
        echo "sin GRUB: se omite"
        return 0
    fi
    sudo pacman -S --needed --noconfirm os-prober
    sudo mkdir -p /boot/grub/themes
    sudo cp -r "$REPO"/grub/themes/. /boot/grub/themes/
    local theme="/boot/grub/themes/$GRUB_THEME_NAME/theme.txt" key val
    for kv in "GRUB_THEME=\"$theme\"" "GRUB_DISABLE_OS_PROBER=false" "GRUB_GFXMODE=auto"; do
        key="${kv%%=*}"
        if grep -q "^#\?$key=" /etc/default/grub; then
            sudo sed -i "s|^#\?$key=.*|$kv|" /etc/default/grub
        else
            echo "$kv" | sudo tee -a /etc/default/grub >/dev/null
        fi
    done
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

# SDDM recuerda la última sesión y usuario: arrancar ya en "Hyprland (uwsm-managed)"
set_sddm_session() {
    sudo install -d -o sddm -g sddm /var/lib/sddm
    printf '[Last]\nSession=/usr/share/wayland-sessions/hyprland-uwsm.desktop\nUser=%s\n' "$USER" |
        sudo tee /var/lib/sddm/state.conf >/dev/null
    sudo chown sddm:sddm /var/lib/sddm/state.conf
}

enable_services() {
    sudo systemctl enable NetworkManager.service bluetooth.service power-profiles-daemon.service sddm.service
}

# ── Main ──────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    echo "Ejecútalo como tu usuario, sin sudo:  ./install.sh" >&2
    exit 1
fi
if ! command -v pacman >/dev/null; then
    echo "Este instalador es para Arch Linux (pacman)." >&2
    exit 1
fi
mkdir -p "$LOG_DIR"
: >"$LOG"

echo -e "${BOLD}Salchipapa-Shell${RESET} ${DIM}— instalador${RESET}"
echo -e "${DIM}Repo: $REPO · Log: $LOG${RESET}"
if ! curl -sfI --max-time 10 https://archlinux.org >/dev/null; then
    echo -e "${RED}Sin conexión a internet.${RESET} Conéctate (p. ej. con nmtui o iwctl) y vuelve a ejecutarlo." >&2
    exit 1
fi

# Pedir la contraseña una vez y mantener sudo vivo mientras dure la instalación
sudo -v
while kill -0 $$ 2>/dev/null; do
    sudo -n true
    sleep 50
done 2>/dev/null &

section "Paquetes"
step "Repositorio multilib (32 bits)" enable_multilib
detect_gpu
if [ ${#GPUS[@]} -gt 0 ]; then
    ok "GPU detectada: ${GPUS[*]}"
else
    warn "No se detectó GPU (¿máquina virtual?): solo drivers genéricos de mesa"
fi
IS_ASUS=0
if grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    IS_ASUS=1
    PKGS+=(asusctl) # perfiles Turbo/Silencioso del centro de control, carga, ventiladores, RGB
fi
step "Paquetes oficiales (${#PKGS[@]})" install_pacman
if [[ " ${GPUS[*]} " == *" nvidia "* ]]; then
    step "NVIDIA: módulos en el arranque (mkinitcpio)" setup_nvidia_initramfs
fi
step "Ayudante de AUR" install_aur_helper
for p in "${AUR_PKGS[@]}"; do
    step "AUR: $p" aur_install "$p"
done
step "Marcar los paquetes como instalados a mano" mark_explicit

section "Archivos del usuario"
step "Fuentes (Google Sans Flex, Material Symbols)" install_fonts
step "Fondos de pantalla y avatar" install_wallpapers
step "Configs: Hyprland, uwsm, shell, monitores, GTK, Qt, btop, cursor" install_configs
step "Scripts de bin/ en ~/.local/bin" install_bin
step "Tema GTK, iconos y cursor (gsettings)" set_gsettings

section "Sistema"
step "Regla sudoers de papirus-folders (color de carpetas)" install_papirus_rule
step "Fondo y colores iniciales" prepare_theme
if [ "$IS_ASUS" -eq 1 ]; then
    step "ASUS: ajustes de asusd (carga, perfiles, ventiladores, RGB)" install_asusd_config
fi
step "Tema de SDDM ($SDDM_THEME)" install_sddm_theme
step "Tema de GRUB ($GRUB_THEME_NAME) y otros sistemas en el menú" install_grub_theme
step "Cambiar temas de SDDM/GRUB desde Ajustes (helpers + sudoers)" install_theme_helpers
step "Sesión por defecto en SDDM: Hyprland (uwsm)" set_sddm_session
step "Servicios: NetworkManager, bluetooth, power-profiles, sddm" enable_services

section "Resumen"
if [ ${#FAILED[@]} -eq 0 ]; then
    ok "Salchipapa-Shell instalada."
else
    warn "Terminó con ${#FAILED[@]} paso(s) fallido(s):"
    for f in "${FAILED[@]}"; do fail "$f"; done
    echo -e "  ${DIM}Detalles en $LOG. Puedes volver a ejecutar ./install.sh.${RESET}"
fi
echo -e "  ${DIM}Al reiniciar entrarás por SDDM en Hyprland; el primer arranque aplica el fondo y el tema.${RESET}"

echo
if ask "¿Instalar también Salchipapa.Dots (fish, foot, kitty, nvim, agentes…)? En «Terminal» elige Foot"; then
    if [ ! -d "$DOTS_DIR/.git" ]; then
        mkdir -p "$(dirname "$DOTS_DIR")"
        git clone "$DOTS_URL" "$DOTS_DIR"
    fi
    # Dots es interactivo y al final abre la shell elegida: va al final y reemplaza este proceso
    exec sudo "$DOTS_DIR/install.sh"
fi
echo -e "\n  Reinicia para entrar:  ${BOLD}sudo reboot${RESET}\n"
