# fish シェル統合スニペット
# ~/.config/fish/config.fish に追加するか、このファイルを source する

# Launcher: fish_function_path に追加
set -p fish_function_path ~/.config/launcher

# クイックターミナルモードでランチャーを自動起動
# 対応ターミナル: Ghostty（GHOSTTY_QUICK_TERMINAL）
#                 カスタム設定（LAUNCHER_QUICK_TERMINAL）
if status is-interactive
    if set -q GHOSTTY_QUICK_TERMINAL; or set -q LAUNCHER_QUICK_TERMINAL
        while true
            clear
            launcher
        end
    end
end
