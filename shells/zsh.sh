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
    # fzf を Ctrl-C で抜けたとき zsh が while ループごと打ち切るのを防ぐ
    # （死ぬと Quick Terminal は同じシェルを使い回すため素のプロンプトのまま戻らない）
    TRAPINT() { return 0 }
    while true; do
        clear
        launcher
    done
fi
