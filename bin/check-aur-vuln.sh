#!/usr/bin/env bash
#
# AUR Malware (deps) Comprehensive Detection Script
# ================================================
# Based on: https://ioctl.fail/preliminary-analysis-of-aur-malware/
#           https://md.archlinux.org/s/SxbqukK6IA (official Arch Linux infected packages list)
#
# PHASE 1: Check installed AUR packages against the known infected list
# PHASE 2: Deep-scan ALL AUR packages for malware indicators (deps binary,
#          persistence, eBPF rootkit, C2 connections, npm/bun artifacts, staging)
#
# Requires: pacman, curl, jq (recommended), sha256sum, ss
#

# Note: intentionally NOT using 'set -e' — this is a detection script where
# many commands are expected to return non-zero (grep no match, curl timeout, etc.)
set -uo pipefail

# ==============================
# Parse arguments
# ==============================
PARANOID=0
FULL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --paranoid) PARANOID=1; shift ;;
    --full)     FULL=1; shift ;;
    -h|--help)
      echo "Usage: check-aur-vuln.sh [--paranoid] [--full]"
      echo ""
      echo "  --paranoid  Scan ALL filesystems including /mnt, /media, /run, /proc, /dev"
      echo "              (slower, but more thorough — useful if you suspect the malware"
      echo "              was copied to an external drive or unusual mount point)"
      echo ""
      echo "  --full      Also scan pacman logs for historical installs, check bun cache,"
      echo "              and run all optional checks (npm cache, bun cache, systemd,"
      echo "              eBPF rootkit). Without --full, only Phase 1 and Phase 2 run."
      echo ""
      echo "Without --paranoid, the scan excludes /mnt, /media, /run, /proc, /dev"
      echo "to avoid scanning large media libraries and virtual filesystems."
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ==============================
# Known indicators from analysis
# ==============================
MALWARE_SHA256="6144D433F8A0316869877B5F834C801251BBB936E5F1577C5680878C7443C98B"
MALWARE_MD5="42B59FDBE1B72895B2951412222EBF40"
C2_ONION="olrh4mibs62l6kkuvvjyc5lrercqg5tz543r4lsw3o6mh5qb7g7sneid.onion"
UPLOAD_HOST="temp.sh"
NPM_PACKAGE="atomic-lockfile"
NPM_VERSION="1.4.2"
PAYLOAD_PATH="src/hooks/deps"
ATTACK_START=$(date -d "2026-06-09 00:00:00" +%s 2>/dev/null || echo 1750000000)
ATTACK_END=$(date -d "2026-06-12 23:59:59" +%s 2>/dev/null || echo 1750432000)

# Malicious npm/bun package names (Wave 1 + Wave 2)
MALICIOUS_NPM_PKGS=(
  atomic-lockfile
  lockfile-js
  js-digest
  nextfile-js
)

# Infected packages list URLs — all are fetched and merged into one deduplicated list
INFECTED_LIST_URLS=(
  "https://md.archlinux.org/s/SxbqukK6IA"
  "https://cscs.pastes.sh/raw/aurvulnlist20260611.txt"
  "https://gist.githubusercontent.com/quantenProjects/3f768dce7331618310f016d975bf8547/raw/beef579f8a8efeed6ccf60788e5b768775550095/packages"
)

# Temp file for fast lookup
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

# ==============================
# Fetch or load infected packages list
# ==============================
echo "Fetching latest infected packages list..."

# Temp file for merging all sources
merged_tmp=$(mktemp)

fetched=0
for url in "${INFECTED_LIST_URLS[@]}"; do
  raw=$(curl -sL --max-time 10 "$url" 2>/dev/null) || continue
  [[ -z "$raw" ]] && continue

  # Detect format and extract package names
  if echo "$raw" | grep -q '<!DOCTYPE\|<html'; then
    # HedgeDoc returns HTML — strip tags, extract package names
    echo "$raw" | sed 's/<[^>]*>//g' | \
      grep -E '^[a-z0-9][a-z0-9_.+\-]*$' >> "$merged_tmp" || continue
  elif echo "$raw" | grep -q '^INFECTED_PKGS=('; then
    # Gist returns bash script — extract from INFECTED_PKGS=(...) array
    echo "$raw" | sed -n '/^INFECTED_PKGS=(/,/^)/p' | \
      grep -oP '^\s+\K[a-z0-9._-]+' >> "$merged_tmp" || continue
  else
    # Plain text list — one package per line
    grep -E '^[a-z0-9][a-z0-9_.+\-]*$' <<< "$raw" >> "$merged_tmp" || continue
  fi

  count=$(grep -c . <<< "$raw" 2>/dev/null || echo 0)
  echo "  Fetched $url ($count lines)"
  fetched=1
done

# Merge with embedded list and deduplicate
{
  cat "$merged_tmp" 2>/dev/null
  printf '%s\n' "${INFECTED_PKGS[@]}"
} | sort -u > "$tmpfile"
rm -f "$merged_tmp"

list_count=$(wc -l < "$tmpfile")
if [[ $fetched -eq 0 ]]; then
  echo "  WARNING: All remote sources failed, using embedded list only"
else
  echo "  Combined and deduplicated: $list_count unique packages"
fi

# ==============================
# Embedded fallback list (used if fetch fails)
# ==============================
INFECTED_PKGS=(
123pan-bin 1code 8192eu-dkms-git actual-ai adblock2privoxy aion-git
albion-online-launcher-bin alienfx alvr android-signapk android-signapk-gui
android-support-repository annobin ansible-language-server antfs-cli-git
anythingllm-appimage anythingllm-cli-bin apk-installer-gui apm_planner-bin
apothem apple-music-desktop arch-update-vai archjh archlinux-themes-slim
archmage archtex-git arm-linux-gnueabihf-binutils artanis-git
astro-editor-appimage atomicwalet atomicwalllet autohand-cli autolabel
autologin azurlaneautoscript bcachefs-kernel-dkms-git beebeep bitcoin-core-git
blinkenlib blueproximity-py3-git booklore brow6el brow6el-git
canon-pixma-mg3000-complete-fixed cartridge-cli ccase-bin ccl-git cgminer
charcoal cinny-desktop-system-tray clai clang19 clash-mi cling-git cmuclmtk
cnijfilter-common codenomad-bin codeql-cli-bin cogpit-bin colorhug-client
colorz compiler-rt19 compizconfig-python coolreader cowdancer
cutefish-calculator cutefish-core cutefish-dock cutefish-filemanager
cutefish-icons cutefish-launcher cutefish-qt-plugins cutefish-screenlocker
cutefish-screenshot cutefish-settings cutefish-statusbar cutefish-wallpapers
cvs-feature-bin cynthiune.app dagu-bin datatype99 deheader dep dh-python
difi difi-bin doctoc dots-hyprland-fork-git dvdrip dyad-bin easy_spice
edconv-bin efiboots-git electrum-nmc elmerfem eisl
epson-inkjet-printer-escpr2-clos-bin exodas exodis exodud exoduss
exodus-wallet-bin exoduswallet exodux exoduz exodys exouds farmmod-hub
fastoggenc fastjet fatx fcitx5-pinyin-sougou-dict-git ffmpeg-bitrate-stats
ffmpeg-quality-metrics findpkg-git firefox-extension-adnauseam-bin-amo
firmium-desktop-git fishui fishui-git flashfocus flexiblas flynarwhal fmlib
forgecode-bin formidable-bin frame ftl frutool futhark-bin gdl gdlmm
git-annex-standalone gnome-contacts-git gnome-randr-rust gnutls3.8.9
gopher2600 gopher2600-bin gosh gpx-viewer graveman green-tunnel-bin
greetd-wlgreet-git gtkimageview guile-reader gummy gummy-git hackmatrix-git
harmony-wad headphones hearthstone-linux-gui-appimage hearthstone-linux-gui-bin
hepmc2 hister-git hnswlib-git horst hydownloader-git hydrus-git i3bar-river
ianny-bin ibm-sw-tpm2 ihaskell-git imageglass inadyn indicator-session
infnoise-openssl-git interface99 ios-webkit-debug-proxy ipfs-desktop-bin ipsw
iron-heart-git jasp-desktop jd-gui k3sup kdb kddockwidgets-git kexi kiss
ktea kookbook kproperty kreport latex-digsig lazylpsolverlibs-git
ledger-udev-bin lesstif lib32-egl-wayland libafterimage libbobcat libcutefish
libffi-static libgdata libjxl-noglycin libquvi libquvi-scripts
libretro-hatari-enhanced-git libxdiff libxml-ruby libyami
linux-cachyos-deckify-native linux-cachyos-deckify-native-headers
linux-cachyos-native linux-cachyos-native-headers
linux-cachyos-native-nvidia-open linux-cachyos-rc-native
linux-cachyos-rc-native-headers linux-cachyos-rc-native-nvidia-open
linux-tool liri-cmake-shared-git lite lll llvm-cbe-git lowfi-bin "ls++"
lucidvideo m5rcode magpie-wm mako-center-git manuskript maszyna-git
mathsat-5 matrixbrandy mcp-probe mcpatcher mermaid-ascii-git mermark-editor
mesa-dlss-reflex-git meteo mimic-node-git mingw-w64-geos
mingw-w64-libsndfile minimax-bin-hardened minitube misuzu-music-bin
mono-addins monochrome monochrome-git moor-git mount-gtk mopen n1-translator
naemon naemon-livestatus natapp nebuchadnezzar-git neovim-autopairs-git
neovim-nvim-treesitter nerf-pi neuro-karaoke-wrapper-git
new-api-privacy-filter new-api-privacy-filter-git nextcloud-app-audioplayer
nextcloud-app-facerecognition nextcloud-app-gpoddersync
nextcloud-app-integration-google nextcloud-app-repod
nextcloud-app-twofactor-gateway nextcloud-git nexus-bin nginx-mod-vts
nhentai-git nocodb noctyra-dotfiles-git noctyra-meta-git "notepad---bin"
nox-bin nrpe nwchem-bin ob-xd octocode opencode-codebase-index-bin openui5
opl-synth optimizevideo-git oracle-bin pacforge paper-desktop-bin paq8o
parallel-python pass-cli pelican-git penguin-subtitle-player
perl-proc-parallelloop perl-set-object perl-term-extendedcolor
phonon-qt5-vlc php-geoip php-legacy-memcache php-memcache
php-openswoole-git php-xdiff picom-ftlabs-git pidgin-kwallet pipetoys
pipewire-visualizer-git plex-media-player-custom plex-media-player-mod
plex-media-player-v2 premake-git prisma4postgres-bin
profile-sync-daemon-zen pymacs pypiserver pypy-setuptools python-apt
python-affine python-argdispatch python-awkward python-axolotl-git
python-calmjs python-celery python-cerealizer python-ci-info python-coolname
python-cu2qu-git python-dataproperty python-dbapi-compliance python-dictobject
python-dj-database-url python-django-modelcluster python-django-rest-knox
python-fastmcp-slim python-finnhub-python python-firebase-admin
python-fmu_manipulation_toolbox python-future python-g4f python-hist
python-histoprint python-hsaudiotag3k python-iminuit python-iso3166
python-isr-git python-jsmin python-json2xml python-luckydonald-utils
python-milvus-lite-bin python-mmcif python-monotonic python-mplhep
python-mplhep_data python-netaudio-git python-netaudio-lib
python-newspaper4k python-nipype python-nodejs-wheel python-openai-harmony
python-orange python-pdf2docx python-piecash python-pluginmgr
python-poetry-plugin-dotenv python-privy-git "python-pushbullet.py"
python-pychromecast-git python-pylsp-rope python-pymilvus
python-pysocks-git python-rembg python-scikit-hep-testdata
python-sklearn-pandas python-sqliteschema python-starlette-compress
python-starsessions python-steamcontroller-git python-tabledata
python-tarantool python-tradingeconomics python-uhi python-uproot
python-vector python-xtarfile python2-appdirs python2-fusepy python2-lazr-uri
python2-mutagen python2-notify python2-packaging python2-paver
python2-pyparsing python2-simplejson python2-simpleparse python2-stomper
python2-twodict-git python2-xlib qhttpengine qlementine qmdnsengine qnapi
qobuz-player-bin qtum-core quickswitch-i3 r-dbplyr reactphysics3d repoporge
retibbs-client-git rhythmbox-git rimworld rog-helper-git
ros2-humble-nav2-msgs rtspeccy-git ruah-orch ruby-excon
ruby-kramdown-rfc2629 ruby-selenium-webdriver runescape-launcher
sakura-launcher-gui sandlock screenpipe-bin sdcc-bin seahorse-nautilus
shhmsg shhopt slipnet slipnet-bin smenu smenu-git smolrtsp
smolrtsp-libevent snry-shell-qs soapyptezuka solara-kernel-headers
sonosano soundpaad-bin sshuttlee sshuttlee-bin stompbox-jack-git stripe-cli
stylelint-config-recommended subbrute sublist3r-git subprocess subsync svu
sway-xkb-switcher tack tarantool tesseract-gui thunar-nextcloud-plugin
thunderbird-conversations tinyemu tlpui-git torch7-git touchhle touchosc-bin
transcreen tsm ttf-material-design-icons-git tunacode-cli typing-game-cli
ukui-notification-daemon vapoursynth-preview-git vbam-git verso-git vidcutter
vim-easymotion vim-gitgutter vim-indent-object vim-molokai vim-pythonhelper
vim-solidity vim-vital vocalinux-git voquill-gpu wallpaper-generator-next
wayland-static we-layerd-git whatsie-git whisper2tr whisper2tr-git
windowmaker-git wine-nine wire-desktop word-snatchers-cli workbench
workbuddy-bin wrystr-git wsjtx-beta xf86-input-mtrack-git xorg-xfsinfo
xplot xpra-html5 xray-domain-list-community yarg yt6801-dkms yy
zathura-gruvbox-git zerx-lab-dida-bin zerx-lab-zed-nightly-bin zing-8-bin
zing-17-bin zing-21-bin zinnia-python zsdx
)

total_issues=0

# ============================================================
# PHASE 1: Known infected packages check
# ============================================================
echo ""
echo "=============================================="
echo " PHASE 1: Known infected AUR packages check"
echo "=============================================="
echo ""

installed_aur=$(pacman -Qmq 2>/dev/null)

if [[ -z "$installed_aur" ]]; then
  echo "No AUR packages installed."
  exit 0
fi

total_aur=$(echo "$installed_aur" | wc -l)
list_count=$(wc -l < "$tmpfile")
echo "Total AUR packages installed: $total_aur"
echo "Known infected packages in list: $list_count"
echo ""

# Find intersection
phase1_matches=()
while IFS= read -r pkg; do
  if grep -qx "$pkg" "$tmpfile"; then
    phase1_matches+=("$pkg")
  fi
done <<< "$installed_aur"

if [[ ${#phase1_matches[@]} -eq 0 ]]; then
  echo "Clean: None of the known infected packages are installed."
else
  echo "WARNING: ${#phase1_matches[@]} package(s) from the infected list are installed:"
  echo ""
  for pkg in "${phase1_matches[@]}"; do
    local_info=$(pacman -Qi "$pkg" 2>/dev/null || echo "N/A")
    install_date=$(echo "$local_info" | grep "Date" | head -1 | awk -F: '{print $2}' | xargs)
    version=$(echo "$local_info" | grep "Version" | head -1 | awk -F: '{print $2}' | xargs)
    install_ts=$(date -d "$install_date" +%s 2>/dev/null || echo 0)

    # Check if installed during attack window
    in_window="no"
    if [[ "$install_ts" -ge "$ATTACK_START" && "$install_ts" -le "$ATTACK_END" ]]; then
      in_window="YES - installed during attack window"
    fi

    # Query AUR API for current status
    aur_info=$(curl -s "https://aur.archlinux.org/rpc/v5/info/?arg=${pkg}&type=info" 2>/dev/null)
    if command -v jq &>/dev/null && [[ -n "$aur_info" ]]; then
      aur_version=$(echo "$aur_info" | jq -r '.results[0].Version // "N/A"')
      aur_outdated=$(echo "$aur_info" | jq -r '.results[0].Out-of-date // false')
      last_update_ts=$(echo "$aur_info" | jq -r '.results[0].LastPackageModified // 0')
      if [[ "$last_update_ts" != "0" && "$last_update_ts" != "null" ]]; then
        last_update=$(date -d "@$last_update_ts" '+%Y-%m-%d' 2>/dev/null || echo "N/A")
      else
        last_update="N/A"
      fi
    else
      aur_version="N/A"
      aur_outdated="N/A"
      last_update="N/A"
    fi

    echo "  $pkg"
    echo "    Local version: $version (installed: $install_date)"
    echo "    AUR version:   $aur_version (updated: $last_update)"
    echo "    Out-of-date:   $aur_outdated"
    echo "    Attack window: $in_window"

    if [[ "$version" != "$aur_version" && "$aur_version" != "N/A" ]]; then
      echo "    >>> LOCAL IS OUTDATED - reinstall from AUR <<<"
    fi
    echo ""
    total_issues=$((total_issues + 1))
  done
fi

# ============================================================
# PHASE 2: Deep-scan ALL AUR packages for malware indicators
# ============================================================
if [[ $PARANOID -eq 1 ]]; then
  SCAN_MODE="(paranoid — scanning all filesystems)"
else
  SCAN_MODE="(standard — excluding /mnt, /media, /proc, /sys, /dev, /run)"
fi
echo ""
echo "=============================================="
echo " PHASE 2: Deep-scan for deps malware indicators $SCAN_MODE"
echo "=============================================="
echo ""

phase2_issues=0

# 2.1 Check for the malware binary (deps) on the filesystem
echo "2.1 Scanning for malware binary (deps)..."
if command -v find &>/dev/null; then
  while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
      sha256=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
      md5=$(md5sum "$file" 2>/dev/null | awk '{print $1}')

      if [[ "$sha256" == "$MALWARE_SHA256" || "$md5" == "$MALWARE_MD5" ]]; then
        echo "  FOUND: $file"
        echo "    SHA256: $sha256"
        echo "    MD5:    $md5"
        phase2_issues=$((phase2_issues + 1))
      fi
    fi
  done < <(find / -name "deps" -type f \
    $(if [[ $PARANOID -eq 0 ]]; then echo \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -not -path "/dev/*" \
    -not -path "/mnt/*" \
    -not -path "/media/*" \
    -not -path "/run/*"; fi) \
    2>/dev/null)
fi
if [[ $phase2_issues -eq 0 ]]; then echo "  Clean."; fi

# 2.2 Check for malicious npm package (atomic-lockfile@1.4.2)
echo "2.2 Checking for malicious npm package..."
npm_found=0
if command -v npm &>/dev/null; then
  if npm list -g --depth=0 2>/dev/null | grep -q "$NPM_PACKAGE"; then
    echo "  FOUND: $NPM_PACKAGE installed globally"
    npm_found=1
  fi
  if npm list --depth=0 2>/dev/null | grep -q "$NPM_PACKAGE"; then
    echo "  FOUND: $NPM_PACKAGE installed locally"
    npm_found=1
  fi
fi
# Check npm cache
if [[ -d "$HOME/.npm" ]]; then
  while IFS= read -r dir; do
    if [[ -f "$dir/package.json" ]]; then
      version=$(grep '"version"' "$dir/package.json" | head -1 | awk -F: '{print $2}' | tr -d ' ",')
      if [[ "$version" == "$NPM_VERSION" ]]; then
        echo "  FOUND: $NPM_PACKAGE@$NPM_VERSION in npm cache at $dir"
        npm_found=1
      fi
    fi
  done < <(find "$HOME/.npm" -name "$NPM_PACKAGE" -type d 2>/dev/null)
fi
phase2_issues=$((phase2_issues + npm_found))
if [[ $npm_found -eq 0 ]]; then echo "  Clean."; fi

# 2.3 Check for persistence (systemd services)
echo "2.3 Checking for persistence..."
persist_found=0
if [[ -d "/var/lib" ]]; then
  while IFS= read -r service; do
    if grep -q "Restart=always" "$service" && grep -q "RestartSec=30" "$service"; then
      echo "  FOUND: Suspicious service $service"
      echo "    Contains: Restart=always, RestartSec=30"
      persist_found=$((persist_found + 1))
    fi
  done < <(find /var/lib -name "*.service" -type f 2>/dev/null)
fi
if [[ -d "$HOME/.config/systemd/user" ]]; then
  while IFS= read -r service; do
    if grep -q "Restart=always" "$service" && grep -q "RestartSec=30" "$service"; then
      echo "  FOUND: Suspicious user service $service"
      echo "    Contains: Restart=always, RestartSec=30"
      persist_found=$((persist_found + 1))
    fi
  done < <(find "$HOME/.config/systemd/user" -name "*.service" -type f 2>/dev/null)
fi
phase2_issues=$((phase2_issues + persist_found))
if [[ $persist_found -eq 0 ]]; then echo "  Clean."; fi

# 2.4 Check for eBPF rootkit
echo "2.4 Checking for eBPF rootkit..."
ebpf_found=0
if [[ -d "/sys/fs/bpf" ]]; then
  for map in hidden_pids hidden_names hidden_inodes; do
    if [[ -e "/sys/fs/bpf/$map" ]]; then
      echo "  FOUND: eBPF rootkit artifact /sys/fs/bpf/$map"
      ebpf_found=$((ebpf_found + 1))
    fi
  done
fi
phase2_issues=$((phase2_issues + ebpf_found))
if [[ $ebpf_found -eq 0 ]]; then echo "  Clean."; fi

# 2.5 Check for network connections to C2
echo "2.5 Checking for network connections..."
net_found=0
if command -v ss &>/dev/null; then
  if ss -tunap 2>/dev/null | grep -qE "($C2_ONION|$UPLOAD_HOST)"; then
    echo "  FOUND: Active connection to C2/upload host"
    net_found=1
  fi
fi
phase2_issues=$((phase2_issues + net_found))
if [[ $net_found -eq 0 ]]; then echo "  Clean."; fi

# 2.6 Check for credential theft indicators
echo "2.6 Checking for credential theft indicators..."
cred_found=0
if [[ -f "$HOME/.ssh/known_hosts" ]]; then
  if grep -qE "(temp\.sh|$C2_ONION)" "$HOME/.ssh/known_hosts" 2>/dev/null; then
    echo "  FOUND: Suspicious SSH known_hosts entries"
    cred_found=$((cred_found + 1))
  fi
fi
for hist_file in "$HOME/.bash_history" "$HOME/.zsh_history" "$HOME/.local/share/fish/fish_history"; do
  if [[ -f "$hist_file" ]]; then
    if grep -qE "(curl.*$C2_ONION|wget.*$C2_ONION|npm.*install.*$NPM_PACKAGE)" "$hist_file" 2>/dev/null; then
      echo "  FOUND: Suspicious command history in $hist_file"
      cred_found=$((cred_found + 1))
    fi
  fi
done
phase2_issues=$((phase2_issues + cred_found))
if [[ $cred_found -eq 0 ]]; then echo "  Clean."; fi

# 2.7 Check for staging path (monero-wallet-gui)
echo "2.7 Checking for staging indicators..."
stage_found=0
if [[ -f "/usr/bin/monero-wallet-gui" ]]; then
  file_age=$(stat -c %Y "/usr/bin/monero-wallet-gui" 2>/dev/null || echo 0)
  current_time=$(date +%s)
  age_days=$(( (current_time - file_age) / 86400 ))

  if [[ $age_days -lt 30 ]]; then
    echo "  FOUND: /usr/bin/monero-wallet-gui modified recently ($age_days days ago)"
    stage_found=1
  fi
fi
phase2_issues=$((phase2_issues + stage_found))
if [[ $stage_found -eq 0 ]]; then echo "  Clean."; fi

# 2.8 Check for npm lifecycle scripts in AUR package build dirs
echo "2.8 Checking for npm lifecycle scripts in AUR build dirs..."
npm_cache_found=0
if [[ -d "$HOME/.cache/yay" ]] || [[ -d "$HOME/.cache/paru" ]]; then
  for cache_dir in "$HOME/.cache/yay" "$HOME/.cache/paru"; do
    if [[ -d "$cache_dir" ]]; then
      while IFS= read -r pkg_json; do
        echo "  FOUND: Suspicious npm lifecycle in $pkg_json"
        npm_cache_found=$((npm_cache_found + 1))
      done < <(find "$cache_dir" -name "package.json" -exec grep -l "preinstall.*deps" {} \; 2>/dev/null)
    fi
  done
fi
phase2_issues=$((phase2_issues + npm_cache_found))
if [[ $npm_cache_found -eq 0 ]]; then echo "  Clean."; fi

# ============================================================
# PHASE 3: Optional deep checks (--full flag)
# ============================================================
if [[ $FULL -eq 1 ]]; then
  echo ""
  echo "=============================================="
  echo " PHASE 3: Optional deep checks (--full)"
  echo "=============================================="
  echo ""

  # 3.1 Check pacman logs for historical installs of infected packages
  echo "3.1 Scanning pacman logs for historical installs..."
  log_hits=()
  pacman_log_glob="/var/log/pacman.log*"
  for logfile in $pacman_log_glob; do
    [[ -e "$logfile" ]] || continue
    # Handle compressed logs
    read_cmd="cat"
    case "$logfile" in
      *.gz)  read_cmd="gzip -cd" ;;
      *.xz)  read_cmd="xz -cd" ;;
      *.zst) read_cmd="zstdcat" ;;
      *.bz2) read_cmd="bzip2 -cd" ;;
    esac
    while IFS= read -r line; do
      # Extract date from pacman log format: [YYYY-MM-DD HH:MM:SS]
      if [[ "$line" =~ ^\[([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        log_date="${BASH_REMATCH[1]}"
        log_ts=$(date -d "$log_date" +%s 2>/dev/null || echo 0)
        # Skip if outside attack window
        if [[ "$log_ts" -lt "$ATTACK_START" || "$log_ts" -gt "$ATTACK_END" ]]; then
          continue
        fi
        # Check if line contains an infected package being installed/upgraded/reinstalled
        if [[ "$line" =~ \[ALPM\]\ (installed|upgraded|reinstalled)\ ([^ ]+) ]]; then
          action="${BASH_REMATCH[1]}"
          pkg="${BASH_REMATCH[2]}"
          if grep -qx "$pkg" "$tmpfile"; then
            log_hits+=("$pkg ($action on $log_date)")
          fi
        fi
      fi
    done < <($read_cmd "$logfile" 2>/dev/null) || true
  done
  if [[ ${#log_hits[@]} -eq 0 ]]; then
    echo "  Clean: no historical log matches found."
  else
    echo "  WARNING: ${#log_hits[@]} historical install(s) of infected packages found:"
    for hit in "${log_hits[@]}"; do
      echo "    - $hit"
    done
    phase2_issues=$((phase2_issues + ${#log_hits[@]}))
  fi

  # 3.2 Check bun cache for malicious packages (Wave 2: js-digest)
  echo "3.2 Checking bun cache for malicious packages..."
  bun_found=0
  if command -v bun &>/dev/null; then
    bun_cache_dir=$(bun pm cache 2>/dev/null || echo "$HOME/.bun/install/cache")
    if [[ -d "$bun_cache_dir" ]]; then
      for pkg in "${MALICIOUS_NPM_PKGS[@]}"; do
        while IFS= read -r cached; do
          echo "  FOUND: $pkg in bun cache: $cached"
          bun_found=1
        done < <(find "$bun_cache_dir" -name "*${pkg}*" -type d 2>/dev/null | head -5)
      done
    fi
    # Also check bun pm cache ls
    for pkg in "${MALICIOUS_NPM_PKGS[@]}"; do
      if bun pm cache ls 2>/dev/null | grep -q "$pkg"; then
        echo "  FOUND: $pkg in bun cache listing"
        bun_found=1
      fi
    done
  fi
  phase2_issues=$((phase2_issues + bun_found))
  if [[ $bun_found -eq 0 ]]; then echo "  Clean."; fi

  # 3.3 Check npm cache for all malicious packages (Wave 1 + Wave 2)
  echo "3.3 Checking npm cache for all malicious packages..."
  npm_all_found=0
  if command -v npm &>/dev/null; then
    npm_cache_dir=$(npm config get cache 2>/dev/null)
    for pkg in "${MALICIOUS_NPM_PKGS[@]}"; do
      # Check npm cache ls
      if npm cache ls 2>/dev/null | grep -q "$pkg"; then
        echo "  FOUND: $pkg in npm cache listing"
        npm_all_found=1
      fi
      # Check global node_modules
      global_mod=$(npm root -g 2>/dev/null)/"$pkg"
      if [[ -d "$global_mod" ]]; then
        echo "  FOUND: $pkg in global node_modules"
        npm_all_found=1
      fi
      # Check npm cache directory
      if [[ -n "$npm_cache_dir" && -d "$npm_cache_dir" ]]; then
        while IFS= read -r cached; do
          echo "  FOUND: $pkg in npm cache directory: $cached"
          npm_all_found=1
        done < <(find "$npm_cache_dir" -name "*${pkg}*" -type d 2>/dev/null | head -5)
      fi
    done
  fi
  phase2_issues=$((phase2_issues + npm_all_found))
  if [[ $npm_all_found -eq 0 ]]; then echo "  Clean."; fi
fi

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "=============================================="
echo " SUMMARY"
echo "=============================================="
echo ""

total_issues=$((total_issues + phase2_issues))

echo "Phase 1 (known infected packages): $total_issues issue(s)"
echo "Phase 2 (deep malware scan):       $phase2_issues issue(s)"
if [[ $FULL -eq 1 ]]; then
  echo "Phase 3 (optional deep checks):    included"
fi
echo ""

if [[ $total_issues -eq 0 ]]; then
  echo "Clean: No indicators of the deps malware found on this system."
  echo ""
  echo "Note: This is a static check. If you suspect compromise,"
  echo "consider a full forensic analysis and credential rotation."
else
  echo "WARNING: $total_issues indicator(s) of the deps malware were found!"
  echo ""
  echo "Recommended actions:"
  echo "1. Treat this system as compromised"
  echo "2. Rotate all credentials (SSH keys, browser sessions, Slack,"
  echo "   Discord, GitHub, npm, Vault, Docker/Podman, VPN)"
  echo "3. Remove any suspicious systemd services"
  echo "4. Remove eBPF artifacts from /sys/fs/bpf/"
  echo "5. Reinstall affected AUR packages from clean sources"
  echo "6. Preserve evidence for forensic analysis"
  echo "7. Consider reinstalling the system from trusted media"
fi

echo ""
