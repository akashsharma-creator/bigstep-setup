#!/bin/bash
# =====================================================================
#  Bigstep new-Mac setup
#
#  On a fresh Mac, open Terminal and run ONE line:
#     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/akashsharma-creator/bigstep-setup/main/macos/setup.sh)"
#
#  Apps are listed in apps.txt. The script detects the Mac's chip
#  (Intel or Apple M-series) and downloads the matching latest version
#  straight from the vendor. Apps without a direct link (or whose download
#  fails) are installed with Homebrew, which also picks the right chip.
#  Written for the bash 3.2 that ships with macOS.
# =====================================================================

# ---- EDIT THESE TO MATCH YOUR GITHUB REPO ---------------------------
GITHUB_USER='akashsharma-creator'
REPO_NAME='bigstep-setup'
BRANCH='main'
# ---------------------------------------------------------------------

BASE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$BRANCH/macos"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script is for macOS only. See https://$GITHUB_USER.github.io/$REPO_NAME/"
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Please run this WITHOUT sudo - it will ask for your password when needed."
    exit 1
fi

LOG_DIR="$HOME/BigstepSetup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
trim()   { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# ---- 0. Detect the chip: Intel or Apple M-series -----------------------
#      hw.optional.arm64 is 1 on Apple Silicon even if Terminal runs under Rosetta.
CPU_NAME="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then
    IS_ARM=1; CHIP="Apple M-series (Apple Silicon)"
else
    IS_ARM=0; CHIP="Intel"
fi
cyan "This Mac: $CHIP - ${CPU_NAME:-unknown CPU}, macOS $(sw_vers -productVersion 2>/dev/null)"

# ---- 1. Load the app list (local apps.txt next to the script, else GitHub)
SCRIPT_DIR=''
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/apps.txt" ]; then
    APP_LIST="$(cat "$SCRIPT_DIR/apps.txt")"
else
    cyan "Fetching app list from GitHub ($GITHUB_USER/$REPO_NAME)..."
    APP_LIST="$(curl -fsSL "$BASE_URL/apps.txt")" || { red 'Could not download the app list - check the internet connection.'; exit 1; }
fi

NAMES=(); DEFAULTS=(); KINDS=(); IDS=(); URLS=()
while IFS='|' read -r name def kind id intel arm; do
    name="$(trim "$name")"
    case "$name" in ''|'#'*) continue ;; esac
    intel="$(trim "$intel")"; arm="$(trim "$arm")"
    [ "$arm" = same ] && arm="$intel"
    NAMES+=("$name"); DEFAULTS+=("$(trim "$def")"); KINDS+=("$(trim "$kind")"); IDS+=("$(trim "$id")")
    if [ "$IS_ARM" = 1 ]; then URLS+=("$arm"); else URLS+=("$intel"); fi
done <<< "$APP_LIST"
COUNT=${#NAMES[@]}

# ---- 2. Let the user choose which apps to install ----------------------
PICKED=()   # 1/0 per app, same order as NAMES

select_window() {
    # Native macOS multi-select dialog. Returns 1 if it can't be shown.
    local items='' defaults='' i
    for ((i = 0; i < COUNT; i++)); do
        items+="${items:+, }\"${NAMES[$i]}\""
        [ "${DEFAULTS[$i]}" = 1 ] && defaults+="${defaults:+, }\"${NAMES[$i]}\""
    done
    local result
    result="$(osascript -e "choose from list {$items} with title \"Bigstep Mac Setup\" with prompt \"Select the software to install on this Mac (Cmd-click to select several), then click Install.\" default items {$defaults} OK button name \"Install\" cancel button name \"Cancel\" with multiple selections allowed" 2>/dev/null)" || return 1
    [ "$result" = 'false' ] && return 2   # Cancel clicked
    for ((i = 0; i < COUNT; i++)); do
        case ", $result, " in *", ${NAMES[$i]}, "*) PICKED[$i]=1 ;; *) PICKED[$i]=0 ;; esac
    done
}

select_console() {
    # Fallback text menu
    local i n input
    for ((i = 0; i < COUNT; i++)); do PICKED[$i]="${DEFAULTS[$i]}"; done
    while true; do
        echo
        cyan 'Choose software to install (number = tick/untick, A = all, N = none, Enter = install, Q = quit):'
        for ((i = 0; i < COUNT; i++)); do
            if [ "${PICKED[$i]}" = 1 ]; then mark='[X]'; else mark='[ ]'; fi
            printf '  %2d. %s %s\n' $((i + 1)) "$mark" "${NAMES[$i]}"
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

select_window; rc=$?
if [ $rc -eq 1 ]; then
    yellow 'Selection window unavailable - using text menu.'
    select_console; rc=$?
fi
SELECTED=()
for ((i = 0; i < COUNT; i++)); do [ "${PICKED[$i]}" = 1 ] && SELECTED+=("$i"); done
if [ $rc -eq 2 ] || [ ${#SELECTED[@]} -eq 0 ]; then
    yellow 'Nothing selected - exiting.'
    exit 0
fi
sel_names=''; for i in "${SELECTED[@]}"; do sel_names+="${sel_names:+, }${NAMES[$i]}"; done
green "Selected: $sel_names"

# ---- 3. Ask for the Mac password once and keep it for the whole run ----
yellow 'Some apps need administrator rights. Type your Mac login password (nothing is shown while you type):'
sudo -v < /dev/tty || { red 'Administrator password needed - exiting.'; exit 1; }
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# ---- 4. Rosetta on M-series Macs ---------------------------------------
#      Lets older Intel-only apps run on Apple Silicon.
if [ "$IS_ARM" = 1 ] && ! /usr/bin/pgrep -q oahd; then
    cyan 'Installing Rosetta 2 (runs Intel-only apps on M-series Macs)...'
    sudo softwareupdate --install-rosetta --agree-to-license || yellow '  Rosetta install failed - most apps will still work.'
fi

# ---- 5. Homebrew - only set up if an app actually needs it --------------
#      (Homebrew itself installs to /opt/homebrew on M-series, /usr/local on Intel)
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
BREW=''
find_brew() {
    command -v brew 2>/dev/null && return
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$p" ] && { echo "$p"; return; }; done
}
ensure_brew() {
    [ -n "$BREW" ] && return 0
    BREW="$(find_brew)"
    if [ -z "$BREW" ]; then
        cyan '  Installing Homebrew (the Mac package manager) - this can take 5-10 minutes...'
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null
        BREW="$(find_brew)"
        [ -z "$BREW" ] && { red '  Homebrew install failed - see the log.'; return 1; }
        # Make brew available in future Terminal windows
        SHELLENV_LINE="eval \"\$($BREW shellenv)\""
        grep -qsF "$SHELLENV_LINE" "$HOME/.zprofile" || echo "$SHELLENV_LINE" >> "$HOME/.zprofile"
    fi
    eval "$("$BREW" shellenv)"
    green "  Using Homebrew: $BREW"
    cyan '  Updating Homebrew catalog so the latest versions are installed...'
    brew update --quiet
}
brew_has() {   # is this app already managed by Homebrew?  $1 = kind, $2 = name
    local p; p="$(find_brew)"; [ -n "$p" ] || return 1
    if [ "$1" = cask ]; then "$p" list --cask "$2" >/dev/null 2>&1; else "$p" list --formula "$2" >/dev/null 2>&1; fi
}

# ---- 6. Direct download from the vendor (for this Mac's chip) ----------
copy_app() {   # $1 = path to a .app bundle -> /Applications (replaces old version)
    local dest="/Applications/$(basename "$1")"
    [ -e "$dest" ] && { echo "  Replacing existing $(basename "$1") with the latest version"; sudo rm -rf "$dest"; }
    sudo ditto "$1" "$dest" && sudo chown -R "$(id -un):admin" "$dest"
}

install_direct() {   # $1 = download URL
    local tmp f magic mnt app pkg rc=1
    tmp="$(mktemp -d /tmp/bigstep.XXXXXX)"; f="$tmp/download"
    echo "  Downloading latest version for $CHIP from the vendor..."
    if ! curl -fL --retry 3 --connect-timeout 20 --progress-bar -A 'Mozilla/5.0 (Macintosh)' -o "$f" "$1"; then
        rm -rf "$tmp"; return 1
    fi
    # Work out the file type from its first bytes (download links often have no extension)
    magic="$(head -c 4 "$f")"
    if [ "$magic" = 'xar!' ]; then                       # .pkg installer
        echo '  Running installer package...'
        sudo installer -pkg "$f" -target / && rc=0
    elif [ "$magic" = $'PK\003\004' ]; then              # .zip containing the .app
        ditto -x -k "$f" "$tmp/unzipped" &&
        app="$(find "$tmp/unzipped" -maxdepth 2 -name '*.app' -type d | head -n 1)" &&
        [ -n "$app" ] && copy_app "$app" && rc=0
    else                                                 # .dmg disk image
        mnt="$tmp/mnt"; mkdir -p "$mnt"
        if yes | hdiutil attach -nobrowse -noautoopen -readonly -mountpoint "$mnt" "$f" >/dev/null; then
            pkg="$(find "$mnt" -maxdepth 1 -name '*.pkg' | head -n 1)"
            app="$(find "$mnt" -maxdepth 1 -name '*.app' -type d | head -n 1)"
            if   [ -n "$pkg" ]; then sudo installer -pkg "$pkg" -target / && rc=0
            elif [ -n "$app" ]; then copy_app "$app" && rc=0
            else red '  No app or installer found in the download.'
            fi
            hdiutil detach "$mnt" -quiet -force
        fi
    fi
    rm -rf "$tmp"
    return $rc
}

# ---- 7. Install / upgrade the selected apps ----------------------------
install_app() {   # $1 = app index. Sets VIA to how it was installed.
    local url="${URLS[$1]}" kind="${KINDS[$1]}" id="${IDS[$1]}"
    VIA='-'
    # Already managed by Homebrew -> let Homebrew upgrade it (keeps its records right)
    if [ -n "$id" ] && [ "$id" != '-' ] && brew_has "$kind" "$id"; then
        ensure_brew && install_brew "$kind" "$id" && { VIA='homebrew'; return 0; }
        return 1
    fi
    if [ -n "$url" ] && [ "$url" != '-' ]; then
        install_direct "$url" && { VIA="direct ($([ "$IS_ARM" = 1 ] && echo M-series || echo Intel))"; return 0; }
        yellow '  Direct download failed - trying Homebrew instead...'
    fi
    [ -n "$id" ] && [ "$id" != '-' ] || return 1
    ensure_brew && install_brew "$kind" "$id" && { VIA='homebrew'; return 0; }
    return 1
}

install_brew() {   # $1 = kind (cask/formula), $2 = Homebrew name
    local flag=''
    [ "$1" = cask ] && flag='--cask'
    if brew list $flag "$2" >/dev/null 2>&1; then
        echo "  Already installed - upgrading to the latest version..."
        # --greedy: also upgrade apps that normally update themselves (Chrome, Zoom...)
        [ "$1" = cask ] && flag='--cask --greedy'
        brew upgrade $flag "$2" && return 0     # no-op if already latest
        return 1
    fi
    echo "  brew install $flag $2 (latest)"
    brew install $flag "$2" && return 0
    if [ "$1" = cask ]; then
        # Usually means the app was installed manually (not via Homebrew):
        # replace it with the latest version managed by Homebrew.
        yellow '  App already exists in /Applications - replacing it with the latest version...'
        brew install --cask --force "$2" && return 0
    fi
    return 1
}

RESULTS=()
START=$(date +%s)
n=0
for i in "${SELECTED[@]}"; do
    n=$((n + 1))
    echo; cyan "=== [$n/${#SELECTED[@]}] ${NAMES[$i]} ==="
    t0=$(date +%s)
    if install_app "$i"; then status='OK'; else status='FAILED'; fi
    mins=$(awk "BEGIN { printf \"%.1f\", ($(date +%s) - $t0) / 60 }")
    echo "  $status in $mins min"
    RESULTS+=("$(printf '%-24s %-7s %-20s %s' "${NAMES[$i]}" "$status" "$VIA" "$mins")")
done

# ---- 8. Summary --------------------------------------------------------
total=$(awk "BEGIN { printf \"%.1f\", ($(date +%s) - $START) / 60 }")
echo; cyan "================ SUMMARY - $CHIP Mac ($total min total) ================"
printf '%-24s %-7s %-20s %s\n' 'App' 'Status' 'Installed via' 'Minutes'
printf '%-24s %-7s %-20s %s\n' '---' '------' '-------------' '-------'
for r in "${RESULTS[@]}"; do echo "$r"; done
echo; echo "Log saved in $LOG_DIR"
green 'Done. Restart the Mac to finish.'
