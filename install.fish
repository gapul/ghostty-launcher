#!/usr/bin/env fish
# Launcher インストールスクリプト
# 新しいマシンでクローン後に実行: fish ~/.config/launcher/install.fish

set LAUNCHER_DIR (realpath (dirname (status filename)))

# 1. fish_function_path への追加（config.fish）
set CONFIG_FISH ~/.config/fish/config.fish
set MARKER "# Launcher: fish_function_path に追加"

if not grep -qF "$MARKER" $CONFIG_FISH
    echo "" >> $CONFIG_FISH
    echo $MARKER >> $CONFIG_FISH
    echo "set -p fish_function_path $LAUNCHER_DIR" >> $CONFIG_FISH
    echo "✓ config.fish を更新しました"
else
    echo "- config.fish は設定済みです"
end

# 2. icon_map.sh のダウンロード（sketchybar-app-font）
set ICON_MAP $LAUNCHER_DIR/icon_map.sh
if not test -f $ICON_MAP
    echo "icon_map.sh をダウンロード中..."
    set RELEASE_URL "https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/icon_map.sh"
    if curl -fsSL $RELEASE_URL -o $ICON_MAP
        echo "✓ icon_map.sh をダウンロードしました"
    else
        echo "✗ icon_map.sh のダウンロードに失敗しました（スキップ）"
    end
else
    echo "- icon_map.sh は既に存在します"
end

# 3. launcher_search.sh に実行権限を付与
chmod +x $LAUNCHER_DIR/launcher_search.sh
echo "✓ launcher_search.sh に実行権限を付与しました"

# 4. Ghostty の設定確認
set GHOSTTY_CONFIG ~/Library/Application\ Support/com.mitchellh.ghostty/config
if not grep -q "toggle_quick_terminal" $GHOSTTY_CONFIG 2>/dev/null
    echo ""
    echo "⚠ Ghostty の設定が必要です。以下を追加してください："
    echo "  $GHOSTTY_CONFIG"
    echo ""
    echo "  initial-window = false"
    echo "  keybind = global:super+space=toggle_quick_terminal"
    echo "  quick-terminal-position = center"
else
    echo "- Ghostty は設定済みです"
end

echo ""
echo "インストール完了。新しいターミナルを開くか、以下を実行してください："
echo "  source ~/.config/fish/config.fish"
