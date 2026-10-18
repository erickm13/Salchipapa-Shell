#!/usr/bin/env bash
set -euo pipefail

color=$1
range=$2
offset=$3

hyprctl eval "hl.config({
    ['decoration.shadow.color'] = '$color',
    ['decoration.shadow.color_inactive'] = '$color',
    ['decoration.shadow.range'] = $range,
    ['decoration.shadow.offset'] = {0, $offset},
})" >/dev/null
