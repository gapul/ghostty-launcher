#!/usr/bin/env bash
# Launcher preview pane — called by fzf --preview with the selected line as $1
# Preview settings are exported by launcher.sh from config.toml [preview]
_IMG_TIMEOUT="${LAUNCHER_IMG_TIMEOUT:-3}"
_CMD_TIMEOUT="${LAUNCHER_CMD_TIMEOUT:-5}"
_MAX_ARCHIVE="${LAUNCHER_MAX_ARCHIVE:-40}"
_MAX_TEXT="${LAUNCHER_MAX_TEXT:-100}"
_MAX_PDF="${LAUNCHER_MAX_PDF:-80}"

line="$1"
# TYPE field may carry extra data: "BOOKMARK:URL" or plain "TYPE"
raw_type="${line%%|*}"
display="${line#*|}"
value="${display#* }"  # strip icon + space

# Split type and embedded data (e.g. BOOKMARK:https://...)
type="${raw_type%%:*}"
type_data="${raw_type#*:}"
[ "$type_data" = "$raw_type" ] && type_data=""  # no colon → no embedded data

# ANSI helpers
bold() { printf '\033[1m%s\033[0m' "$*"; }
dim()  { printf '\033[2m%s\033[0m' "$*"; }

# ── Preview by type ────────────────────────────────────────────────────────

case "$type" in

APP)
    printf '%s\n' "$(bold "$value")"
    printf '\n'

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
            # Images — chafa with timeout (see config.toml [preview] image_timeout)
            jpg|jpeg|png|gif|webp|heic|bmp|tiff)
                if command -v chafa >/dev/null 2>&1; then
                    cols="${FZF_PREVIEW_COLUMNS:-$(tput cols)}"
                    lines="${FZF_PREVIEW_LINES:-$(($(tput lines) - 4))}"
                    _chafa_cmd=(chafa --format=symbols --size="${cols}x${lines}" "$value")
                    if   command -v timeout  >/dev/null 2>&1; then
                        timeout "$_IMG_TIMEOUT" "${_chafa_cmd[@]}" 2>/dev/null
                    elif command -v gtimeout >/dev/null 2>&1; then
                        gtimeout "$_IMG_TIMEOUT" "${_chafa_cmd[@]}" 2>/dev/null
                    else
                        perl -e "alarm $_IMG_TIMEOUT; exec @ARGV" "${_chafa_cmd[@]}" 2>/dev/null
                    fi
                else
                    file "$value"
                    printf '\n%s\n' "$(dim "(install chafa for image preview)")"
                fi
                ;;
            # PDF
            pdf)
                if command -v pdftotext >/dev/null 2>&1; then
                    pdftotext "$value" - 2>/dev/null | head -"$_MAX_PDF"
                else
                    file "$value"
                fi
                ;;
            # E: Archives — show file list with truncation notice
            zip|ZIP)
                printf '%s\n\n' "$(bold "ZIP archive: $(basename "$value")")"
                _all=$(unzip -l "$value" 2>/dev/null | tail -n +4 | grep -v '^-' || true)
                _total=$(printf '%s\n' "$_all" | wc -l | tr -d ' ')
                printf '%s\n' "$_all" | head -"$_MAX_ARCHIVE"
                [ "$_total" -gt "$_MAX_ARCHIVE" ] && printf '\n%s\n' "$(dim "… and $((_total - _MAX_ARCHIVE)) more files (${_total} total)")"
                ;;
            tar)
                printf '%s\n\n' "$(bold "TAR archive: $(basename "$value")")"
                _all=$(tar -tf "$value" 2>/dev/null)
                _total=$(printf '%s\n' "$_all" | wc -l | tr -d ' ')
                printf '%s\n' "$_all" | head -"$_MAX_ARCHIVE"
                [ "$_total" -gt "$_MAX_ARCHIVE" ] && printf '\n%s\n' "$(dim "… and $((_total - _MAX_ARCHIVE)) more files (${_total} total)")"
                ;;
            gz|bz2|xz)
                printf '%s\n\n' "$(bold "Archive: $(basename "$value")")"
                _all=$(tar -tf "$value" 2>/dev/null)
                if [ -n "$_all" ]; then
                    _total=$(printf '%s\n' "$_all" | wc -l | tr -d ' ')
                    printf '%s\n' "$_all" | head -"$_MAX_ARCHIVE"
                    [ "$_total" -gt "$_MAX_ARCHIVE" ] && printf '\n%s\n' "$(dim "… and $((_total - _MAX_ARCHIVE)) more files")"
                else
                    file "$value"
                fi
                ;;
            tgz)
                printf '%s\n\n' "$(bold "TAR.GZ archive: $(basename "$value")")"
                _all=$(tar -tzf "$value" 2>/dev/null)
                _total=$(printf '%s\n' "$_all" | wc -l | tr -d ' ')
                printf '%s\n' "$_all" | head -"$_MAX_ARCHIVE"
                [ "$_total" -gt "$_MAX_ARCHIVE" ] && printf '\n%s\n' "$(dim "… and $((_total - _MAX_ARCHIVE)) more files")"
                ;;
            7z)
                printf '%s\n\n' "$(bold "7-Zip archive: $(basename "$value")")"
                if command -v 7z >/dev/null 2>&1; then
                    _all=$(7z l "$value" 2>/dev/null | tail -n +10)
                    _total=$(printf '%s\n' "$_all" | wc -l | tr -d ' ')
                    printf '%s\n' "$_all" | head -"$_MAX_ARCHIVE"
                    [ "$_total" -gt "$_MAX_ARCHIVE" ] && printf '\n%s\n' "$(dim "… and $((_total - _MAX_ARCHIVE)) more entries")"
                else
                    file "$value"
                fi
                ;;
            # Text / code
            *)
                if command -v bat >/dev/null 2>&1; then
                    bat --color=always --style=numbers,changes \
                        --line-range=":${_MAX_TEXT}" "$value" 2>/dev/null \
                    || file "$value"
                else
                    head -"$_MAX_TEXT" "$value" 2>/dev/null || file "$value"
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
        sw=$(( ${FZF_PREVIEW_COLUMNS:-40} - 6 ))
        [ "$sw" -lt 8 ] && sw=8

        # RGB → H S L
        read -r hue sat lum < <(awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN {
            r/=255; g/=255; b/=255
            mx=r>g?(r>b?r:b):(g>b?g:b); mn=r<g?(r<b?r:b):(g<b?g:b)
            l=(mx+mn)/2
            if(mx==mn){h=0;s=0}
            else{
                d=mx-mn; s=l>.5?d/(2-mx-mn):d/(mx+mn)
                if(mx==r)h=(g-b)/d+(g<b?6:0)
                else if(mx==g)h=(b-r)/d+2
                else h=(r-g)/d+4; h/=6
            }
            printf "%d %d %d", int(h*360+.5), int(s*100+.5), int(l*100+.5)
        }')

        printf '\n'

        # Solid swatch (3 rows)
        for _ in 1 2 3; do
            printf "  \033[48;2;%d;%d;%dm%*s\033[0m\n" "$r" "$g" "$b" "$sw" ""
        done
        printf '\n'

        # Gradient bars
        awk -v h="$hue" -v s="$sat" -v l="$lum" -v w="$sw" 'BEGIN {
            printf "  "
            for(i=0;i<w;i++){
                cl = i*100/(w>1?w-1:1)
                split(hsl2rgb(h,s,cl),c)
                printf "\033[48;2;%d;%d;%dm ",c[1],c[2],c[3]
            }
            printf "\033[0m  L\n"

            printf "  "
            for(i=0;i<w;i++){
                cs = i*100/(w>1?w-1:1)
                split(hsl2rgb(h,cs,l),c)
                printf "\033[48;2;%d;%d;%dm ",c[1],c[2],c[3]
            }
            printf "\033[0m  S\n"

            marker = int(h * w / 360 + .5)
            printf "  "
            sl = (s>20?s:70); ll = (l>10&&l<90?l:50)
            for(i=0;i<w;i++){
                ch = i*360/(w>1?w-1:1)
                split(hsl2rgb(ch,sl,ll),c)
                if(i==marker)
                    printf "\033[48;2;%d;%d;%dm\033[38;2;255;255;255m▲\033[0m",c[1],c[2],c[3]
                else
                    printf "\033[48;2;%d;%d;%dm ",c[1],c[2],c[3]
            }
            printf "\033[0m  H\n"
        }
        function hue2rgb(p,q,t){
            if(t<0)t+=1; if(t>1)t-=1
            if(t<1/6)return p+(q-p)*6*t
            if(t<1/2)return q
            if(t<2/3)return p+(q-p)*(2/3-t)*6
            return p
        }
        function hsl2rgb(h,s,l,    q,p,r,g,b){
            h/=360; s/=100; l/=100
            if(s==0){r=g=b=l}
            else{
                q=l<.5?l*(1+s):l+s-l*s; p=2*l-q
                r=hue2rgb(p,q,h+1/3); g=hue2rgb(p,q,h); b=hue2rgb(p,q,h-1/3)
            }
            return int(r*255+.5)" "int(g*255+.5)" "int(b*255+.5)
        }'

        printf '\n'

        hex_lo=$(printf '#%02x%02x%02x' "$r" "$g" "$b")
        hex_up=$(printf '#%02X%02X%02X' "$r" "$g" "$b")
        printf '  HEX  %s  /  %s\n' "$(bold "$hex_lo")" "$hex_up"
        printf '  RGB  rgb(%d, %d, %d)\n' "$r" "$g" "$b"
        printf '  HSL  hsl(%d, %d%%, %d%%)\n' "$hue" "$sat" "$lum"

        awk -v r="$r" -v g="$g" -v b="$b" '
        function lin(c) { c/=255; return c<=0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4 }
        function rate(c) {
            if(c>=7)   return "AAA"
            if(c>=4.5) return "AA"
            if(c>=3)   return "AA large"
            return "fail"
        }
        BEGIN {
            lum = 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b)
            cw = 1.05 / (lum + 0.05)
            cb = (lum + 0.05) / 0.05
            printf "  Contrast  on white %.1f:1 (%s)   on black %.1f:1 (%s)\n",
                cw, rate(cw), cb, rate(cb)
        }'

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
    # Display value is "Name: query" — extract both parts
    _web_name="${value%%: *}"
    _search_query="${value#*: }"
    printf '%s\n\n' "$(bold "Web search")"
    printf '  %s\n\n' "$_search_query"
    printf '%s\n' "$(dim "Enter → open ${_web_name} in browser")"
    ;;

CMD)
    # J: Show live preview of command output
    cmd="${value#> }"
    printf '%s\n\n' "$(bold "$ $cmd")"
    # macOS doesn't ship timeout; use perl as fallback
    if command -v timeout >/dev/null 2>&1; then
        timeout "$_CMD_TIMEOUT" bash -c "$cmd" 2>&1 | head -"$_MAX_TEXT"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$_CMD_TIMEOUT" bash -c "$cmd" 2>&1 | head -"$_MAX_TEXT"
    else
        # perl-based timeout
        perl -e "alarm $_CMD_TIMEOUT; exec @ARGV" bash -c "$cmd" 2>&1 | head -"$_MAX_TEXT"
    fi
    printf '\n%s\n' "$(dim "Enter → execute in terminal")"
    ;;

BOOKMARK)
    url="${type_data//%7C/|}"
    printf '%s\n\n' "$(bold "$value")"
    printf '%s\n\n' "$(dim "$url")"
    printf '%s\n' "$(dim "Enter → open in browser")"
    ;;

KILL)
    # value is "processname [PID]"
    proc="${value% \[*\]}"
    pid="${value##*\[}"; pid="${pid%\]}"
    printf '%s\n\n' "$(bold "Kill: $proc")"
    printf 'PID  %s\n\n' "$pid"
    # Show process info
    ps -p "$pid" -o pid,ppid,%cpu,%mem,start,command 2>/dev/null | tail -n +2
    printf '\n%s\n' "$(dim "Enter → pkill $proc")"
    ;;

CLIP)
    printf '%s\n\n' "$(bold "Clipboard")"
    # Unescape stored newlines for display
    printf '%s\n\n' "${value//\\n/$'\n'}"
    printf '%s\n' "$(dim "Enter → copy to clipboard")"
    ;;

CLAUDE)
    printf '%s\n\n' "$(bold "Claude Code")"
    printf '  $ %s\n\n' "$value"
    printf '%s\n' "$(dim "Enter → launch in terminal")"
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
