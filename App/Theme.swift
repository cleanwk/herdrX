import AppKit
import SwiftUI
import GhosttyTerminal
import GhosttyTheme
import HerdCore

enum Theme {
    static let palettes = [("default", "HerdrX Default"), ("herdr", "Local Herdr theme"), ("catppuccin", "Catppuccin"), ("tokyo-night", "Tokyo Night"), ("gruvbox", "Gruvbox"), ("one", "One"), ("solarized", "Solarized"), ("kanagawa", "Kanagawa"), ("rose-pine", "Rosé Pine"), ("dracula", "Dracula"), ("nord", "Nord"), ("vesper", "Vesper")]
    static let accents = ["blue", "graphite", "green", "cyan", "purple", "amber", "pink", "red", "orange"]
    static var family: String {
        let name = UserDefaults.standard.string(forKey: "palette") ?? "default"
        return name == "herdr" ? UserDefaults.standard.string(forKey: "resolvedHerdrTheme") ?? "catppuccin" : name
    }
    static func definition(dark: Bool) -> GhosttyThemeDefinition {
        definition(family: family, dark: dark)
    }
    private static func definition(family: String, dark: Bool) -> GhosttyThemeDefinition {
        switch family {
        case "tokyo-night": dark ? .tokyoNight_Night : tokyoDay
        case "gruvbox": dark ? .gruvbox_Dark : lightBlack(.gruvbox_Light)
        case "one": dark ? .one_Half_Dark : .one_Half_Light
        case "solarized": dark ? .iTerm2_Solarized_Dark : .iTerm2_Solarized_Light
        case "kanagawa": dark ? .kanagawa_Wave : .kanagawa_Lotus
        case "rose-pine": dark ? .rose_Pine : lightBlack(.rose_Pine_Dawn)
        case "dracula": dark ? .dracula : lightCompanion(.dracula, background: "f4f3f7", foreground: "514761")
        case "nord": dark ? .nord : .nord_Light
        case "vesper": dark ? .vesper : lightCompanion(.vesper, background: "faf8f5", foreground: "504b44")
        default: dark ? .catppuccin_Mocha : .catppuccin_Latte
        }
    }
    /// Some light presets put an almost-white color in ANSI black. Programs
    /// using black text on pale diff backgrounds need an actual dark slot 0.
    static func lightBlack(_ source: GhosttyThemeDefinition) -> GhosttyThemeDefinition {
        var palette = source.palette; palette[0] = source.foreground
        return GhosttyThemeDefinition(name: "HerdrX " + source.name, background: source.background,
            foreground: source.foreground, cursorColor: source.cursorColor, cursorText: source.cursorText,
            selectionBackground: source.selectionBackground, selectionForeground: source.selectionForeground, palette: palette)
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
    // Tokyo Day's upstream default foreground is blue. Keep its ANSI palette,
    // but use a slate default for ordinary prose, as in the ACCM reference.
    static var tokyoDay: GhosttyThemeDefinition {
        let source = GhosttyThemeDefinition.tokyoNight_Day
        var palette = source.palette
        // Upstream slot 0 is almost white in Day, hiding black text on diff fills.
        palette[0] = "4c5269"
        palette[8] = "6b7089"
        return GhosttyThemeDefinition(name: "HerdrX Tokyo Night Day", background: source.background,
            foreground: "4c5269", cursorColor: "4c5269", cursorText: source.background,
            selectionBackground: source.selectionBackground, selectionForeground: "4c5269", palette: palette)
    }
    static var accentName: String { accentName(family: family) }
    private static func accentName(family: String) -> String {
        let choice = UserDefaults.standard.string(forKey: "accent") ?? "theme"
        guard choice == "theme" else { return choice }
        switch family {
        case "gruvbox", "vesper": return "amber"
        case "rose-pine": return "pink"
        case "dracula": return "purple"
        case "nord": return "cyan"
        default: return "blue"
        }
    }
    private struct RoleKey: Equatable { let family: String; let accent: String }
    private static let roleLock = NSLock()
    private static var roleKey: RoleKey?
    private static var roleCache: [Bool: ThemeColors] = [:]

    static func roles(dark: Bool) -> ThemeColors {
        let family = family
        let key = RoleKey(family: family, accent: accentName(family: family))
        // Dynamic NSColors can resolve many times per draw. Retain only the two
        // appearances for the current preferences, and check the key on every
        // read so Follow Herdr and accent changes never require manual invalidation.
        roleLock.lock(); defer { roleLock.unlock() }
        if roleKey != key { roleKey = key; roleCache.removeAll(keepingCapacity: true) }
        if let cached = roleCache[dark] { return cached }
        let colors = makeRoles(family: family, accent: key.accent, dark: dark)
        roleCache[dark] = colors
        return colors
    }
    private static func makeRoles(family: String, accent name: String, dark: Bool) -> ThemeColors {
        let definition = definition(family: family, dark: dark)
        // Explicit navigation roles: a palette may use a chromatic terminal
        // default without turning every task name and toolbar label that color.
        let text: String
        switch family {
        case "tokyo-night": text = dark ? "c0caf5" : "4c5269"
        case "gruvbox": text = dark ? "ebdbb2" : "3c3836"
        case "one": text = dark ? "dcdfe4" : "383a42"
        case "solarized": text = dark ? "93a1a1" : "586e75"
        case "kanagawa": text = dark ? "dcd7ba" : "545464"
        case "rose-pine": text = dark ? "e0def4" : "575279"
        case "dracula": text = dark ? "f8f8f2" : "514761"
        case "nord": text = dark ? "d8dee9" : "2e3440"
        case "vesper": text = dark ? "ffffff" : "504b44"
        default: text = dark ? "cdd6f4" : "4c4f69"
        }
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var selectedAccent = NSColor.black
        appearance.performAsCurrentDrawingAppearance { selectedAccent = accent(name).usingColorSpace(.sRGB)! }
        let catppuccin = !["tokyo-night", "gruvbox", "one", "solarized", "kanagawa", "rose-pine", "dracula", "nord", "vesper"].contains(family)
        return ThemeColors(background: color(definition.background), foreground: color(text), accent: selectedAccent, dark: dark,
            chrome: catppuccin ? color(dark ? 0x181825 : 0xe6e9ef) : nil,
            secondary: catppuccin ? color(dark ? 0xa6adc8 : 0x676b80) : nil,
            decoration: catppuccin ? color(dark ? 0x6c7086 : 0x8c8fa1) : nil)
    }
    static var content: NSColor { dynamic { roles(dark: $0).background } }
    static var foreground: NSColor { dynamic { roles(dark: $0).foreground } }
    static var secondary: NSColor { dynamic { roles(dark: $0).secondary } }
    static var chrome: NSColor { dynamic { roles(dark: $0).chrome } }
    static var selectedText: NSColor { dynamic { roles(dark: $0).selectedText } }
    static var selectedSecondary: NSColor { dynamic { roles(dark: $0).selectedSecondary } }
    static var decoration: NSColor { dynamic { roles(dark: $0).decoration } }
    static var hover: NSColor { dynamic { roles(dark: $0).hover } }
    static var accentStroke: NSColor { dynamic { roles(dark: $0).accentStroke } }
    static var accent: NSColor { dynamic { roles(dark: $0).accentText } }
    static var accentWash: NSColor { dynamic { roles(dark: $0).accentWash } }
    static var accentStrongWash: NSColor { dynamic { roles(dark: $0).accentStrongWash } }
    static var tabWash: NSColor { dynamic { roles(dark: $0).tabWash } }
    static var accentWashBorder: NSColor { dynamic { roles(dark: $0).accentWashBorder } }
    static var onAccent: NSColor { dynamic { roles(dark: $0).onAccent } }
    static func selectedState(_ color: NSColor) -> NSColor { dynamic { dark in
        var resolved = color
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance { resolved = color.usingColorSpace(.sRGB)! }
        return ThemeColors.readable(resolved, on: roles(dark: dark).selectedSurfaces)
    } }
    static var separator: NSColor { foreground.withAlphaComponent(0.16) }
    static func stateColor(light: UInt32, dark: UInt32) -> NSColor { dynamic {
        ThemeColors.readable(color($0 ? dark : light), on: roles(dark: $0).surfaces)
    } }
    static var working: NSColor { stateColor(light: 0x2463eb, dark: 0x82aaff) }
    static var success: NSColor { stateColor(light: 0x287b48, dark: 0xa6e3a1) }
    static var warning: NSColor { stateColor(light: 0x986500, dark: 0xf9e2af) }
    static var failure: NSColor { stateColor(light: 0xc43b4b, dark: 0xf38ba8) }
    static var defaultFont: String { NSFont(name: "Maple Mono CN", size: 13.5) != nil ? "Maple Mono CN" : "SF Mono" }
    @MainActor static func apply() {
        NotificationCenter.default.post(name: SelectionTerminalView.configurationWillChange, object: nil)
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
                if let color = theme.cursorText { $0.withCustom("cursor-text", color) }
                $0.withMinimumContrast(1)
                $0.withCustom("faint-opacity", "0.65")
                if let color = theme.selectionBackground { $0.withSelectionBackground(color) }
                if let color = theme.selectionForeground { $0.withSelectionForeground(color) }
                for index in theme.palette.keys.sorted() {
                    // An ANSI slot may be foreground, background or inverted.
                    // Preserve palette semantics instead of darkening both uses.
                    $0.withPalette(index, color: theme.palette[index]!)
                }
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
            $0.withCustom("copy-on-select", "false")
            $0.withCustom("selection-clear-on-copy", "true")
            $0.withCustom("mouse-shift-capture", "never")
            $0.withCustom("mouse-reporting", (defaults.object(forKey: "disableMouseReporting") as? Bool ?? true) ? "false" : "true")
            $0.withCustom("macos-option-as-alt", "true")
        })
    }
}
