import AppKit

/// Text is checked against its actual surfaces; an accent cannot recolor metadata.
struct ThemeColors {
    let background: NSColor
    let chrome: NSColor
    let hover: NSColor
    let foreground: NSColor
    let secondary: NSColor
    let decoration: NSColor
    let selectedText: NSColor
    let selectedSecondary: NSColor
    let accentStroke: NSColor
    let accentText: NSColor
    let accentWash: NSColor
    let accentStrongWash: NSColor
    let tabInactiveWash: NSColor
    let tabHoverWash: NSColor
    let tabText: NSColor
    let tabWash: NSColor
    let accentWashBorder: NSColor
    let onAccent: NSColor
    let surfaces: [NSColor]
    let selectedSurfaces: [NSColor]

    init(background: NSColor, foreground: NSColor, accent: NSColor, dark: Bool,
         chrome: NSColor? = nil, secondary: NSColor? = nil, decoration: NSColor? = nil) {
        self.background = background
        self.chrome = chrome ?? Self.mix(background, foreground, dark ? 0.06 : 0.045)
        hover = Self.mix(background, foreground, 0.04)
        surfaces = [background, self.chrome, hover]
        self.foreground = Self.readable(foreground, on: surfaces)
        self.secondary = Self.readable(secondary ?? Self.mix(foreground, background, 0.28), on: surfaces)
        self.decoration = decoration ?? Self.mix(foreground, background, 0.50)
        accentStroke = accent
        accentWash = Self.mix(background, accent, dark ? 0.14 : 0.10)
        accentStrongWash = Self.mix(background, accent, dark ? 0.19 : 0.14)
        // Give every tab a visible surface, then layer selection over that base.
        tabInactiveWash = Self.mix(self.chrome, self.foreground, dark ? 0.10 : 0.08)
        tabHoverWash = Self.mix(self.chrome, self.foreground, dark ? 0.14 : 0.12)
        tabText = Self.readable(self.secondary, on: [tabInactiveWash, tabHoverWash])
        tabWash = Self.mix(tabInactiveWash, accent, dark ? 0.22 : 0.16)
        accentWashBorder = accent.withAlphaComponent(0.24)
        selectedSurfaces = [accentWash, accentStrongWash, tabWash]
        selectedText = Self.readable(self.foreground, on: selectedSurfaces)
        selectedSecondary = Self.readable(self.secondary, on: selectedSurfaces)
        accentText = Self.readable(accent, on: surfaces)
        onAccent = Self.contrast(.white, accent) >= Self.contrast(.black, accent) ? .white : .black
    }
    static func mix(_ a: NSColor, _ b: NSColor, _ fraction: CGFloat) -> NSColor {
        let a = a.usingColorSpace(.sRGB)!, b = b.usingColorSpace(.sRGB)!
        return NSColor(srgbRed: a.redComponent * (1 - fraction) + b.redComponent * fraction,
                       green: a.greenComponent * (1 - fraction) + b.greenComponent * fraction,
                       blue: a.blueComponent * (1 - fraction) + b.blueComponent * fraction, alpha: 1)
    }
    static func luminance(_ color: NSColor) -> CGFloat {
        let c = color.usingColorSpace(.sRGB)!
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
    }
    static func contrast(_ a: NSColor, _ b: NSColor) -> CGFloat {
        let a = luminance(a), b = luminance(b)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
    static func readable(_ color: NSColor, on surfaces: [NSColor]) -> NSColor {
        func minimum(_ c: NSColor) -> CGFloat { surfaces.map { contrast(c, $0) }.min() ?? 21 }
        guard minimum(color) < 4.5 else { return color }
        let endpoint: NSColor = minimum(.black) > minimum(.white) ? .black : .white
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if minimum(mix(color, endpoint, mid)) < 4.5 { low = mid } else { high = mid }
        }
        return mix(color, endpoint, high)
    }
}
