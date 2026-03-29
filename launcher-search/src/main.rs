use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::Deserialize;

// ── Config ────────────────────────────────────────────────────────────────

#[derive(Deserialize, Default)]
struct Config {
    #[serde(default)]
    search: SearchConfig,
    #[serde(default)]
    appearance: AppearanceConfig,
    #[serde(default)]
    aliases: HashMap<String, String>,
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
    vec!["/Library/".into(), "node_modules".into(), "/.".into()]
}

// Catppuccin Macchiato defaults
#[derive(Deserialize)]
struct AppearanceConfig {
    #[serde(default = "d_bg")]      bg: String,
    #[serde(default = "d_bg_sel")]  bg_selected: String,
    #[serde(default = "d_border")]  border: String,
    #[serde(default = "d_fg")]      fg: String,
    #[serde(default = "d_gutter")]  gutter: String,
    #[serde(default = "d_hl")]      hl: String,
    #[serde(default = "d_prompt")]  prompt: String,
    #[serde(default = "d_pointer")] pointer: String,
    #[serde(default = "d_label")]   label: String,
}

impl Default for AppearanceConfig {
    fn default() -> Self {
        Self {
            bg: d_bg(), bg_selected: d_bg_sel(), border: d_border(),
            fg: d_fg(), gutter: d_gutter(), hl: d_hl(),
            prompt: d_prompt(), pointer: d_pointer(), label: d_label(),
        }
    }
}

fn d_bg()      -> String { "#1e1e2e".into() }
fn d_bg_sel()  -> String { "#313244".into() }
fn d_border()  -> String { "#6e6a86".into() }
fn d_fg()      -> String { "#cad3f5".into() }
fn d_gutter()  -> String { "#1e1e2e".into() }
fn d_hl()      -> String { "#8aadf4".into() }
fn d_prompt()  -> String { "#c6a0f6".into() }
fn d_pointer() -> String { "#ed8796".into() }
fn d_label()   -> String { "#c6a0f6".into() }

fn load_config(launcher_dir: &Path) -> Config {
    let config_path = launcher_dir.join("config.toml");
    if let Ok(content) = fs::read_to_string(&config_path) {
        toml::from_str(&content).unwrap_or_default()
    } else {
        Config::default()
    }
}

// ── Frecency ──────────────────────────────────────────────────────────────
// Storage: {launcher_dir}/frecency.txt
// Format per line: COUNT\tLAST_TS\tTYPE\tNAME

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn frecency_path(launcher_dir: &Path) -> PathBuf {
    launcher_dir.join("frecency.txt")
}

/// Load frecency db. Key = "TYPE\tNAME", value = (count, last_ts).
fn load_frecency(path: &Path) -> HashMap<String, (u32, u64)> {
    let mut db = HashMap::new();
    let Ok(content) = fs::read_to_string(path) else {
        return db;
    };
    for line in content.lines() {
        let parts: Vec<&str> = line.splitn(4, '\t').collect();
        if parts.len() != 4 { continue; }
        let Ok(count) = parts[0].parse::<u32>() else { continue };
        let Ok(ts)    = parts[1].parse::<u64>() else { continue };
        let key = format!("{}\t{}", parts[2], parts[3]);
        db.insert(key, (count, ts));
    }
    db
}

const FRECENCY_MAX_AGE_DAYS: u64 = 90;

fn save_frecency(path: &Path, db: &HashMap<String, (u32, u64)>) {
    let cutoff = now_secs().saturating_sub(FRECENCY_MAX_AGE_DAYS * 86400);
    let Ok(mut f) = fs::File::create(path) else { return };
    for (key, &(count, ts)) in db {
        if ts >= cutoff {
            let _ = writeln!(f, "{}\t{}\t{}", count, ts, key);
        }
    }
}

/// Higher = more recent and frequently used.
fn frecency_score(count: u32, last_ts: u64, now: u64) -> f64 {
    let age_secs = now.saturating_sub(last_ts);
    let age_days = (age_secs as f64) / 86400.0;
    let recency = 1.0 / (1.0 + age_days);
    count as f64 * recency
}

/// Record a launch. Called as a subcommand: `launcher-search record TYPE NAME`
fn cmd_record(launcher_dir: &Path, type_str: &str, name: &str) {
    let path = frecency_path(launcher_dir);
    let mut db = load_frecency(&path);
    let key = format!("{}\t{}", type_str, name);
    let entry = db.entry(key).or_insert((0, 0));
    entry.0 += 1;
    entry.1 = now_secs();
    save_frecency(&path, &db);
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
    if path.is_dir() { return "󰉋"; }
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
    let home = env::var("HOME").unwrap_or_default();
    let home_apps = format!("{}/Applications", home);
    let dirs = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        home_apps.as_str(),
    ];

    let mut results = Vec::new();
    for dir in dirs {
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
        let p = Path::new(dir.as_str());
        if !p.is_dir() { continue; }
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
    let apps = if cfg!(target_os = "macos") {
        scan_apps_macos()
    } else {
        scan_apps_linux()
    };
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

/// Returns apps sorted by frecency score (descending), remaining items after.
fn list_apps_sorted(frecency: &HashMap<String, (u32, u64)>, now: u64) -> Vec<String> {
    let apps = list_apps();
    let mut scored: Vec<(f64, String)> = apps
        .into_iter()
        .map(|line| {
            let name = line
                .split_once('|')
                .and_then(|(_, rest)| rest.split_once(' '))
                .map(|(_, n)| n)
                .unwrap_or("");
            let key = format!("APP\t{}", name);
            let score = frecency
                .get(&key)
                .map(|&(c, ts)| frecency_score(c, ts, now))
                .unwrap_or(0.0);
            (score, line)
        })
        .collect();
    // Stable sort: ties preserve original alphabetical order
    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    scored.into_iter().map(|(_, l)| l).collect()
}

// ── Recent files ──────────────────────────────────────────────────────────

fn list_recent(config: &Config) -> Vec<String> {
    if cache_valid(RECENT_CACHE, 60) {
        if let Ok(content) = fs::read_to_string(RECENT_CACHE) {
            return content.lines().map(String::from).collect();
        }
    }

    let home = env::var("HOME").unwrap_or_default();
    let exclude = &config.search.exclude_patterns;
    let max = config.search.max_recent_results;
    let mut lines = Vec::new();

    let raw = if cfg!(target_os = "macos") && spotlight_enabled() {
        Command::new("mdfind")
            .args(["-onlyin", &home, "kMDItemLastUsedDate >= $time.today(-7)"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    } else {
        // find files modified within 7 days, skip hidden dirs and noise
        Command::new("find")
            .args([
                &home,
                "-maxdepth", "5",
                "(", "-name", ".git",
                     "-o", "-name", "node_modules",
                     "-o", "-name", "target",
                     "-o", "-name", ".cursor",
                     "-o", "-name", "Library",
                ")", "-prune", "-o",
                "-not", "-name", ".*",
                "-not", "-type", "d",
                "-mtime", "-7",
                "-print",
            ])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    };

    for path_str in raw.lines() {
        if lines.len() >= max { break; }
        if path_str.ends_with(".app") { continue; }
        if exclude.iter().any(|p| path_str.contains(p.as_str())) { continue; }
        lines.push(format!("FILE|{} {}", file_icon(Path::new(path_str)), path_str));
    }

    if let Ok(mut f) = fs::File::create(RECENT_CACHE) {
        for line in &lines {
            let _ = writeln!(f, "{}", line);
        }
    }
    lines
}

// ── SSH hosts ─────────────────────────────────────────────────────────────

const SSH_ICON: &str = "\u{f0200}";  // 󰈀  nf-md-server_network

/// Parse ~/.ssh/config and return matching Host entries.
/// Pass `query_lower = ""` to return all hosts.
fn ssh_hosts(query_lower: &str) -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let ssh_config = PathBuf::from(&home).join(".ssh/config");
    let Ok(content) = fs::read_to_string(&ssh_config) else {
        return Vec::new();
    };

    content
        .lines()
        .filter_map(|line| {
            let line = line.trim();
            // Match "Host <name>" (case-insensitive keyword)
            let rest = if line.len() > 5 && line[..5].eq_ignore_ascii_case("host ") {
                line[5..].trim()
            } else {
                return None;
            };
            // Skip wildcards and empty patterns
            if rest.is_empty() || rest.contains('*') || rest.contains('?') {
                return None;
            }
            if query_lower.is_empty() || rest.to_lowercase().contains(query_lower) {
                Some(format!("SSH|{} {}", SSH_ICON, rest))
            } else {
                None
            }
        })
        .collect()
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

/// Convert bare math function names to `math::` prefixed forms.
fn normalize_math(query: &str) -> String {
    const MATH_FNS: &[&str] = &[
        "sqrt", "cbrt", "abs", "floor", "ceil", "round",
        "sin", "cos", "tan", "asin", "acos", "atan",
        "ln", "log2", "log10", "exp",
    ];
    let mut result = query.to_string();
    for name in MATH_FNS {
        let bare = format!("{}(", name);
        let prefixed = format!("math::{}(", name);
        if result.contains(&bare) && !result.contains(&prefixed) {
            result = result.replace(&bare, &prefixed);
        }
    }
    result
}

/// When the expression contains `/`, convert integer literals to floats
/// so that `100/7` evaluates to `14.285...` rather than `14`.
fn normalize_division(expr: &str) -> String {
    if !expr.contains('/') {
        return expr.to_string();
    }
    let bytes = expr.as_bytes();
    let mut result = String::with_capacity(expr.len() + 16);
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i].is_ascii_digit() {
            let start = i;
            while i < bytes.len() && bytes[i].is_ascii_digit() {
                i += 1;
            }
            result.push_str(&expr[start..i]);
            // Append `.0` only if not already a float literal
            if i >= bytes.len() || bytes[i] != b'.' {
                result.push_str(".0");
            }
        } else {
            result.push(bytes[i] as char);
            i += 1;
        }
    }
    result
}

// ── Color detection ───────────────────────────────────────────────────────

/// Detect CSS color codes: #rgb, #rrggbb, #rrggbbaa, rgb(), rgba(), hsl(), hsla()
fn search_color(query: &str) -> Option<String> {
    let q = query.trim();

    // Hex color: #rgb, #rrggbb, #rrggbbaa
    if let Some(hex) = q.strip_prefix('#') {
        if matches!(hex.len(), 3 | 6 | 8) && hex.chars().all(|c| c.is_ascii_hexdigit()) {
            return Some(format!("COLOR|\u{f0765} {}", q));
        }
    }

    // rgb() / rgba() / hsl() / hsla()
    let ql = q.to_lowercase();
    let color_fns = ["rgb(", "rgba(", "hsl(", "hsla("];
    if ql.ends_with(')') && color_fns.iter().any(|f| ql.starts_with(f)) {
        return Some(format!("COLOR|\u{f0765} {}", q));
    }

    None
}

fn search_calc(query: &str) -> Option<String> {
    if !query.chars().any(|c| c.is_ascii_digit()) {
        return None;
    }
    let normalized = normalize_division(&normalize_math(query));
    match evalexpr::eval(&normalized) {
        Ok(result) => {
            let s = match result {
                evalexpr::Value::Float(f) => {
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
            Some(format!("CALC|\u{f00ec} = {}", s))
        }
        Err(_) => None,
    }
}

// ── Alias search ──────────────────────────────────────────────────────────

fn search_aliases(query_lower: &str, config: &Config) -> Vec<String> {
    config
        .aliases
        .iter()
        .filter(|(alias, _)| alias.to_lowercase().contains(query_lower))
        .map(|(_, app_name)| format!("APP|{} {}", app_icon(app_name), app_name))
        .collect()
}

// ── Spotlight / file-search backend ──────────────────────────────────────

static SPOTLIGHT_OK: OnceLock<bool> = OnceLock::new();

/// Returns true if Spotlight indexing is enabled on the root volume.
fn spotlight_enabled() -> bool {
    *SPOTLIGHT_OK.get_or_init(|| {
        Command::new("mdutil")
            .args(["-s", "/"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).contains("enabled"))
            .unwrap_or(false)
    })
}

fn cmd_exists(name: &str) -> bool {
    Command::new("which").arg(name).output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// find-based fallback: prune noisy dirs, case-insensitive name glob.
fn find_by_name(home: &str, query: &str, max_results: usize) -> String {
    // Prune dirs that produce noise. The -prune branches never print.
    let prune_names = [
        ".git", "node_modules", "target", ".cursor", ".venv",
        "venv", "__pycache__", ".npm",
    ];
    let mut args: Vec<String> = vec![
        home.to_string(),
        "-maxdepth".into(), "6".into(),
        "(".into(),
    ];
    for (i, name) in prune_names.iter().enumerate() {
        if i > 0 { args.push("-o".into()); }
        args.push("-name".into());
        args.push(name.to_string());
    }
    args.extend([
        ")".into(), "-prune".into(), "-o".into(),
        "-iname".into(), format!("*{}*", query),
        "-print".into(),
    ]);

    let out = Command::new("find")
        .args(&args)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();

    // Limit lines early to avoid processing thousands of matches
    out.lines()
        .take(max_results * 4)   // extra room for post-filtering
        .collect::<Vec<_>>()
        .join("\n")
}

// ── File search ───────────────────────────────────────────────────────────

fn search_files(query: &str, config: &Config) -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let exclude = &config.search.exclude_patterns;
    let max = config.search.max_file_results;

    let raw: String = if cfg!(target_os = "macos") {
        if spotlight_enabled() {
            Command::new("mdfind")
                .args(["-onlyin", &home, "-name", query])
                .output()
                .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
                .unwrap_or_default()
        } else if cmd_exists("fd") {
            Command::new("fd")
                .args(["--base-directory", &home, "-I", "--max-depth", "6", "-i", query])
                .output()
                .map(|o| {
                    String::from_utf8_lossy(&o.stdout)
                        .lines()
                        .map(|l| format!("{}/{}", home, l))
                        .collect::<Vec<_>>()
                        .join("\n")
                })
                .unwrap_or_default()
        } else {
            find_by_name(&home, query, max)
        }
    } else {
        // Linux: locate → fd → find
        let locate_out = Command::new("locate")
            .args(["-i", query])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default();
        if !locate_out.trim().is_empty() {
            locate_out
        } else if cmd_exists("fd") {
            Command::new("fd")
                .args(["--base-directory", &home, "-I", "--max-depth", "6", "-i", query])
                .output()
                .map(|o| {
                    String::from_utf8_lossy(&o.stdout)
                        .lines()
                        .map(|l| format!("{}/{}", home, l))
                        .collect::<Vec<_>>()
                        .join("\n")
                })
                .unwrap_or_default()
        } else {
            find_by_name(&home, query, max)
        }
    };

    let mut results = Vec::new();
    for path_str in raw.lines() {
        if results.len() >= max { break; }
        if path_str.ends_with(".app") || path_str.contains(".app/Contents") { continue; }
        if exclude.iter().any(|p| path_str.contains(p.as_str())) { continue; }
        results.push(format!("FILE|{} {}", file_icon(Path::new(path_str)), path_str));
    }
    results
}

// ── Colors subcommand ─────────────────────────────────────────────────────

/// Output fzf --color value string derived from config [appearance].
fn cmd_colors(config: &Config) {
    let a = &config.appearance;
    println!(
        "bg:{},bg+:{},border:{},fg:{},fg+:{},gutter:{},hl:{},hl+:{},prompt:{},pointer:{},label:{}",
        a.bg, a.bg_selected, a.border,
        a.fg, a.fg, a.gutter,
        a.hl, a.hl,
        a.prompt, a.pointer, a.label,
    );
}

// ── Path helper ───────────────────────────────────────────────────────────

fn launcher_dir() -> PathBuf {
    if let Ok(d) = env::var("LAUNCHER_DIR") {
        return PathBuf::from(d);
    }
    if let Ok(exe) = env::current_exe() {
        if let Some(parent) = exe.parent() {
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

// ── Main ──────────────────────────────────────────────────────────────────

fn main() {
    let mut args = env::args().skip(1);
    let first = args.next().unwrap_or_default();

    let dir = launcher_dir();

    // Subcommands (not search queries)
    match first.as_str() {
        "record" => {
            // launcher-search record TYPE NAME
            let type_str = args.next().unwrap_or_default();
            let name = args.next().unwrap_or_default();
            if !type_str.is_empty() && !name.is_empty() {
                cmd_record(&dir, &type_str, &name);
            }
            return;
        }
        "colors" => {
            let config = load_config(&dir);
            cmd_colors(&config);
            return;
        }
        _ => {}
    }

    // Normal search mode: first arg is the query
    let query = first;
    let config = load_config(&dir);
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());

    // Empty query: frecency-sorted apps + SSH hosts + recent files + sys
    if query.is_empty() {
        let now = now_secs();
        let frecency = load_frecency(&frecency_path(&dir));
        for line in list_apps_sorted(&frecency, now) {
            let _ = writeln!(out, "{}", line);
        }
        for line in list_recent(&config) {
            let _ = writeln!(out, "{}", line);
        }
        for line in ssh_hosts("") {
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

    // Phase 1: fast results (in-memory / cache)

    // Color code
    if let Some(color) = search_color(&query) {
        emit!(color);
    }

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

    // Apps — frecency-sorted, then filter by query
    let now = now_secs();
    let frecency = load_frecency(&frecency_path(&dir));
    for line in list_apps_sorted(&frecency, now) {
        if let Some(display) = line.split_once('|').map(|(_, d)| d) {
            if display.to_lowercase().contains(&query_lower) {
                emit!(line);
            }
        }
    }

    // SSH hosts
    for line in ssh_hosts(&query_lower) {
        emit!(line);
    }

    // System commands
    for line in search_sys(&query_lower) {
        emit!(line.to_string());
    }

    let _ = out.flush();

    // Phase 2: file search
    if query.chars().count() >= config.search.min_query_for_files {
        for line in search_files(&query, &config) {
            emit!(line);
        }
        let _ = out.flush();
    }

    // Always last
    emit!(format!("CMD|\u{f0188} > {}", query));
    emit!(format!("WEB|\u{f059f} DuckDuckGo: {}", query));
    let _ = out.flush();
}
