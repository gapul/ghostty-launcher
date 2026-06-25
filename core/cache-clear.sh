#!/usr/bin/env bash
# ランチャーのキャッシュを削除（次回起動時に再構築される）
# Rust 側 (main.rs::tmp_dir) は $TMPDIR を見るので同じパスを使うこと。
# macOS では $TMPDIR=/var/folders/.../T/、未設定なら /tmp。
TMPD="${TMPDIR:-/tmp}"
rm -f "${TMPD%/}/launcher_apps_cache.txt" "${TMPD%/}/launcher_recent_cache.txt"
printf 'launcher: cache cleared (%s)\n' "${TMPD%/}"
