import Foundation

public enum ThemePreference {
    /// Herdr theme names vary in separators and may contain a light/dark variant.
    public static func family(_ name: String) -> String {
        let compact = name.lowercased().filter { $0.isLetter || $0.isNumber }
        let families = [("catppuccin", "catppuccin"), ("tokyonight", "tokyo-night"), ("gruvbox", "gruvbox"), ("one", "one"), ("solarized", "solarized"), ("kanagawa", "kanagawa"), ("rosepine", "rose-pine"), ("dracula", "dracula"), ("nord", "nord"), ("vesper", "vesper")]
        return families.first { compact.hasPrefix($0.0) }?.1 ?? "catppuccin"
    }
    public static func herdrFamily(in text: String) -> String {
        var inTheme = false
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { inTheme = line.split(separator: "#", maxSplits: 1)[0].trimmingCharacters(in: .whitespaces) == "[theme]" }
            guard inTheme, let range = line.range(of: #"^name\s*=\s*[\"']([^\"']+)[\"']"#, options: .regularExpression) else { continue }
            let value = line[range].split(separator: "=", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return family(value)
        }
        return "catppuccin"
    }
}
