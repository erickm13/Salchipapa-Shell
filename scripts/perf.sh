#!/usr/bin/env bash
# Datos para la página "Performance" de la isla (Super+Shift+Esc). Imprime un JSON:
#   cpu   {model, threads, temp}            temp en °C (coretemp/k10temp), o null
#   mem   {MemTotal, MemAvailable, SwapTotal, SwapFree, Cached, Buffers, Committed_AS}  en bytes
#   gpus  [{kind: nvidia|intel|amd, name, state, util, memUsed, memTotal, temp, power, freq, maxFreq,
#          memFreq, pstate}]                 freq/maxFreq/memFreq en MHz (NVIDIA solo si está despierta)
#   disks [{mount, size, used}]              particiones reales (/dev/…), en bytes
#   io    {dev, model, temp, read, write}    disco de / : contadores en bytes (la isla calcula la velocidad)
#   fans  [{label, rpm}]
#   net   {iface, rx, tx}                    contadores en bytes (la isla calcula la velocidad)
# OJO: nvidia-smi DESPIERTA la GPU si está dormida (gasta batería): solo se consulta si ya está activa.
set -uo pipefail

hwmon_by_name() {
    local h
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] && {
            echo "$h"
            return
        }
    done
}

# --- CPU ---
model=$(sed -n 's/^model name\s*:\s*//p' /proc/cpuinfo | head -1)
threads=$(nproc)
cpu_hw=$(hwmon_by_name coretemp)
[ -n "$cpu_hw" ] || cpu_hw=$(hwmon_by_name k10temp)
cpu_temp=null
[ -n "$cpu_hw" ] && [ -r "$cpu_hw/temp1_input" ] && cpu_temp=$(($(cat "$cpu_hw/temp1_input") / 1000))

# --- Memoria (kB -> bytes) ---
mem=$(awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree|Cached|Buffers|Committed_AS):/ { gsub(":", "", $1); printf "\"%s\": %d, ", $1, $2 * 1024 }' /proc/meminfo)
mem="{ ${mem%, } }"

# --- GPUs ---
gpus="[]"
for d in /sys/bus/pci/devices/*; do
    [[ "$(cat "$d/class")" == 0x03* ]] || continue
    vendor=$(cat "$d/vendor")
    case "$vendor" in
    0x10de)
        state=$(cat "$d/power/runtime_status" 2>/dev/null || echo active)
        g=$(jq -n --arg state "$state" '{kind: "nvidia", name: "NVIDIA", state: $state}')
        if [ "$state" != "suspended" ] && command -v nvidia-smi >/dev/null; then
            IFS=',' read -r name util mu mt temp power clk clkmax clkmem pstate < <(nvidia-smi \
                --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr,clocks.max.gr,clocks.mem,pstate \
                --format=csv,noheader,nounits 2>/dev/null | head -1)
            [ -n "${name:-}" ] && g=$(jq -n --arg state "$state" --arg name "$(echo "$name" | sed 's/^ *//')" \
                --argjson util "${util// /}" --argjson mu "${mu// /}" --argjson mt "${mt// /}" \
                --argjson temp "${temp// /}" --arg power "${power// /}" --arg clk "${clk// /}" \
                --arg clkmax "${clkmax// /}" --arg clkmem "${clkmem// /}" --arg pstate "${pstate// /}" \
                '{kind: "nvidia", name: $name, state: $state, util: $util, memUsed: ($mu * 1048576),
                  memTotal: ($mt * 1048576), temp: $temp, power: ($power | tonumber? // null),
                  freq: ($clk | tonumber? // null), maxFreq: ($clkmax | tonumber? // null),
                  memFreq: ($clkmem | tonumber? // null), pstate: $pstate}')
        fi
        ;;
    0x8086 | 0x1002)
        kind=$([ "$vendor" = 0x8086 ] && echo intel || echo amd)
        card=$(ls -d "$d"/drm/card* 2>/dev/null | head -1)
        cur=$(cat "$card/gt_cur_freq_mhz" 2>/dev/null || echo null)
        max=$(cat "$card/gt_max_freq_mhz" 2>/dev/null || echo null)
        g=$(jq -n --arg kind "$kind" --argjson cur "$cur" --argjson max "$max" \
            '{kind: $kind, name: (if $kind == "intel" then "Intel (integrated)" else "AMD" end), state: "active", freq: $cur, maxFreq: $max}')
        ;;
    *) continue ;;
    esac
    gpus=$(jq -c --argjson g "$g" '. + [$g]' <<<"$gpus")
done

# --- Discos (solo particiones reales; cada dispositivo una vez) ---
disks=$(df -B1 --output=source,target,size,used -x tmpfs -x devtmpfs -x efivarfs -x overlay 2>/dev/null |
    awk 'NR > 1 && $1 ~ "^/dev/" && !seen[$1]++ { printf "{\"mount\": \"%s\", \"size\": %s, \"used\": %s}\n", $2, $3, $4 }' | jq -s -c .)

# --- Disco de / : modelo, temperatura (NVMe) y bytes leídos/escritos (/proc/diskstats, sectores de 512) ---
root_src=$(findmnt -no SOURCE / 2>/dev/null)
root_dev=$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -1)
[ -n "$root_dev" ] || root_dev=$(basename "${root_src:-}")
io='{}'
if [ -n "$root_dev" ] && [ -d "/sys/block/$root_dev" ]; then
    io_model=$(sed 's/ *$//' "/sys/block/$root_dev/device/model" 2>/dev/null)
    io_temp=null
    for h in /sys/block/$root_dev/device/hwmon*/temp1_input /sys/block/$root_dev/device/device/hwmon/hwmon*/temp1_input; do
        [ -r "$h" ] && io_temp=$(($(cat "$h") / 1000)) && break
    done
    read -r rd wr < <(awk -v d="$root_dev" '$3 == d { print $6 * 512, $10 * 512 }' /proc/diskstats)
    io=$(jq -n -c --arg dev "$root_dev" --arg model "${io_model:-}" --argjson temp "$io_temp" \
        --argjson read "${rd:-0}" --argjson write "${wr:-0}" '{dev: $dev, model: $model, temp: $temp, read: $read, write: $write}')
fi

# --- Ventiladores (hwmon con fanN_input; el ASUS los etiqueta cpu_fan/gpu_fan/mid_fan) ---
fans=$(for f in /sys/class/hwmon/hwmon*/fan*_input; do
    [ -r "$f" ] || continue
    label=$(cat "${f%_input}_label" 2>/dev/null || basename "${f%_input}")
    printf '{"label": "%s", "rpm": %s}\n' "$label" "$(cat "$f")"
done | jq -s -c .)

# --- Red: interfaz de la ruta por defecto ---
iface=$(ip route show default 2>/dev/null | awk '{ print $5; exit }')
rx=0 tx=0
[ -n "$iface" ] && [ -r "/sys/class/net/$iface/statistics/rx_bytes" ] &&
    rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes") tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes")

jq -n -c --arg model "$model" --argjson threads "$threads" --argjson temp "$cpu_temp" --argjson mem "$mem" \
    --argjson gpus "$gpus" --argjson disks "${disks:-[]}" --argjson io "$io" --argjson fans "${fans:-[]}" \
    --arg iface "${iface:-}" --argjson rx "$rx" --argjson tx "$tx" \
    '{cpu: {model: $model, threads: $threads, temp: $temp}, mem: $mem, gpus: $gpus, disks: $disks, io: $io,
      fans: $fans, net: {iface: $iface, rx: $rx, tx: $tx}}'
