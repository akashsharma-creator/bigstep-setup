#!/bin/bash
# =====================================================================
#  Bigstep new-PC setup - Ubuntu (also Debian / Linux Mint)
#
#  On a fresh PC, open Terminal (Ctrl+Alt+T) and run ONE line:
#     bash -c "$(wget -qO- https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/linux/setup.sh)"
#
#  Apps are listed in apps.txt. The script detects the PC's chip
#  (Intel/AMD = amd64, or ARM = arm64) and installs the latest version
#  for that chip from the vendor (.deb), the Snap Store, or Ubuntu's apt.
# =====================================================================

# ---- EDIT THESE TO MATCH YOUR GITHUB REPO ---------------------------
GITHUB_USER='akashsharma-creator'
REPO_NAME='bigstep-setup'
BRANCH='main'
# ---------------------------------------------------------------------

BASE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$BRANCH/linux"

if [ "$(uname -s)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then
    echo "This script is for Ubuntu / Debian Linux only. See https://$GITHUB_USER.github.io/$REPO_NAME/"
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then SUDO=''; else SUDO='sudo'; fi

LOG_DIR="$HOME/BigstepSetup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
trim()   { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

fetch() {   # $1 = URL, $2 = output file ("-" = stdout)
    if command -v wget >/dev/null 2>&1; then
        if [ "$2" = - ]; then wget -qO- "$1"; else wget -q --show-progress --tries=3 -O "$2" "$1"; fi
    else
        if [ "$2" = - ]; then curl -fsSL "$1"; else curl -fL --retry 3 --progress-bar -o "$2" "$1"; fi
    fi
}

# ---- 0. Detect the chip: Intel/AMD (amd64) or ARM (arm64) ---------------
ARCH="$(dpkg --print-architecture 2>/dev/null)"
CPU_NAME="$(lscpu 2>/dev/null | awk -F: '/^Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')"
. /etc/os-release 2>/dev/null
case "$ARCH" in
    amd64) CHIP='Intel/AMD 64-bit (amd64)' ;;
    arm64) CHIP='ARM 64-bit (arm64)' ;;
    *)     red "Unsupported processor type: ${ARCH:-unknown}. Only amd64 and arm64 are supported."; exit 1 ;;
esac
cyan "This PC: ${PRETTY_NAME:-Linux}, $CHIP - ${CPU_NAME:-unknown CPU}"

# ---- 1. Load the app list (local apps.txt next to the script, else GitHub)
SCRIPT_DIR=''
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/apps.txt" ]; then
    APP_LIST="$(cat "$SCRIPT_DIR/apps.txt")"
else
    cyan "Fetching app list from GitHub ($GITHUB_USER/$REPO_NAME)..."
    APP_LIST="$(fetch "$BASE_URL/apps.txt" -)" || { red 'Could not download the app list - check the internet connection.'; exit 1; }
fi

NAMES=(); DEFAULTS=(); SOURCES=()
while IFS='|' read -r name def amd arm; do
    name="$(trim "$name")"
    case "$name" in ''|'#'*) continue ;; esac
    amd="$(trim "$amd")"; arm="$(trim "$arm")"
    [ "$arm" = same ] && arm="$amd"
    NAMES+=("$name"); DEFAULTS+=("$(trim "$def")")
    if [ "$ARCH" = arm64 ]; then SOURCES+=("$arm"); else SOURCES+=("$amd"); fi
done <<< "$APP_LIST"
COUNT=${#NAMES[@]}

# ---- 2. Let the user choose which apps to install ----------------------
#      Desktop: zenity checkbox window. Terminal only: whiptail checklist.
#      Last resort: numbered text menu.
PICKED=()   # 1/0 per app, same order as NAMES
label() { [ "${SOURCES[$1]}" = '-' ] && echo "${NAMES[$1]} (not available for $ARCH)" || echo "${NAMES[$1]}"; }

pick_from() {   # $1 = list of chosen labels, one per line
    local i
    for ((i = 0; i < COUNT; i++)); do
        if grep -qxF "$(label "$i")" <<< "$1"; then PICKED[$i]=1; else PICKED[$i]=0; fi
    done
}

select_zenity() {
    command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 1
    local args=() i result
    for ((i = 0; i < COUNT; i++)); do
        [ "${DEFAULTS[$i]}" = 1 ] && [ "${SOURCES[$i]}" != '-' ] && args+=(TRUE) || args+=(FALSE)
        args+=("$(label "$i")")
    done
    result="$(zenity --list --checklist --title='Bigstep PC Setup' \
        --text='Tick the software to install on this PC, then click Install.' \
        --column='Install' --column='Software' --ok-label='Install' --cancel-label='Cancel' \
        --separator=$'\n' --width=460 --height=520 "${args[@]}" 2>/dev/null)"
    case $? in 0) ;; 1) return 2 ;; *) return 1 ;; esac   # 1 = Cancel, other = no display
    pick_from "$result"
}

select_whiptail() {
    command -v whiptail >/dev/null 2>&1 && [ -e /dev/tty ] || return 1
    local args=() i out
    for ((i = 0; i < COUNT; i++)); do
        args+=("$(label "$i")" '')
        [ "${DEFAULTS[$i]}" = 1 ] && [ "${SOURCES[$i]}" != '-' ] && args+=(ON) || args+=(OFF)
    done
    out="$(mktemp)"
    # whiptail draws on the terminal and writes the result to stderr
    whiptail --title 'Bigstep PC Setup' --separate-output --ok-button 'Install' --cancel-button 'Cancel' \
        --checklist 'Space = tick/untick, arrows = move, Enter = Install' 22 64 $COUNT "${args[@]}" \
        < /dev/tty > /dev/tty 2> "$out"
    local rc=$?
    local result; result="$(cat "$out")"; rm -f "$out"
    case $rc in 0) ;; 1) return 2 ;; *) return 1 ;; esac   # 1 = Cancel, other = can't draw
    pick_from "$result"
}

select_console() {
    local i n input
    for ((i = 0; i < COUNT; i++)); do PICKED[$i]="${DEFAULTS[$i]}"; done
    while true; do
        echo
        cyan 'Choose software to install (number = tick/untick, A = all, N = none, Enter = install, Q = quit):'
        for ((i = 0; i < COUNT; i++)); do
            if [ "${PICKED[$i]}" = 1 ]; then mark='[X]'; else mark='[ ]'; fi
            printf '  %2d. %s %s\n' $((i + 1)) "$mark" "$(label "$i")"
        done
        read -r -p 'Your choice: ' input < /dev/tty
        input="$(trim "$input")"
        case "$input" in
            '')    return 0 ;;
            [Qq])  return 2 ;;
            [Aa])  for ((i = 0; i < COUNT; i++)); do PICKED[$i]=1; done ;;
            [Nn])  for ((i = 0; i < COUNT; i++)); do PICKED[$i]=0; done ;;
            *)     for n in ${input//,/ }; do
                       case "$n" in *[!0-9]*|'') continue ;; esac
                       if [ "$n" -ge 1 ] && [ "$n" -le "$COUNT" ]; then
                           i=$((n - 1)); PICKED[$i]=$((1 - PICKED[$i]))
                       fi
                   done ;;
        esac
    done
}

select_zenity; rc=$?
if [ $rc -eq 1 ]; then select_whiptail; rc=$?; fi
if [ $rc -eq 1 ]; then select_console;  rc=$?; fi
SELECTED=()
for ((i = 0; i < COUNT; i++)); do [ "${PICKED[$i]}" = 1 ] && SELECTED+=("$i"); done
if [ $rc -eq 2 ] || [ ${#SELECTED[@]} -eq 0 ]; then
    yellow 'Nothing selected - exiting.'
    exit 0
fi
sel_names=''; for i in "${SELECTED[@]}"; do sel_names+="${sel_names:+, }${NAMES[$i]}"; done
green "Selected: $sel_names"

# ---- 3. Ask for the password once and keep it for the whole run --------
if [ -n "$SUDO" ]; then
    yellow 'Installing needs administrator rights. Type your password (nothing is shown while you type):'
    sudo -v < /dev/tty || { red 'Administrator password needed - exiting.'; exit 1; }
    while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
fi

apt_get() { $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=600 "$@"; }

cyan 'Updating package lists so the latest versions are installed...'
apt_get update -qq
apt_get install -qq ca-certificates wget >/dev/null

# ---- 4. Install methods ------------------------------------------------
install_deb_file() {   # $1 = local .deb; apt installs it with its dependencies (upgrades if older is installed)
    chmod 644 "$1"
    apt_get install "$1"
}

install_deb_url() {   # $1 = URL of a .deb
    local tmp rc
    tmp="$(mktemp -d /tmp/bigstep.XXXXXX)"; chmod 755 "$tmp"
    echo "  Downloading latest $ARCH version from the vendor..."
    fetch "$1" "$tmp/package.deb" && install_deb_file "$tmp/package.deb"; rc=$?
    rm -rf "$tmp"
    return $rc
}

install_debrepo() {   # $1 = <repo>/dists/<dist>/<component>#<package>
    local index="${1%%#*}/binary-$ARCH/Packages" pkg="${1##*#}" base="${1%%/dists/*}" file
    # Newest version of the package for this chip, from the vendor's repo index
    file="$(fetch "$index" - | awk -v p="$pkg" '
        /^Package: / { cur = $2 } /^Version: / { ver = $2 }
        /^Filename: / && cur == p { print ver " " $2 }' | sort -V | tail -n 1 | cut -d' ' -f2)"
    [ -n "$file" ] || { red "  $pkg not found for $ARCH in $index"; return 1; }
    install_deb_url "$base/$file"
}

install_snap() {   # $1 = snap name
    if ! command -v snap >/dev/null 2>&1; then
        echo '  Installing snap support...'
        apt_get install -qq snapd >/dev/null || return 1
    fi
    if snap list "$1" >/dev/null 2>&1; then
        echo '  Already installed - updating to the latest version...'
        $SUDO snap refresh "$1"
    else
        $SUDO snap install "$1" 2>/dev/null || $SUDO snap install "$1" --classic
    fi
}

install_apt() {   # $1 = package[,fallback...]
    local p
    for p in ${1//,/ }; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            apt_get install "$p" && { VIA="apt ($p)"; return 0; }
        fi
    done
    return 1
}

install_app() {   # $1 = app index. Sets VIA to how it was installed.
    local src="${SOURCES[$1]}"
    VIA='-'
    case "$src" in
        -)          yellow "  Not available for $ARCH - skipped."; VIA='not for this chip'; return 2 ;;
        deb:*)      install_deb_url "${src#deb:}"  && { VIA="vendor .deb ($ARCH)"; return 0; } ;;
        debrepo:*)  install_debrepo "${src#debrepo:}" && { VIA="vendor .deb ($ARCH)"; return 0; } ;;
        snap:*)     install_snap "${src#snap:}"    && { VIA='snap'; return 0; } ;;
        apt:*)      install_apt "${src#apt:}"      && return 0 ;;
        *)          red "  Unknown source in apps.txt: $src" ;;
    esac
    return 1
}

# ---- 5. Install / upgrade the selected apps ----------------------------
RESULTS=()
START=$(date +%s)
n=0
for i in "${SELECTED[@]}"; do
    n=$((n + 1))
    echo; cyan "=== [$n/${#SELECTED[@]}] ${NAMES[$i]} ==="
    t0=$(date +%s)
    install_app "$i"
    case $? in 0) status='OK' ;; 2) status='SKIPPED' ;; *) status='FAILED' ;; esac
    mins=$(awk "BEGIN { printf \"%.1f\", ($(date +%s) - $t0) / 60 }")
    echo "  $status in $mins min"
    RESULTS+=("$(printf '%-32s %-8s %-22s %s' "${NAMES[$i]}" "$status" "$VIA" "$mins")")
done

# ---- 6. Summary --------------------------------------------------------
total=$(awk "BEGIN { printf \"%.1f\", ($(date +%s) - $START) / 60 }")
echo; cyan "================ SUMMARY - $CHIP ($total min total) ================"
printf '%-32s %-8s %-22s %s\n' 'App' 'Status' 'Installed via' 'Minutes'
printf '%-32s %-8s %-22s %s\n' '---' '------' '-------------' '-------'
for r in "${RESULTS[@]}"; do echo "$r"; done
echo; echo "Log saved in $LOG_DIR"
green 'Done. Restart the PC to finish.'
