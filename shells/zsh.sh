# zsh シェル統合スニペット
# ~/.zshrc の末尾に追加:
#   source ~/.config/launcher/shells/zsh.sh

launcher() {
    bash ~/.config/launcher/core/launcher.sh
}

launcher-restart() {
    bash ~/.config/launcher/core/restart.sh
}

# クイックターミナルモードでランチャーを自動起動
# 対応ターミナル: Ghostty（GHOSTTY_QUICK_TERMINAL）
#                 カスタム設定（LAUNCHER_QUICK_TERMINAL）
if [[ -n "${GHOSTTY_QUICK_TERMINAL}" ]] || [[ -n "${LAUNCHER_QUICK_TERMINAL}" ]]; then
    while true; do
        clear
        launcher
    done
fi
