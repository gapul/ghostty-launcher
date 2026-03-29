use std::collections::HashSet;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

// ── Config ────────────────────────────────────────────────────────────────

#[derive(Deserialize, Default)]
struct Config {
    #[serde(default)]
    search: SearchConfig,
    #[serde(default)]
    aliases: std::collections::HashMap<String, String>,
}

#[derive(Deserialize)]
struct SearchConfig {
    #[serde(default = "default_min_query")]
    min_query_for_files: usize,
    #[serde(default = "default_max_files")]
    max_file_results: usize,
    #[serde(default = "default_max_recent")]
    max_recent_results: usize,
    #[serde(default = "default_exclude")]
    exclude_patterns: Vec<String>,
}

impl Default for SearchConfig {
    fn default() -> Self {
        Self {
            min_query_for_files: default_min_query(),
            max_file_results: default_max_files(),
            max_recent_results: default_max_recent(),
            exclude_patterns: default_exclude(),
        }
    }
}

fn default_min_query() -> usize { 3 }
fn default_max_files() -> usize { 15 }
fn default_max_recent() -> usize { 10 }
fn default_exclude() -> Vec<String> {
    vec![
        "/Library/".into(),
        "node_modules".into(),
        "/.".into(),
    ]
}

fn load_config(launcher_dir: &Path) -> Config {
    let config_path = launcher_dir.join("config.toml");
    if let Ok(content) = fs::read_to_string(&config_path) {
        toml::from_str(&content).unwrap_or_default()
    } else {
        Config::default()
    }
}

// ── App icon mapping ──────────────────────────────────────────────────────

fn app_icon(name: &str) -> &'static str {
    match name {
        // Browsers
        "Brave Browser" => "󰖟",
        "Google Chrome" | "Google Chrome Canary" | "Chromium" => "󰊯",
        "Firefox" | "Firefox Developer Edition" | "Firefox Nightly" => "󰈹",
        "Safari" | "Safari Technology Preview" => "󰀵",
        "Arc" | "Orion" | "Vivaldi" | "Opera" => "󰖟",
        // Dev tools
        "Visual Studio Code" | "VSCodium" => "󰨞",
        "Xcode" => "󰀵",
        "Android Studio" | "Simulator" => "󰀲",
        "Cursor" | "Zed" | "RustRover" | "GoLand" | "WebStorm"
        | "IntelliJ IDEA" | "PyCharm" | "CLion" => "󰨞",
        "Instruments" => "󰃬",
        "Postman" | "Insomnia" | "RapidAPI" => "󰖟",
        "TablePlus" | "DBngin" | "Sequel Pro" => "󰆼",
        "Docker" | "OrbStack" => "󰡨",
        "GitHub Desktop" | "GitKraken" | "Tower" | "Sourcetree" => "󰊢",
        // System (macOS)
        "Finder" => "󰀶",
        "System Preferences" | "System Settings" => "󰒓",
        "Activity Monitor" => "󰓅",
        "App Store" => "󰀶",
        "Disk Utility" => "󰋊",
        "Migration Assistant" | "Installer" => "󰋑",
        "Keychain Access" => "󰌾",
        "Script Editor" | "Automator" => "󰗈",
        "ColorSync Utility" | "Digital Color Meter" => "󰃣",
        "Accessibility Inspector" => "󰀂",
        "Boot Camp Assistant" => "󰖳",
        // Communication
        "Slack" => "󰒱",
        "Discord" | "Canary" => "󰙯",
        "Messages" => "󰍦",
        "Mail" => "󰇮",
        "FaceTime" => "󰒯",
        "Zoom" | "zoom.us" => "󰐸",
        "Microsoft Teams" => "󰊻",
        "Telegram" | "Telegram Desktop" => "󰔁",
        "WhatsApp" => "󰖣",
        "Signal" | "Beeper" | "Beeper Desktop" => "󰍦",
        // Media
        "Music" | "GarageBand" | "Logic Pro" | "Logic Pro X" => "󰝚",
        "Spotify" => "󰓇",
        "Photos" => "󰈟",
        "QuickTime Player" | "IINA" | "Infuse 7" | "Infuse"
        | "Final Cut Pro" | "Motion" | "Compressor" => "󰸖",
        "VLC" => "󰕧",
        "Audacity" | "Ableton Live" | "Live" => "󰎆",
        // Productivity
        "Calendar" => "󰃭",
        "Notes" | "Notion" | "Obsidian" | "Craft" | "Bear"
        | "Ulysses" | "Tot" => "󰠮",
        "Reminders" => "󰄲",
        "Contacts" => "󰮤",
        "Maps" => "󰺿",
        "News" => "󰑈",
        "Podcasts" => "󱆺",
        "Books" => "󰂿",
        "Preview" => "󰈦",
        "TextEdit" | "Numbers" | "Pages" | "Microsoft Word" => "󰈙",
        "Keynote" => "󰐩",
        "Microsoft Excel" => "󰈛",
        "Microsoft PowerPoint" => "󰈧",
        "Microsoft Outlook" => "󰇮",
        // Security
        "1Password 7" | "1Password" | "Bitwarden" => "󰌾",
        // Design
        "Figma" | "Sketch" | "Affinity Designer"
        | "Affinity Designer 2" | "OmniGraffle" => "󰙧",
        "Pixelmator Pro" | "Pixelmator" | "Affinity Photo"
        | "Affinity Photo 2" | "GIMP" | "Inkscape" => "󰋩",
        "Blender" => "󰂮",
        // Utilities
        "CleanMyMac" | "CleanMyMac X" => "󰃢",
        "Amphetamine" => "󰂓",
        "Bartender" | "Ice" => "󰀺",
        "Rectangle" | "Magnet" | "Moom" | "BetterSnapTool" | "AeroSpace" => "󰁴",
        "Karabiner-Elements" | "Karabiner-EventViewer" => "⌨",
        "BetterTouchTool" => "󱕴",
        "PopClip" => "󰏌",
        "Dropbox" | "OneDrive" | "Google Drive" => "󰅧",
        "Transmit 5" | "Transmit" | "Cyberduck" | "FileZilla" => "󰀸",
        "Proxyman" | "Charles" | "Wireshark" => "󰖟",
        "Raycast" | "Alfred" => "󰀻",
        _ => "󰀻",
    }
}

fn file_icon(path: &Path) -> &'static str {
    if path.is_dir() {
        return "󰉋";
    }
    match path.extension().and_then(|e| e.to_str()).unwrap_or("") {
        "pdf" => "󰈦",
        "jpg" | "jpeg" | "png" | "gif" | "svg" | "webp" | "heic" => "󰋩",
        "md" | "markdown" => "󰍔",
        "py" | "js" | "ts" | "go" | "rs" | "sh" | "fish" | "rb"
        | "java" | "c" | "cpp" | "h" | "swift" | "kt" | "lua" => "󰈮",
        "zip" | "tar" | "gz" | "7z" | "rar" => "󰗄",
        "txt" | "rtf" => "󰈙",
        "mp4" | "mov" | "avi" | "mkv" | "webm" => "󰈫",
        "mp3" | "flac" | "wav" | "aac" | "m4a" => "󰈣",
        _ => "󰈔",
    }
}

// ── Cache helpers ─────────────────────────────────────────────────────────

const APPS_CACHE: &str = "/tmp/launcher_apps_cache.txt";
const RECENT_CACHE: &str = "/tmp/launcher_recent_cache.txt";

fn cache_valid(path: &str, ttl_secs: u64) -> bool {
    if let Ok(meta) = fs::metadata(path) {
        if let Ok(modified) = meta.modified() {
            if let Ok(elapsed) = modified.elapsed() {
                return elapsed.as_secs() < ttl_secs;
            }
        }
    }
    false
}

// ── App scanning ──────────────────────────────────────────────────────────

fn scan_apps_macos() -> Vec<String> {
    let dirs = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
    ];
    let home = env::var("HOME").unwrap_or_default();
    let home_apps = format!("{}/Applications", home);

    let mut results = Vec::new();

    let all_dirs: Vec<&str> = dirs.iter().map(|s| *s)
        .chain(std::iter::once(home_apps.as_str()))
        .collect();

    for dir in all_dirs {
        if let Ok(entries) = fs::read_dir(dir) {
            for entry in entries.flatten() {
                let name = entry.file_name();
                let s = name.to_string_lossy();
                if s.ends_with(".app") {
                    let app_name = &s[..s.len() - 4];
                    results.push(format!("APP|{} {}", app_icon(app_name), app_name));
                }
            }
        }
    }

    // Finder lives outside /Applications
    if Path::new("/System/Library/CoreServices/Finder.app").exists() {
        results.push(format!("APP|{} Finder", app_icon("Finder")));
    }

    results.sort();
    results.dedup();
    results
}

fn scan_apps_linux() -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let dirs = [
        "/usr/share/applications".to_string(),
        format!("{}/.local/share/applications", home),
    ];

    let mut results = Vec::new();
    for dir in &dirs {
        let p = Path::new(dir);
        if !p.is_dir() {
            continue;
        }
        if let Ok(entries) = fs::read_dir(p) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                    continue;
                }
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Some(name) = content.lines()
                        .find(|l| l.starts_with("Name="))
                        .map(|l| l.trim_start_matches("Name=").trim())
                    {
                        results.push(format!("APP|{} {}", app_icon(name), name));
                    }
                }
            }
        }
    }

    results.sort();
    results.dedup();
    results
}

fn build_apps_cache() -> Vec<String> {
    let is_macos = cfg!(target_os = "macos");
    let apps = if is_macos { scan_apps_macos() } else { scan_apps_linux() };

    if let Ok(mut f) = fs::File::create(APPS_CACHE) {
        for line in &apps {
            let _ = writeln!(f, "{}", line);
        }
    }
    apps
}

fn list_apps() -> Vec<String> {
    if cache_valid(APPS_CACHE, 300) {
        if let Ok(content) = fs::read_to_string(APPS_CACHE) {
            return content.lines().map(String::from).collect();
        }
    }
    build_apps_cache()
}

// ── Recent files ──────────────────────────────────────────────────────────

fn list_recent(config: &Config) -> Vec<String> {
    if cache_valid(RECENT_CACHE, 60) {
        if let Ok(content) = fs::read_to_string(RECENT_CACHE) {
            return content.lines().map(String::from).collect();
        }
    }

    let home = env::var("HOME").unwrap_or_default();
    let mut lines = Vec::new();

    if cfg!(target_os = "macos") {
        if let Ok(output) = Command::new("mdfind")
            .args([
                "-onlyin", &home,
                "kMDItemLastUsedDate >= $time.today(-7)",
            ])
            .output()
        {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let exclude = &config.search.exclude_patterns;
            let max = config.search.max_recent_results;

            for path_str in stdout.lines() {
                if lines.len() >= max {
                    break;
                }
                if path_str.ends_with(".app") {
                    continue;
                }
                if exclude.iter().any(|p| path_str.contains(p.as_str())) {
                    continue;
                }
                let path = Path::new(path_str);
                lines.push(format!("FILE|{} {}", file_icon(path), path_str));
            }
        }
    }

    if let Ok(mut f) = fs::File::create(RECENT_CACHE) {
        for line in &lines {
            let _ = writeln!(f, "{}", line);
        }
    }
    lines
}

// ── System commands ───────────────────────────────────────────────────────

fn list_sys() -> Vec<&'static str> {
    vec![
        "SYS_LOCK|\u{f033e} Lock Screen",
        "SYS_SLEEP|\u{f04b2} Sleep",
        "SYS_TRASH|\u{f0a7a} Empty Trash",
        "SYS_RESTART|\u{f0450} Restart",
        "SYS_SHUTDOWN|\u{f0425} Shut Down",
    ]
}

fn search_sys(query_lower: &str) -> Vec<&'static str> {
    let mut results = Vec::new();
    if query_lower.contains("lock") || query_lower.contains("ロック") {
        results.push("SYS_LOCK|\u{f033e} Lock Screen");
    }
    if query_lower.contains("sleep") || query_lower.contains("スリープ") || query_lower.contains("眠") {
        results.push("SYS_SLEEP|\u{f04b2} Sleep");
    }
    if query_lower.contains("trash") || query_lower.contains("ゴミ") || query_lower.contains("empty") {
        results.push("SYS_TRASH|\u{f0a7a} Empty Trash");
    }
    if query_lower.contains("restart") || query_lower.contains("再起動") || query_lower.contains("reboot") {
        results.push("SYS_RESTART|\u{f0450} Restart");
    }
    if query_lower.contains("shutdown") || query_lower.contains("シャットダウン") || query_lower.contains("電源") {
        results.push("SYS_SHUTDOWN|\u{f0425} Shut Down");
    }
    results
}

// ── Calculator ────────────────────────────────────────────────────────────

/// Rewrite bare math function names to their `math::` prefixed forms.
/// e.g. `sqrt(144)` → `math::sqrt(144)`, `sin(0)` → `math::sin(0)`
fn normalize_math(query: &str) -> String {
    const MATH_FNS: &[&str] = &[
        "sqrt", "cbrt", "abs", "floor", "ceil", "round",
        "sin", "cos", "tan", "asin", "acos", "atan",
        "ln", "log2", "log10", "exp",
    ];
    let mut result = query.to_string();
    for name in MATH_FNS {
        // Replace `name(` with `math::name(` only when not already prefixed
        let bare = format!("{}(", name);
        let prefixed = format!("math::{}(", name);
        if result.contains(&bare) && !result.contains(&prefixed) {
            result = result.replace(&bare, &prefixed);
        }
    }
    result
}

fn search_calc(query: &str) -> Option<String> {
    // Only try if the query contains a digit
    if !query.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }

    let normalized = normalize_math(query);
    match evalexpr::eval(&normalized) {
        Ok(result) => {
            let result_str = match result {
                evalexpr::Value::Float(f) => {
                    // Round to avoid floating point noise
                    let rounded = (f * 1e10).round() / 1e10;
                    if rounded == rounded.floor() && rounded.abs() < 1e15 {
                        format!("{}", rounded as i64)
                    } else {
                        format!("{}", rounded)
                    }
                }
                evalexpr::Value::Int(i) => format!("{}", i),
                evalexpr::Value::Boolean(b) => format!("{}", b),
                _ => return None,
            };
            Some(format!("CALC|\u{f00ec} = {}", result_str))
        }
        Err(_) => None,
    }
}

// ── Alias search ──────────────────────────────────────────────────────────

fn search_aliases<'a>(query_lower: &str, config: &'a Config) -> Vec<String> {
    let mut results = Vec::new();
    for (alias, app_name) in &config.aliases {
        if alias.to_lowercase().contains(query_lower) {
            results.push(format!("APP|{} {}", app_icon(app_name), app_name));
        }
    }
    results
}

// ── File search ───────────────────────────────────────────────────────────

fn search_files(query: &str, config: &Config) -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let exclude = &config.search.exclude_patterns;
    let max = config.search.max_file_results;
    let mut results = Vec::new();

    let raw_paths = if cfg!(target_os = "macos") {
        Command::new("mdfind")
            .args(["-onlyin", &home, "-name", query])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    } else {
        // Linux: try locate
        Command::new("locate")
            .args(["-i", query])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    };

    for path_str in raw_paths.lines() {
        if results.len() >= max {
            break;
        }
        // Must be under HOME for locate results
        if !cfg!(target_os = "macos") && !path_str.starts_with(&home) {
            continue;
        }
        if path_str.ends_with(".app") || path_str.contains(".app/Contents") {
            continue;
        }
        if exclude.iter().any(|p| path_str.contains(p.as_str())) {
            continue;
        }
        let path = Path::new(path_str);
        results.push(format!("FILE|{} {}", file_icon(path), path_str));
    }

    results
}

// ── Main ──────────────────────────────────────────────────────────────────

fn launcher_dir() -> PathBuf {
    // Binary lives at <launcher_dir>/core/launcher-search
    // or at <launcher_dir>/launcher-search/target/release/launcher-search
    // We try env var first, then walk up from the binary's location
    if let Ok(d) = env::var("LAUNCHER_DIR") {
        return PathBuf::from(d);
    }

    // Fallback: assume the binary is at <launcher_dir>/core/launcher-search
    if let Ok(exe) = env::current_exe() {
        if let Some(parent) = exe.parent() {
            // parent = .../core/
            if let Some(grandparent) = parent.parent() {
                return grandparent.to_path_buf();
            }
        }
    }

    PathBuf::from(
        env::var("HOME")
            .map(|h| format!("{}/.config/launcher", h))
            .unwrap_or_else(|_| ".".into()),
    )
}

fn main() {
    let query = env::args().nth(1).unwrap_or_default();
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());

    let dir = launcher_dir();
    let config = load_config(&dir);

    // Empty query: show all apps + recent + sys
    if query.is_empty() {
        for line in list_apps() {
            let _ = writeln!(out, "{}", line);
        }
        for line in list_recent(&config) {
            let _ = writeln!(out, "{}", line);
        }
        for line in list_sys() {
            let _ = writeln!(out, "{}", line);
        }
        return;
    }

    let query_lower = query.to_lowercase();
    let mut seen: HashSet<String> = HashSet::new();

    macro_rules! emit {
        ($line:expr) => {{
            let s: String = $line;
            if seen.insert(s.clone()) {
                let _ = writeln!(out, "{}", s);
            }
        }};
    }

    // Phase 1: fast results (cache / in-memory)
    // Calculator
    if query.chars().any(|c| c.is_ascii_digit()) {
        if let Some(calc) = search_calc(&query) {
            emit!(calc);
        }
    }

    // Aliases
    for line in search_aliases(&query_lower, &config) {
        emit!(line);
    }

    // Apps (from cache or scan)
    let apps = list_apps();
    for line in &apps {
        // field 2 onwards = "ICON appname"
        if let Some(display) = line.splitn(2, '|').nth(1) {
            if display.to_lowercase().contains(&query_lower) {
                emit!(line.clone());
            }
        }
    }

    // System commands
    for line in search_sys(&query_lower) {
        emit!(line.to_string());
    }

    // Flush phase 1 immediately
    let _ = out.flush();

    // Phase 2: file search (slower, streamed after)
    if query.chars().count() >= config.search.min_query_for_files {
        for line in search_files(&query, &config) {
            emit!(line);
        }
        let _ = out.flush();
    }

    // Always last: CMD + WEB
    emit!(format!("CMD|\u{f0188} > {}", query));
    emit!(format!("WEB|\u{f059f} DuckDuckGo: {}", query));
    let _ = out.flush();
}
