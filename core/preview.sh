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

COLOR)
    r=-1; g=-1; b=-1

    # #rrggbb
    if [[ "$value" =~ ^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2}) ]]; then
        r=$(( 16#${BASH_REMATCH[1]} ))
        g=$(( 16#${BASH_REMATCH[2]} ))
        b=$(( 16#${BASH_REMATCH[3]} ))
    # #rgb → expand
    elif [[ "$value" =~ ^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$ ]]; then
        r=$(( 16#${BASH_REMATCH[1]}${BASH_REMATCH[1]} ))
        g=$(( 16#${BASH_REMATCH[2]}${BASH_REMATCH[2]} ))
        b=$(( 16#${BASH_REMATCH[3]}${BASH_REMATCH[3]} ))
    # rgb(r, g, b) / rgba(r, g, b, a)
    elif [[ "$value" =~ [Rr][Gg][Bb][Aa]?\(([0-9]+)[^0-9]+([0-9]+)[^0-9]+([0-9]+) ]]; then
        r="${BASH_REMATCH[1]}"; g="${BASH_REMATCH[2]}"; b="${BASH_REMATCH[3]}"
    # hsl(h, s%, l%) → convert to RGB via awk
    elif [[ "$value" =~ [Hh][Ss][Ll][Aa]?\(([0-9.]+)[^0-9.]+([0-9.]+)[^0-9.]+([0-9.]+) ]]; then
        hh="${BASH_REMATCH[1]}"; ss="${BASH_REMATCH[2]}"; ll="${BASH_REMATCH[3]}"
        read -r r g b < <(awk -v h="$hh" -v s="$ss" -v l="$ll" 'BEGIN {
            h/=360; s/=100; l/=100
            if (s==0) { ri=gi=bi=int(l*255+.5) }
            else {
                q = l<.5 ? l*(1+s) : l+s-l*s
                p = 2*l - q
                ri = int(hue(p,q,h+1/3)*255+.5)
                gi = int(hue(p,q,h    )*255+.5)
                bi = int(hue(p,q,h-1/3)*255+.5)
            }
            print ri, gi, bi
        }
        function hue(p,q,t) {
            if(t<0)t+=1; if(t>1)t-=1
            if(t<1/6) return p+(q-p)*6*t
            if(t<1/2) return q
            if(t<2/3) return p+(q-p)*(2/3-t)*6
            return p
        }')
    fi

    if [ "$r" -ge 0 ] 2>/dev/null; then
        # Color swatch
        sw=$(( ${FZF_PREVIEW_COLUMNS:-40} - 4 ))
        [ "$sw" -lt 8 ] && sw=8
        printf '\n'
        for _ in 1 2 3 4 5 6 7 8; do
            printf "  \033[48;2;%d;%d;%dm%*s\033[0m\n" "$r" "$g" "$b" "$sw" ""
        done
        printf '\n'

        # Representations
        hex_lo=$(printf '#%02x%02x%02x' "$r" "$g" "$b")
        hex_up=$(printf '#%02X%02X%02X' "$r" "$g" "$b")
        printf '  HEX  %s  /  %s\n' "$(bold "$hex_lo")" "$hex_up"
        printf '  RGB  rgb(%d, %d, %d)\n' "$r" "$g" "$b"

        # RGB → HSL
        hsl=$(awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN {
            r/=255; g/=255; b/=255
            mx = r>g?(r>b?r:b):(g>b?g:b)
            mn = r<g?(r<b?r:b):(g<b?g:b)
            l  = (mx+mn)/2
            if (mx==mn) { h=0; s=0 }
            else {
                d = mx-mn
                s = l>.5 ? d/(2-mx-mn) : d/(mx+mn)
                if      (mx==r) h=(g-b)/d + (g<b?6:0)
                else if (mx==g) h=(b-r)/d + 2
                else            h=(r-g)/d + 4
                h/=6
            }
            printf "hsl(%d, %d%%, %d%%)", int(h*360+.5), int(s*100+.5), int(l*100+.5)
        }')
        printf '  HSL  %s\n' "$hsl"
        printf '\n%s\n' "$(dim "Enter → copy to clipboard")"
    else
        printf '%s\n\n%s\n' "$(bold "$value")" "$(dim "Could not parse color")"
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
