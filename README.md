# ghostty-launcher

Spotlight風ランチャー。Ghostty のクイックターミナル + fzf で構築。

![demo](https://github.com/user-attachments/assets/placeholder)

## 機能

| 種別 | 説明 | 例 |
|------|------|-----|
| アプリ起動 | インストール済みアプリを検索して起動 | `brave` → Brave Browser |
| ファイル検索 | Spotlight（mdfind）でファイルを検索 | `report.pdf` |
| 計算 | 数式をその場で評価、結果をクリップボードにコピー | `1920 * 1080` |
| Web検索 | DuckDuckGo で検索 | `rust ownership` |
| CLIコマンド | コマンドをその場で実行して出力を確認 | `git status` |
| システム | Lock / Sleep / Empty Trash / Restart / Shut Down | `sleep` |
| エイリアス | アプリの通称で検索 | `vscode`, `chrome` |

## 必要なもの

- [Ghostty](https://ghostty.org/)
- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [fish](https://fishshell.com/) — `brew install fish`
- [Nerd Font](https://www.nerdfonts.com/)（アイコン表示用）— 推奨: HackGen Console NF

## インストール

```sh
git clone https://github.com/gapul/ghostty-launcher ~/.config/launcher
fish ~/.config/launcher/install.fish
```

`install.fish` は以下を自動で行います：

1. `~/.config/fish/config.fish` に `fish_function_path` を追加
2. `icon_map.sh`（sketchybar-app-font）をダウンロード
3. `launcher_search.sh` に実行権限を付与

### Ghostty 設定

`~/Library/Application Support/com.mitchellh.ghostty/config` に追加：

```
initial-window = false
keybind = global:super+space=toggle_quick_terminal
quick-terminal-position = center
quick-terminal-size = 38%,480px
quick-terminal-autohide = true
quick-terminal-animation-duration = 0.12
```

### fish 設定

`~/.config/fish/config.fish` に追加（`install.fish` が自動で行う）：

```fish
# Ghostty クイックターミナルでランチャーを起動
if status is-interactive && set -q GHOSTTY_QUICK_TERMINAL
    while true
        clear
        launcher
    end
end
```

## 使い方

`cmd+space` でランチャーを開く。

- **入力**: リアルタイムで結果が絞り込まれる
- **Enter**: 選択して実行
- **ESC**: ランチャーを閉じる

### エイリアスのカスタマイズ

`app_aliases.txt` を編集することでアプリの通称を追加できます：

```
# alias:正式なアプリ名
code:Visual Studio Code
brave:Brave Browser
```

### ランチャーの再起動

アプリをインストールした後などキャッシュを更新したい場合：

```sh
launcher-restart
```

または、ランチャー上で `> launcher-restart` と入力して実行。

## ファイル構成

```
~/.config/launcher/
├── launcher.fish          # メインランチャー（fzf UI・アクション処理）
├── launcher-restart.fish  # キャッシュクリア＆再起動
├── launcher_search.sh     # 検索ロジック（アプリ/ファイル/計算/Web）
├── app_aliases.txt        # アプリ通称マッピング（編集可）
├── install.fish           # セットアップスクリプト
└── icon_map.sh            # sketchybar-app-font マッピング（.gitignore）
```

## アイコンについて

アプリアイコンは [Nerd Fonts](https://www.nerdfonts.com/) の Material Design Icons を使用。
マッピングされていないアプリは汎用アイコン（󰀻）で表示されます。

`launcher_search.sh` 内の `get_app_icon()` 関数にアプリ名とアイコンを追加することでカスタマイズできます。

## ライセンス

MIT
