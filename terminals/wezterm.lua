-- WezTerm 設定スニペット
-- ~/.config/wezterm/wezterm.lua に追加

-- グローバルホットキーでランチャーを起動（overlay pane）
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.keys = {
    {
        key = 'Space',
        mods = 'SUPER',
        action = wezterm.action.SpawnCommandInNewTab {
            args = { 'bash', '-c',
                'LAUNCHER_QUICK_TERMINAL=1 bash ~/.config/launcher/core/launcher.sh' },
        },
    },
}

return config
