#!/usr/bin/env bash
# Genera shell/assets/emojis.json para el selector de emojis de la isla (Super+.).
# Fuentes: emojibase (nombres y etiquetas en español + inglés, categorías) y los glifos de
# Nerd Fonts. Se ejecuta a mano para actualizar; el resultado va versionado en el repo.
#   [{e: carácter, n: nombre, k: palabras para buscar, g: grupo}]
#   g: 0-9 = categorías de emojibase (sin "componentes"), 10 = Nerd Font
# Solo emojis hasta la versión que dibuja la fuente (noto-fonts-emoji 2.051 llega a Emoji 16):
# los más nuevos salen como un recuadro. Subirlo cuando se actualice la fuente.
set -euo pipefail

max_version="${MAX_EMOJI_VERSION:-16}"

repo="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
out="$repo/shell/assets/emojis.json"
base=https://raw.githubusercontent.com/milesj/emojibase/refs/heads/master/packages/data
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$base/es/data.raw.json" -o "$tmp/es.json"
curl -fsSL "$base/en/data.raw.json" -o "$tmp/en.json"
curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/glyphnames.json -o "$tmp/nerd.json"

# Símbolos útiles que no son emojis (los traía el selector de caelestia)
extras='[
  {"e":"¿?","n":"interrogación de apertura y cierre","k":"pregunta question spanish"},
  {"e":"¡!","n":"exclamación de apertura y cierre","k":"exclamation spanish"},
  {"e":"←","n":"flecha izquierda","k":"left arrow"}, {"e":"↑","n":"flecha arriba","k":"up arrow"},
  {"e":"→","n":"flecha derecha","k":"right arrow"}, {"e":"↓","n":"flecha abajo","k":"down arrow"},
  {"e":"⇆","n":"flechas izquierda y derecha","k":"arrows swap"},
  {"e":"•","n":"punto medio","k":"bullet dot separator"}, {"e":"·","n":"punto centrado","k":"middle dot interpunct"},
  {"e":"…","n":"puntos suspensivos","k":"ellipsis"},
  {"e":"«»","n":"comillas latinas","k":"quotes guillemets"}, {"e":"「」","n":"comillas japonesas","k":"japanese quote brackets"},
  {"e":"¯\\_(ツ)_/¯","n":"encogerse de hombros","k":"shrug idk no se"},
  {"e":"↵","n":"tecla enter","k":"enter return key"}, {"e":"⌘","n":"tecla comando","k":"command key mac"},
  {"e":"°","n":"grados","k":"degrees temperatura"}, {"e":"±","n":"más o menos","k":"plus minus"},
  {"e":"×","n":"multiplicación","k":"times multiply por"}, {"e":"÷","n":"división","k":"divide entre"},
  {"e":"≈","n":"aproximadamente","k":"approx"}, {"e":"≠","n":"distinto","k":"not equal"},
  {"e":"≤","n":"menor o igual","k":"less equal"}, {"e":"≥","n":"mayor o igual","k":"greater equal"},
  {"e":"∞","n":"infinito","k":"infinity"}, {"e":"€","n":"euro","k":"euro money dinero"},
  {"e":"™","n":"marca registrada (TM)","k":"trademark tm"}, {"e":"®","n":"marca registrada","k":"registered"},
  {"e":"©","n":"copyright","k":"copyright derechos"}, {"e":"—","n":"raya","k":"em dash guion largo"},
  {"e":"–","n":"semirraya","k":"en dash guion"}
]'

jq -c -n --slurpfile es "$tmp/es.json" --slurpfile en "$tmp/en.json" --slurpfile nerd "$tmp/nerd.json" \
    --argjson extras "$extras" --argjson maxv "$max_version" '
    ($en[0] | map({key: .hexcode, value: .}) | from_entries) as $byHex |
    [ $es[0][] | select(.group != null and .group != 2 and (.version // 0) <= $maxv) |
      ($byHex[.hexcode] // {}) as $e |
      { e: .emoji, n: .label, g: .group,
        k: ([.label] + (.tags // []) + [$e.label // ""] + ($e.tags // []) + [(.emoticon // empty) | if type == "array" then .[] else . end]
            | map(ascii_downcase) | unique | join(" ")) } ] +
    ($extras | map(. + {g: 8, k: ((.n + " " + .k) | ascii_downcase)})) +
    [ $nerd[0] | to_entries[] | select(.key != "METADATA") |
      { e: .value.char, n: (.key | ltrimstr("nf-")), g: 10, k: (.key | ltrimstr("nf-") | gsub("[-_]"; " ")) } ]
' >"$out"

echo "$(jq length "$out") entradas -> $out"
