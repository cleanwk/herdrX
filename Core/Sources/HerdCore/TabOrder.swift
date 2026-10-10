import Foundation

/// A move is anchored to another tab, so replaying later moves survives a failed RPC.
public struct TabOrder: Sendable {
    public struct Move: Identifiable, Sendable {
        public let id: UUID
        public let source: String
        public let before: String?
        public let atStart: Bool
    }
    public private(set) var base: [String]
    public private(set) var pending: [Move] = []
    public init(_ ids: [String]) { base = ids }
    public var visible: [String] { pending.reduce(base) { Self.apply($1, to: $0) } }
    public mutating func enqueue(source: String, insertion: Int) {
        let ids = visible
        guard let old = ids.firstIndex(of: source) else { return }
        var rest = ids; rest.remove(at: old)
        let index = max(0, min(rest.count, insertion > old ? insertion - 1 : insertion))
        pending.append(Move(id: UUID(), source: source, before: index < rest.count ? rest[index] : nil, atStart: index == 0))
    }
    public func serverIndex(_ move: Move) -> Int { move.atStart ? 0 : move.before.flatMap { base.firstIndex(of: $0) } ?? base.count }
    public mutating func complete(_ id: UUID, server: [String]?) {
        guard pending.first?.id == id else { return }
        pending.removeFirst(); if let server { base = server }
    }
    public mutating func synchronize(_ ids: [String]) { base = ids }
    private static func apply(_ move: Move, to ids: [String]) -> [String] {
        guard ids.contains(move.source) else { return ids }
        var next = ids.filter { $0 != move.source }
        let index = move.atStart ? 0 : move.before.flatMap { next.firstIndex(of: $0) } ?? next.count
        next.insert(move.source, at: index); return next
    }
}
