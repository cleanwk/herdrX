import AppKit
import SwiftUI
import GhosttyTerminal
import GhosttyTheme

enum Theme {
    static var family: String {
        let name = UserDefaults.standard.string(forKey: "palette") ?? "default"
        return name == "herdr" ? UserDefaults.standard.string(forKey: "resolvedHerdrTheme") ?? "default" : name
    }
    static func color(_ hex: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
    static var accent: NSColor {
        switch UserDefaults.standard.string(forKey: "accent") ?? "theme" {
        case "graphite": return .systemGray; case "green": return .systemGreen; case "blue": return .systemBlue; case "purple": return .systemPurple
        case "amber": return .systemYellow; case "pink": return .systemPink; case "red": return .systemRed; case "orange": return .systemOrange
        default: return family == "catppuccin" ? color(0x8b6cef) : .controlAccentColor
        }
    }
    static var content: NSColor {
        NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if family == "catppuccin" { return color(dark ? 0x1e1e2e : 0xeff1f5) }
            if dark, family == "dracula" { return color(0x282a36) }
            if dark, family == "nord" { return color(0x2e3440) }
            return color(dark ? 0x181818 : 0xf6f6f6)
        }
    }
    @MainActor static func apply() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "palette") == "herdr" {
            let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/herdr/config.toml")
            let text = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
            var inTheme = false, name = "catppuccin"
            for raw in text.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("[") { inTheme = line == "[theme]" }
                if inTheme, line.hasPrefix("name"), let match = line.range(of: #"^name\s*=\s*["']([^"']+)["']"#, options: .regularExpression) {
                    name = String(line[match]).split(separator: "=", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) } ?? "default"
                }
            }
            defaults.set(["catppuccin", "dracula", "nord"].contains(name) ? name : "default", forKey: "resolvedHerdrTheme")
        }
        let cat = family == "catppuccin"
        var terminalTheme = TerminalTheme(light: TerminalConfiguration {
            $0.withBackground(cat ? "eff1f5" : "ffffff"); $0.withForeground(cat ? "4c4f69" : "242424")
            $0.withSelectionBackground(cat ? "ccd0da" : "c6dafb")
        }, dark: TerminalConfiguration {
            $0.withBackground(cat ? "1e1e2e" : "101012"); $0.withForeground(cat ? "cdd6f4" : "e2e2e2")
            $0.withSelectionBackground(cat ? "45475a" : "30466c")
        })
        func configuration(_ theme: GhosttyThemeDefinition) -> TerminalConfiguration {
            TerminalConfiguration {
                $0.withBackground(theme.background); $0.withForeground(theme.foreground)
                if let color = theme.cursorColor { $0.withCustom("cursor-color", color) }
                if let color = theme.selectionBackground { $0.withSelectionBackground(color) }
                if let color = theme.selectionForeground { $0.withSelectionForeground(color) }
                for index in theme.palette.keys.sorted() { $0.withPalette(index, color: theme.palette[index]!) }
            }
        }
        if cat { terminalTheme = TerminalTheme(light: configuration(.catppuccin_Latte), dark: configuration(.catppuccin_Mocha)) }
        if family == "dracula" { terminalTheme = TerminalTheme(light: .alabaster, dark: configuration(.dracula)) }
        if family == "nord" { terminalTheme = TerminalTheme(light: .alabaster, dark: configuration(.nord)) }
        Terminal.controller.setTheme(terminalTheme)
        Terminal.controller.setTerminalConfiguration(TerminalConfiguration {
            $0.withFontFamily(defaults.string(forKey: "fontFamily") ?? "SF Mono")
            $0.withFontSize(Float(defaults.double(forKey: "fontSize") > 0 ? defaults.double(forKey: "fontSize") : 13))
            if (defaults.string(forKey: "fontFamily") ?? "SF Mono") == "SF Mono" { $0.withCustom("font-style", defaults.string(forKey: "fontWeight") ?? "Regular") }
            $0.withFontThicken(!defaults.bool(forKey: "thinStrokes"))
            $0.withCustom("adjust-cell-height", "\(Int(max(0, defaults.double(forKey: "lineSpacing") - 1) * 100))%")
            $0.withCustom("copy-on-select", defaults.bool(forKey: "copyOnSelect") ? "clipboard" : "false")
            $0.withCustom("macos-option-as-alt", "true")
        })
    }
}
