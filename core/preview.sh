#!/usr/bin/env bash
# Launcher preview pane — called by fzf --preview with the selected line as $1

line="$1"
type="${line%%|*}"
display="${line#*|}"
value="${display#* }"  # strip icon + space

# ANSI helpers
bold() { printf '\033[1m%s\033[0m' "$*"; }
dim()  { printf '\033[2m%s\033[0m' "$*"; }

# ── Preview by type ────────────────────────────────────────────────────────

case "$type" in

APP)
    printf '%s\n' "$(bold "$value")"
    printf '\n'

    # Find the .app bundle
    found_app=""
    for dir in /Applications /System/Applications \
               "/System/Applications/Utilities" \
               "/System/Library/CoreServices" \
               "$HOME/Applications"; do
        candidate="$dir/$value.app"
        if [ -d "$candidate" ]; then
            found_app="$candidate"
            break
        fi
    done

    if [ -n "$found_app" ]; then
        plist_base="${found_app}/Contents/Info"

        ver=$(defaults read "$plist_base" CFBundleShortVersionString 2>/dev/null)
        [ -n "$ver" ] && printf 'Version   %s\n' "$(bold "$ver")"

        bundle=$(defaults read "$plist_base" CFBundleIdentifier 2>/dev/null)
        [ -n "$bundle" ] && printf 'Bundle    %s\n' "$(dim "$bundle")"

        category=$(defaults read "$plist_base" LSApplicationCategoryType 2>/dev/null \
                   | sed 's/public.app-category.//')
        [ -n "$category" ] && printf 'Category  %s\n' "$category"

        printf '\n%s\n' "$(dim "$found_app")"
    else
        printf '%s\n' "$(dim "(app not found in standard locations)")"
    fi
    ;;

FILE)
    if [ ! -e "$value" ]; then
        printf '%s\n' "$(dim "$value")"
        printf 'File not found\n'
        exit
    fi

    if [ -d "$value" ]; then
        printf '%s\n\n' "$(bold "$value")"
        ls -lhA "$value" 2>/dev/null | head -40
    else
        ext="${value##*.}"
        case "$ext" in
            jpg|jpeg|png|gif|webp|heic|bmp|tiff)
                if command -v chafa >/dev/null 2>&1; then
                    # --format=symbols: ANSI block chars (works in fzf preview)
                    # Kitty/sixel protocols are not supported inside fzf panes
                    cols="${FZF_PREVIEW_COLUMNS:-$(tput cols)}"
                    lines="${FZF_PREVIEW_LINES:-$(($(tput lines) - 4))}"
                    chafa --format=symbols --size="${cols}x${lines}" "$value" 2>/dev/null
                else
                    file "$value"
                    printf '\n%s\n' "$(dim "(install chafa for image preview)")"
                fi
                ;;
            pdf)
                if command -v pdftotext >/dev/null 2>&1; then
                    pdftotext "$value" - 2>/dev/null | head -80
                else
                    file "$value"
                fi
                ;;
            *)
                if command -v bat >/dev/null 2>&1; then
                    bat --color=always --style=numbers,changes \
                        --line-range=":100" "$value" 2>/dev/null \
                    || file "$value"
                else
                    head -100 "$value" 2>/dev/null || file "$value"
                fi
                ;;
        esac
    fi
    ;;

CALC)
    printf '%s\n\n' "$(bold "Result")"
    printf '  %s\n\n' "$value"
    printf '%s\n' "$(dim "Enter → copy to clipboard")"
    ;;

SSH)
    printf '%s\n\n' "$(bold "SSH: $value")"

    ssh_config="$HOME/.ssh/config"
    if [ -f "$ssh_config" ]; then
        awk -v host="$value" '
            /^[Hh]ost[[:space:]]/ { found = ($2 == host); next }
            found && /^[^[:space:]]/ { exit }
            found { print }
        ' "$ssh_config"
    else
        printf '%s\n' "$(dim "(~/.ssh/config not found)")"
    fi
    ;;

WEB)
    query="${value#DuckDuckGo: }"
    printf '%s\n\n' "$(bold "Web search")"
    printf '  %s\n\n' "$query"
    printf '%s\n' "$(dim "Enter → open DuckDuckGo in browser")"
    ;;

CMD)
    cmd="${value#> }"
    printf '%s\n\n' "$(bold "Run command")"
    printf '  $ %s\n\n' "$cmd"
    printf '%s\n' "$(dim "Enter → execute in terminal")"
    ;;

SYS_LOCK)     printf '%s\n\nLock the screen\n' "$(bold "󰌾  Lock Screen")" ;;
SYS_SLEEP)    printf '%s\n\nPut the system to sleep\n' "$(bold "󰒲  Sleep")" ;;
SYS_TRASH)    printf '%s\n\nPermanently delete items in Trash\n' "$(bold "󰩺  Empty Trash")" ;;
SYS_RESTART)  printf '%s\n\nRestart the system\n' "$(bold "󰑐  Restart")" ;;
SYS_SHUTDOWN) printf '%s\n\nShut down the system\n' "$(bold "󰐥  Shut Down")" ;;

*)
    printf '%s\n' "$line"
    ;;

esac
