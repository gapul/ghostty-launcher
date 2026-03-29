function launcher --description "Spotlight風ランチャー"
    set -l search ~/.config/launcher/launcher_search.sh

    set -l selected (
        fzf \
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
            --bind="start:reload($search '')" \
            --bind="change:reload($search {q})" \
            --bind="esc:abort" \
            --bind="ctrl-c:abort" \
            --color="bg:#1e1e2e,bg+:#313244,border:#6e6a86" \
            --color="fg:#cad3f5,fg+:#cad3f5,gutter:#1e1e2e" \
            --color="hl:#8aadf4,hl+:#8aadf4" \
            --color="prompt:#c6a0f6,pointer:#ed8796" \
            --color="label:#c6a0f6"
    )

    printf '\033[2J\033[H'

    if test -z "$selected"
        # ESC/Ctrl+C: ターミナルを閉じる
        osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
        sleep 0.4
        return
    end

    # "TYPE|ICON 表示テキスト" をパース
    set -l parts (string split --max 1 '|' "$selected")
    set -l type $parts[1]
    set -l display $parts[2]
    set -l value (string sub -s 3 "$display")   # アイコン + スペースを除去

    switch $type
        case APP
            open -a "$value"
            sleep 0.4

        case FILE
            open "$value"
            sleep 0.4

        case CALC
            # クリップボードにコピーして閉じる
            set -l result (string replace '= ' '' "$value")
            printf '%s' "$result" | pbcopy
            osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
            sleep 0.4

        case CMD
            # コマンドを実行してターミナルに出力を表示
            set -l cmd (string replace '> ' '' "$value")
            fish -c "$cmd"
            stty sane 2>/dev/null
            printf '\n\033[2m[Press Enter to close]\033[0m'
            read -l _
            printf '\033[2J\033[H'
            osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
            sleep 0.4
            return

        case WEB
            set -l query (string replace 'DuckDuckGo: ' '' "$value")
            set -l encoded (python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=''))" "$query" 2>/dev/null)
            open "https://duckduckgo.com/?q=$encoded"
            sleep 0.4

        case SYS_LOCK
            # 先に閉じてからロック
            osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
            sleep 0.3
            pmset displaysleepnow

        case SYS_SLEEP
            pmset sleepnow

        case SYS_TRASH
            osascript -e 'tell application "Finder" to empty trash'
            osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
            sleep 0.4

        case SYS_RESTART
            osascript -e 'tell application "System Events" to restart'

        case SYS_SHUTDOWN
            osascript -e 'tell application "System Events" to shut down'
    end
end
