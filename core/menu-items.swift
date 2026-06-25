// menu-items: list / click menu bar items of the previously-frontmost app.
//
// Subcommands:
//   list           — enumerate every enabled leaf menu item of the previously-
//                    frontmost app. Format: "MENU:<base64-path>|<icon> <Display>"
//                    Side effect: writes the target PID to /tmp/launcher_menu_target_pid
//                    so that `click` can address the same app even after Ghostty
//                    Quick Terminal regains focus.
//   click <b64>    — read the stored PID, raise that app, and AXPress the leaf.
//
// Build: swiftc -O menu-items.swift -o menu-items
// AX permission: granted to the *host terminal* (Ghostty / Wezterm), not this
// binary. If missing, prompts on first call and exits non-zero.

import Foundation
import Cocoa
import ApplicationServices

let SEP = "\u{001F}"                // Unit Separator — never appears in menu titles
let PID_FILE = "/tmp/launcher_menu_target_pid"
let ICON = "\u{f035c}"              // 󰍜 nf-md-menu

// ── AX helpers ─────────────────────────────────────────────────────────────

func axAttr(_ el: AXUIElement, _ key: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, key as CFString, &v) == .success ? v : nil
}

func axString(_ el: AXUIElement, _ key: String) -> String? {
    axAttr(el, key) as? String
}

func axBool(_ el: AXUIElement, _ key: String) -> Bool? {
    axAttr(el, key) as? Bool
}

func axChildren(_ el: AXUIElement) -> [AXUIElement] {
    (axAttr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func axRole(_ el: AXUIElement) -> String {
    axString(el, kAXRoleAttribute) ?? ""
}

// ── Shell helper ───────────────────────────────────────────────────────────

func shellOutput(_ path: String, _ args: [String]) -> String {
    let task = Process()
    task.launchPath = path
    task.arguments = args
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    do { try task.run() } catch { return "" }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

// ── Previous-frontmost-app discovery ───────────────────────────────────────
//
// `lsappinfo visibleProcessList` returns Application Serial Numbers in
// front-to-back z-order. Format:
//   ASN:0x0-0x22022-"Zen": ASN:0x0-0x1d01d-"Ghostty": ASN:0x0-0x10010-"Finder":
// Tokens are space-separated; `lsappinfo info` accepts just the `ASN:0x0-0xHEX`
// prefix. The first token is the current frontmost (our terminal host); the
// next token whose PID isn't in our process tree is the user's target.

/// Strip the trailing `-"Name":` suffix → returns `ASN:0x0-0xHEX`.
func asnPrefix(_ token: String) -> String? {
    guard token.hasPrefix("ASN:") else { return nil }
    if let dashQuote = token.range(of: "-\"") {
        return String(token[..<dashQuote.lowerBound])
    }
    return token.hasSuffix(":") ? String(token.dropLast()) : token
}

func parseASNPrefixes(_ s: String) -> [String] {
    s.split(separator: " ", omittingEmptySubsequences: true)
        .compactMap { asnPrefix(String($0)) }
}

func pidForASN(_ asn: String) -> pid_t? {
    // `lsappinfo info -only pid ASN:0x0-0xHEX` → `"pid"=12345`
    let out = shellOutput("/usr/bin/lsappinfo", ["info", "-only", "pid", asn])
    guard let eq = out.firstIndex(of: "=") else { return nil }
    let raw = out[out.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines)
    return Int32(raw)
}

func ancestorPIDs(of pid: pid_t) -> Set<pid_t> {
    var result: Set<pid_t> = [pid]
    var cur = pid
    while cur > 1 {
        let ppidStr = shellOutput("/bin/ps", ["-o", "ppid=", "-p", "\(cur)"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let next = Int32(ppidStr), next > 1, !result.contains(next) else { break }
        result.insert(next)
        cur = next
    }
    return result
}

func previousFrontApp() -> pid_t? {
    let myPID = getpid()
    let parentPID = getppid()
    let kin = ancestorPIDs(of: parentPID).union([myPID, parentPID])
    let listOut = shellOutput("/usr/bin/lsappinfo", ["visibleProcessList"])
    for asn in parseASNPrefixes(listOut) {
        guard let pid = pidForASN(asn) else { continue }
        if kin.contains(pid) { continue }
        return pid
    }
    return nil
}

// ── Menu walking ───────────────────────────────────────────────────────────

struct Leaf {
    let path: [String]
}

func walkMenu(_ menu: AXUIElement, prefix: [String], out: inout [Leaf]) {
    for item in axChildren(menu) {
        guard let title = axString(item, kAXTitleAttribute), !title.isEmpty else { continue }
        let enabled = axBool(item, kAXEnabledAttribute) ?? true
        let newPath = prefix + [title]
        // A submenu shows up as a child AXMenu of this item.
        if let sub = axChildren(item).first(where: { axRole($0) == "AXMenu" }) {
            walkMenu(sub, prefix: newPath, out: &out)
        } else if enabled {
            out.append(Leaf(path: newPath))
        }
    }
}

func enumerateMenuBar(pid: pid_t) -> [Leaf] {
    let app = AXUIElementCreateApplication(pid)
    guard let menuBarRaw = axAttr(app, kAXMenuBarAttribute) else { return [] }
    let menuBar = menuBarRaw as! AXUIElement
    let topItems = axChildren(menuBar)
    var result: [Leaf] = []
    // Drop the Apple menu (always first). It's app-agnostic and clutters the list.
    for top in topItems.dropFirst() {
        guard let title = axString(top, kAXTitleAttribute), !title.isEmpty else { continue }
        if let sub = axChildren(top).first(where: { axRole($0) == "AXMenu" }) {
            walkMenu(sub, prefix: [title], out: &result)
        }
    }
    return result
}

// ── Permission ─────────────────────────────────────────────────────────────

func ensurePermissionOrExit() {
    if AXIsProcessTrusted() { return }
    // Trigger the system prompt for the host terminal so the user sees a banner.
    let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(opts)
    let msg = "menu-items: Accessibility permission required. Grant access to the host terminal (Ghostty / Wezterm) in System Settings → Privacy & Security → Accessibility.\n"
    FileHandle.standardError.write(msg.data(using: .utf8)!)
    exit(2)
}

// ── Commands ───────────────────────────────────────────────────────────────

func cmdList() {
    ensurePermissionOrExit()
    guard let pid = previousFrontApp() else {
        FileHandle.standardError.write("menu-items: could not determine previous frontmost app\n".data(using: .utf8)!)
        exit(3)
    }
    try? "\(pid)".write(toFile: PID_FILE, atomically: true, encoding: .utf8)

    let leaves = enumerateMenuBar(pid: pid)
    var out = ""
    for leaf in leaves {
        let joined = leaf.path.joined(separator: SEP)
        let b64 = Data(joined.utf8).base64EncodedString()
        let display = leaf.path.joined(separator: " ▸ ")
        out += "MENU:\(b64)|\(ICON) \(display)\n"
    }
    FileHandle.standardOutput.write(out.data(using: .utf8)!)
}

func cmdClick(_ b64: String) {
    ensurePermissionOrExit()
    guard let pidRaw = try? String(contentsOfFile: PID_FILE, encoding: .utf8),
          let pid = Int32(pidRaw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        FileHandle.standardError.write("menu-items: no target PID stored — run `list` first\n".data(using: .utf8)!)
        exit(4)
    }
    guard let data = Data(base64Encoded: b64),
          let pathStr = String(data: data, encoding: .utf8) else {
        FileHandle.standardError.write("menu-items: malformed path encoding\n".data(using: .utf8)!)
        exit(5)
    }
    let path = pathStr.components(separatedBy: SEP)
    guard !path.isEmpty else { exit(6) }

    // Disabled items in the target app's "non-frontmost" state need the app
    // raised before AXPress will dispatch the action reliably.
    if let running = NSRunningApplication(processIdentifier: pid) {
        running.activate(options: [])
    }

    let app = AXUIElementCreateApplication(pid)
    guard let menuBarRaw = axAttr(app, kAXMenuBarAttribute) else { exit(7) }
    let menuBar = menuBarRaw as! AXUIElement

    guard let top = axChildren(menuBar).first(where: {
        axString($0, kAXTitleAttribute) == path[0]
    }) else { exit(8) }

    var cur = top
    for i in 1..<path.count {
        guard let sub = axChildren(cur).first(where: { axRole($0) == "AXMenu" }) else { exit(9) }
        guard let next = axChildren(sub).first(where: {
            axString($0, kAXTitleAttribute) == path[i]
        }) else { exit(10) }
        cur = next
    }

    let err = AXUIElementPerformAction(cur, kAXPressAction as CFString)
    if err != .success {
        FileHandle.standardError.write("menu-items: AXPress failed: \(err.rawValue)\n".data(using: .utf8)!)
        exit(11)
    }

    try? FileManager.default.removeItem(atPath: PID_FILE)
}

// ── Main ───────────────────────────────────────────────────────────────────

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("Usage: menu-items {list|click <base64>}\n".data(using: .utf8)!)
    exit(1)
}

switch args[1] {
case "list":
    cmdList()
case "click":
    guard args.count >= 3 else {
        FileHandle.standardError.write("Usage: menu-items click <base64>\n".data(using: .utf8)!)
        exit(1)
    }
    cmdClick(args[2])
default:
    FileHandle.standardError.write("Usage: menu-items {list|click <base64>}\n".data(using: .utf8)!)
    exit(1)
}
