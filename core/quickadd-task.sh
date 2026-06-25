#!/usr/bin/env bash
# Tasks 風モーダル: 本文 → 期日 → 優先度 → タグ を順次プロンプトし、
# Tasks プラグインの絵文字記法で組み立てた文字列を QuickAdd の "Add Task"
# choice に CLI 経由で渡す。各ステップ Esc/Ctrl-C で全体キャンセル。

set -u

VAULT_NAME="notes"
VAULT_PATH="/Users/yuki/Documents/notes"
OBSIDIAN_BIN="/Applications/Obsidian.app/Contents/MacOS/obsidian"
TAG_CACHE="/tmp/launcher_obsidian_tags.txt"
TAG_CACHE_TTL=3600  # 1h

# 親 launcher.sh から色を受け取れたら使う
FZF_COLORS="${_fzf_colors:-}"
POINTER="${_pointer:-❯}"

_fzf() {
    fzf --layout=reverse --height=100% \
        --border=rounded --border-label-pos=2 --padding="1,2" \
        --pointer="$POINTER" --info=hidden --no-scrollbar \
        ${FZF_COLORS:+--color="$FZF_COLORS"} \
        --bind="esc:abort" --bind="ctrl-c:abort" \
        "$@"
}

# Step 1: 本文 (必須)
desc=$(
    : | _fzf --print-query --prompt="󰄬 Task> " \
             --border-label=" 󰄬  本文 " | head -1
)
[ -z "$desc" ] && exit 0

# Step 2: 期日 — プリセット選択
date_choice=$(printf '%s\n' \
    "none|（期日なし）" \
    "today|今日" \
    "tomorrow|明日" \
    "+3d|3日後" \
    "+1w|1週間後" \
    "+2w|2週間後" \
    "+1m|1ヶ月後" \
    "mon|次の月曜" \
    "tue|次の火曜" \
    "wed|次の水曜" \
    "thu|次の木曜" \
    "fri|次の金曜" \
    "sat|次の土曜" \
    "sun|次の日曜" \
    "custom|YYYY-MM-DD を入力…" \
    | _fzf --delimiter='|' --with-nth=2 \
           --prompt="📅 期日> " --border-label=" 📅  期日 ")
[ -z "$date_choice" ] && exit 0
date_key="${date_choice%%|*}"

if [ "$date_key" = "custom" ]; then
    date_key=$(: | _fzf --print-query --prompt="📅 YYYY-MM-DD> " \
                        --border-label=" 📅  日付入力 " | head -1)
    [ -z "$date_key" ] && exit 0
fi

due=""
if [ "$date_key" != "none" ]; then
    due=$(python3 - "$date_key" <<'PY'
import sys, datetime, re
key = sys.argv[1].strip().lower()
today = datetime.date.today()
WD = {"mon":0,"tue":1,"wed":2,"thu":3,"fri":4,"sat":5,"sun":6}
if key == "today":
    d = today
elif key == "tomorrow":
    d = today + datetime.timedelta(days=1)
elif m := re.fullmatch(r"\+(\d+)d", key):
    d = today + datetime.timedelta(days=int(m.group(1)))
elif m := re.fullmatch(r"\+(\d+)w", key):
    d = today + datetime.timedelta(weeks=int(m.group(1)))
elif m := re.fullmatch(r"\+(\d+)m", key):
    # 月加算: dateutil なしで近似
    y, mo = today.year, today.month + int(m.group(1))
    y += (mo - 1) // 12; mo = (mo - 1) % 12 + 1
    import calendar
    d = today.replace(year=y, month=mo, day=min(today.day, calendar.monthrange(y, mo)[1]))
elif key in WD:
    target = WD[key]
    delta = (target - today.weekday()) % 7
    delta = 7 if delta == 0 else delta  # 「次の」なので同じ曜日は来週
    d = today + datetime.timedelta(days=delta)
elif re.fullmatch(r"\d{4}-\d{2}-\d{2}", key):
    d = datetime.date.fromisoformat(key)
else:
    print("", end=""); sys.exit(0)
print(d.isoformat(), end="")
PY
)
fi

# Step 3: 優先度
prio_choice=$(printf '%s\n' \
    "none|（優先度なし）" \
    "🔺|🔺 highest" \
    "⏫|⏫ high" \
    "🔼|🔼 medium" \
    "🔽|🔽 low" \
    "⏬|⏬ lowest" \
    | _fzf --delimiter='|' --with-nth=2 \
           --prompt="⚡ 優先度> " --border-label=" ⚡  優先度 ")
[ -z "$prio_choice" ] && exit 0
prio_emoji="${prio_choice%%|*}"
[ "$prio_emoji" = "none" ] && prio_emoji=""

# Step 4: タグ (vault からキャッシュ + 多選択 + 自由入力可)
need_refresh=1
if [ -f "$TAG_CACHE" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$TAG_CACHE" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$TAG_CACHE_TTL" ] && need_refresh=0
fi
if [ "$need_refresh" -eq 1 ]; then
    grep -hroE '#[A-Za-z0-9_/一-龯ぁ-んァ-ヶー-]+' \
        --include='*.md' "$VAULT_PATH" 2>/dev/null \
        | sort -u > "$TAG_CACHE"
fi

tag_selection=$(
    cat "$TAG_CACHE" 2>/dev/null \
        | _fzf --multi --print-query \
               --prompt="# タグ> " --border-label=" #  タグ (Tab=複数, Enter=確定) "
)
[ $? -ne 0 ] && exit 0  # Esc

# --print-query は1行目=クエリ、2行目以降=選択。両方使う
typed=$(printf '%s\n' "$tag_selection" | head -1)
picked=$(printf '%s\n' "$tag_selection" | tail -n +2)

# typed が選択行と重複しない、空でない場合だけ追加。# が無ければ付ける
typed_tag=""
if [ -n "$typed" ] && ! printf '%s\n' "$picked" | grep -qFx -- "$typed" \
   && ! printf '%s\n' "$picked" | grep -qFx -- "#$typed"; then
    case "$typed" in
        \#*) typed_tag="$typed" ;;
        *)   typed_tag="#$typed" ;;
    esac
fi

tags=""
if [ -n "$picked" ] || [ -n "$typed_tag" ]; then
    tags=$(printf '%s\n%s' "$picked" "$typed_tag" | awk 'NF' | tr '\n' ' ')
    tags="${tags% }"
fi

# 組み立て: 本文 [#tags] [優先度] [📅 due]
line="$desc"
[ -n "$tags" ]       && line="$line $tags"
[ -n "$prio_emoji" ] && line="$line $prio_emoji"
[ -n "$due" ]        && line="$line 📅 $due"

# QuickAdd CLI 経由で投入
printf '\033[2J\033[H'
"$OBSIDIAN_BIN" vault="$VAULT_NAME" quickadd:run \
    choice="Add Task" value-text="$line" 2>&1 \
    | grep -v 'installer is out of date' \
    | grep -v 'Loading updated app package' \
    | tail -3
