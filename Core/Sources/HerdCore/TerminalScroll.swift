import Foundation

/// Accumulate native wheel samples for Herdr's line-based history API.
/// Positive deltas move toward older output; fractional trackpad motion survives batches.
public struct TerminalScroll: Sendable {
    private var remainder: Double = 0
    public init() {}
    public mutating func lines(delta: Double, precise: Bool, lineHeight: Double) -> Int {
        guard delta.isFinite, lineHeight.isFinite, lineHeight > 0 else { return 0 }
        let amount = precise ? delta / lineHeight : delta * 3
        if amount * remainder < 0 { remainder = 0 }
        let total = max(-10_000, min(10_000, remainder + amount))
        let lines = Int(total)
        remainder = total - Double(lines)
        return lines
    }
    public static func offset(current: Int, maximum: Int, lines: Int) -> Int {
        let maximum = max(0, maximum), current = max(0, min(maximum, current))
        return lines > 0 ? current + min(lines, maximum - current) : current + max(lines, -current)
    }
}
