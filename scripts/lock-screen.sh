#!/usr/bin/env bash
set -euo pipefail

repo="${SALCHIPAPA_SHELL_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"

exec qs ipc --path "$repo/shell/shell.qml" call salchipapa-lock activate
