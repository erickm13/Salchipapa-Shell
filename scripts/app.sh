#!/usr/bin/env bash
# Lanza una app DENTRO de la sesión gráfica: con uwsm, `uwsm app` la pone en su propia unidad de
# systemd y al cerrar sesión se cierra con ella. Sin esto, las apps de Chromium (Spotify, Vesktop,
# VS Code…) se mueven solas a un grupo fuera de la sesión y sobreviven al logout sin ventana.
#   app.sh <programa> [args…]      (también acepta un .desktop: app.sh firefox.desktop)
# Fuera de una sesión uwsm (p. ej. la sesión "Hyprland" sin uwsm), la lanza desacoplada como antes.
# Siempre en segundo plano: `uwsm app` espera a que la app termine, y scratch.sh se quedaría bloqueado
if [ -n "${UWSM_FINALIZE_VARNAMES:-}" ] && command -v uwsm >/dev/null; then
    exec setsid -f uwsm app -- "$@"
fi
case "$1" in
*.desktop) exec setsid -f gtk-launch "${1%.desktop}" ;;
*) exec setsid -f "$@" ;;
esac
