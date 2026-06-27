#!/usr/bin/env bash
# Launcher core — shell & terminal agnostic (bash 3.2+)

LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LAUNCHER_DIR

# ── 直接アクションモード ──────────────────────────────────────────────────
# Usage: launcher.sh --action <TYPE>
#   fzf を介さず特定の type の dispatch を直接実行する。
#   例: launcher.sh --action QUICKADD     # Add Logプロンプト
#       launcher.sh --action WIFI_TOGGLE  # Wi-Fiオンオフ
#       launcher.sh --action SYS_LOCK     # 画面ロック
DIRECT_ACTION=""
if [ "$1" = "--action" ] && [ -n "$2" ]; then
    DIRECT_ACTION="$2"
fi

# ホットキー等から /tmp/launcher_action_pending にアクション名が書かれていれば
# それを --action として再exec (通常ランチャーを経由せず直接該当画面へ)
if [ -z "$DIRECT_ACTION" ] && [ -f /tmp/launcher_action_pending ]; then
    _flag_action=$(cat /tmp/launcher_action_pending 2>/dev/null)
    rm -f /tmp/launcher_action_pending
    if [ -n "$_flag_action" ]; then
        exec bash "$0" --action "$_flag_action"
    fi
fi

_BIN="$LAUNCHER_DIR/core/launcher-search"
SEARCH="$_BIN"

if [ ! -x "$_BIN" ]; then
    printf 'launcher: binary not found: %s\n' "$_BIN" >&2
    printf 'launcher: run: cd %s/launcher-search && cargo build --release\n' "$LAUNCHER_DIR" >&2
    exit 1
fi

OS="$(uname)"

command -v fzf >/dev/null 2>&1 || {
    printf 'launcher: fzf not found. Install it with: brew install fzf\n' >&2
    exit 1
}

# ── Temp file — cleaned up on exit ────────────────────────────────────────
_TMPOUT=$(mktemp /tmp/launcher_out.XXXXXX)

# Cleanup on exit (Ctrl-C, abort, normal exit)
# stty sane を入れることで Ctrl+C で read 中断時に raw mode が残るのを防ぐ
_cleanup() {
    rm -f "$_TMPOUT"
    stty sane 2>/dev/null
}
trap '_cleanup' EXIT

# ── Terminal close helper ─────────────────────────────────────────────────
# ── Terminal close helper ─────────────────────────────────────────────────
# Call _close only when Ghostty is still frontmost (Esc, CLIP, KILL, etc.).
# For APP/FILE/WEB/BOOKMARK don't call _close: quick-terminal-autohide=true
# hides the window as soon as the opened app takes focus.  Sending the toggle
# key at that point would re-open the terminal instead of keeping it hidden.
_close() {
    if   [ -n "$GHOSTTY_QUICK_TERMINAL" ]; then
        osascript -e 'tell application "System Events" to key code 49 using {command down}' 2>/dev/null
        sleep 0.1
    elif [ -n "$KITTY_WINDOW_ID" ]; then
        kitty @ close-window 2>/dev/null
    elif [ -n "$WEZTERM_PANE" ]; then
        wezterm cli kill-pane 2>/dev/null
    elif [ -n "$LAUNCHER_CLOSE_CMD" ]; then
        # Safety: reject strings containing shell metacharacters
        case "$LAUNCHER_CLOSE_CMD" in
            *[\;\|\&\`\$\(\)\<\>\\]*)
                printf 'launcher: LAUNCHER_CLOSE_CMD contains unsafe characters, skipping\n' >&2
                ;;
            *)
                # Execute as a simple command (no eval, no shell expansion)
                $LAUNCHER_CLOSE_CMD 2>/dev/null
                ;;
        esac
    fi
}

# ── OS helpers ────────────────────────────────────────────────────────────
_open() {
    if [ "$OS" = "Darwin" ]; then open "$@"
    else xdg-open "$@" 2>/dev/null
    fi
}

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

# ── Clipboard ─────────────────────────────────────────────────────────────
_copy() {
    if   command -v pbcopy >/dev/null 2>&1; then printf '%s' "$1" | pbcopy
    elif command -v xclip  >/dev/null 2>&1; then printf '%s' "$1" | xclip -selection clipboard
    elif command -v xsel   >/dev/null 2>&1; then printf '%s' "$1" | xsel --clipboard --input
    fi
    # Record to clipboard history (fire-and-forget)
    "$_BIN" clip-record "$1" &
}

# ── Frecency record ───────────────────────────────────────────────────────
_record() { "$_BIN" record "$1" "$2" & }

# ── Config-driven fzf layout (one binary call, 4 lines) ──────────────────
{ IFS= read -r _prompt
  IFS= read -r _pointer
  IFS= read -r _border_label
  IFS= read -r _preview_window
} < <("$_BIN" fzf-layout 2>/dev/null)
: "${_prompt:=  }"
: "${_pointer:=❯}"
: "${_border_label:= 󰀻  Launcher }"
: "${_preview_window:=right:40%:wrap}"

# ── Config-driven preview settings (exported for preview.sh) ─────────────
{ IFS= read -r LAUNCHER_IMG_TIMEOUT
  IFS= read -r LAUNCHER_CMD_TIMEOUT
  IFS= read -r LAUNCHER_MAX_ARCHIVE
  IFS= read -r LAUNCHER_MAX_TEXT
  IFS= read -r LAUNCHER_MAX_PDF
} < <("$_BIN" preview-config 2>/dev/null)
: "${LAUNCHER_IMG_TIMEOUT:=3}"
: "${LAUNCHER_CMD_TIMEOUT:=5}"
: "${LAUNCHER_MAX_ARCHIVE:=40}"
: "${LAUNCHER_MAX_TEXT:=100}"
: "${LAUNCHER_MAX_PDF:=80}"
export LAUNCHER_IMG_TIMEOUT LAUNCHER_CMD_TIMEOUT LAUNCHER_MAX_ARCHIVE LAUNCHER_MAX_TEXT LAUNCHER_MAX_PDF

# ── fzf colors ───────────────────────────────────────────────────────────
# 端末の 16 色 ANSI を継承 → ghostty の Rosé Pine / Rosé Pine Dawn (macOS 外観追従)
# に自動で乗る。config.toml [appearance] の hex 固定をやめ light/dark 自動切替に対応。
_fzf_colors="16"

_PREVIEW="$LAUNCHER_DIR/core/preview.sh"

if [ -n "$DIRECT_ACTION" ]; then
    # ── 直接アクションモード: fzfをスキップして type を直接セット ───────────
    type="$DIRECT_ACTION"
    type_data=""
    value=""
    printf '\033[2J\033[H'
else
    # ── Launch fzf ────────────────────────────────────────────────────────
    fzf \
        --prompt="$_prompt" \
        --pointer="$_pointer" \
        --height=100% \
        --border=rounded \
        --border-label="$_border_label" \
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
        --bind="ctrl-o:become(bash $LAUNCHER_DIR/core/launcher.sh --action QUICKADD)" \
        --preview="$_PREVIEW {}" \
        --preview-window="$_preview_window" \
        --color="$_fzf_colors" \
        > "$_TMPOUT"
    _FZF_EXIT=$?

    selected=$(cat "$_TMPOUT")
    # _TMPOUT cleaned up by EXIT trap

    if [ -z "$selected" ] || [ "$_FZF_EXIT" -ne 0 ]; then
        # Close the terminal BEFORE clearing the screen so the user sees an
        # instant hide — identical to pressing Cmd+Space while the terminal is open.
        _close
        printf '\033[2J\033[H'
        exit 0
    fi

    printf '\033[2J\033[H'

    # ── Parse selection ───────────────────────────────────────────────────
    # Format: "TYPE|ICON display"  — TYPE may embed data: "BOOKMARK:URL"
    raw_type="${selected%%|*}"
    display="${selected#*|}"
    value="${display:2}"  # strip icon (1 code point) + space

    type="${raw_type%%:*}"
    type_data="${raw_type#*:}"
    [ "$type_data" = "$raw_type" ] && type_data=""
fi

# ── Action dispatch ───────────────────────────────────────────────────────
case "$type" in
    APP)
        _record APP "$value"
        _open_app "$value"
        # No _close: quick-terminal-autohide hides the window when the app takes focus
        ;;
    FILE)
        _record FILE "$value"
        _open "$value"
        # No _close: quick-terminal-autohide hides the window when the app takes focus
        ;;
    COLOR)
        _copy "$value"
        _close
        ;;
    CALC)
        _copy "${value#= }"
        _close
        ;;
    CMD)
        # Intentional shell execution for CMD type — value comes from user's own query
        cmd="${value#> }"
        # tee で stdout/stderr を画面と一時ファイルへ同時に流し、後でクリップボードに転送。
        out_file=$(mktemp /tmp/launcher_cmdout.XXXXXX)
        # launcher.sh は SIGINT を ignore (case 内ずっと)。
        # Ctrl+C で launcher.sh が死ぬと fish の while ループも脱出してしまうため。
        # 走るコマンドは内側で trap - INT して Ctrl+C で殺せるようにする。
        trap '' SIGINT
        ${SHELL:-bash} -c "trap - INT; $cmd" 2>&1 | tee "$out_file"
        # ANSI escape (色・カーソル制御) は pbcopy で貼ったときにゴミになるので除去。
        out=$(perl -pe 's/\e\[[0-9;?]*[a-zA-Z]//g' < "$out_file")
        rm -f "$out_file"
        # クリップボードには "$ cmd\n<出力>" をフルで。
        full="\$ $cmd"$'\n'"$out"
        if   command -v pbcopy >/dev/null 2>&1; then printf '%s' "$full" | pbcopy
        elif command -v xclip  >/dev/null 2>&1; then printf '%s' "$full" | xclip -selection clipboard
        elif command -v xsel   >/dev/null 2>&1; then printf '%s' "$full" | xsel --clipboard --input
        fi
        # ランチャーのクリップ履歴には残さない (COLOR/CALC/CLIP のような明示的な
        # 「コピー」と違い、CMD は実行が主目的でコマンド文字列を履歴に貯める価値が薄い)。
        stty sane 2>/dev/null
        printf '\n\033[2m[Enter to close · ESC to back]\033[0m'
        # 1文字読み: Enter=閉じる / ESC=launcher fzfに戻る / その他=無視して待機
        while IFS= read -rsn 1 _key; do
            case "$_key" in
                $'\e')
                    printf '\033[2J\033[H'
                    exit 0  # _closeせず終了 → fish loopが新launcher fzfを起動
                    ;;
                '')
                    break  # Enter
                    ;;
            esac
        done
        printf '\033[2J\033[H'
        _close
        ;;
    WEB)
        # Full URL is embedded in type_data (e.g. https://duckduckgo.com/?q=hello)
        _open "${type_data}"
        # No _close: quick-terminal-autohide hides the window when the browser takes focus
        ;;
    SSH)
        _record SSH "$value"
        # CMDと同じく: case 内ずっと SIGINT ignore で launcher.sh を保護。
        # ssh 自体は Ctrl+C を remote に転送する処理を持つので影響なし。
        trap '' SIGINT
        ssh "$value"
        stty sane 2>/dev/null
        printf '\n\033[2m[Enter to close · ESC to back]\033[0m'
        while IFS= read -rsn 1 _key; do
            case "$_key" in
                $'\e')
                    printf '\033[2J\033[H'
                    exit 0
                    ;;
                '')
                    break
                    ;;
            esac
        done
        printf '\033[2J\033[H'
        _close
        ;;
    BOOKMARK)
        url="${type_data//%7C/|}"
        _record BOOKMARK "$url"
        _open "$url"
        # No _close: quick-terminal-autohide hides the window when the browser takes focus
        ;;
    KILL)
        proc="${value% \[*\]}"
        pkill -x "$proc" 2>/dev/null || pkill "$proc" 2>/dev/null || true
        _close
        ;;
    CLIP)
        text="${value//\\n/$'\n'}"
        _copy "$text"
        _close
        ;;
    CLAUDE)
        printf '\033[2J\033[H'
        # Split args on whitespace so "claude --project foo" passes 2 separate args
        read -ra _claude_args <<< "${value#claude}"
        claude "${_claude_args[@]}"
        ;;
    QUICKADD)
        log_text=$(
            : | fzf --print-query --prompt="󰏭 Add Log> " \
                    --layout=reverse --height=100% \
                    --border=rounded --border-label=" 󰏭  Add Log " \
                    --border-label-pos=2 --padding="1,2" \
                    --pointer="$_pointer" --info=hidden --no-scrollbar \
                    --color="$_fzf_colors" \
                    --bind="esc:abort" --bind="ctrl-c:abort" \
                | head -1
        )
        printf '\033[2J\033[H'
        if [ -n "$log_text" ]; then
            /Applications/Obsidian.app/Contents/MacOS/obsidian \
                vault=notes quickadd:run \
                choice="Add Log" value-text="$log_text" >/dev/null 2>&1
        fi
        _close
        ;;
    QUICKTASK)
        # 擬似モーダル (本文/期日/優先度/タグ) はヘルパースクリプトに分離
        _fzf_colors="$_fzf_colors" _pointer="$_pointer" \
            bash "$LAUNCHER_DIR/core/quickadd-task.sh"
        _close
        ;;
    WIFI_TOGGLE)
        state=$(networksetup -getairportpower en0 2>/dev/null | awk '{print $NF}')
        new=$([ "$state" = "On" ] && echo off || echo on)
        networksetup -setairportpower en0 "$new"
        _close
        ;;
    WIFI|WIFI_LIST)
        # WIFI_LIST is a drill-down: re-prompt with all preferred SSIDs.
        # WIFI dispatches directly with $type_data already containing the SSID.
        if [ "$type" = "WIFI_LIST" ]; then
            sub_selected=$(
                "$_BIN" wifi-list \
                    | fzf --prompt="Wi-Fi> " --layout=reverse --height=100% \
                          --border=rounded --border-label=" 󰖩  Wi-Fi " \
                          --border-label-pos=2 --padding="1,2" \
                          --pointer="$_pointer" --info=hidden --no-scrollbar \
                          --delimiter='|' --with-nth=2.. \
                          --color="$_fzf_colors"
            )
            [ -z "$sub_selected" ] && _close && exit 0
            ssid="${sub_selected%%|*}"; ssid="${ssid#WIFI:}"
        else
            ssid="$type_data"
        fi
        # macOS Sequoia restricts `networksetup -setairportnetwork`: it
        # returns -3900 tmpErr for in-keychain networks, "Could not find" for
        # out-of-range, etc. networksetup always exits 0, so any output means
        # failure (success is silent). On failure, open the Wi-Fi Control
        # Center popup — Apple's built-in Wi-Fi UI has full permissions and
        # the user can complete the join with one click.
        result=$(networksetup -setairportnetwork en0 "$ssid" 2>&1)
        echo "$(date '+%H:%M:%S') WIFI ssid=[$ssid] result=[$result]" >>/tmp/launcher_wifi.log
        if [ -n "$result" ]; then
            osascript -e 'tell application "System Events" to tell process "ControlCenter" to click (first menu bar item of menu bar 1 whose description starts with "Wi‑Fi")' 2>/dev/null
        fi
        _close
        ;;
    WIFI_STATUS)
        open /System/Library/PreferencePanes/Network.prefPane
        ;;
    BT_TOGGLE)
        state=$(blueutil --power 2>/dev/null)
        blueutil --power $((1 - state))
        _close
        ;;
    BT|BT_LIST)
        if [ "$type" = "BT_LIST" ]; then
            sub_selected=$(
                "$_BIN" bt-list \
                    | fzf --prompt="Bluetooth> " --layout=reverse --height=100% \
                          --border=rounded --border-label=" 󰂯  Bluetooth " \
                          --border-label-pos=2 --padding="1,2" \
                          --pointer="$_pointer" --info=hidden --no-scrollbar \
                          --delimiter='|' --with-nth=2.. \
                          --color="$_fzf_colors"
            )
            [ -z "$sub_selected" ] && _close && exit 0
            addr="${sub_selected%%|*}"; addr="${addr#BT:}"
        else
            addr="$type_data"
        fi
        connected=$(blueutil --is-connected "$addr" 2>&1)
        if [ "$connected" = "1" ]; then
            action=disconnect
            result=$(blueutil --disconnect "$addr" 2>&1)
        else
            action=connect
            result=$(blueutil --connect "$addr" 2>&1)
        fi
        echo "$(date '+%H:%M:%S') BT $action addr=[$addr] connected_was=[$connected] result=[$result] exit=$?" \
            >>/tmp/launcher_bt.log
        _close
        ;;
    BT_STATUS)
        open /System/Library/PreferencePanes/Bluetooth.prefPane
        ;;
    MENU_ITEMS_LIST)
        # Raycast 風: 直前まで前面だったアプリのメニューバー項目を fzf で検索→実行。
        # menu-items list が /tmp/launcher_menu_target_pid に対象PIDを書き、
        # click で同じPIDに AXPress を送る。`_close` してから click することで
        # 対象アプリが前面に戻ってから dispatch される (= 一部の "frontmost-only" 項目も発火する)。
        sub_selected=$(
            "$LAUNCHER_DIR/core/menu-items" list 2>/dev/null \
                | fzf --prompt="󰍜 Menu> " --layout=reverse --height=100% \
                      --border=rounded --border-label=" 󰍜  Menu Items " \
                      --border-label-pos=2 --padding="1,2" \
                      --pointer="$_pointer" --info=hidden --no-scrollbar \
                      --delimiter='|' --with-nth=2.. \
                      --color="$_fzf_colors" \
                      --bind="esc:abort" --bind="ctrl-c:abort"
        )
        if [ -z "$sub_selected" ]; then
            rm -f /tmp/launcher_menu_target_pid
            _close
            exit 0
        fi
        raw="${sub_selected%%|*}"
        b64="${raw#MENU:}"
        _close
        # Ghostty が hide してフォーカスが戻るのを待つ (短すぎると AXPress が
        # disabled な menu item に当たることがある)。
        sleep 0.15
        "$LAUNCHER_DIR/core/menu-items" click "$b64" 2>/dev/null
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
        if [ "$OS" = "Darwin" ]; then
            osascript -e 'tell application "Finder" to empty trash'
        else
            rm -rf ~/.local/share/Trash/files/* 2>/dev/null
        fi
        _close
        ;;
    SYS_RESTART)
        if [ "$OS" = "Darwin" ]; then
            osascript -e 'tell application "System Events" to restart'
        else
            systemctl reboot 2>/dev/null
        fi
        ;;
    SYS_SHUTDOWN)
        if [ "$OS" = "Darwin" ]; then
            osascript -e 'tell application "System Events" to shut down'
        else
            systemctl poweroff 2>/dev/null
        fi
        ;;
    LAUNCHER_RESTART)
        # restart.sh はキャッシュ削除＋残留 fzf/launcher プロセスの掃除を行う。
        # `exec` で置き換える理由: bash で呼ぶと restart.sh の `pgrep -f launcher.sh`
        # が自分の呼び出し元 (この launcher.sh プロセス) にマッチして自殺してしまう。
        # exec すると現プロセスが restart.sh に置き換わってコマンドラインが変わり、
        # pgrep にマッチしなくなる。PID 連続性も保たれる。
        # _close は呼ばない: Ghostty Quick Terminal なら fish の while ループが
        # 自動的に launcher を再起動する。それ以外のターミナルでは
        # スクリプトが終了してシェルに戻るだけで、こちらも期待通りの挙動。
        exec bash "$LAUNCHER_DIR/core/restart.sh"
        ;;
esac
