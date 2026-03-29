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

- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [Nerd Font](https://www.nerdfonts.com/)（アイコン表示用）— 推奨: HackGen Console NF
- Rust / Cargo（検索バイナリのビルド用）— `brew install rustup`

対応シェル: fish / zsh / bash
対応ターミナル: Ghostty / kitty / WezTerm（その他も `LAUNCHER_CLOSE_CMD` で設定可）

## インストール

```sh
git clone https://github.com/gapul/ghostty-launcher ~/.config/launcher
bash ~/.config/launcher/install.sh
```

`install.sh` は以下を自動で行います：

1. シェル設定ファイル（`config.fish` / `.zshrc` / `.bashrc`）にランチャー起動設定を追加
2. Rust 検索バイナリをビルドして `core/launcher-search` に配置

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

詳細は `terminals/ghostty.conf` を参照。

## 使い方

`cmd+space` でランチャーを開く（Ghostty の場合）。

- **入力**: リアルタイムで結果が絞り込まれる
- **Enter**: 選択して実行
- **ESC**: ランチャーを閉じる

### 計算機

数字を含む式を入力すると自動的に計算します。結果を選択するとクリップボードにコピーされます。

```
2 + 2          → 4
1920 * 1080    → 2073600
sqrt(144)      → 12
2^10           → 1024
math::sin(0)   → 0
```

> **Note:** `sqrt`, `sin`, `cos` など数学関数はそのまま使えます（内部で `math::` プレフィックスを自動付加）。

### カスタマイズ

`config.toml` を編集してエイリアスや検索設定を変更できます：

```toml
[search]
min_query_for_files = 3   # ファイル検索を開始する最小文字数
max_file_results = 15     # ファイル検索の最大件数

[aliases]
vscode = "Visual Studio Code"
code = "Visual Studio Code"
chrome = "Google Chrome"
# myapp = "My Application Name"
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
├── config.toml                # 設定ファイル（エイリアス・検索設定）
├── launcher.fish              # fish 用ラッパー関数
├── launcher-restart.fish      # fish 用キャッシュクリア関数
├── install.sh                 # セットアップスクリプト
├── core/
│   ├── launcher.sh            # メインランチャー（fzf UI・アクション処理）
│   ├── launcher-search        # 検索バイナリ（ビルド後に生成）
│   ├── search.sh              # 検索シェルスクリプト（フォールバック用）
│   └── restart.sh             # キャッシュクリアスクリプト
├── launcher-search/           # Rust クレート（検索バイナリのソース）
│   ├── Cargo.toml
│   └── src/main.rs
├── shells/                    # シェル別設定スニペット
│   ├── fish.fish
│   ├── zsh.sh
│   └── bash.sh
└── terminals/                 # ターミナル別設定スニペット
    ├── ghostty.conf
    ├── kitty.conf
    └── wezterm.lua
```

## アイコンについて

アプリアイコンは [Nerd Fonts](https://www.nerdfonts.com/) の Material Design Icons を使用。
マッピングされていないアプリは汎用アイコン（󰀻）で表示されます。

アイコンマッピングを追加するには `launcher-search/src/main.rs` の `app_icon()` 関数を編集してビルドしてください。

## ライセンス

MIT
