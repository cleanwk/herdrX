import AppKit

/// UI text roles are independent of terminal ANSI colors. All authored text is
/// checked against the surface, tab chrome, hover, and strongest selection fill.
struct ThemeColors {
    let background: NSColor
    let chrome: NSColor
    let selection: NSColor
    let foreground: NSColor
    let secondary: NSColor
    let accent: NSColor
    let surfaces: [NSColor]

    init(background: NSColor, foreground: NSColor, accent: NSColor, dark: Bool) {
        self.background = background
        chrome = Self.mix(background, foreground, dark ? 0.06 : 0.025)
        selection = accent
        surfaces = [background, chrome, Self.mix(background, foreground, 0.05),
                    Self.mix(background, accent, dark ? 0.30 : 0.25),
                    Self.mix(chrome, accent, dark ? 0.20 : 0.18)]
        self.foreground = Self.readable(foreground, on: surfaces)
        secondary = Self.readable(Self.mix(foreground, background, 0.20), on: surfaces)
        self.accent = Self.readable(accent, on: surfaces)
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
