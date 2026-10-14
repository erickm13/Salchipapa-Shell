#!/usr/bin/env bash
# Crea una regla sudoers ACOTADA para que Salchipapa-Shell pueda cambiar el color
# de las carpetas de Papirus (que vive en /usr/share, de root) SIN pedir contraseña.
# Solo permite ejecutar papirus-folders como root; nada más.
#
# Ejecútalo UNA vez:   sudo bash scripts/instalar-papirus-sudo.sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecútalo con sudo:  sudo bash scripts/instalar-papirus-sudo.sh" >&2
    exit 1
fi

user_name="${SUDO_USER:-$(id -un)}"
pf="$(command -v papirus-folders 2>/dev/null || echo /usr/bin/papirus-folders)"
file="/etc/sudoers.d/salchipapa-papirus-folders"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

printf '%s ALL=(root) NOPASSWD: %s\n' "$user_name" "$pf" >"$tmp"

# Validar la sintaxis ANTES de instalar (nunca dejar un sudoers roto).
if visudo -cf "$tmp" >/dev/null; then
    install -m 0440 -o root -g root "$tmp" "$file"
    echo "OK: regla creada en $file"
    echo "    $user_name puede ejecutar '$pf' como root sin contraseña."
    echo "    A partir de ahora el color de las carpetas seguirá al tema."
else
    echo "ERROR: la regla sudoers no es válida; no se instaló nada." >&2
    exit 1
fi
