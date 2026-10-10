import AppKit
import SwiftUI
import GhosttyTerminal
import GhosttyTheme
import HerdCore

enum Theme {
    static let palettes = [("default", "HerdrX Default"), ("herdr", "Follow Herdr"), ("catppuccin", "Catppuccin"), ("tokyo-night", "Tokyo Night"), ("gruvbox", "Gruvbox"), ("one", "One"), ("solarized", "Solarized"), ("kanagawa", "Kanagawa"), ("rose-pine", "Rosé Pine"), ("dracula", "Dracula"), ("nord", "Nord"), ("vesper", "Vesper")]
    static let accents = ["blue", "graphite", "green", "cyan", "purple", "amber", "pink", "red", "orange"]
    static var family: String {
        let name = UserDefaults.standard.string(forKey: "palette") ?? "default"
        return name == "herdr" ? UserDefaults.standard.string(forKey: "resolvedHerdrTheme") ?? "catppuccin" : name
    }
    static func definition(dark: Bool) -> GhosttyThemeDefinition {
        switch family {
        case "tokyo-night": dark ? .tokyoNight_Night : .tokyoNight_Day
        case "gruvbox": dark ? .gruvbox_Dark : .gruvbox_Light
        case "one": dark ? .one_Half_Dark : .one_Half_Light
        case "solarized": dark ? .iTerm2_Solarized_Dark : .iTerm2_Solarized_Light
        case "kanagawa": dark ? .kanagawa_Wave : .kanagawa_Lotus
        case "rose-pine": dark ? .rose_Pine : .rose_Pine_Dawn
        case "dracula": dark ? .dracula : lightCompanion(.dracula, background: "f4f3f7", foreground: "514761")
        case "nord": dark ? .nord : .nord_Light
        case "vesper": dark ? .vesper : lightCompanion(.vesper, background: "faf8f5", foreground: "504b44")
        default: dark ? .catppuccin_Mocha : .catppuccin_Latte
        }
    }
    /// A distinct light companion for upstream themes that only define a dark palette.
    static func lightCompanion(_ theme: GhosttyThemeDefinition, background: String, foreground: String) -> GhosttyThemeDefinition {
        let palette = theme.palette.mapValues { hex -> String in
            let source = color(hex).usingColorSpace(.sRGB)!
            let darkened = NSColor(hue: source.hueComponent, saturation: source.saturationComponent, brightness: min(0.55, source.brightnessComponent), alpha: 1).usingColorSpace(.sRGB)!
            return String(format: "%02x%02x%02x", Int(darkened.redComponent * 255), Int(darkened.greenComponent * 255), Int(darkened.blueComponent * 255))
        }
        return GhosttyThemeDefinition(name: "HerdrX " + theme.name + " Light", background: background, foreground: foreground, cursorColor: foreground, selectionBackground: "ddd9e4", selectionForeground: foreground, palette: palette)
    }
    static func color(_ hex: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
    static func color(_ hex: String) -> NSColor { color(UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0) }
    static func dynamic(_ resolve: @escaping (Bool) -> NSColor) -> NSColor {
        NSColor(name: nil) { resolve($0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua) }
    }
    static func accent(_ name: String) -> NSColor {
        switch name {
        case "graphite": dynamic { color($0 ? 0xa6adc8 : 0x494a50) }
        case "green": dynamic { color($0 ? 0x8bd5a2 : 0x159570) }
        case "cyan": dynamic { color($0 ? 0x7dc4e4 : 0x1d85c0) }
        case "purple": dynamic { color($0 ? 0xc6a0f6 : 0x6956a6) }
        case "amber": dynamic { color($0 ? 0xeed49f : 0xb08009) }
        case "pink": dynamic { color($0 ? 0xf5bde6 : 0xd5537f) }
        case "red": dynamic { color($0 ? 0xed8796 : 0xcc3a52) }
        case "orange": dynamic { color($0 ? 0xf5a97f : 0xdf5619) }
        default: dynamic { color($0 ? 0x82aaff : 0x2463eb) }
        }
    }
    static var accent: NSColor {
        let choice = UserDefaults.standard.string(forKey: "accent") ?? "theme"
        guard choice == "theme" else { return accent(choice) }
        switch family {
        case "gruvbox", "vesper": return accent("amber")
        case "rose-pine": return accent("pink")
        case "dracula": return accent("purple")
        case "nord": return accent("cyan")
        default: return accent("blue")
        }
    }
    static var content: NSColor { dynamic { color(definition(dark: $0).background) } }
    static var foreground: NSColor { dynamic { color(definition(dark: $0).foreground) } }
    static var secondary: NSColor { dynamic { dark in
        let definition = definition(dark: dark)
        return color(definition.foreground).blended(withFraction: dark ? 0.22 : 0.20, of: color(definition.background))!
    } }
    static var chrome: NSColor { dynamic { dark in
        color(definition(dark: dark).background).blended(withFraction: dark ? 0.06 : 0.025, of: color(definition(dark: dark).foreground))!
    } }
    static var separator: NSColor { foreground.withAlphaComponent(0.16) }
    static var success: NSColor { dynamic { color($0 ? 0xa6e3a1 : 0x287b48) } }
    static var warning: NSColor { dynamic { color($0 ? 0xf9e2af : 0x986500) } }
    static var failure: NSColor { dynamic { color($0 ? 0xf38ba8 : 0xc43b4b) } }
    static var defaultFont: String { NSFont(name: "Maple Mono CN", size: 13.5) != nil ? "Maple Mono CN" : "SF Mono" }
    @MainActor static func apply() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "palette") == "herdr" {
            let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/herdr/config.toml")
            let text = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
            defaults.set(ThemePreference.herdrFamily(in: text), forKey: "resolvedHerdrTheme")
        }
        func configuration(_ theme: GhosttyThemeDefinition) -> TerminalConfiguration {
            TerminalConfiguration {
                $0.withBackground(theme.background); $0.withForeground(theme.foreground)
                if let color = theme.cursorColor { $0.withCustom("cursor-color", color) }
                if let color = theme.selectionBackground { $0.withSelectionBackground(color) }
                if let color = theme.selectionForeground { $0.withSelectionForeground(color) }
                for index in theme.palette.keys.sorted() { $0.withPalette(index, color: theme.palette[index]!) }
            }
        }
        Terminal.controller.setTheme(TerminalTheme(light: configuration(definition(dark: false)), dark: configuration(definition(dark: true))))
        Terminal.controller.setTerminalConfiguration(TerminalConfiguration {
            let family = defaults.string(forKey: "fontFamily") ?? defaultFont
            $0.withFontFamily(family)
            $0.withFontSize(Float(defaults.double(forKey: "fontSize") > 0 ? defaults.double(forKey: "fontSize") : 13.5))
            if family == "SF Mono" { $0.withCustom("font-style", defaults.string(forKey: "fontWeight") ?? "Regular") }
            $0.withFontThicken(!(defaults.object(forKey: "thinStrokes") as? Bool ?? true))
            $0.withCustom("adjust-cell-height", "\(Int(max(0, defaults.double(forKey: "lineSpacing") - 1) * 100))%")
            $0.withCustom("copy-on-select", (defaults.object(forKey: "copyOnSelect") as? Bool ?? true) ? "clipboard" : "false")
            $0.withCustom("macos-option-as-alt", "true")
        })
    }
}
