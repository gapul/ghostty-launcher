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
| **Wi-Fi** | 電源トグル + 既知ネットワーク一覧から接続切替 | `wifi` |
| **Bluetooth** | 電源トグル + ペアリング済デバイスのトグル | `bt` |
| **メニュー検索** | 直前まで前面だったアプリのメニューバー項目を検索→実行 (Raycast 風) | `menu` / `メニュー` |
| エイリアス | アプリの通称で検索 | `vscode`, `chrome` |

## 必要なもの

- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [Nerd Font](https://www.nerdfonts.com/)（アイコン表示用）— 推奨: HackGen Console NF
- Rust / Cargo（検索バイナリのビルド用）— `brew install rustup`
- [blueutil](https://github.com/toy/blueutil)（Bluetooth 操作用、任意）— `brew install blueutil`

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

### Wi-Fi / Bluetooth

`wifi` または `bluetooth` (`bt`) と入力するとトグル項目とドリルダウン項目が出ます。

```
wifi                          → Turn Wi-Fi Off / Wi-Fi networks…
└ Wi-Fi networks…             → サブ fzf で既知 SSID 一覧から接続切替
                                失敗時は Wi-Fi メニュー popup を自動オープン

bt                            → Turn Bluetooth Off / Bluetooth devices…
└ Bluetooth devices…          → サブ fzf でペアリング済デバイスをトグル
                                接続中デバイスには ✓ が付く
```

空クエリでもステータス行（`󰖩 Wi-Fi: connected` / `󰂱 Bluetooth: <デバイス名>`）が表示されます。

操作結果のログは `/tmp/launcher_wifi.log` / `/tmp/launcher_bt.log` に記録されます（トラブル時の調査用）。

### メニュー検索 (Search Menu Items)

`menu` / `メニュー` / `menubar` 等のキーワードで「Search menu items of <直前のアプリ>…」が候補に出ます。選ぶと、そのアプリのメニューバー項目を全列挙したサブ fzf が開き、ファジー検索 → Enter で実行できます。Raycast の "Search Menu Items" 相当です。

```
menu                              → Search menu items of Safari…
└ Search menu items of Safari…    → サブ fzf でメニュー項目を列挙
                                    例: `File ▸ New Private Window`
                                        `Edit ▸ Find ▸ Find on Page…`
                                    Enter で AXPress 発火
```

ホットキーから直接開きたいときは：

```sh
echo MENU_ITEMS_LIST > /tmp/launcher_action_pending && open -a Ghostty
# あるいは AeroSpace / Karabiner などに以下を bind
bash ~/.config/launcher/core/launcher.sh --action MENU_ITEMS_LIST
```

技術的詳細:

- `core/menu-items` (Swift / Accessibility API 直叩き) が `lsappinfo visibleProcessList` で直前まで前面だったアプリの PID を解決し、`AXUIElement` で再帰的にメニューを列挙
- 100〜300ms 程度で全項目を取得（AppleScript 方式の数十倍速い）
- 選択後は `_close` → 対象アプリが前面に戻る → AXPress で項目を click
- **要 Accessibility 権限**: ホストターミナル (Ghostty / Wezterm) に対して「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で許可。未許可だと初回実行時にプロンプトが出ます

> **macOS Sequoia の制約:**
>
> - **SSID 名取得**: OS のプライバシー機能でマスクされ、`com.apple.developer.networking.wifi-info` エンタイトルメント（Apple Developer Program 必須）を持たない限り読めません。そのため Wi-Fi 一覧での「現在接続中」マーキング (✓) は表示されません。
> - **`networksetup -setairportnetwork` が不安定**: Keychain アクセス制限により、認証付きネットワークへの切替が `-3900 tmpErr` で失敗するケースがあります。launcher は失敗を検出したら自動で **Wi-Fi メニューバー popup を開く** ので、もう 1 クリックで接続できます（Apple 純正 UI は全権限を持つため確実）。
> - **iPhone Personal Hotspot**: networksetup の対象外。launcher 経由だと必ず popup fallback になります。同じ Apple ID でサインインしていれば Instant Hotspot として popup 内の「Personal Hotspot」セクションにリストされるので 1 クリックで接続。
> - **Bluetooth 側は影響を受けません**: 接続中デバイスへの ✓ も、`blueutil` 経由のトグルも正常動作します。

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

アプリをインストールした後など、キャッシュをクリアしたい時や fzf がフリーズした時に：

```sh
launcher-restart
```

または、ランチャー上で `> launcher-restart` と入力して実行。

`launcher-restart` は以下を行います:

- 残留している `fzf` / `launcher.sh` / `launcher-search` プロセスを TERM → 0.3s → KILL の二段階で終了
- アプリ／recent ファイルキャッシュのクリア
- `/tmp/launcher_out.*` の残骸削除
- Wi-Fi / Bluetooth アクションログ (`/tmp/launcher_wifi.log` / `/tmp/launcher_bt.log`) の削除

fish の `while true` ループが新しい `launcher` を即座に再起動するので、Quick Terminal を開き直すだけで復旧します。

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
│   ├── menu-items.swift       # メニュー検索 (Raycast 風) のソース
│   ├── menu-items             # メニュー検索バイナリ（ビルド後に生成）
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
