import Foundation

public struct KeyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1), shift = Self(rawValue: 2), option = Self(rawValue: 4), control = Self(rawValue: 8)
}
public enum WorkbenchShortcut {
    public static func action(_ key: String, modifiers: KeyModifiers) -> String? {
        let key = key.lowercased()
        if modifiers == .command {
            if let digit = Int(key), (1...9).contains(digit) { return "tab" + key }
            return ["t": "terminal", "w": "close", "d": "splitRight", "b": "sidebar", "k": "search"][key]
        }
        if modifiers == [.command, .shift] { return ["n": "space", "w": "closePane", "d": "splitDown", "j": "attention", "r": "repair", "[": "previous", "{": "previous", "]": "next", "}": "next", "\r": "zoom"][key] }
        if modifiers == [.command, .option] { return ["w": "closeTab", "\u{f702}": "left", "\u{f703}": "right", "\u{f700}": "up", "\u{f701}": "down"][key] }
        if modifiers == [.command, .control] { return ["\u{f702}": "resizeLeft", "\u{f703}": "resizeRight", "\u{f700}": "resizeUp", "\u{f701}": "resizeDown"][key] }
        return nil
    }
}
