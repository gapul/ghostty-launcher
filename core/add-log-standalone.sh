#!/bin/bash
# ホットキー(Cmd+Ctrl+Opt+O)から呼ばれる。
# フラグファイル方式: 次に起動する launcher.sh が QUICKADD で直接立ち上がる。
# 通常ランチャーを経由しないので一切フラッシュなし。

# ── 二重発火防止 ──
LOCK=/tmp/launcher_addlog_inflight
if [ -e "$LOCK" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
    [ "$age" -lt 3 ] && exit 0
fi
touch "$LOCK"
( sleep 4 && rm -f "$LOCK" ) &

# 次の launcher.sh 起動でQUICKADDに分岐させるフラグ
echo QUICKADD > /tmp/launcher_action_pending

# 現在動いてる launcher / fzf を kill → fish loopが反復 → 新 launcher.sh がフラグを拾う
pgrep -f "launcher.sh" | xargs kill 2>/dev/null
pgrep -x fzf | xargs kill 2>/dev/null

# Ghostty quick terminal が前面でなければ Cmd+Space で表示
front=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
if [ "$front" != "Ghostty" ]; then
    osascript -e 'tell application "System Events" to keystroke space using {command down}' 2>/dev/null
fi
