#!/usr/bin/env bash
# ランチャーを再起動する
# fish の while true ループが launcher.sh を自動的に再実行するため、
# 既存のプロセスを終了してキャッシュをクリアするだけで再起動が完了する

# 1. ターミナル状態をリセット（フリーズ後に文字が表示されない場合など）
stty sane 2>/dev/null

# 2. 実行中の fzf と launcher と「子孫プロセス」を終了
# CMD アクションで暴走した ping 等を取りこぼさないよう、launcher.sh の
# 子孫を再帰的に集めてから TERM → 0.3s → KILL の二段階で落とす。
_descendants() {
    # $1 のPIDの全子孫を出力 (DFS)
    local parent=$1
    local child
    for child in $(pgrep -P "$parent" 2>/dev/null); do
        echo "$child"
        _descendants "$child"
    done
}
_pids() {
    {
        pgrep -x fzf
        for p in $(pgrep -f "launcher.sh" 2>/dev/null); do
            echo "$p"
            _descendants "$p"
        done
        pgrep -f "launcher-search"
    } 2>/dev/null | sort -u
}
killed=0
pids="$(_pids | tr '\n' ' ')"
if [ -n "$pids" ]; then
    kill $pids 2>/dev/null
    killed=$(printf '%s\n' $pids | wc -l | tr -d ' ')
    sleep 0.3
    still="$(_pids | tr '\n' ' ')"
    [ -n "$still" ] && kill -9 $still 2>/dev/null
fi

# 3. キャッシュ・テンポラリ・ログをまとめて掃除
T="${TMPDIR:-/tmp}"
rm -f "$T/launcher_apps_cache.txt" "$T/launcher_recent_cache.txt"
# launcher.sh の `mktemp /tmp/launcher_out.XXXXXX` が残骸として溜まる
find /tmp -maxdepth 1 -name 'launcher_out.*' -user "$USER" -delete 2>/dev/null
# Wi-Fi / Bluetooth アクションのデバッグログ
rm -f /tmp/launcher_wifi.log /tmp/launcher_bt.log
# 現在 SSID キャッシュ（system_profiler のフォールバック結果）
rm -f /tmp/launcher_wifi_ssid.txt

printf 'launcher: restarted (killed %d process(es))\n' "$killed"
