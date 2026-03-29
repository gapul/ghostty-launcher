function launcher-restart --description "ランチャーのキャッシュをクリアして再起動"
    rm -f /tmp/launcher_apps_cache.txt /tmp/launcher_recent_cache.txt
    pkill -x fzf 2>/dev/null
end
