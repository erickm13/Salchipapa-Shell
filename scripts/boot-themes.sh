#!/usr/bin/env bash
# Temas de la pantalla de login (SDDM) y del arranque (GRUB), para Ajustes > Login & Boot.
#   boot-themes.sh list              -> JSON { sddm: {current, themes:[{name, preview, video}]}, grub: {...} }
#   boot-themes.sh apply sddm|grub <tema>
# Aplicar usa /usr/local/bin/{sddm,grub}-theme-apply (de bin/) con la regla sudoers sin contraseña
# que crea install.sh; sin ella, pkexec (la contraseña la pide la isla).
set -euo pipefail

sddm_dir=/usr/share/sddm/themes
grub_dir=/boot/grub/themes
thumbs="${XDG_CACHE_HOME:-$HOME/.cache}/salchipapa-shell/boot-thumbs"
mkdir -p "$thumbs"

# La misma búsqueda de vista previa que tenía theme-picker
preview_of() {
    local dir="$1" name="$2" f sub
    for f in preview.png preview.jpg Preview.png screenshot.png bg.png bg.jpg background.png background.jpg \
        "$name.png" "$name.jpg" "${name,,}.png" "${name,,}.jpg"; do
        [ -f "$dir/$f" ] && {
            echo "$dir/$f"
            return
        }
    done
    for sub in screenshots preview background images assets .; do
        f=$(find "$dir/$sub" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | sort | head -1)
        [ -n "$f" ] && {
            echo "$f"
            return
        }
    done
    echo ""
}

themes_json() {
    local base="$1" need="$2" d name preview video
    [ -d "$base" ] || {
        echo "[]"
        return
    }
    for d in "$base"/*/; do
        d="${d%/}"
        name="$(basename "$d")"
        [ -n "$need" ] && [ ! -f "$d/$need" ] && continue
        # Los que trae SDDM de serie (los ocultaba también el script sddm-theme)
        [ "$base" = "$sddm_dir" ] && case "$name" in elarun | maldives | maya) continue ;; esac
        preview="$(preview_of "$d" "$name")"
        video="$(find "$d" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' \) | sort | head -1)"
        # Solo vídeo de fondo: un fotograma como vista previa (en caché)
        if [ -z "$preview" ] && [ -n "$video" ]; then
            [ -s "$thumbs/$name.jpg" ] ||
                ffmpeg -v quiet -ss 1 -i "$video" -frames:v 1 -vf scale=480:-1 -y "$thumbs/$name.jpg" </dev/null || true
            [ -s "$thumbs/$name.jpg" ] && preview="$thumbs/$name.jpg"
        fi
        jq -n --arg name "$name" --arg preview "$preview" --arg video "$video" \
            '{name: $name, preview: $preview, video: $video}'
    done | jq -s .
}

case "${1:-}" in
list)
    # (|| true: sin /etc/sddm.conf o sin GRUB, sed falla y pipefail cortaría el script)
    sddm_current=$( (sed -n 's/^Current=//p' /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null || true) | tail -1)
    grub_current=$( (sed -n 's|^GRUB_THEME="\?.*/themes/\([^/]*\)/.*|\1|p' /etc/default/grub 2>/dev/null || true) | tail -1)
    jq -n --arg sc "$sddm_current" --arg gc "$grub_current" \
        --argjson st "$(themes_json "$sddm_dir" "")" --argjson gt "$(themes_json "$grub_dir" theme.txt)" \
        '{sddm: {current: $sc, themes: $st}, grub: {current: $gc, themes: $gt}}'
    ;;
apply)
    kind="${2:?sddm o grub}"
    theme="${3:?falta el tema}"
    case "$kind" in
    sddm) helper=/usr/local/bin/sddm-theme-apply ;;
    grub) helper=/usr/local/bin/grub-theme-apply ;;
    *)
        echo "tipo desconocido: $kind" >&2
        exit 1
        ;;
    esac
    [ -x "$helper" ] || {
        echo "falta $helper (lo instala install.sh)" >&2
        exit 1
    }
    sudo -n "$helper" "$theme" 2>/dev/null || pkexec "$helper" "$theme"
    ;;
*)
    echo "uso: boot-themes.sh list | apply sddm|grub <tema>" >&2
    exit 1
    ;;
esac
