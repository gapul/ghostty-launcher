#!/usr/bin/env bash
# Launcher install script
# Run after cloning: bash ~/.config/launcher/install.sh

set -euo pipefail

LAUNCHER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

section "Launcher install"

chmod +x "$LAUNCHER_DIR/core/launcher.sh" \
         "$LAUNCHER_DIR/core/restart.sh" \
         "$LAUNCHER_DIR/core/cache-clear.sh" \
         "$LAUNCHER_DIR/core/preview.sh"
info "permissions set"

# ── Rust search binary ──────────────────────────────────────────────────
section "Building search binary"

SEARCH_SRC="$LAUNCHER_DIR/launcher-search"
SEARCH_BIN="$LAUNCHER_DIR/core/launcher-search"

if [ -d "$SEARCH_SRC" ] && command -v cargo >/dev/null 2>&1; then
    # cp ではなく symlink で配置する。
    # macOS 14+ では `cp` した未署名バイナリに `com.apple.provenance` 拡張属性が
    # 自動付与され、AMFI によって実行時に SIGKILL される場合がある (xattr -c でも消せない)。
    # symlink なら配置先 (= リンク自身) は inode を新規作成しないので属性が付かず、
    # AMFI が見るのは実体側 (target/release のバイナリ) なので回避できる。
    (cd "$SEARCH_SRC" && cargo build --release 2>&1 | grep -E '^(error|warning:|Compiling|Finished)') && \
        ln -sf "$SEARCH_SRC/target/release/launcher-search" "$SEARCH_BIN" && \
        info "Rust search binary built → core/launcher-search (symlink)" || \
        warn "Build failed — launcher-search binary required"
elif [ -d "$SEARCH_SRC" ]; then
    warn "cargo not found — build core/launcher-search manually with: cargo build --release"
fi

# ── Swift menu-items helper (macOS only) ────────────────────────────────
if [ "$(uname)" = "Darwin" ]; then
    section "Building menu-items (Raycast-style menu bar search)"
    MENU_SRC="$LAUNCHER_DIR/core/menu-items.swift"
    MENU_BIN="$LAUNCHER_DIR/core/menu-items"
    if [ -f "$MENU_SRC" ] && command -v swiftc >/dev/null 2>&1; then
        if swiftc -O "$MENU_SRC" -o "$MENU_BIN" 2>&1; then
            info "menu-items built → core/menu-items"
            warn "Grant Accessibility permission to your host terminal (Ghostty/Wezterm) in System Settings → Privacy & Security → Accessibility — without it the menu list is empty."
        else
            warn "swiftc build failed — menu items search will be unavailable"
        fi
    elif [ -f "$MENU_SRC" ]; then
        warn "swiftc not found — menu items search will be unavailable (install Xcode CLT)"
    fi
fi

# ── Shell setup ─────────────────────────────────────────────────────────
section "Shell setup"

SHELL_NAME="$(basename "${SHELL:-bash}")"
MARKER="# launcher — do not edit this line"

setup_fish() {
    local config="$HOME/.config/fish/config.fish"
    if grep -qF "$MARKER" "$config" 2>/dev/null; then
        info "fish: already configured"; return
    fi
    cat >> "$config" <<EOF

$MARKER
set -p fish_function_path $LAUNCHER_DIR
if status is-interactive
    if set -q GHOSTTY_QUICK_TERMINAL; or set -q LAUNCHER_QUICK_TERMINAL
        while true; clear; launcher; end
    end
end
EOF
    info "fish: updated ~/.config/fish/config.fish"
}

setup_zsh() {
    local config="$HOME/.zshrc"
    if grep -qF "$MARKER" "$config" 2>/dev/null; then
        info "zsh: already configured"; return
    fi
    printf '\n%s\nsource %s/shells/zsh.sh\n' "$MARKER" "$LAUNCHER_DIR" >> "$config"
    info "zsh: updated ~/.zshrc"
}

setup_bash() {
    local config="$HOME/.bashrc"
    if grep -qF "$MARKER" "$config" 2>/dev/null; then
        info "bash: already configured"; return
    fi
    printf '\n%s\nsource %s/shells/bash.sh\n' "$MARKER" "$LAUNCHER_DIR" >> "$config"
    info "bash: updated ~/.bashrc"
}

case "$SHELL_NAME" in
    fish) setup_fish ;;
    zsh)  setup_zsh  ;;
    bash) setup_bash ;;
    *)    warn "unknown shell '$SHELL_NAME' — add shells/${SHELL_NAME}.sh manually" ;;
esac

# ── Terminal setup ──────────────────────────────────────────────────────
section "Terminal setup"
printf '  Copy the snippet for your terminal into its config:\n'
printf '    Ghostty  →  terminals/ghostty.conf\n'
printf '    kitty    →  terminals/kitty.conf\n'
printf '    WezTerm  →  terminals/wezterm.lua\n'

section "Done"
printf '  Open a new terminal or reload your shell config.\n\n'
