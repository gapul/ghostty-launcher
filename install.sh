#!/usr/bin/env bash
# Launcher インストールスクリプト
# 新しいマシンでクローン後に実行: bash ~/.config/launcher/install.sh

set -e
LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Launcher インストール ==="
echo ""

# 実行権限
chmod +x "$LAUNCHER_DIR/core/launcher.sh"
chmod +x "$LAUNCHER_DIR/core/search.sh"
chmod +x "$LAUNCHER_DIR/core/restart.sh"
echo "✓ 実行権限を付与しました"

# icon_map.sh のダウンロード
ICON_MAP="$LAUNCHER_DIR/icon_map.sh"
if [ ! -f "$ICON_MAP" ]; then
    echo "icon_map.sh をダウンロード中..."
    RELEASE_URL="https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/icon_map.sh"
    if curl -fsSL "$RELEASE_URL" -o "$ICON_MAP"; then
        echo "✓ icon_map.sh をダウンロードしました"
    else
        echo "⚠ icon_map.sh のダウンロードに失敗しました（スキップ）"
    fi
else
    echo "- icon_map.sh は既に存在します"
fi

echo ""
echo "=== シェル設定 ==="

# シェルを自動検出してセットアップ方法を案内
SHELL_NAME="$(basename "${SHELL:-bash}")"

case "$SHELL_NAME" in
    fish)
        CONFIG="$HOME/.config/fish/config.fish"
        MARKER="# Launcher: fish_function_path に追加"
        if ! grep -qF "$MARKER" "$CONFIG" 2>/dev/null; then
            echo "" >> "$CONFIG"
            echo "$MARKER" >> "$CONFIG"
            echo "set -p fish_function_path $LAUNCHER_DIR" >> "$CONFIG"
            echo "" >> "$CONFIG"
            cat "$LAUNCHER_DIR/shells/fish.fish" | grep -A999 "クイックターミナル" >> "$CONFIG"
            echo "✓ ~/.config/fish/config.fish を更新しました"
        else
            echo "- fish config は設定済みです"
        fi
        ;;
    zsh)
        CONFIG="$HOME/.zshrc"
        MARKER="# Launcher"
        if ! grep -qF "$MARKER" "$CONFIG" 2>/dev/null; then
            echo "" >> "$CONFIG"
            echo "source $LAUNCHER_DIR/shells/zsh.sh" >> "$CONFIG"
            echo "✓ ~/.zshrc を更新しました"
        else
            echo "- zsh config は設定済みです"
        fi
        ;;
    bash)
        CONFIG="$HOME/.bashrc"
        MARKER="# Launcher"
        if ! grep -qF "$MARKER" "$CONFIG" 2>/dev/null; then
            echo "" >> "$CONFIG"
            echo "source $LAUNCHER_DIR/shells/bash.sh" >> "$CONFIG"
            echo "✓ ~/.bashrc を更新しました"
        else
            echo "- bash config は設定済みです"
        fi
        ;;
    *)
        echo "⚠ シェルを自動検出できませんでした。手動で設定してください："
        echo "  shells/ 以下のスニペットをシェルの設定ファイルに追加してください"
        ;;
esac

echo ""
echo "=== ターミナル設定 ==="
echo "使用するターミナルの設定スニペットを確認してください："
echo "  terminals/ghostty.conf   - Ghostty"
echo "  terminals/kitty.conf     - kitty"
echo "  terminals/wezterm.lua    - WezTerm"

echo ""
echo "=== 完了 ==="
echo "新しいターミナルを開くか、設定ファイルを再読み込みしてください。"
