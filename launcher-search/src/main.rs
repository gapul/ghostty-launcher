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
    launcher: LauncherConfig,
    #[serde(default)]
    preview: PreviewConfig,
    #[serde(default)]
    aliases: HashMap<String, String>,
    #[serde(default)]
    bookmarks: BookmarkConfig,
    #[serde(default)]
    clipboard: ClipboardConfig,
    #[serde(default)]
    icons: IconsConfig,
    #[serde(default)]
    app_icons: HashMap<String, String>,
    #[serde(default)]
    file_icons: HashMap<String, String>,
}

#[derive(Deserialize, Default)]
struct BookmarkConfig {
    #[serde(default)]
    xbel_path: String,
}

#[derive(Deserialize)]
struct ClipboardConfig {
    #[serde(default = "default_max_clip")]
    max_entries: usize,
}
impl Default for ClipboardConfig {
    fn default() -> Self { Self { max_entries: default_max_clip() } }
}
fn default_max_clip() -> usize { 50 }

#[derive(Deserialize)]
struct SearchConfig {
    #[serde(default = "default_min_query")]
    min_query_for_files: usize,
    #[serde(default = "default_max_files")]
    max_file_results: usize,
    #[serde(default = "default_max_recent")]
    max_recent_results: usize,
    /// Post-filter: paths containing these strings are excluded from results
    #[serde(default = "default_exclude")]
    exclude_patterns: Vec<String>,
    /// Prune: directory names skipped entirely during `find` traversal
    #[serde(default = "default_prune_dirs")]
    prune_dirs: Vec<String>,
    /// Web search base URL (query is appended URL-encoded)
    #[serde(default = "default_web_url")]
    web_search_url: String,
    /// Web search display name shown in the launcher list
    #[serde(default = "default_web_name")]
    web_search_name: String,
    /// Frecency entries older than this are pruned on write
    #[serde(default = "default_frecency_max_age")]
    frecency_max_age_days: u64,
    /// How many days back to look for recently used files (empty query)
    #[serde(default = "default_recent_days")]
    recent_days: u32,
    /// App list cache lifetime in seconds
    #[serde(default = "default_apps_cache_ttl")]
    apps_cache_ttl: u64,
    /// Recent files cache lifetime in seconds
    #[serde(default = "default_recent_cache_ttl")]
    recent_cache_ttl: u64,
    /// Max processes shown in kill list
    #[serde(default = "default_max_processes")]
    max_process_results: usize,
    /// Min query length before process list is searched
    #[serde(default = "default_min_proc_query")]
    min_query_for_processes: usize,
}

impl Default for SearchConfig {
    fn default() -> Self {
        Self {
            min_query_for_files:     default_min_query(),
            max_file_results:        default_max_files(),
            max_recent_results:      default_max_recent(),
            exclude_patterns:        default_exclude(),
            prune_dirs:              default_prune_dirs(),
            web_search_url:          default_web_url(),
            web_search_name:         default_web_name(),
            frecency_max_age_days:   default_frecency_max_age(),
            recent_days:             default_recent_days(),
            apps_cache_ttl:          default_apps_cache_ttl(),
            recent_cache_ttl:        default_recent_cache_ttl(),
            max_process_results:     default_max_processes(),
            min_query_for_processes: default_min_proc_query(),
        }
    }
}

fn default_min_query()        -> usize { 3 }
fn default_max_files()        -> usize { 15 }
fn default_max_recent()       -> usize { 10 }
fn default_exclude() -> Vec<String> {
    vec!["/Library/".into(), "node_modules".into(), "/.".into()]
}
fn default_prune_dirs() -> Vec<String> {
    vec![
        ".git".into(), "node_modules".into(), "target".into(),
        ".cursor".into(), ".venv".into(), "venv".into(),
        "__pycache__".into(), ".npm".into(), "Library".into(),
    ]
}
fn default_web_url()          -> String { "https://duckduckgo.com/?q=".into() }
fn default_web_name()         -> String { "DuckDuckGo".into() }
fn default_frecency_max_age() -> u64   { 90 }
fn default_recent_days()      -> u32   { 7 }
fn default_apps_cache_ttl()   -> u64   { 300 }
fn default_recent_cache_ttl() -> u64   { 60 }
fn default_max_processes()    -> usize { 20 }
fn default_min_proc_query()   -> usize { 2 }

// ── Launcher UI config ────────────────────────────────────────────────────

#[derive(Deserialize)]
struct LauncherConfig {
    #[serde(default = "d_prompt")]         prompt:         String,
    #[serde(default = "d_pointer")]        pointer:        String,
    #[serde(default = "d_border_label")]   border_label:   String,
    #[serde(default = "d_preview_window")] preview_window: String,
}

impl Default for LauncherConfig {
    fn default() -> Self {
        Self {
            prompt:         d_prompt(),
            pointer:        d_pointer(),
            border_label:   d_border_label(),
            preview_window: d_preview_window(),
        }
    }
}

fn d_prompt()         -> String { "  ".into() }
fn d_pointer()        -> String { "❯".into() }
fn d_border_label()   -> String { " \u{f003b}  Launcher ".into() }  // 󰀻
fn d_preview_window() -> String { "right:40%:wrap".into() }

// ── Preview config ────────────────────────────────────────────────────────

#[derive(Deserialize)]
struct PreviewConfig {
    #[serde(default = "d_img_timeout")]   image_timeout:      u32,
    #[serde(default = "d_cmd_timeout")]   cmd_timeout:        u32,
    #[serde(default = "d_max_archive")]   max_archive_entries: usize,
    #[serde(default = "d_max_text")]      max_text_lines:     usize,
    #[serde(default = "d_max_pdf")]       max_pdf_lines:      usize,
}

impl Default for PreviewConfig {
    fn default() -> Self {
        Self {
            image_timeout:       d_img_timeout(),
            cmd_timeout:         d_cmd_timeout(),
            max_archive_entries: d_max_archive(),
            max_text_lines:      d_max_text(),
            max_pdf_lines:       d_max_pdf(),
        }
    }
}

fn d_img_timeout()  -> u32   { 3 }
fn d_cmd_timeout()  -> u32   { 5 }
fn d_max_archive()  -> usize { 40 }
fn d_max_text()     -> usize { 100 }
fn d_max_pdf()      -> usize { 80 }

// ── Icons config ──────────────────────────────────────────────────────────
// Type-level icons (SSH, bookmark, etc.) are configured here.
// Per-app and per-extension icons are loaded from data/app_icons.toml and
// data/file_icons.toml, and overridable via [app_icons] / [file_icons] in config.toml.

#[derive(Deserialize)]
struct IconsConfig {
    #[serde(default = "d_icon_ssh")]      pub ssh:      String,
    #[serde(default = "d_icon_bookmark")] pub bookmark: String,
    #[serde(default = "d_icon_clip")]     pub clip:     String,
    #[serde(default = "d_icon_kill")]     pub kill:     String,
    #[serde(default = "d_icon_claude")]   pub claude:   String,
    #[serde(default = "d_icon_color")]    pub color:    String,
    #[serde(default = "d_icon_calc")]     pub calc:     String,
    #[serde(default = "d_icon_cmd")]      pub cmd:      String,
    #[serde(default = "d_icon_web")]      pub web:      String,
}

impl Default for IconsConfig {
    fn default() -> Self {
        Self {
            ssh:      d_icon_ssh(),
            bookmark: d_icon_bookmark(),
            clip:     d_icon_clip(),
            kill:     d_icon_kill(),
            claude:   d_icon_claude(),
            color:    d_icon_color(),
            calc:     d_icon_calc(),
            cmd:      d_icon_cmd(),
            web:      d_icon_web(),
        }
    }
}

fn d_icon_ssh()      -> String { "\u{f0200}".into() }  // 󰈀
fn d_icon_bookmark() -> String { "\u{f0114}".into() }  // 󰄔
fn d_icon_clip()     -> String { "\u{f0315}".into() }  // 󰌕
fn d_icon_kill()     -> String { "\u{f0e2a}".into() }  // 󰸪
fn d_icon_claude()   -> String { "\u{e28b}".into()  }  //
fn d_icon_color()    -> String { "\u{f0765}".into() }  // 󰝥
fn d_icon_calc()     -> String { "\u{f00ec}".into() }  // 󰃬
fn d_icon_cmd()      -> String { "\u{f0188}".into() }  // 󰆈
fn d_icon_web()      -> String { "\u{f059f}".into() }  // 󰖟

// Catppuccin Macchiato defaults
#[derive(Deserialize)]
struct AppearanceConfig {
    #[serde(default = "da_bg")]      bg: String,
    #[serde(default = "da_bg_sel")]  bg_selected: String,
    #[serde(default = "da_border")]  border: String,
    #[serde(default = "da_fg")]      fg: String,
    #[serde(default = "da_gutter")]  gutter: String,
    #[serde(default = "da_hl")]      hl: String,
    #[serde(default = "da_prompt")]  prompt: String,
    #[serde(default = "da_pointer")] pointer: String,
    #[serde(default = "da_label")]   label: String,
}

impl Default for AppearanceConfig {
    fn default() -> Self {
        Self {
            bg: da_bg(), bg_selected: da_bg_sel(), border: da_border(),
            fg: da_fg(), gutter: da_gutter(), hl: da_hl(),
            prompt: da_prompt(), pointer: da_pointer(), label: da_label(),
        }
    }
}

fn da_bg()      -> String { "#1e1e2e".into() }
fn da_bg_sel()  -> String { "#313244".into() }
fn da_border()  -> String { "#6e6a86".into() }
fn da_fg()      -> String { "#cad3f5".into() }
fn da_gutter()  -> String { "#1e1e2e".into() }
fn da_hl()      -> String { "#8aadf4".into() }
fn da_prompt()  -> String { "#c6a0f6".into() }
fn da_pointer() -> String { "#ed8796".into() }
fn da_label()   -> String { "#c6a0f6".into() }

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

/// 一時ファイルに書き込んでからリネームするアトミック書き込み。
/// 書き込み中にプロセスが死んでも元のファイルが壊れない。
fn write_lines_atomic(path: &Path, content: &str) -> io::Result<()> {
    let parent = path.parent().unwrap_or(Path::new("."));
    let fname  = path.file_name().and_then(|n| n.to_str()).unwrap_or("tmp");
    let tmp    = parent.join(format!(".{}.tmp", fname));
    fs::write(&tmp, content)?;
    fs::rename(&tmp, path)?;
    Ok(())
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

fn save_frecency(path: &Path, db: &HashMap<String, (u32, u64)>, max_age_days: u64) {
    let cutoff = now_secs().saturating_sub(max_age_days * 86400);
    let mut content = String::new();
    for (key, &(count, ts)) in db {
        if ts >= cutoff {
            content.push_str(&format!("{}\t{}\t{}\n", count, ts, key));
        }
    }
    let _ = write_lines_atomic(path, &content);
}

/// Higher = more recent and frequently used.
///
/// Formula: ln(1 + count) × 0.5^(age_days / 30)
///   - ln(1+count) prevents a 1-use recent item from outranking a 10-use older item
///   - 30-day half-life: score halves every 30 days (much gentler than 1/(1+age))
///     - 0 days:  ×1.00
///     - 30 days: ×0.50
///     - 90 days: ×0.125
fn frecency_score(count: u32, last_ts: u64, now: u64) -> f64 {
    let age_secs = now.saturating_sub(last_ts);
    let age_days = (age_secs as f64) / 86400.0;
    let recency = 0.5_f64.powf(age_days / 30.0);
    (count as f64 + 1.0).ln() * recency
}

/// Record a launch. Called as a subcommand: `launcher-search record TYPE NAME`
fn cmd_record(launcher_dir: &Path, type_str: &str, name: &str, max_age_days: u64) {
    let path = frecency_path(launcher_dir);
    let mut db = load_frecency(&path);
    let key = format!("{}\t{}", type_str, name);
    let entry = db.entry(key).or_insert((0, 0));
    entry.0 += 1;
    entry.1 = now_secs();
    save_frecency(&path, &db, max_age_days);
}

// ── App / file icon lookup ────────────────────────────────────────────────

fn app_icon(name: &str, overrides: &HashMap<String, String>) -> String {
    if let Some(s) = overrides.get(name) { return s.clone(); }
    default_app_icons().get(name).cloned().unwrap_or_else(|| "󰀻".to_string())
}

fn file_icon(path: &Path, overrides: &HashMap<String, String>) -> String {
    if path.is_dir() {
        if let Some(s) = overrides.get("_directory") { return s.clone(); }
        return default_file_icons().get("_directory").cloned().unwrap_or_else(|| "󰉋".to_string());
    }
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    if let Some(s) = overrides.get(ext) { return s.clone(); }
    default_file_icons().get(ext).cloned().unwrap_or_else(|| "󰈔".to_string())
}

// ── Cache helpers ─────────────────────────────────────────────────────────

fn tmp_dir() -> String {
    env::var("TMPDIR").unwrap_or_else(|_| "/tmp".to_string())
}
fn apps_cache_path()   -> String { format!("{}/launcher_apps_cache.txt",   tmp_dir()) }
fn recent_cache_path() -> String { format!("{}/launcher_recent_cache.txt", tmp_dir()) }

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

fn scan_apps_macos(overrides: &HashMap<String, String>) -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let home_apps = format!("{}/Applications", home);
    let dirs = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        home_apps.as_str(),
    ];

    let mut results = Vec::new();
    let push_app = |s: &str, results: &mut Vec<String>| {
        if let Some(app_name) = s.strip_suffix(".app") {
            results.push(format!("APP|{} {}", app_icon(app_name, overrides), app_name));
        }
    };

    for dir in dirs {
        let Ok(entries) = fs::read_dir(dir) else { continue; };
        for entry in entries.flatten() {
            let name = entry.file_name();
            let s = name.to_string_lossy();
            if s.ends_with(".app") {
                push_app(&s, &mut results);
            } else if entry.file_type().map(|t| t.is_dir()).unwrap_or(false) {
                // /Applications/<vendor>/<App>.app のような1階層深いレイアウトに対応。
                // .app バンドル内部には降りないので Helper まで拾うことはない。
                if let Ok(subs) = fs::read_dir(entry.path()) {
                    for sub in subs.flatten() {
                        let sub_name = sub.file_name();
                        let ss = sub_name.to_string_lossy();
                        if ss.ends_with(".app") {
                            push_app(&ss, &mut results);
                        }
                    }
                }
            }
        }
    }
    if Path::new("/System/Library/CoreServices/Finder.app").exists() {
        results.push(format!("APP|{} Finder", app_icon("Finder", overrides)));
    }
    results.sort();
    results.dedup();
    results
}

fn scan_apps_linux(overrides: &HashMap<String, String>) -> Vec<String> {
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
                        results.push(format!("APP|{} {}", app_icon(name, overrides), name));
                    }
                }
            }
        }
    }
    results.sort();
    results.dedup();
    results
}

fn build_apps_cache(overrides: &HashMap<String, String>) -> Vec<String> {
    let apps = if cfg!(target_os = "macos") {
        scan_apps_macos(overrides)
    } else {
        scan_apps_linux(overrides)
    };
    let content = apps.join("\n") + "\n";
    let _ = write_lines_atomic(Path::new(&apps_cache_path()), &content);
    apps
}

fn list_apps(config: &Config) -> Vec<String> {
    let path = apps_cache_path();
    if cache_valid(&path, config.search.apps_cache_ttl) {
        if let Ok(content) = fs::read_to_string(&path) {
            return content.lines().map(String::from).collect();
        }
    }
    build_apps_cache(&config.app_icons)
}

/// Returns apps sorted by frecency score (descending), remaining items after.
fn list_apps_sorted(frecency: &HashMap<String, (u32, u64)>, now: u64, config: &Config) -> Vec<String> {
    let apps = list_apps(config);
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
    let recent_path = recent_cache_path();
    if cache_valid(&recent_path, config.search.recent_cache_ttl) {
        if let Ok(content) = fs::read_to_string(&recent_path) {
            return content.lines().map(String::from).collect();
        }
    }

    let home = env::var("HOME").unwrap_or_default();
    let exclude = &config.search.exclude_patterns;
    let max = config.search.max_recent_results;
    let mut lines = Vec::new();

    let days = config.search.recent_days;
    let raw = if cfg!(target_os = "macos") && spotlight_enabled() {
        Command::new("mdfind")
            .args(["-onlyin", &home,
                   &format!("kMDItemLastUsedDate >= $time.today(-{})", days)])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    } else {
        // find files modified within recent_days days, skip hidden dirs and noise
        let prune_names = &config.search.prune_dirs;
        let mut find_args: Vec<String> = vec![
            home.clone(), "-maxdepth".into(), "5".into(), "(".into(),
        ];
        for (i, name) in prune_names.iter().enumerate() {
            if i > 0 { find_args.push("-o".into()); }
            find_args.push("-name".into());
            find_args.push(name.clone());
        }
        find_args.extend([
            ")".into(), "-prune".into(), "-o".into(),
            "-not".into(), "-name".into(), ".*".into(),
            "-not".into(), "-type".into(), "d".into(),
            "-mtime".into(), format!("-{}", days),
            "-print".into(),
        ]);
        Command::new("find")
            .args(&find_args)
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    };

    for path_str in raw.lines() {
        if lines.len() >= max { break; }
        if path_str.ends_with(".app") { continue; }
        if exclude.iter().any(|p| path_str.contains(p.as_str())) { continue; }
        lines.push(format!("FILE|{} {}", file_icon(Path::new(path_str), &config.file_icons), path_str));
    }

    let content = lines.join("\n") + "\n";
    let _ = write_lines_atomic(Path::new(&recent_cache_path()), &content);
    lines
}

// ── SSH hosts ─────────────────────────────────────────────────────────────

/// Parse ~/.ssh/config and return matching Host entries.
/// Pass `query_lower = ""` to return all hosts.
fn ssh_hosts(query_lower: &str, config: &Config) -> Vec<String> {
    let home = env::var("HOME").unwrap_or_default();
    let ssh_config = PathBuf::from(&home).join(".ssh/config");
    let Ok(content) = fs::read_to_string(&ssh_config) else {
        return Vec::new();
    };
    let icon = &config.icons.ssh;
    content
        .lines()
        .filter_map(|line| {
            let line = line.trim();
            let rest = if line.len() > 5 && line[..5].eq_ignore_ascii_case("host ") {
                line[5..].trim()
            } else {
                return None;
            };
            if rest.is_empty() || rest.contains('*') || rest.contains('?') {
                return None;
            }
            if query_lower.is_empty() || rest.to_lowercase().contains(query_lower) {
                Some(format!("SSH|{} {}", icon, rest))
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
        "LAUNCHER_RESTART|\u{f0709} Restart Launcher",
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
    if query_lower.contains("launcher") || query_lower.contains("ランチャー") {
        results.push("LAUNCHER_RESTART|\u{f0709} Restart Launcher");
    }
    results
}

// ── Wi-Fi / Bluetooth ─────────────────────────────────────────────────────
//
// Glyphs (Nerd Font Material Design):
//   󰖩 nf-md-wifi          /  󰖪 nf-md-wifi_off
//   󰂯 nf-md-bluetooth     /  󰂲 nf-md-bluetooth_off  /  󰂱 nf-md-bluetooth_connect

const ICON_WIFI_ON:    &str = "\u{f05a9}"; // 󰖩
const ICON_WIFI_OFF:   &str = "\u{f05aa}"; // 󰖪
const ICON_BT_ON:      &str = "\u{f00af}"; // 󰂯
const ICON_BT_OFF:     &str = "\u{f00b2}"; // 󰂲
const ICON_BT_CONNECT: &str = "\u{f00b1}"; // 󰂱

const WIFI_DEVICE: &str = "en0";

fn run_capture(prog: &str, args: &[&str]) -> Option<String> {
    let out = Command::new(prog).args(args).output().ok()?;
    if !out.status.success() { return None; }
    Some(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn wifi_power_on() -> bool {
    run_capture("/usr/sbin/networksetup", &["-getairportpower", WIFI_DEVICE])
        .map(|s| s.contains(": On"))
        .unwrap_or(false)
}

/// Current SSID. macOS Sequoia returns the literal string `<redacted>` from
/// every public SSID API (`ipconfig`, `system_profiler`, `networksetup`,
/// `wdutil`, even sudo) and CoreWLAN's `CWInterface.ssid()` returns nil
/// for any process without the `com.apple.developer.networking.wifi-info`
/// entitlement — which requires a paid Apple Developer ID. So this lookup is
/// best-effort: we try ipconfig (works only on older macOS / pre-Sequoia
/// boxes) and, if that's redacted, return None and live without the
/// "currently connected" marker.
fn wifi_current_ssid() -> Option<String> {
    let s = ipconfig_ssid()?;
    if is_real_ssid(&s) { Some(s) } else { None }
}

fn is_real_ssid(s: &str) -> bool {
    !s.is_empty() && !s.eq_ignore_ascii_case("redacted")
}

/// Extract the SSID from the sketchybar wifi item's label. The user's
/// sketchybar/items/wifi.sh sets the label to `"$SSID [<RSSI>dBm] [<TXRATE>Mb]"`
/// — strip the trailing signal-info tokens and what remains is the SSID.
fn ipconfig_ssid() -> Option<String> {
    let s = run_capture("/usr/sbin/ipconfig", &["getsummary", WIFI_DEVICE])?;
    for line in s.lines() {
        let t = line.trim();
        // "SSID : <name>" (skip the "BSSID :" line which doesn't start with "SSID :")
        if let Some(rest) = t.strip_prefix("SSID :") {
            let raw = rest.trim();
            let stripped = raw.strip_prefix('<').and_then(|r| r.strip_suffix('>')).unwrap_or(raw);
            return Some(stripped.to_string());
        }
    }
    None
}

fn wifi_preferred_networks() -> Vec<String> {
    let Some(s) = run_capture("/usr/sbin/networksetup", &["-listpreferredwirelessnetworks", WIFI_DEVICE]) else {
        return Vec::new();
    };
    s.lines()
        .skip(1) // header line "Preferred networks on en0:"
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect()
}

fn blueutil_available() -> bool {
    static CACHE: OnceLock<bool> = OnceLock::new();
    *CACHE.get_or_init(|| {
        run_capture("/bin/sh", &["-c", "command -v blueutil >/dev/null 2>&1 && echo y"])
            .map(|s| s.trim() == "y")
            .unwrap_or(false)
    })
}

fn bt_power_on() -> Option<bool> {
    if !blueutil_available() { return None; }
    let s = run_capture("blueutil", &["--power"])?;
    Some(s.trim() == "1")
}

#[derive(Debug, Deserialize)]
struct BtDevice {
    address: String,
    name: String,
    #[serde(default)]
    connected: bool,
}

fn bt_paired_devices() -> Vec<BtDevice> {
    if !blueutil_available() { return Vec::new(); }
    let Some(s) = run_capture("blueutil", &["--paired", "--format", "json"]) else { return Vec::new(); };
    serde_json::from_str(&s).unwrap_or_default()
}

/// Items shown on empty query: status lines + power toggles.
fn list_wifi_bt() -> Vec<String> {
    let mut out = Vec::new();

    // WiFi status (read-only; clicking opens Network panel via launcher.sh)
    if wifi_power_on() {
        match wifi_current_ssid() {
            Some(ssid) => out.push(format!("WIFI_STATUS|{} Wi-Fi: {}", ICON_WIFI_ON, ssid)),
            None       => out.push(format!("WIFI_STATUS|{} Wi-Fi: on (not connected)", ICON_WIFI_ON)),
        }
    } else {
        out.push(format!("WIFI_STATUS|{} Wi-Fi: off", ICON_WIFI_OFF));
    }

    // BT status
    if let Some(power) = bt_power_on() {
        if power {
            let connected: Vec<_> = bt_paired_devices().into_iter().filter(|d| d.connected).collect();
            let label = match connected.len() {
                0 => "Bluetooth: on (no devices)".to_string(),
                1 => format!("Bluetooth: {}", connected[0].name),
                n => format!("Bluetooth: {} devices", n),
            };
            let icon = if connected.is_empty() { ICON_BT_ON } else { ICON_BT_CONNECT };
            out.push(format!("BT_STATUS|{} {}", icon, label));
        } else {
            out.push(format!("BT_STATUS|{} Bluetooth: off", ICON_BT_OFF));
        }
    }
    out
}

/// Resolve the name of the app that was frontmost just before our terminal host.
/// Uses `lsappinfo visibleProcessList` (front-to-back z-order). Output looks
/// like `ASN:0x0-0x22022-"Zen": ASN:0x0-0x1d01d-"Ghostty": ...` — the first
/// token is the launcher's host terminal, the second is the previous frontmost.
/// The name is embedded directly between `-"` and `":`, so we don't need a
/// second `lsappinfo info` call.
fn prev_frontmost_app_name() -> Option<String> {
    let list = run_capture("/usr/bin/lsappinfo", &["visibleProcessList"])?;
    let names: Vec<String> = list.split_whitespace()
        .filter_map(|tok| {
            let start = tok.find("-\"")? + 2;
            let rest = &tok[start..];
            let end = rest.find("\":")?;
            Some(rest[..end].to_string())
        })
        .collect();
    // index 0 = our terminal, index 1 = previous frontmost
    let name = names.get(1)?;
    if name.is_empty() { None } else { Some(name.clone()) }
}

fn search_menu_items(query_lower: &str) -> Vec<String> {
    let trigger = ["menu", "メニュー", "めにゅー", "menubar", "menu bar"]
        .iter().any(|k| query_lower.contains(k));
    if !trigger { return Vec::new(); }
    let label = match prev_frontmost_app_name() {
        Some(name) => format!("Search menu items of {}…", name),
        None       => "Search menu items…".to_string(),
    };
    // 󰍜 nf-md-menu
    vec![format!("MENU_ITEMS_LIST|\u{f035c} {}", label)]
}

fn search_quickadd(query_lower: &str) -> Vec<String> {
    let mut out = Vec::new();
    let log_trigger = ["log", "addlog", "add log", "ログ", "quickadd"]
        .iter().any(|k| query_lower.contains(k));
    if log_trigger {
        out.push(format!("QUICKADD|\u{f03ed} Add Log (Obsidian QuickAdd)"));
    }
    let task_trigger = ["task", "addtask", "add task", "todo", "タスク", "quickadd"]
        .iter().any(|k| query_lower.contains(k));
    if task_trigger {
        out.push(format!("QUICKTASK|\u{f0139} Add Task (Obsidian QuickAdd)"));
    }
    out
}

fn search_wifi(query_lower: &str) -> Vec<String> {
    let trigger = ["wifi", "wi-fi", "wi‑fi", "ワイファイ", "ワイヤレス", "wlan"]
        .iter().any(|k| query_lower.contains(k));
    if !trigger { return Vec::new(); }

    let mut out = Vec::new();
    let on = wifi_power_on();
    let toggle_label = if on { "Turn Wi-Fi Off" } else { "Turn Wi-Fi On" };
    let toggle_icon  = if on { ICON_WIFI_ON } else { ICON_WIFI_OFF };
    out.push(format!("WIFI_TOGGLE|{} {}", toggle_icon, toggle_label));
    if on {
        out.push(format!("WIFI_LIST|{} Wi-Fi networks…", ICON_WIFI_ON));
    }
    out
}

fn search_bluetooth(query_lower: &str) -> Vec<String> {
    let trigger = ["bluetooth", "bt", "ブルートゥース", "ぶるーとぅーす"]
        .iter().any(|k| query_lower.contains(k));
    if !trigger { return Vec::new(); }
    let Some(on) = bt_power_on() else { return Vec::new(); };

    let mut out = Vec::new();
    let toggle_label = if on { "Turn Bluetooth Off" } else { "Turn Bluetooth On" };
    let toggle_icon  = if on { ICON_BT_ON } else { ICON_BT_OFF };
    out.push(format!("BT_TOGGLE|{} {}", toggle_icon, toggle_label));
    if on {
        out.push(format!("BT_LIST|{} Bluetooth devices…", ICON_BT_ON));
    }
    out
}

/// Lines for the Wi-Fi sub-launcher (`launcher-search wifi-list`).
fn wifi_list_entries() -> Vec<String> {
    if !wifi_power_on() { return Vec::new(); }
    let current = wifi_current_ssid().map(|s| s.to_lowercase());
    wifi_preferred_networks()
        .into_iter()
        .map(|ssid| {
            let is_current = current.as_deref() == Some(ssid.to_lowercase().as_str());
            let prefix = if is_current { "✓ " } else { "" };
            format!("WIFI:{}|{} {}{}", ssid, ICON_WIFI_ON, prefix, ssid)
        })
        .collect()
}

/// Lines for the Bluetooth sub-launcher (`launcher-search bt-list`).
fn bt_list_entries() -> Vec<String> {
    if !matches!(bt_power_on(), Some(true)) { return Vec::new(); }
    let mut devices = bt_paired_devices();
    // Connected first, then by name.
    devices.sort_by(|a, b| b.connected.cmp(&a.connected).then_with(|| a.name.cmp(&b.name)));
    devices
        .into_iter()
        .map(|d| {
            let icon = if d.connected { ICON_BT_CONNECT } else { ICON_BT_ON };
            let prefix = if d.connected { "✓ " } else { "" };
            format!("BT:{}|{} {}{}", d.address, icon, prefix, d.name)
        })
        .collect()
}

// ── URL encoding ──────────────────────────────────────────────────────────

/// Percent-encode a string for use in a URL query parameter (RFC 3986 + space→+).
fn url_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 16);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9'
            | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            b' ' => out.push('+'),
            _ => {
                out.push('%');
                out.push(char::from_digit((b >> 4) as u32, 16).unwrap_or('0').to_ascii_uppercase());
                out.push(char::from_digit((b & 0xf) as u32, 16).unwrap_or('0').to_ascii_uppercase());
            }
        }
    }
    out
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
fn search_color(query: &str, config: &Config) -> Option<String> {
    let q = query.trim();
    let icon = &config.icons.color;

    if let Some(hex) = q.strip_prefix('#') {
        if matches!(hex.len(), 3 | 6 | 8) && hex.chars().all(|c| c.is_ascii_hexdigit()) {
            return Some(format!("COLOR|{} {}", icon, q));
        }
    }
    let ql = q.to_lowercase();
    let color_fns = ["rgb(", "rgba(", "hsl(", "hsla("];
    if ql.ends_with(')') && color_fns.iter().any(|f| ql.starts_with(f)) {
        return Some(format!("COLOR|{} {}", icon, q));
    }
    None
}

// ── Unit conversion (A) ──────────────────────────────────────────────────

fn normalize_unit(u: &str) -> &str {
    match u {
        "kilometer" | "kilometers" | "kilometre" | "kilometres" => "km",
        "meter" | "meters" | "metre" | "metres" => "m",
        "centimeter" | "centimeters" | "centimetre" | "centimetres" => "cm",
        "millimeter" | "millimeters" | "millimetre" | "millimetres" => "mm",
        "mile" | "miles" => "mi",
        "foot" | "feet" => "ft",
        "inch" | "inches" => "in",
        "yard" | "yards" => "yd",
        "kilogram" | "kilograms" => "kg",
        "gram" | "grams" => "g",
        "milligram" | "milligrams" => "mg",
        "pound" | "pounds" => "lb",
        "ounce" | "ounces" => "oz",
        "celsius" | "°c" => "c",
        "fahrenheit" | "°f" => "f",
        "kelvin" => "k",
        "gigabyte" | "gigabytes" => "gb",
        "megabyte" | "megabytes" => "mb",
        "kilobyte" | "kilobytes" => "kb",
        "byte" | "bytes" => "b",
        "terabyte" | "terabytes" => "tb",
        "hour" | "hours" => "h",
        "minute" | "minutes" => "min",
        "second" | "seconds" => "s",
        "day" | "days" => "d",
        "millisecond" | "milliseconds" => "ms",
        _ => u,
    }
}

fn parse_unit_query(q: &str) -> Option<(f64, String, String)> {
    // Find separator " to " or " in " (must be surrounded by spaces to avoid
    // matching mid-word: "100to km" must NOT parse as from_unit="" → reject)
    let sep = if q.contains(" to ") { " to " } else if q.contains(" in ") { " in " } else { return None; };
    let idx = q.find(sep)?;
    let left = q[..idx].trim();
    let right = q[idx + sep.len()..].trim();
    if right.is_empty() { return None; }

    // Split number from unit (e.g. "100F" → 100, "f")
    let num_end = left.find(|c: char| !(c.is_ascii_digit() || c == '.' || c == '-')).unwrap_or(left.len());
    if num_end == 0 { return None; }
    let value: f64 = left[..num_end].parse().ok()?;
    let from_unit = left[num_end..].trim().to_lowercase();
    let to_unit = right.to_lowercase();

    // Both units must be non-empty and not contain digits (guards against
    // "100 to 200" being misinterpreted as a unit query)
    if from_unit.is_empty() || to_unit.is_empty() { return None; }
    if from_unit.chars().any(|c| c.is_ascii_digit()) { return None; }
    if to_unit.chars().any(|c| c.is_ascii_digit()) { return None; }
    Some((value, from_unit, to_unit))
}

fn fmt_num(v: f64) -> String {
    let r = (v * 1e8).round() / 1e8;
    // Use i64 cast only when safe (no overflow / not fractional)
    if r.fract() == 0.0 && r >= i64::MIN as f64 && r <= i64::MAX as f64 {
        format!("{}", r as i64)
    } else if r.abs() >= 1000.0 {
        format!("{:.4}", r)
    } else {
        format!("{:.6}", r).trim_end_matches('0').trim_end_matches('.').to_string()
    }
}

fn convert_unit(val: f64, from: &str, to: &str) -> Option<String> {
    let from = normalize_unit(from);
    let to = normalize_unit(to);

    // Length (base: meters)
    let to_m: Option<f64> = match from {
        "mm" => Some(val * 0.001), "cm" => Some(val * 0.01), "m" => Some(val),
        "km" => Some(val * 1000.0), "in" => Some(val * 0.0254), "ft" => Some(val * 0.3048),
        "yd" => Some(val * 0.9144), "mi" => Some(val * 1609.344), _ => None,
    };
    if let Some(meters) = to_m {
        let result: Option<f64> = match to {
            "mm" => Some(meters / 0.001), "cm" => Some(meters / 0.01), "m" => Some(meters),
            "km" => Some(meters / 1000.0), "in" => Some(meters / 0.0254), "ft" => Some(meters / 0.3048),
            "yd" => Some(meters / 0.9144), "mi" => Some(meters / 1609.344), _ => None,
        };
        if let Some(r) = result { return Some(format!("{} {}", fmt_num(r), to)); }
    }

    // Weight (base: grams)
    let to_g: Option<f64> = match from {
        "mg" => Some(val * 0.001), "g" => Some(val), "kg" => Some(val * 1000.0),
        "lb" => Some(val * 453.592), "oz" => Some(val * 28.3495), _ => None,
    };
    if let Some(grams) = to_g {
        let result: Option<f64> = match to {
            "mg" => Some(grams / 0.001), "g" => Some(grams), "kg" => Some(grams / 1000.0),
            "lb" => Some(grams / 453.592), "oz" => Some(grams / 28.3495), _ => None,
        };
        if let Some(r) = result { return Some(format!("{} {}", fmt_num(r), to)); }
    }

    // Temperature
    let celsius: Option<f64> = match from {
        "c" => Some(val),
        "f" => Some((val - 32.0) * 5.0 / 9.0),
        "k" => Some(val - 273.15),
        _ => None,
    };
    if let Some(c) = celsius {
        let result: Option<f64> = match to {
            "c" => Some(c),
            "f" => Some(c * 9.0 / 5.0 + 32.0),
            "k" => Some(c + 273.15),
            _ => None,
        };
        if let Some(r) = result { return Some(format!("{} °{}", fmt_num(r), to.to_uppercase())); }
    }

    // Data (base: bytes)
    let to_bytes: Option<f64> = match from {
        "b" => Some(val), "kb" => Some(val * 1024.0), "mb" => Some(val * 1024.0_f64.powi(2)),
        "gb" => Some(val * 1024.0_f64.powi(3)), "tb" => Some(val * 1024.0_f64.powi(4)), _ => None,
    };
    if let Some(bytes) = to_bytes {
        let result: Option<f64> = match to {
            "b" => Some(bytes), "kb" => Some(bytes / 1024.0), "mb" => Some(bytes / 1024.0_f64.powi(2)),
            "gb" => Some(bytes / 1024.0_f64.powi(3)), "tb" => Some(bytes / 1024.0_f64.powi(4)), _ => None,
        };
        if let Some(r) = result { return Some(format!("{} {}", fmt_num(r), to.to_uppercase())); }
    }

    // Time (base: seconds)
    let to_secs: Option<f64> = match from {
        "ms" => Some(val * 0.001), "s" => Some(val), "min" => Some(val * 60.0),
        "h" => Some(val * 3600.0), "d" => Some(val * 86400.0), _ => None,
    };
    if let Some(secs) = to_secs {
        let result: Option<f64> = match to {
            "ms" => Some(secs / 0.001), "s" => Some(secs), "min" => Some(secs / 60.0),
            "h" => Some(secs / 3600.0), "d" => Some(secs / 86400.0), _ => None,
        };
        if let Some(r) = result { return Some(format!("{} {}", fmt_num(r), to)); }
    }

    None
}

fn search_unit_convert(query: &str, config: &Config) -> Option<String> {
    let (val, from, to) = parse_unit_query(&query.trim().to_lowercase())?;
    let result = convert_unit(val, &from, &to)?;
    Some(format!("CALC|{} = {}", config.icons.calc, result))
}

// ── Base conversion (B) ───────────────────────────────────────────────────

fn search_base_convert(query: &str, config: &Config) -> Option<String> {
    let q = query.trim();
    let ql = q.to_lowercase();
    let ic = &config.icons.calc;

    if ql.starts_with("0x") {
        let hex = &q[2..];
        if !hex.is_empty() && hex.chars().all(|c| c.is_ascii_hexdigit()) {
            let n = u64::from_str_radix(hex, 16).ok()?;
            return Some(format!("CALC|{} = {} (dec)  0b{:b} (bin)  0o{:o} (oct)", ic, n, n, n));
        }
    }
    if ql.starts_with("0b") {
        let bin = &q[2..];
        if !bin.is_empty() && bin.chars().all(|c| c == '0' || c == '1') {
            let n = u64::from_str_radix(bin, 2).ok()?;
            return Some(format!("CALC|{} = {} (dec)  0x{:x} (hex)  0o{:o} (oct)", ic, n, n, n));
        }
    }
    if ql.starts_with("0o") {
        let oct = &q[2..];
        if !oct.is_empty() && oct.chars().all(|c| ('0'..='7').contains(&c)) {
            let n = u64::from_str_radix(oct, 8).ok()?;
            return Some(format!("CALC|{} = {} (dec)  0x{:x} (hex)  0b{:b} (bin)", ic, n, n, n));
        }
    }
    let sep = if ql.contains(" in ") { " in " } else if ql.contains(" to ") { " to " } else { return None; };
    let idx = ql.find(sep)?;
    let num: u64 = q[..idx].trim().parse().ok()?;
    let target = ql[idx + sep.len()..].trim();
    match target {
        "hex" | "hexadecimal" => Some(format!("CALC|{} = 0x{:X}", ic, num)),
        "bin" | "binary"      => Some(format!("CALC|{} = 0b{:b}", ic, num)),
        "oct" | "octal"       => Some(format!("CALC|{} = 0o{:o}", ic, num)),
        "dec" | "decimal"     => Some(format!("CALC|{} = {}", ic, num)),
        _ => None,
    }
}

fn search_calc(query: &str, config: &Config) -> Option<String> {
    if !query.chars().any(|c| c.is_ascii_digit()) { return None; }
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
                evalexpr::Value::Int(i)   => format!("{}", i),
                evalexpr::Value::Boolean(b) => format!("{}", b),
                _ => return None,
            };
            Some(format!("CALC|{} = {}", config.icons.calc, s))
        }
        Err(_) => None,
    }
}

// ── Bookmarks (H) ────────────────────────────────────────────────────────

fn expand_tilde(path: &str) -> String {
    if let Some(rest) = path.strip_prefix("~/") {
        let home = env::var("HOME").unwrap_or_default();
        format!("{}/{}", home, rest)
    } else {
        path.to_string()
    }
}

/// Parse XBEL file → Vec<(title, url)>
fn parse_xbel(content: &str) -> Vec<(String, String)> {
    let mut results = Vec::new();
    let mut current_href: Option<String> = None;

    for line in content.lines() {
        let line = line.trim();
        // <bookmark href="URL">
        if line.contains("href=") && line.to_ascii_lowercase().contains("bookmark") {
            if let Some(s) = line.find("href=\"") {
                let rest = &line[s + 6..];
                if let Some(e) = rest.find('"') {
                    let url = rest[..e]
                        .replace("&amp;", "&")
                        .replace("&lt;", "<")
                        .replace("&gt;", ">")
                        .replace("&quot;", "\"");
                    current_href = Some(url);
                }
            }
        }
        // <title>NAME</title>
        if line.starts_with("<title>") {
            if let Some(href) = current_href.take() {
                let title = line
                    .trim_start_matches("<title>")
                    .trim_end_matches("</title>")
                    .replace("&amp;", "&")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&quot;", "\"");
                if !title.is_empty() {
                    results.push((title, href));
                }
            }
        }
    }
    results
}

fn load_bookmarks(config: &Config) -> Vec<(String, String)> {
    if config.bookmarks.xbel_path.is_empty() { return Vec::new(); }
    let path = expand_tilde(&config.bookmarks.xbel_path);
    let Ok(content) = fs::read_to_string(&path) else { return Vec::new(); };
    parse_xbel(&content)
}

/// Emit format: "BOOKMARK:URL|ICON Title"  — URL in type field to keep display clean
fn format_bookmark(title: &str, url: &str, config: &Config) -> String {
    let safe_url = url.replace('|', "%7C");
    format!("BOOKMARK:{}|{} {}", safe_url, config.icons.bookmark, title)
}

fn search_bookmarks(query_lower: &str, config: &Config) -> Vec<String> {
    load_bookmarks(config)
        .into_iter()
        .filter(|(title, url)| {
            title.to_lowercase().contains(query_lower) || url.to_lowercase().contains(query_lower)
        })
        .map(|(title, url)| format_bookmark(&title, &url, config))
        .collect()
}

fn list_bookmarks_all(config: &Config) -> Vec<String> {
    load_bookmarks(config)
        .into_iter()
        .map(|(title, url)| format_bookmark(&title, &url, config))
        .collect()
}

// ── Clipboard history (G) ────────────────────────────────────────────────

fn clipboard_history_path(launcher_dir: &Path) -> PathBuf {
    launcher_dir.join("clipboard_history.txt")
}

fn load_clip_history(path: &Path) -> Vec<String> {
    fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .filter(|l| !l.is_empty())
        .map(String::from)
        .collect()
}

fn record_clipboard(launcher_dir: &Path, text: &str, max: usize) {
    let text = text.trim();
    if text.is_empty() || text.len() > 2048 { return; }
    // Only single-line entries in the list view (multi-line stored as \n escaped)
    let stored = text.replace('\n', "\\n").replace('\r', "");
    let path = clipboard_history_path(launcher_dir);
    let mut history = load_clip_history(&path);
    history.retain(|l| l != &stored);
    history.insert(0, stored);
    history.truncate(max);
    let content = history.join("\n") + "\n";
    let _ = write_lines_atomic(&path, &content);
}

fn list_clipboard_history(launcher_dir: &Path, config: &Config) -> Vec<String> {
    let path = clipboard_history_path(launcher_dir);
    load_clip_history(&path)
        .into_iter()
        .take(config.clipboard.max_entries)
        .map(|entry| {
            let display = if entry.chars().count() > 80 {
                format!("{}…", entry.chars().take(79).collect::<String>())
            } else { entry.clone() };
            format!("CLIP|{} {}", config.icons.clip, display)
        })
        .collect()
}

fn cmd_clip_record(launcher_dir: &Path, config: &Config, text: &str) {
    record_clipboard(launcher_dir, text, config.clipboard.max_entries);
}

// ── Process kill (F) ─────────────────────────────────────────────────────

fn search_processes(query_lower: &str, config: &Config) -> Vec<String> {
    let output = Command::new("ps")
        .args(["-eo", "pid,comm"])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();

    let mut seen: HashSet<String> = HashSet::new();
    let mut results = Vec::new();

    for line in output.lines().skip(1) {
        let line = line.trim();
        let mut parts = line.splitn(2, char::is_whitespace);
        let pid = parts.next().unwrap_or("").trim();
        let comm = parts.next().unwrap_or("").trim();
        let name = comm.rsplit('/').next().unwrap_or(comm);

        if name.to_lowercase().contains(query_lower) && seen.insert(name.to_string()) {
            results.push(format!("KILL|{} {} [{}]", config.icons.kill, name, pid));
        }
        if results.len() >= config.search.max_process_results { break; }
    }
    results
}

// ── Claude Code integration ───────────────────────────────────────────────

fn search_claude(query: &str, config: &Config) -> Option<String> {
    let ql = query.trim().to_lowercase();
    if ql == "claude" || ql.starts_with("claude ") {
        let args = query.trim().get(7..).map(|s| s.trim()).unwrap_or("").to_string();
        let display = if args.is_empty() { "claude".to_string() } else { format!("claude {}", args) };
        return Some(format!("CLAUDE|{} {}", config.icons.claude, display));
    }
    None
}

// ── Alias search ──────────────────────────────────────────────────────────

fn search_aliases(query_lower: &str, config: &Config) -> Vec<String> {
    config
        .aliases
        .iter()
        .filter(|(alias, _)| alias.to_lowercase().contains(query_lower))
        .map(|(_, app_name)| format!("APP|{} {}", app_icon(app_name, &config.app_icons), app_name))
        .collect()
}

// ── Spotlight / file-search backend ──────────────────────────────────────

static SPOTLIGHT_OK: OnceLock<bool> = OnceLock::new();

// ── Icon data (embedded TOML) ─────────────────────────────────────────────

const DEFAULT_APP_ICONS_TOML:  &str = include_str!("../data/app_icons.toml");
const DEFAULT_FILE_ICONS_TOML: &str = include_str!("../data/file_icons.toml");

static APP_ICON_DEFAULTS:  OnceLock<HashMap<String, String>> = OnceLock::new();
static FILE_ICON_DEFAULTS: OnceLock<HashMap<String, String>> = OnceLock::new();

fn default_app_icons() -> &'static HashMap<String, String> {
    APP_ICON_DEFAULTS.get_or_init(|| {
        toml::from_str(DEFAULT_APP_ICONS_TOML).unwrap_or_default()
    })
}

fn default_file_icons() -> &'static HashMap<String, String> {
    FILE_ICON_DEFAULTS.get_or_init(|| {
        toml::from_str(DEFAULT_FILE_ICONS_TOML).unwrap_or_default()
    })
}

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
/// Build and run `find` with per-config prune dirs.
fn find_by_name(home: &str, query: &str, max_results: usize, config: &Config) -> String {
    let prune_names = &config.search.prune_dirs;
    let mut args: Vec<String> = vec![
        home.to_string(),
        "-maxdepth".into(), "6".into(),
        "(".into(),
    ];
    for (i, name) in prune_names.iter().enumerate() {
        if i > 0 { args.push("-o".into()); }
        args.push("-name".into());
        args.push(name.clone());
    }
    args.extend([
        ")".into(), "-prune".into(), "-o".into(),
        "-iname".into(), {
            let escaped = query.replace('\\', "\\\\").replace('*', "\\*").replace('?', "\\?").replace('[', "\\[");
            format!("*{}*", escaped)
        },
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
            // -F: クエリを literal として扱う (regex 解釈しない)。
            //   そうしないと "tree -L 2" のような文字列がほぼヒットしない regex
            //   になり、--max-results 打ち切りが効かず全走査で数秒かかる。
            // --max-results: max_file_results * 4 のバッファで早期打ち切り。
            // -I は外す: gitignored を含めると node_modules / .cache などで桁違いに遅い。
            let cap = (max * 4).to_string();
            Command::new("fd")
                .args(["--base-directory", &home, "-F", "--max-depth", "6", "--max-results", &cap, "-i", query])
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
            find_by_name(&home, query, max, config)
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
            // -F: クエリを literal として扱う (regex 解釈しない)。
            //   そうしないと "tree -L 2" のような文字列がほぼヒットしない regex
            //   になり、--max-results 打ち切りが効かず全走査で数秒かかる。
            // --max-results: max_file_results * 4 のバッファで早期打ち切り。
            // -I は外す: gitignored を含めると node_modules / .cache などで桁違いに遅い。
            let cap = (max * 4).to_string();
            Command::new("fd")
                .args(["--base-directory", &home, "-F", "--max-depth", "6", "--max-results", &cap, "-i", query])
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
            find_by_name(&home, query, max, config)
        }
    };

    let mut results = Vec::new();
    for path_str in raw.lines() {
        if results.len() >= max { break; }
        if path_str.ends_with(".app") || path_str.contains(".app/Contents") { continue; }
        if exclude.iter().any(|p| path_str.contains(p.as_str())) { continue; }
        results.push(format!("FILE|{} {}", file_icon(Path::new(path_str), &config.file_icons), path_str));
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
            let type_str = args.next().unwrap_or_default();
            let name = args.next().unwrap_or_default();
            if !type_str.is_empty() && !name.is_empty() {
                let config = load_config(&dir);
                cmd_record(&dir, &type_str, &name, config.search.frecency_max_age_days);
            }
            return;
        }
        "colors" => {
            let config = load_config(&dir);
            cmd_colors(&config);
            return;
        }
        "web-url" => {
            let config = load_config(&dir);
            println!("{}", config.search.web_search_url);
            return;
        }
        "web-name" => {
            let config = load_config(&dir);
            println!("{}", config.search.web_search_name);
            return;
        }
        "clip-record" => {
            let config = load_config(&dir);
            let text: String = std::iter::once(args.next().unwrap_or_default())
                .chain(args.map(|a| format!(" {}", a)))
                .collect();
            cmd_clip_record(&dir, &config, &text);
            return;
        }
        "fzf-layout" => {
            // Outputs 4 lines: prompt, pointer, border_label, preview_window
            // launcher.sh reads these with sequential `read` calls
            let config = load_config(&dir);
            let l = &config.launcher;
            println!("{}", l.prompt);
            println!("{}", l.pointer);
            println!("{}", l.border_label);
            println!("{}", l.preview_window);
            return;
        }
        "wifi-list" => {
            for line in wifi_list_entries() { println!("{}", line); }
            return;
        }
        "bt-list" => {
            for line in bt_list_entries() { println!("{}", line); }
            return;
        }
        "preview-config" => {
            // Outputs 5 lines: image_timeout, cmd_timeout, max_archive, max_text, max_pdf
            // launcher.sh exports these as env vars consumed by preview.sh
            let config = load_config(&dir);
            let p = &config.preview;
            println!("{}", p.image_timeout);
            println!("{}", p.cmd_timeout);
            println!("{}", p.max_archive_entries);
            println!("{}", p.max_text_lines);
            println!("{}", p.max_pdf_lines);
            return;
        }
        _ => {}
    }

    // Normal search mode: first arg is the query
    let query = first;
    let config = load_config(&dir);
    let stdout = io::stdout();
    let mut out = io::BufWriter::new(stdout.lock());

    // Empty query: clipboard history + frecency-sorted apps + bookmarks + SSH + recent + sys
    if query.is_empty() {
        let now = now_secs();
        let frecency = load_frecency(&frecency_path(&dir));
        for line in list_clipboard_history(&dir, &config)   { let _ = writeln!(out, "{}", line); }
        for line in list_apps_sorted(&frecency, now, &config) { let _ = writeln!(out, "{}", line); }
        for line in list_bookmarks_all(&config)             { let _ = writeln!(out, "{}", line); }
        for line in list_recent(&config)                    { let _ = writeln!(out, "{}", line); }
        for line in ssh_hosts("", &config)                  { let _ = writeln!(out, "{}", line); }
        for line in list_wifi_bt()                          { let _ = writeln!(out, "{}", line); }
        for line in list_sys()                              { let _ = writeln!(out, "{}", line); }
        return;
    }

    let query_lower = query.to_lowercase();
    let mut seen: HashSet<String> = HashSet::new();

    macro_rules! emit {
        ($line:expr) => {{
            let s: String = $line;
            if seen.insert(s.clone()) { let _ = writeln!(out, "{}", s); }
        }};
    }

    // Phase 1: fast results (in-memory / cache)
    if let Some(c) = search_claude(&query, &config)            { emit!(c); }
    if let Some(c) = search_color(&query, &config)             { emit!(c); }
    if let Some(r) = search_unit_convert(&query, &config)      { emit!(r); }
    if let Some(r) = search_base_convert(&query, &config)      { emit!(r); }
    if query.chars().any(|c| c.is_ascii_digit()) {
        if let Some(c) = search_calc(&query, &config)          { emit!(c); }
    }

    for line in search_bookmarks(&query_lower, &config)        { emit!(line); }

    let clip_path = clipboard_history_path(&dir);
    for entry in load_clip_history(&clip_path) {
        if entry.to_lowercase().contains(&query_lower) {
            let display = if entry.chars().count() > 80 {
                format!("{}…", entry.chars().take(79).collect::<String>())
            } else { entry.clone() };
            emit!(format!("CLIP|{} {}", config.icons.clip, display));
        }
    }

    for line in search_aliases(&query_lower, &config)          { emit!(line); }

    let now = now_secs();
    let frecency = load_frecency(&frecency_path(&dir));
    for line in list_apps_sorted(&frecency, now, &config) {
        if let Some(d) = line.split_once('|').map(|(_, d)| d) {
            if d.to_lowercase().contains(&query_lower) { emit!(line); }
        }
    }

    for line in ssh_hosts(&query_lower, &config)               { emit!(line); }
    for line in search_quickadd(&query_lower)                  { emit!(line); }
    for line in search_menu_items(&query_lower)                { emit!(line); }
    for line in search_wifi(&query_lower)                      { emit!(line); }
    for line in search_bluetooth(&query_lower)                 { emit!(line); }
    for line in search_sys(&query_lower)                       { emit!(line.to_string()); }
    if query_lower.len() >= config.search.min_query_for_processes {
        for line in search_processes(&query_lower, &config)    { emit!(line); }
    }

    // CMD と WEB は Phase 2 (file search) より前に出す。
    // file search は数秒かかることがあり、その間 fzf の reload が完了せず
    // 「打ったコマンドを Enter で実行できない」状態になるのを避けるため。
    emit!(format!("CMD|{} > {}", config.icons.cmd, query));
    {
        let full_url = format!("{}{}", config.search.web_search_url, url_encode(&query));
        emit!(format!("WEB:{}|{} {}: {}", full_url, config.icons.web, config.search.web_search_name, query));
    }
    let _ = out.flush();

    // Phase 2: file search (重いので最後)
    // 空白を含むクエリ (例: "git status", "tree -L 2") はターミナルコマンドの
    // 入力中とみなして file search をスキップ。ファイル名検索としても通常マッチしない上、
    // fd の literal 検索でも全走査で数秒かかるため。
    if query.chars().count() >= config.search.min_query_for_files
        && !query.contains(' ')
    {
        for line in search_files(&query, &config) { emit!(line); }
        let _ = out.flush();
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn cfg() -> Config { Config::default() }

    // ── Unit conversion ─────────────────────────────────────────────────

    #[test]
    fn unit_km_to_mi() {
        let r = search_unit_convert("10 km to mi", &cfg()).unwrap();
        assert!(r.contains("6.21"), "got: {r}");
    }

    #[test]
    fn unit_f_to_c() {
        let r = search_unit_convert("100F to C", &cfg()).unwrap();
        assert!(r.contains("37.77") || r.contains("37.78"), "got: {r}");
    }

    #[test]
    fn unit_kg_to_lb() {
        let r = search_unit_convert("5 kg to lb", &cfg()).unwrap();
        assert!(r.contains("11.02"), "got: {r}");
    }

    #[test]
    fn unit_gb_to_mb() {
        let r = search_unit_convert("2 gb to mb", &cfg()).unwrap();
        assert!(r.contains("2048"), "got: {r}");
    }

    #[test]
    fn unit_hour_to_min() {
        let r = search_unit_convert("1.5 h to min", &cfg()).unwrap();
        assert!(r.contains("90"), "got: {r}");
    }

    #[test]
    fn unit_misparse_no_space() {
        assert!(search_unit_convert("100to km", &cfg()).is_none());
    }

    #[test]
    fn unit_digits_in_unit() {
        assert!(search_unit_convert("100 to 200", &cfg()).is_none());
    }

    // ── Base conversion ─────────────────────────────────────────────────

    #[test]
    fn base_hex_literal() {
        let r = search_base_convert("0xFF", &cfg()).unwrap();
        assert!(r.contains("255"), "got: {r}");
        assert!(r.contains("0b11111111"), "got: {r}");
    }

    #[test]
    fn base_bin_literal() {
        let r = search_base_convert("0b1010", &cfg()).unwrap();
        assert!(r.contains("10"), "got: {r}");
        assert!(r.contains("0xa"), "got: {r}");
    }

    #[test]
    fn base_dec_to_hex() {
        let r = search_base_convert("255 in hex", &cfg()).unwrap();
        assert!(r.contains("0xFF") || r.contains("0xff"), "got: {r}");
    }

    #[test]
    fn base_dec_to_bin() {
        let r = search_base_convert("10 to bin", &cfg()).unwrap();
        assert!(r.contains("0b1010"), "got: {r}");
    }

    // ── fmt_num edge cases ───────────────────────────────────────────────

    #[test]
    fn fmt_num_large_float() {
        // Should not overflow i64 cast
        let v = 1e18_f64;
        let s = fmt_num(v);
        assert!(!s.is_empty(), "got empty");
    }

    #[test]
    fn fmt_num_integer() {
        assert_eq!(fmt_num(42.0), "42");
    }

    #[test]
    fn fmt_num_fraction() {
        let s = fmt_num(3.14159);
        assert!(s.starts_with("3.14"), "got: {s}");
    }

    // ── XBEL bookmark parsing ─────────────────────────────────────────

    #[test]
    fn xbel_parses_bookmarks() {
        let xbel = r#"<?xml version="1.0"?>
<xbel>
<bookmark href="https://example.com" id="1">
  <title>Example</title>
</bookmark>
<bookmark href="https://github.com" id="2">
  <title>GitHub</title>
</bookmark>
</xbel>"#;
        let bm = parse_xbel(xbel);
        assert_eq!(bm.len(), 2);
        assert_eq!(bm[0].0, "Example");
        assert_eq!(bm[0].1, "https://example.com");
        assert_eq!(bm[1].0, "GitHub");
    }

    #[test]
    fn xbel_html_entities() {
        // XBEL uses multi-line format: href on bookmark line, title on next line
        let xbel = "<bookmark href=\"https://x.com?a=1&amp;b=2\" id=\"1\">\n  <title>A &amp; B</title>\n</bookmark>";
        let bm = parse_xbel(xbel);
        assert_eq!(bm.len(), 1, "expected 1 bookmark, got {}: {:?}", bm.len(), bm);
        assert_eq!(bm[0].0, "A & B");
        assert_eq!(bm[0].1, "https://x.com?a=1&b=2");
    }

    // ── Frecency score ────────────────────────────────────────────────

    #[test]
    fn frecency_recent_beats_old() {
        let now = 100_000_000u64;
        let recent = frecency_score(5, now - 3600, now);       // 1 hour ago
        let old    = frecency_score(5, now - 90 * 86400, now); // 90 days ago
        assert!(recent > old, "recent={recent} old={old}");
    }

    #[test]
    fn frecency_frequent_beats_rare() {
        let now = 100_000_000u64;
        let ts = now - 86400; // same age: 1 day ago
        let frequent = frecency_score(20, ts, now);
        let rare     = frecency_score(1,  ts, now);
        assert!(frequent > rare, "frequent={frequent} rare={rare}");
    }

    #[test]
    fn frecency_30day_halflife() {
        let base = 100_000_000u64;
        let fresh = frecency_score(1, base, base);                   // age = 0
        let month = frecency_score(1, base - 30 * 86400, base);      // 30 days ago
        // month score should be roughly half of fresh
        let ratio = month / fresh;
        assert!((0.4..=0.6).contains(&ratio), "ratio={ratio}");
    }

    // ── Color detection ───────────────────────────────────────────────

    #[test]
    fn color_hex6() {
        assert!(search_color("#ff6655", &cfg()).is_some());
    }

    #[test]
    fn color_hex3() {
        assert!(search_color("#f65", &cfg()).is_some());
    }

    #[test]
    fn color_rgb() {
        assert!(search_color("rgb(255, 100, 50)", &cfg()).is_some());
    }

    #[test]
    fn color_hsl() {
        assert!(search_color("hsl(200, 80%, 50%)", &cfg()).is_some());
    }

    #[test]
    fn color_invalid() {
        assert!(search_color("not a color", &cfg()).is_none());
        assert!(search_color("#gg0000", &cfg()).is_none());
    }
}
