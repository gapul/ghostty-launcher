#!/usr/bin/env bash
# Launcher core — shell & terminal agnostic (bash 3.2+)

LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAUNCHER_DIR

# Use the Rust binary if built, otherwise fall back to the shell script
_BIN="$LAUNCHER_DIR/core/launcher-search"
if [ -x "$_BIN" ]; then
    SEARCH="$_BIN"
else
    SEARCH="$LAUNCHER_DIR/core/search.sh"
fi

OS="$(uname)"

command -v fzf >/dev/null 2>&1 || {
    printf 'launcher: fzf not found. Install it with: brew install fzf\n' >&2
    exit 1
}

# Close the launcher window (terminal-specific)
_close() {
    if   [ -n "$GHOSTTY_QUICK_TERMINAL" ]; then
        osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
        sleep 0.4
    elif [ -n "$KITTY_WINDOW_ID" ]; then
        kitty @ close-window 2>/dev/null
    elif [ -n "$WEZTERM_PANE" ]; then
        wezterm cli kill-pane 2>/dev/null
    elif [ -n "$LAUNCHER_CLOSE_CMD" ]; then
        eval "$LAUNCHER_CLOSE_CMD"
    fi
}

# Open a file (OS-specific)
_open() {
    if [ "$OS" = "Darwin" ]; then open "$@"
    else xdg-open "$@" 2>/dev/null
    fi
}

# Open an app by name
_open_app() {
    if [ "$OS" = "Darwin" ]; then
        open -a "$1"
    else
        local desktop
        desktop=$(grep -rl "^Name=$1$" \
            /usr/share/applications "$HOME/.local/share/applications" 2>/dev/null \
            | head -1)
        if [ -n "$desktop" ]; then
            gtk-launch "$(basename "$desktop" .desktop)" 2>/dev/null &
        fi
    fi
}

# Copy text to clipboard
_copy() {
    if   command -v pbcopy >/dev/null 2>&1; then printf '%s' "$1" | pbcopy
    elif command -v xclip  >/dev/null 2>&1; then printf '%s' "$1" | xclip -selection clipboard
    elif command -v xsel   >/dev/null 2>&1; then printf '%s' "$1" | xsel --clipboard --input
    fi
}

# URL-encode a string
_urlencode() {
    python3 -c \
        "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=''))" \
        "$1" 2>/dev/null \
    || printf '%s' "$1" | sed 's/ /+/g; s/[^a-zA-Z0-9+._~-]//g'
}

# Record a launch to frecency db (fire-and-forget, Rust binary only)
_record() {
    [ -x "$_BIN" ] && "$_BIN" record "$1" "$2" &
}

# Get fzf color string from config (Rust binary) or use built-in default
if [ -x "$_BIN" ]; then
    _fzf_colors=$("$_BIN" colors 2>/dev/null)
else
    _fzf_colors="bg:#1e1e2e,bg+:#313244,border:#6e6a86,fg:#cad3f5,fg+:#cad3f5,gutter:#1e1e2e,hl:#8aadf4,hl+:#8aadf4,prompt:#c6a0f6,pointer:#ed8796,label:#c6a0f6"
fi

_PREVIEW="$LAUNCHER_DIR/core/preview.sh"

# fzf UI
selected=$(fzf \
    --prompt="  " \
    --pointer="❯" \
    --height=100% \
    --border=rounded \
    --border-label=" 󰀻  Launcher " \
    --border-label-pos=2 \
    --padding="1,2" \
    --layout=reverse \
    --info=hidden \
    --no-scrollbar \
    --disabled \
    --delimiter='|' \
    --with-nth=2.. \
    --bind="start:reload($SEARCH '')" \
    --bind="change:reload($SEARCH {q})" \
    --bind="esc:abort" \
    --bind="ctrl-c:abort" \
    --bind="?:toggle-preview" \
    --preview="$_PREVIEW {}" \
    --preview-window="right:40%:wrap:hidden" \
    --color="$_fzf_colors"
)

printf '\033[2J\033[H'

if [ -z "$selected" ]; then
    _close
    exit 0
fi

# Parse "TYPE|ICON display_text"
type="${selected%%|*}"
display="${selected#*|}"
value="${display:2}"  # strip icon + space

case "$type" in
    APP)
        _record APP "$value"
        _open_app "$value"
        sleep 0.4
        ;;
    FILE)
        _record FILE "$value"
        _open "$value"
        sleep 0.4
        ;;
    CALC)
        _copy "${value#= }"
        _close
        ;;
    CMD)
        ${SHELL:-bash} -c "${value#> }"
        stty sane 2>/dev/null
        printf '\n\033[2m[Press Enter to close]\033[0m'
        read -r _
        printf '\033[2J\033[H'
        _close
        ;;
    WEB)
        _open "https://duckduckgo.com/?q=$(_urlencode "${value#DuckDuckGo: }")"
        sleep 0.4
        ;;
    SSH)
        _record SSH "$value"
        ssh "$value"
        stty sane 2>/dev/null
        printf '\n\033[2m[Press Enter to close]\033[0m'
        read -r _
        printf '\033[2J\033[H'
        _close
        ;;
    SYS_LOCK)
        _close; sleep 0.3
        if [ "$OS" = "Darwin" ]; then pmset displaysleepnow
        else loginctl lock-session 2>/dev/null; fi
        ;;
    SYS_SLEEP)
        if [ "$OS" = "Darwin" ]; then pmset sleepnow
        else systemctl suspend 2>/dev/null; fi
        ;;
    SYS_TRASH)
        if [ "$OS" = "Darwin" ]; then osascript -e 'tell application "Finder" to empty trash'
        else rm -rf ~/.local/share/Trash/files/* 2>/dev/null; fi
        _close
        ;;
    SYS_RESTART)
        if [ "$OS" = "Darwin" ]; then osascript -e 'tell application "System Events" to restart'
        else systemctl reboot 2>/dev/null; fi
        ;;
    SYS_SHUTDOWN)
        if [ "$OS" = "Darwin" ]; then osascript -e 'tell application "System Events" to shut down'
        else systemctl poweroff 2>/dev/null; fi
        ;;
esac
