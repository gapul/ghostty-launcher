#!/bin/bash
# Spotlight風ランチャー検索スクリプト
# 出力フォーマット: TYPE|ICON 表示テキスト
QUERY="$1"

WEB_ICON='󰖟'
CALC_ICON='󰃬'

# アプリ名 → Nerd Font アイコン（HackGen Console NF 収録済み）
get_app_icon() {
    case "$1" in
        # ブラウザ
        "Brave Browser")                        printf '󰖟' ;;
        "Google Chrome"|"Google Chrome Canary"|"Chromium") printf '󰊯' ;;
        "Firefox"|"Firefox Developer Edition"|"Firefox Nightly") printf '󰈹' ;;
        "Safari"|"Safari Technology Preview")   printf '󰀵' ;;
        "Arc"|"Orion"|"Vivaldi"|"Opera")        printf '󰖟' ;;
        # 開発ツール
        "Visual Studio Code"|"VSCodium")        printf '󰨞' ;;
        "Xcode")                                printf '󰀵' ;;
        "Android Studio")                       printf '󰀲' ;;
        "Cursor"|"Zed"|"RustRover"|"GoLand"|"WebStorm"|"IntelliJ IDEA"|"PyCharm"|"CLion") printf '󰨞' ;;
        "Simulator")                            printf '󰀲' ;;
        "Instruments")                          printf '󰃬' ;;
        "Postman"|"Insomnia"|"RapidAPI")        printf '󰖟' ;;
        "TablePlus"|"DBngin"|"Sequel Pro")      printf '󰆼' ;;
        "Docker"|"OrbStack")                    printf '󰡨' ;;
        "GitHub Desktop"|"GitKraken"|"Tower"|"Sourcetree") printf '󰊢' ;;
        # システム
        "Finder")                               printf '󰀶' ;;
        "System Preferences"|"System Settings") printf '󰒓' ;;
        "Activity Monitor")                     printf '󰓅' ;;
        "App Store")                            printf '󰀶' ;;
        "Disk Utility")                         printf '󰋊' ;;
        "Migration Assistant"|"Installer")      printf '󰋑' ;;
        "Keychain Access")                      printf '󰌾' ;;
        "Script Editor"|"Automator")            printf '󰗈' ;;
        "ColorSync Utility"|"Digital Color Meter") printf '󰃣' ;;
        "Accessibility Inspector")              printf '󰀂' ;;
        "Boot Camp Assistant")                  printf '󰖳' ;;
        # コミュニケーション
        "Slack")                                printf '󰒱' ;;
        "Discord"|"Canary")                     printf '󰙯' ;;
        "Messages")                             printf '󰍦' ;;
        "Mail")                                 printf '󰇮' ;;
        "FaceTime")                             printf '󰒯' ;;
        "Zoom"|"zoom.us")                       printf '󰐸' ;;
        "Microsoft Teams")                      printf '󰊻' ;;
        "Telegram"|"Telegram Desktop")          printf '󰔁' ;;
        "WhatsApp")                             printf '󰖣' ;;
        "Signal")                               printf '󰍦' ;;
        "Beeper"|"Beeper Desktop")              printf '󰍦' ;;
        # メディア
        "Music")                                printf '󰝚' ;;
        "Spotify")                              printf '󰓇' ;;
        "Photos")                               printf '󰈟' ;;
        "QuickTime Player")                     printf '󰸖' ;;
        "VLC")                                  printf '󰕧' ;;
        "IINA")                                 printf '󰸖' ;;
        "Infuse 7"|"Infuse")                    printf '󰸖' ;;
        "GarageBand")                           printf '󰝚' ;;
        "Logic Pro"|"Logic Pro X")              printf '󰝚' ;;
        "Final Cut Pro")                        printf '󰸖' ;;
        "Motion"|"Compressor")                  printf '󰸖' ;;
        "Audacity")                             printf '󰎆' ;;
        "Ableton Live"|"Live")                  printf '󰎆' ;;
        # 生産性
        "Calendar")                             printf '󰃭' ;;
        "Notes")                                printf '󰠮' ;;
        "Reminders")                            printf '󰄲' ;;
        "Contacts")                             printf '󰮤' ;;
        "Maps")                                 printf '󰺿' ;;
        "News")                                 printf '󰑈' ;;
        "Podcasts")                             printf '󱆺' ;;
        "Books")                                printf '󰂿' ;;
        "Preview")                              printf '󰈦' ;;
        "TextEdit")                             printf '󰈙' ;;
        "Numbers")                              printf '󰈙' ;;
        "Pages")                                printf '󰈙' ;;
        "Keynote")                              printf '󰐩' ;;
        "Microsoft Word")                       printf '󰈙' ;;
        "Microsoft Excel")                      printf '󰈛' ;;
        "Microsoft PowerPoint")                 printf '󰈧' ;;
        "Microsoft Outlook")                    printf '󰇮' ;;
        "Notion")                               printf '󰠮' ;;
        "Obsidian")                             printf '󰠮' ;;
        "Craft")                                printf '󰠮' ;;
        "Bear")                                 printf '󰠮' ;;
        "Ulysses")                              printf '󰠮' ;;
        "Tot")                                  printf '󰠮' ;;
        "1Password 7"|"1Password"|"Bitwarden")  printf '󰌾' ;;
        "Raycast"|"Alfred")                     printf '󰀻' ;;
        # デザイン
        "Figma")                                printf '󰙧' ;;
        "Sketch")                               printf '󰙧' ;;
        "Pixelmator Pro"|"Pixelmator")          printf '󰋩' ;;
        "Affinity Designer"|"Affinity Designer 2") printf '󰙧' ;;
        "Affinity Photo"|"Affinity Photo 2")    printf '󰋩' ;;
        "GIMP"|"Inkscape")                      printf '󰋩' ;;
        "Blender")                              printf '󰂮' ;;
        "OmniGraffle")                          printf '󰙧' ;;
        # その他ユーティリティ
        "Bitwarden")                            printf '󰌾' ;;
        "CleanMyMac"|"CleanMyMac X")            printf '󰃢' ;;
        "Amphetamine")                          printf '󰂓' ;;
        "Bartender"|"Ice")                      printf '󰀺' ;;
        "Rectangle"|"Magnet"|"Moom"|"BetterSnapTool") printf '󰁴' ;;
        "AeroSpace")                            printf '󰁴' ;;
        "sketchybar")                           printf '󰀺' ;;
        "Karabiner-Elements"|"Karabiner-EventViewer") printf '⌨' ;;
        "BetterTouchTool")                      printf '󱕴' ;;
        "PopClip")                              printf '󰏌' ;;
        "Dropbox"|"OneDrive"|"Google Drive")    printf '󰅧' ;;
        "Transmit 5"|"Transmit"|"Cyberduck"|"FileZilla") printf '󰀸' ;;
        "Proxyman"|"Charles"|"Wireshark")       printf '󰖟' ;;
        *)                                      printf '󰀻' ;;
    esac
}

file_icon() {
    p="$1"
    [ -d "$p" ] && { printf '󰉋'; return; }
    case "$p" in
        *.pdf)                                          printf '󰈦' ;;
        *.jpg|*.jpeg|*.png|*.gif|*.svg|*.webp|*.heic)  printf '󰋩' ;;
        *.md|*.markdown)                                printf '󰍔' ;;
        *.py|*.js|*.ts|*.go|*.rs|*.sh|*.fish|*.rb|\
        *.java|*.c|*.cpp|*.h|*.swift|*.kt|*.lua)       printf '󰈮' ;;
        *.zip|*.tar|*.gz|*.7z|*.rar)                   printf '󰗄' ;;
        *.txt|*.rtf)                                    printf '󰈙' ;;
        *.mp4|*.mov|*.avi|*.mkv|*.webm)                printf '󰈫' ;;
        *.mp3|*.flac|*.wav|*.aac|*.m4a)                printf '󰈣' ;;
        *)                                             printf '󰈔' ;;
    esac
}

# キャッシュファイル
APPS_CACHE="/tmp/launcher_apps_cache.txt"
RECENT_CACHE="/tmp/launcher_recent_cache.txt"

cache_valid() {
    local cache="$1" ttl="${2:-300}"
    [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -f %m "$cache" 2>/dev/null || echo 0) )) -lt "$ttl" ]
}

build_apps_cache() {
    {
        for dir in /Applications /System/Applications "/System/Applications/Utilities" "$HOME/Applications"; do
            [ -d "$dir" ] && ls "$dir" 2>/dev/null | grep '\.app$' | sed 's/\.app$//' | while IFS= read -r name; do
                icon=$(get_app_icon "$name")
                printf 'APP|%s %s\n' "$icon" "$name"
            done
        done
        for app in Finder; do
            [ -d "/System/Library/CoreServices/$app.app" ] && {
                icon=$(get_app_icon "$app")
                printf 'APP|%s %s\n' "$icon" "$app"
            }
        done
    } | sort -u
}

list_apps() {
    if ! cache_valid "$APPS_CACHE" 300; then
        build_apps_cache > "$APPS_CACHE"
    fi
    cat "$APPS_CACHE"
}

list_recent() {
    if ! cache_valid "$RECENT_CACHE" 60; then
        mdfind -onlyin "$HOME" 'kMDItemLastUsedDate >= $time.today(-7)' 2>/dev/null \
            | grep -v "^$HOME/Library" \
            | grep -v '\.app' \
            | grep -v '/\.' \
            | grep -v 'node_modules' \
            | head -10 \
            | while IFS= read -r path; do
                icon=$(file_icon "$path")
                printf 'FILE|%s %s\n' "$icon" "$path"
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

# ── クエリなし ──
if [ -z "$QUERY" ]; then
    list_apps
    list_recent
    list_sys
    exit 0
fi

# ── クエリあり ──
QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# フェーズ1: 即座に返せる結果（キャッシュ・計算）をストリーム出力
{
    # 1. 電卓（数字を含む場合のみ python3 を起動）
    case "$QUERY" in *[0-9]*)
        calc=$(python3 -c "
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
except: pass
" "$QUERY" 2>/dev/null)
        [ -n "$calc" ] && printf 'CALC|%s = %s\n' "$CALC_ICON" "$calc"
    ;; esac

    # 2. エイリアスマッチ
    ALIAS_FILE="$HOME/.config/launcher/app_aliases.txt"
    if [ -f "$ALIAS_FILE" ]; then
        while IFS=: read -r alias appname; do
            case "$alias" in '#'*) continue ;; esac
            alias_lower=$(echo "$alias" | tr '[:upper:]' '[:lower:]')
            case "$alias_lower" in
                *"$QUERY_LOWER"*)
                    icon=$(get_app_icon "$appname")
                    printf 'APP|%s %s\n' "$icon" "$appname"
                    ;;
            esac
        done < "$ALIAS_FILE"
    fi

    # 3. アプリ名マッチ（キャッシュから即検索）
    if cache_valid "$APPS_CACHE" 300; then
        grep -i "$QUERY" "$APPS_CACHE" 2>/dev/null
    else
        for dir in /Applications /System/Applications "/System/Applications/Utilities" "$HOME/Applications"; do
            [ -d "$dir" ] && ls "$dir" 2>/dev/null | grep -i "$QUERY" | grep '\.app$' | sed 's/\.app$//' | while IFS= read -r name; do
                icon=$(get_app_icon "$name")
                printf 'APP|%s %s\n' "$icon" "$name"
            done
        done
    fi

    # 4. システムコマンドマッチ
    case "$QUERY_LOWER" in *lock*|*ロック*) printf 'SYS_LOCK|󰌾 Lock Screen\n' ;; esac
    case "$QUERY_LOWER" in *sleep*|*スリープ*|*眠*) printf 'SYS_SLEEP|󰒲 Sleep\n' ;; esac
    case "$QUERY_LOWER" in *trash*|*ゴミ*|*empty*) printf 'SYS_TRASH|󰩺 Empty Trash\n' ;; esac
    case "$QUERY_LOWER" in *restart*|*再起動*|*reboot*) printf 'SYS_RESTART|󰑐 Restart\n' ;; esac
    case "$QUERY_LOWER" in *shutdown*|*シャットダウン*|*電源*) printf 'SYS_SHUTDOWN|󰐥 Shut Down\n' ;; esac

} | awk '!seen[$0]++'

# フェーズ2: mdfind によるファイル検索（3文字以上・アプリ結果の後に流す）
if [ ${#QUERY} -ge 3 ]; then
    mdfind -onlyin "$HOME" -name "$QUERY" 2>/dev/null \
        | grep -v "^$HOME/Library" \
        | grep -v '\.app$' \
        | grep -v '\.app/Contents' \
        | grep -v '/\.' \
        | grep -v 'node_modules' \
        | head -15 \
        | while IFS= read -r path; do
            icon=$(file_icon "$path")
            printf 'FILE|%s %s\n' "$icon" "$path"
        done
fi

# CLIコマンドとWeb検索は常に末尾
printf 'CMD|󰆍 > %s\n' "$QUERY"
printf 'WEB|%s DuckDuckGo: %s\n' "$WEB_ICON" "$QUERY"
