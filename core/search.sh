#!/usr/bin/env bash
# Launcher search — outputs "TYPE|ICON display_text" lines to stdout
QUERY="$1"

WEB_ICON='󰖟'
CALC_ICON='󰃬'

# App name → Nerd Font icon
get_app_icon() {
    case "$1" in
        # Browsers
        "Brave Browser")                                    printf '󰖟' ;;
        "Google Chrome"|"Google Chrome Canary"|"Chromium") printf '󰊯' ;;
        "Firefox"|"Firefox Developer Edition"|"Firefox Nightly") printf '󰈹' ;;
        "Safari"|"Safari Technology Preview")               printf '󰀵' ;;
        "Arc"|"Orion"|"Vivaldi"|"Opera")                   printf '󰖟' ;;
        # Dev tools
        "Visual Studio Code"|"VSCodium")                   printf '󰨞' ;;
        "Xcode")                                           printf '󰀵' ;;
        "Android Studio"|"Simulator")                      printf '󰀲' ;;
        "Cursor"|"Zed"|"RustRover"|"GoLand"|"WebStorm"|\
        "IntelliJ IDEA"|"PyCharm"|"CLion")                 printf '󰨞' ;;
        "Instruments")                                     printf '󰃬' ;;
        "Postman"|"Insomnia"|"RapidAPI")                   printf '󰖟' ;;
        "TablePlus"|"DBngin"|"Sequel Pro")                 printf '󰆼' ;;
        "Docker"|"OrbStack")                               printf '󰡨' ;;
        "GitHub Desktop"|"GitKraken"|"Tower"|"Sourcetree") printf '󰊢' ;;
        # System (macOS)
        "Finder")                                          printf '󰀶' ;;
        "System Preferences"|"System Settings")            printf '󰒓' ;;
        "Activity Monitor")                                printf '󰓅' ;;
        "App Store")                                       printf '󰀶' ;;
        "Disk Utility")                                    printf '󰋊' ;;
        "Migration Assistant"|"Installer")                 printf '󰋑' ;;
        "Keychain Access")                                 printf '󰌾' ;;
        "Script Editor"|"Automator")                       printf '󰗈' ;;
        "ColorSync Utility"|"Digital Color Meter")         printf '󰃣' ;;
        "Accessibility Inspector")                         printf '󰀂' ;;
        "Boot Camp Assistant")                             printf '󰖳' ;;
        # Communication
        "Slack")                                           printf '󰒱' ;;
        "Discord"|"Canary")                                printf '󰙯' ;;
        "Messages")                                        printf '󰍦' ;;
        "Mail")                                            printf '󰇮' ;;
        "FaceTime")                                        printf '󰒯' ;;
        "Zoom"|"zoom.us")                                  printf '󰐸' ;;
        "Microsoft Teams")                                 printf '󰊻' ;;
        "Telegram"|"Telegram Desktop")                     printf '󰔁' ;;
        "WhatsApp")                                        printf '󰖣' ;;
        "Signal"|"Beeper"|"Beeper Desktop")                printf '󰍦' ;;
        # Media
        "Music"|"GarageBand"|"Logic Pro"|"Logic Pro X")   printf '󰝚' ;;
        "Spotify")                                         printf '󰓇' ;;
        "Photos")                                          printf '󰈟' ;;
        "QuickTime Player"|"IINA"|"Infuse 7"|"Infuse"|\
        "Final Cut Pro"|"Motion"|"Compressor")             printf '󰸖' ;;
        "VLC")                                             printf '󰕧' ;;
        "Audacity"|"Ableton Live"|"Live")                  printf '󰎆' ;;
        # Productivity
        "Calendar")                                        printf '󰃭' ;;
        "Notes"|"Notion"|"Obsidian"|"Craft"|"Bear"|\
        "Ulysses"|"Tot")                                   printf '󰠮' ;;
        "Reminders")                                       printf '󰄲' ;;
        "Contacts")                                        printf '󰮤' ;;
        "Maps")                                            printf '󰺿' ;;
        "News")                                            printf '󰑈' ;;
        "Podcasts")                                        printf '󱆺' ;;
        "Books")                                           printf '󰂿' ;;
        "Preview")                                         printf '󰈦' ;;
        "TextEdit"|"Numbers"|"Pages"|"Microsoft Word")     printf '󰈙' ;;
        "Keynote")                                         printf '󰐩' ;;
        "Microsoft Excel")                                 printf '󰈛' ;;
        "Microsoft PowerPoint")                            printf '󰈧' ;;
        "Microsoft Outlook")                               printf '󰇮' ;;
        # Security
        "1Password 7"|"1Password"|"Bitwarden")             printf '󰌾' ;;
        # Design
        "Figma"|"Sketch"|"Affinity Designer"|\
        "Affinity Designer 2"|"OmniGraffle")               printf '󰙧' ;;
        "Pixelmator Pro"|"Pixelmator"|"Affinity Photo"|\
        "Affinity Photo 2"|"GIMP"|"Inkscape")              printf '󰋩' ;;
        "Blender")                                         printf '󰂮' ;;
        # Utilities
        "CleanMyMac"|"CleanMyMac X")                       printf '󰃢' ;;
        "Amphetamine")                                     printf '󰂓' ;;
        "Bartender"|"Ice")                                 printf '󰀺' ;;
        "Rectangle"|"Magnet"|"Moom"|"BetterSnapTool"|\
        "AeroSpace")                                       printf '󰁴' ;;
        "Karabiner-Elements"|"Karabiner-EventViewer")      printf '⌨' ;;
        "BetterTouchTool")                                 printf '󱕴' ;;
        "PopClip")                                         printf '󰏌' ;;
        "Dropbox"|"OneDrive"|"Google Drive")               printf '󰅧' ;;
        "Transmit 5"|"Transmit"|"Cyberduck"|"FileZilla")   printf '󰀸' ;;
        "Proxyman"|"Charles"|"Wireshark")                  printf '󰖟' ;;
        "Raycast"|"Alfred")                                printf '󰀻' ;;
        *)                                                 printf '󰀻' ;;
    esac
}

# File path → Nerd Font icon
file_icon() {
    [ -d "$1" ] && { printf '󰉋'; return; }
    case "$1" in
        *.pdf)                                         printf '󰈦' ;;
        *.jpg|*.jpeg|*.png|*.gif|*.svg|*.webp|*.heic) printf '󰋩' ;;
        *.md|*.markdown)                               printf '󰍔' ;;
        *.py|*.js|*.ts|*.go|*.rs|*.sh|*.fish|*.rb|\
        *.java|*.c|*.cpp|*.h|*.swift|*.kt|*.lua)      printf '󰈮' ;;
        *.zip|*.tar|*.gz|*.7z|*.rar)                  printf '󰗄' ;;
        *.txt|*.rtf)                                   printf '󰈙' ;;
        *.mp4|*.mov|*.avi|*.mkv|*.webm)               printf '󰈫' ;;
        *.mp3|*.flac|*.wav|*.aac|*.m4a)               printf '󰈣' ;;
        *)                                             printf '󰈔' ;;
    esac
}

# Cache helpers
APPS_CACHE="/tmp/launcher_apps_cache.txt"
RECENT_CACHE="/tmp/launcher_recent_cache.txt"

_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

cache_valid() {
    local cache="$1" ttl="${2:-300}"
    [ -f "$cache" ] && [ $(( $(date +%s) - $(_mtime "$cache") )) -lt "$ttl" ]
}

build_apps_cache() {
    {
        # macOS
        for dir in /Applications /System/Applications \
                   "/System/Applications/Utilities" "$HOME/Applications"; do
            [ -d "$dir" ] && ls "$dir" 2>/dev/null | grep '\.app$' | sed 's/\.app$//' \
                | while IFS= read -r name; do
                    printf 'APP|%s %s\n' "$(get_app_icon "$name")" "$name"
                done
        done
        # macOS: Finder lives outside /Applications
        [ -d "/System/Library/CoreServices/Finder.app" ] && \
            printf 'APP|%s %s\n' "$(get_app_icon "Finder")" "Finder"
        # Linux
        for dir in /usr/share/applications "$HOME/.local/share/applications"; do
            [ -d "$dir" ] && grep -rl '^Name=' "$dir"/*.desktop 2>/dev/null \
                | while IFS= read -r f; do
                    name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
                    [ -n "$name" ] && printf 'APP|%s %s\n' "$(get_app_icon "$name")" "$name"
                done
        done
    } | sort -u
}

list_apps() {
    cache_valid "$APPS_CACHE" 300 || build_apps_cache > "$APPS_CACHE"
    cat "$APPS_CACHE"
}

list_recent() {
    if ! cache_valid "$RECENT_CACHE" 60; then
        {
            if command -v mdfind >/dev/null 2>&1; then
                mdfind -onlyin "$HOME" 'kMDItemLastUsedDate >= $time.today(-7)' 2>/dev/null \
                    | grep -v "^$HOME/Library" \
                    | grep -v '\.app' | grep -v '/\.' | grep -v 'node_modules' \
                    | head -10
            fi
        } | while IFS= read -r path; do
            printf 'FILE|%s %s\n' "$(file_icon "$path")" "$path"
        done > "$RECENT_CACHE"
    fi
    cat "$RECENT_CACHE"
}

list_sys() {
    printf 'SYS_LOCK|󰌾 Lock Screen\n'
    printf 'SYS_SLEEP|󰒲 Sleep\n'
    printf 'SYS_TRASH|󰩺 Empty Trash\n'
    printf 'SYS_RESTART|󰑐 Restart\n'
    printf 'SYS_SHUTDOWN|󰐥 Shut Down\n'
}

search_calc() {
    local result
    result=$(python3 - "$QUERY" 2>/dev/null <<'EOF'
import math, sys
try:
    ns = {k: getattr(math, k) for k in dir(math)}
    ns['__builtins__'] = {}
    r = eval(sys.argv[1], ns)
    if isinstance(r, float):
        r = round(r, 10)
        print(int(r) if r == int(r) else r)
    elif isinstance(r, (int, bool)):
        print(r)
except:
    pass
EOF
)
    [ -n "$result" ] && printf 'CALC|%s = %s\n' "$CALC_ICON" "$result"
}

search_aliases() {
    local alias_file="$HOME/.config/launcher/app_aliases.txt"
    [ -f "$alias_file" ] || return
    while IFS=: read -r alias appname; do
        case "$alias" in '#'*|'') continue ;; esac
        case "$(printf '%s' "$alias" | tr '[:upper:]' '[:lower:]')" in
            *"$QUERY_LOWER"*)
                printf 'APP|%s %s\n' "$(get_app_icon "$appname")" "$appname" ;;
        esac
    done < "$alias_file"
}

search_sys() {
    case "$QUERY_LOWER" in
        *lock*|*ロック*)                    printf 'SYS_LOCK|󰌾 Lock Screen\n' ;;
        *sleep*|*スリープ*|*眠*)            printf 'SYS_SLEEP|󰒲 Sleep\n' ;;
        *trash*|*ゴミ*|*empty*)             printf 'SYS_TRASH|󰩺 Empty Trash\n' ;;
        *restart*|*再起動*|*reboot*)        printf 'SYS_RESTART|󰑐 Restart\n' ;;
        *shutdown*|*シャットダウン*|*電源*) printf 'SYS_SHUTDOWN|󰐥 Shut Down\n' ;;
    esac
}

search_files() {
    if command -v mdfind >/dev/null 2>&1; then
        mdfind -onlyin "$HOME" -name "$QUERY" 2>/dev/null
    elif command -v locate >/dev/null 2>&1; then
        locate -i -l 30 "$QUERY" 2>/dev/null | grep "^$HOME"
    fi \
        | grep -v "^$HOME/Library" \
        | grep -v '\.app$' | grep -v '\.app/Contents' \
        | grep -v '/\.' | grep -v 'node_modules' \
        | head -15 \
        | while IFS= read -r path; do
            printf 'FILE|%s %s\n' "$(file_icon "$path")" "$path"
        done
}

# ── Empty query: show all apps, recent files, system commands ──────────
if [ -z "$QUERY" ]; then
    list_apps
    list_recent
    list_sys
    exit 0
fi

# ── Non-empty query ────────────────────────────────────────────────────
QUERY_LOWER="$(printf '%s' "$QUERY" | tr '[:upper:]' '[:lower:]')"

# Phase 1: fast sources (cache / in-memory) — stream immediately
{
    case "$QUERY" in *[0-9]*) search_calc ;; esac
    search_aliases
    cache_valid "$APPS_CACHE" 300 && grep -i "$QUERY" "$APPS_CACHE" 2>/dev/null \
        || build_apps_cache | grep -i "$QUERY"
    search_sys
} | awk '!seen[$0]++'

# Phase 2: file search — appended after fast results
[ ${#QUERY} -ge 3 ] && search_files

# Always last
printf 'CMD|󰆍 > %s\n' "$QUERY"
printf 'WEB|%s DuckDuckGo: %s\n' "$WEB_ICON" "$QUERY"
