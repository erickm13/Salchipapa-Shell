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
    # Audio, red, bluetooth, energía, brillo
    pipewire pipewire-pulse pipewire-audio wireplumber libcanberra
    networkmanager bluez bluez-utils upower power-profiles-daemon brightnessctl
    # Lo que usan los scripts y la isla
    matugen jq python imagemagick grim slurp swappy wl-clipboard cliphist hyprpicker
    libnotify gnome-keyring trash-cli glib2 dconf
    # Apps de los atajos
    foot kitty fuzzel yazi btop firefox pavucontrol thunar nemo
    # Temas e iconos
    papirus-icon-theme adw-gtk-theme
    # Fuentes
    noto-fonts noto-fonts-emoji adwaita-fonts inter-font ttf-cascadia-code-nerd ttf-material-symbols-variable
)
# Paquetes de AUR (se instalan de uno en uno: si falla uno, siguen los demás)
AUR_PKGS=(qtengine bibata-cursor-theme-bin papirus-folders otf-geist spotify vesktop-bin visual-studio-code-bin)

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
    # Cursor también para apps X11
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nName=Default\nInherits=Bibata-Modern-Classic\n' >"$HOME/.icons/default/index.theme"
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
if grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    PKGS+=(asusctl) # perfiles Turbo/Silencioso del centro de control
fi
step "Paquetes oficiales (${#PKGS[@]})" install_pacman
step "Ayudante de AUR" install_aur_helper
for p in "${AUR_PKGS[@]}"; do
    step "AUR: $p" aur_install "$p"
done

section "Archivos del usuario"
step "Fuentes (Google Sans Flex, Material Symbols)" install_fonts
step "Fondos de pantalla y avatar" install_wallpapers
step "Configs: Hyprland, uwsm, shell, GTK, Qt, cursor" install_configs
step "Tema GTK, iconos y cursor (gsettings)" set_gsettings

section "Sistema"
step "Regla sudoers de papirus-folders (color de carpetas)" install_papirus_rule
step "Fondo y colores iniciales" prepare_theme
step "Tema de SDDM ($SDDM_THEME)" install_sddm_theme
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
