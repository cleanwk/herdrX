import Foundation

/// Projects only explicit protocol fields. It never infers a task from terminal contents.
public enum DisplayTitle {
    private static let knownTools = ["codex", "claude", "gemini", "opencode", "kimi", "grok", "cursor", "copilot", "pi", "omp"]
    // Compiling a pattern for every title is much more expensive than matching
    // against a cached expression.
    private static let genericTitle = try! NSRegularExpression(pattern: #"^(tab|pane|shell|terminal|agent)[ -]?[0-9]*$"#)
    private static let generatedID = try! NSRegularExpression(pattern: #"^[a-z]+-[0-9a-f]{6,}$"#)
    private static let userHost = try! NSRegularExpression(pattern: #"^[^\s@:]+@[^\s:]+$"#)

    public static func clean(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        // Most labels are already trimmed, single-space-separated text. Return
        // that value without allocating the split/join result.
        var lastWasWhitespace = true
        var normalized = true
        for scalar in value.unicodeScalars {
            if scalar.properties.isWhitespace {
                if lastWasWhitespace || scalar != " " { normalized = false; break }
                lastWasWhitespace = true
            } else {
                lastWasWhitespace = false
            }
        }
        if lastWasWhitespace { normalized = false }
        if normalized { return value }
        let text = value.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        return text.isEmpty ? nil : text
    }
    private static func isToolInvocation(_ lower: String, tool: String?) -> Bool {
        if let tool {
            let name = tool.lowercased()
            if lower == name || lower.hasPrefix(name + " ") || lower.hasPrefix("exec " + name) { return true }
        }
        return knownTools.contains { lower == $0 || lower.hasPrefix($0 + " ") || lower.hasPrefix("exec " + $0) }
    }
    private static func isToolName(_ value: String, tool: String?) -> Bool {
        if let tool, value == tool.lowercased() { return true }
        return knownTools.contains(value)
    }
    private static func matches(_ expression: NSRegularExpression, _ value: String) -> Bool {
        expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }
    public static func meaningful(_ value: String?, tool: String?) -> String? {
        guard let text = clean(value) else { return nil }
        let lower = text.lowercased()
        if Int(lower) != nil { return nil }
        if isToolInvocation(lower, tool: tool) { return nil }
        if matches(genericTitle, lower) { return nil }
        if matches(generatedID, lower) { return nil }
        return text
    }
    public static func pane(_ pane: Item, tab: Item?, fallback: String = "Terminal") -> String {
        pane.customLabel ?? meaningful(pane.agentTitle, tool: pane.agent)
            ?? meaningful(tab?.customLabel, tool: pane.agent)
            ?? meaningful(pane.sessionName, tool: pane.agent)
            ?? meaningful(pane.terminalTitle, tool: pane.agent)
            ?? pane.agent ?? fallback
    }
    public static func agentRow(_ pane: Item, tab: Item?, fallback: String) -> String {
        authoredTask(pane.customLabel, tool: pane.agent) ?? meaningful(pane.agentTitle, tool: pane.agent)
            ?? authoredTask(tab?.customLabel, tool: pane.agent) ?? meaningful(pane.sessionName, tool: pane.agent)
            ?? meaningful(pane.terminalTitle, tool: pane.agent) ?? pane.cwd.map(directory) ?? fallback
    }
    /// Shorten only a recognizable shell location, preserving authored labels and OSC tasks.
    private static func authoredTask(_ value: String?, tool: String?) -> String? {
        guard let value = clean(value) else { return nil }
        return isToolName(value.lowercased(), tool: tool) ? nil : value
    }
    public static func terminal(_ pane: Item, fallback: String = "Terminal") -> String {
        if let label = pane.customLabel { return label }
        if let title = pane.terminalTitle {
            if let cwd = pane.cwd {
                if title == cwd { return directory(cwd) }
                let parts = title.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2, matches(userHost, parts[0]) {
                    let path = parts[1]
                    if path == cwd || (path.hasPrefix("~/") && cwd.hasSuffix(String(path.dropFirst()))) {
                        return directory(path)
                    }
                    if path == "~", (cwd as NSString).lastPathComponent == parts[0].components(separatedBy: "@")[0] { return "~" }
                }
            }
            return title
        }
        return pane.cwd.map(directory) ?? fallback
    }
    private static func directory(_ path: String) -> String {
        let last = (path as NSString).lastPathComponent
        return last.isEmpty ? path : last
    }
    public static func detail(_ parts: [String?]) -> String { parts.compactMap(clean).joined(separator: " · ") }
}

/// Keep selection on a surviving neighbour in the previous visual order.
public enum NeighbourSelection {
    public static func resolve(_ selected: String?, previous: [String], current: [String]) -> String? {
        guard let selected else { return current.first }
        if current.contains(selected) { return selected }
        guard let index = previous.firstIndex(of: selected) else { return current.first }
        for distance in 1...max(previous.count, 1) {
            if index + distance < previous.count, current.contains(previous[index + distance]) { return previous[index + distance] }
            if index - distance >= 0, current.contains(previous[index - distance]) { return previous[index - distance] }
        }
        return current.first
    }
}

/// A disappearing highlighted object invalidates Enter until a deliberate selection.
public struct SearchSelection: Sendable {
    public private(set) var id: String?
    public init() {}
    public mutating func reset(_ results: [String]) { id = results.first }
    public mutating func reconcile(_ results: [String]) { if let id, !results.contains(id) { self.id = nil } }
    public mutating func choose(_ id: String) { self.id = id }
    public mutating func move(_ step: Int, in results: [String]) {
        guard !results.isEmpty else { id = nil; return }
        let index = id.flatMap { results.firstIndex(of: $0) } ?? (step > 0 ? -1 : results.count)
        id = results[min(results.count - 1, max(0, index + step))]
    }
}
