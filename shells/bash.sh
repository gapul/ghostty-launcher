# bash シェル統合スニペット
# ~/.bashrc の末尾に追加:
#   source ~/.config/launcher/shells/bash.sh

launcher() {
    bash ~/.config/launcher/core/launcher.sh
}

launcher-restart() {
    bash ~/.config/launcher/core/restart.sh
}

# クイックターミナルモードでランチャーを自動起動
if [[ -n "${GHOSTTY_QUICK_TERMINAL}" ]] || [[ -n "${LAUNCHER_QUICK_TERMINAL}" ]]; then
    while true; do
        clear
        launcher
    done
fi
