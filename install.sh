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
         "$LAUNCHER_DIR/core/search.sh" \
         "$LAUNCHER_DIR/core/restart.sh"
info "permissions set"

# ── Rust search binary ──────────────────────────────────────────────────
section "Building search binary"

SEARCH_SRC="$LAUNCHER_DIR/launcher-search"
SEARCH_BIN="$LAUNCHER_DIR/core/launcher-search"

if [ -d "$SEARCH_SRC" ] && command -v cargo >/dev/null 2>&1; then
    (cd "$SEARCH_SRC" && cargo build --release 2>&1 | grep -E '^(error|warning:|Compiling|Finished)') && \
        cp "$SEARCH_SRC/target/release/launcher-search" "$SEARCH_BIN" && \
        chmod +x "$SEARCH_BIN" && \
        info "Rust search binary built → core/launcher-search" || \
        warn "Build failed — falling back to search.sh"
elif [ -d "$SEARCH_SRC" ]; then
    warn "cargo not found — skipping Rust build (using search.sh fallback)"
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
