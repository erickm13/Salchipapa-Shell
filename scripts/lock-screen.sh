#!/usr/bin/env bash
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$HOME/proyects/Salchipapa-Shell}"

exec qs ipc --path "$repo/shell/shell.qml" call salchipapa-lock activate
